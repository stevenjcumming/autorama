#!/usr/bin/env bash
# PreToolUse hook: Log when autocode skills/agents are invoked.
# Triggered on Task tool calls to track agent spawning.
#
# Reads tool_input from stdin (JSON with subagent_type, prompt).
# Logs to CLAUDE_PLUGIN_DATA/usage.jsonl via log-usage.sh.

set -euo pipefail

HOOK_NAME="log-skill-usage"

# Log unparseable/unexpected payloads so hook failures are observable
# instead of silent. Never fails the hook.
log_hook_error() {
  [ -z "${CLAUDE_PLUGIN_DATA:-}" ] && return 0
  mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || return 0
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  if command -v jq &>/dev/null; then
    jq -cn --arg ts "$ts" --arg hook "$HOOK_NAME" --arg reason "$1" --arg payload "${INPUT:-}" \
      '{timestamp: $ts, hook: $hook, reason: $reason, payload: $payload[0:2000]}' \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  else
    printf '{"timestamp":"%s","hook":"%s","reason":"%s"}\n' "$ts" "$HOOK_NAME" "$1" \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  fi
  return 0
}

# Require CLAUDE_PLUGIN_DATA
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"

# Read hook input from stdin
INPUT=$(cat)

# Parse documented JSON fields with jq first; there is no useful text
# fallback for subagent_type, so an unparseable payload is logged and
# skipped rather than guessed at.
if ! command -v jq &>/dev/null; then
  log_hook_error "jq not available; usage logging skipped"
  exit 0
fi

if ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  log_hook_error "stdin payload is not valid JSON"
  exit 0
fi

AGENT_NAME=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)

# Only log autocode agent spawns.
# Shared convention (also used by load-context.sh and on-agent-complete.sh):
# an autocode agent is one spawned with subagent_type "autocode:<name>".
if [ -z "$AGENT_NAME" ] || [[ "$AGENT_NAME" != autocode:* ]]; then
  exit 0
fi

# Strip prefix
SHORT_NAME="${AGENT_NAME#autocode:}"

# Extract SPEC_DIR from prompt if present
SPEC_DIR=""
if command -v jq &>/dev/null; then
  PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)
  # Use grep -oE for POSIX compatibility (grep -oP requires PCRE, unavailable on macOS)
  SPEC_DIR=$(echo "$PROMPT" | grep -oE 'SPEC_DIR[=:][[:space:]]*[^[:space:]]+' | head -1 | sed 's/^SPEC_DIR[=:][[:space:]]*//' || true)
fi

export SPEC_DIR
bash "$PLUGIN_ROOT/scripts/log-usage.sh" "agent_spawn" "$SHORT_NAME" "ok" ""
