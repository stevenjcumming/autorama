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

# Shared helpers. Sourced before the local log_hook_error definition
# below, so that local definition - which uses this hook's existing
# single-arg call convention (relying on the global $INPUT for the
# payload rather than lib.sh's log_hook_error(hook, message, payload)
# signature) - intentionally shadows the one lib.sh provides, keeping
# the one existing call site in this file unchanged.
source "$(dirname "$0")/../scripts/lib.sh" 2>/dev/null || true
source "$(dirname "$0")/../scripts/read-config.sh" 2>/dev/null || true

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

# Parse the edited file path from the documented PostToolUse payload
# FIRST (item 43 partial): the config gate below needs the payload's
# .cwd to locate the project's config file, so INPUT must be read and
# parsed before any config-file check runs.
if ! command -v jq &> /dev/null; then
  exit 0
fi

INPUT=$(cat)

if ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  log_hook_error "stdin payload is not valid JSON"
  exit 0
fi

# Locate the project's config relative to the hook payload's cwd, not
# this process's own cwd (which need not match the project root the
# edit happened in).
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
if [ -z "$CWD" ]; then
  CWD="$(pwd)"
fi
CONFIG_FILE="$CWD/.claude/autocode.yml"

# No config, nothing to run
if [ ! -f "$CONFIG_FILE" ]; then
  exit 0
fi

# Master switch and per-edit toggle, both read via read_config_value
# (item 23/2.4 fix - replaces the old `grep -A2` window parsing, which
# broke the moment a comment line separated a parent key from its
# child, or any other `enabled:` key fell inside the grepped window).
# Both default to ON, matching the previous fallback: they only disable
# when explicitly set to false.
if command -v read_config_value >/dev/null 2>&1; then
  STATIC_ANALYSIS_ENABLED=$(read_config_value "$CONFIG_FILE" "static_analysis.enabled" "true")
  ON_EDIT_ENABLED=$(read_config_value "$CONFIG_FILE" "static_analysis.on_edit.enabled" "true")
else
  STATIC_ANALYSIS_ENABLED="true"
  ON_EDIT_ENABLED="true"
fi
if [ "$STATIC_ANALYSIS_ENABLED" = "false" ] || [ "$ON_EDIT_ENABLED" = "false" ]; then
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
CHECK_CMD=""
if command -v read_config_value >/dev/null 2>&1; then
  CHECK_CMD=$(read_config_value "$CONFIG_FILE" "static_analysis.on_edit.command" "")
fi
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

# Run the check against the edited file. Run via `bash -c` with the
# file path passed as a positional arg ($1), not word-split/glob-
# expanded from the config string directly (item 24/2.6 fix): the old
# `$CHECK_CMD "$FILE_PATH"` broke on any quoted arg or glob character in
# the configured command string. Exit 2 feeds the output back to Claude
# for an immediate fix.
set +e
OUTPUT=$(bash -c "$CHECK_CMD \"\$1\"" _ "$FILE_PATH" 2>&1)
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
