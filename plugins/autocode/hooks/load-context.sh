#!/usr/bin/env bash
#
# load-context.sh - PreToolUse hook for loading agent context
#
# Injects condensed handoff context when an autocode task agent is
# spawned, so agents have relevant context from previous task
# completions.
#
# Triggered by: PreToolUse hook on Task tool
#
# Injection mechanism (verified against the hooks reference, see
# docs/autocode/hook-system.md "Hook I/O Decision"): plain stdout from a
# PreToolUse hook is NOT added to model context, so echoing context here
# would never reach the spawned agent. The documented mechanism is JSON
# output with hookSpecificOutput.updatedInput, which rewrites the Task
# tool's input. This script appends the handoff context to the Task
# prompt that way. The full tool_input object is returned (not just the
# prompt field) because merge-vs-replace semantics for partial objects
# are not documented.
#

set -euo pipefail

HOOK_NAME="load-context"

# Log unparseable/unexpected payloads so hook failures are observable
# instead of silent. Never fails the hook.
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

# Check for jq dependency (required for parsing JSON input and for
# producing the updatedInput JSON output)
if ! command -v jq &> /dev/null; then
  log_hook_error "jq not available; context injection skipped"
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Validate the payload is JSON before doing anything else
if ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  log_hook_error "stdin payload is not valid JSON"
  exit 0
fi

# Extract documented JSON fields first (tool_name, tool_input.*); text
# matching below is only a fallback for values embedded in the prompt.
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || true)
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)

# Only trigger for Task tool
if [ "$TOOL_NAME" != "Task" ]; then
  exit 0
fi

# Shared convention (also used by log-skill-usage.sh and on-agent-complete.sh):
# an autocode agent is one spawned with subagent_type "autocode:<name>".
if [[ "$SUBAGENT_TYPE" != autocode:* ]]; then
  exit 0
fi

# Try to extract SPEC_DIR from structured tool input first, then fall back to prompt parsing
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)

# Method 1: Extract from structured env/arguments if available
SPEC_DIR=$(echo "$INPUT" | jq -r '.tool_input.env.SPEC_DIR // empty' 2>/dev/null || true)

# Method 2: Look for SPEC_DIR=value pattern in prompt (handles both = and : separators)
if [ -z "$SPEC_DIR" ]; then
  # Use grep -oE for POSIX compatibility (grep -oP requires PCRE, unavailable on macOS)
  SPEC_DIR=$(echo "$PROMPT" | grep -oE 'SPEC_DIR[=:][[:space:]]*[^[:space:]]+' | head -1 | sed 's/^SPEC_DIR[=:][[:space:]]*//' || true)
fi

# Method 3: Match .specs/<id> path pattern anywhere in prompt
if [ -z "$SPEC_DIR" ]; then
  SPEC_DIR=$(echo "$PROMPT" | grep -oE '\.specs/[^[:space:]/]+' | head -1 || true)
fi

# Strip trailing punctuation/backticks that prompts may wrap around the path
SPEC_DIR=$(printf '%s' "$SPEC_DIR" | sed "s/[\`'\".,;:)]*\$//")

# If still no SPEC_DIR, exit silently (an autocode agent without a spec
# is normal for some skills; nothing to inject)
if [ -z "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
  exit 0
fi

# ============================================================================
# Delegate to read-handoff.sh (provides the condensed handoff context)
# ============================================================================

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-${AUTOCODE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}}"
READ_HANDOFF="$PLUGIN_DIR/scripts/read-handoff.sh"

if [ ! -x "$READ_HANDOFF" ]; then
  log_hook_error "read-handoff.sh not found or not executable at $READ_HANDOFF"
  exit 0
fi

# Never block the Task call if the handoff reader fails
CONTEXT=$("$READ_HANDOFF" "$SPEC_DIR" 2>/dev/null || true)

if [ -z "$CONTEXT" ]; then
  exit 0
fi

# ============================================================================
# Emit updatedInput: append the handoff context to the Task prompt
# ============================================================================

# permissionDecision "allow" is paired with updatedInput per the documented
# example. Task spawns of plugin agents do not normally prompt, so this does
# not change effective permission behavior.
echo "$INPUT" | jq -c --arg ctx "$CONTEXT" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: "autocode load-context: appended handoff context to Task prompt",
    updatedInput: (.tool_input | .prompt = ((.prompt // "") + "\n\n" + $ctx))
  }
}' 2>/dev/null || log_hook_error "failed to build updatedInput JSON"

exit 0
