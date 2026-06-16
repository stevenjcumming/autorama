#!/usr/bin/env bash
#
# check-edit.sh - PostToolUse hook on Write|Edit for per-edit analysis
#
# Runs the project's configured static analysis against the file that
# was just edited and exits 2 with the error output on failure, so
# Claude gets immediate feedback and fixes the problem while the edit
# is still in context. The analyzer agent still performs the
# full-project pass during the execute loop; this hook handles per-edit
# feedback deterministically.
#
# Triggered by: PostToolUse hook on Write|Edit|MultiEdit
#
# Configuration (.claude/autocode.yml):
#   static_analysis:
#     enabled: true          # master switch
#     on_edit:
#       enabled: true        # this hook's toggle (default on when the
#                            # section exists; projects with slow
#                            # linters can set false to opt out)
#       command: ""          # per-file command; the edited file path is
#                            # appended (e.g. "npx eslint"). When empty,
#                            # falls back to the first simple string in
#                            # static_analysis.commands.
#
# Exit codes: 0 = pass/skip, 2 = analysis failed (stderr fed to Claude).
# PostToolUse cannot block (the edit already happened); exit 2 feeds
# stderr back to Claude as feedback.
#

set -euo pipefail

HOOK_NAME="check-edit"

log_hook_error() {
  [ -z "${CLAUDE_PLUGIN_DATA:-}" ] && return 0
  mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || return 0
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  if command -v jq &> /dev/null; then
    jq -cn --arg ts "$ts" --arg hook "$HOOK_NAME" --arg reason "$1" --arg payload "${INPUT:-}" \
      '{timestamp: $ts, hook: $hook, reason: $reason, payload: $payload[0:2000]}' \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  else
    printf '{"timestamp":"%s","hook":"%s","reason":"%s"}\n' "$ts" "$HOOK_NAME" "$1" \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  fi
  return 0
}

CONFIG_FILE=".claude/autocode.yml"

# No config, nothing to run
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

# Master switch and per-edit toggle. The toggle defaults to ON: it only
# disables when explicitly set to false.
if grep -qE '^[[:space:]]*enabled:[[:space:]]*false' <(grep -A2 '^static_analysis:' "$CONFIG_FILE" 2>/dev/null) 2>/dev/null; then
  exit 0
fi
ON_EDIT_BLOCK=$(awk '/^[[:space:]]{2}on_edit:/{f=1; next} f && /^[[:space:]]{0,2}[a-z_]+:/{f=0} f{print}' "$CONFIG_FILE" 2>/dev/null || true)
if echo "$ON_EDIT_BLOCK" | grep -qE '^[[:space:]]*enabled:[[:space:]]*false'; then
  exit 0
fi

# Parse the edited file path from the documented PostToolUse payload
if ! command -v jq &> /dev/null; then
  exit 0
fi

INPUT=$(cat)

if ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  log_hook_error "stdin payload is not valid JSON"
  exit 0
fi

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)
if [ -z "$FILE_PATH" ] || [ ! -f "$FILE_PATH" ]; then
  exit 0
fi

# Never lint the spec workspace or the plugin's own config
case "$FILE_PATH" in
  *.specs/*|*.claude/*) exit 0 ;;
esac

# Resolve the per-file command: on_edit.command first, then the first
# simple string entry under static_analysis.commands.
CHECK_CMD=$(echo "$ON_EDIT_BLOCK" | sed -n 's/^[[:space:]]*command:[[:space:]]*//p' | head -1 | sed 's/^["'\'']//; s/["'\'']$//' || true)
if [ -z "$CHECK_CMD" ]; then
  CHECK_CMD=$(awk '/^static_analysis:/{f=1; next} f && /^[a-z_]/{f=0} f && /^[[:space:]]+commands:/{c=1; next} f && c && /^[[:space:]]+-[[:space:]]+[^[:space:]]/{sub(/^[[:space:]]+-[[:space:]]+/, ""); print; exit} f && c && /^[[:space:]]+[a-z_]+:/{c=0}' "$CONFIG_FILE" 2>/dev/null || true)
  # Skip the structured "- command:" form; only simple strings are safe
  # to append a file path to.
  case "$CHECK_CMD" in
    command:*|"") CHECK_CMD="" ;;
  esac
fi

if [ -z "$CHECK_CMD" ]; then
  exit 0
fi

# Run the check against the edited file. Exit 2 feeds the output back
# to Claude for an immediate fix.
set +e
OUTPUT=$($CHECK_CMD "$FILE_PATH" 2>&1)
STATUS=$?
set -e

if [ "$STATUS" -ne 0 ]; then
  {
    echo "autocode check-edit: '$CHECK_CMD $FILE_PATH' failed (exit $STATUS). Fix these issues now:"
    echo "$OUTPUT" | head -50
  } >&2
  exit 2
fi

exit 0
