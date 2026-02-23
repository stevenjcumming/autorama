#!/bin/bash
#
# load-context.sh - PreToolUse hook for loading agent context
#
# Loads context from handoff artifacts before spawning autopilot task
# agents. This ensures agents have relevant context from previous
# task completions.
#
# Triggered by: PreToolUse hook on Task tool
#

set -e

# Check for jq dependency (required for parsing JSON input)
if ! command -v jq &> /dev/null; then
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool name and subagent type
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')

# Only trigger for Task tool
if [ "$TOOL_NAME" != "Task" ]; then
  exit 0
fi

# Only trigger for autopilot agents
if [[ "$SUBAGENT_TYPE" != autopilot-* ]]; then
  exit 0
fi

# Try to extract spec_dir from the prompt
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty')

# Look for SPEC_DIR in the prompt
SPEC_DIR=$(echo "$PROMPT" | grep -oP 'SPEC_DIR[=:]\s*\K[^\s]+' | head -1 || echo "")

# If no SPEC_DIR found, try to find it from common patterns
if [ -z "$SPEC_DIR" ]; then
  SPEC_DIR=$(echo "$PROMPT" | grep -oP '\.claude/specs/[^\s/]+' | head -1 || echo "")
fi

# If still no SPEC_DIR, exit silently
if [ -z "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
  exit 0
fi

# ============================================================================
# Use read-handoff.sh if available (it provides richer context)
# ============================================================================

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-${AUTOPILOT_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}}"
READ_HANDOFF="$PLUGIN_DIR/scripts/read-handoff.sh"

if [ -x "$READ_HANDOFF" ]; then
  # Use the dedicated handoff reader script
  "$READ_HANDOFF" "$SPEC_DIR"
  exit 0
fi

# ============================================================================
# Fallback: Manual context loading
# ============================================================================

# Read handoff artifact
HANDOFF_FILE="$SPEC_DIR/artifacts/handoff/handoff.md"
if [ -f "$HANDOFF_FILE" ]; then
  echo "<handoff-context>"
  cat "$HANDOFF_FILE"
  echo "</handoff-context>"
  echo ""
fi

# Read current task from TODO.md
TODO_FILE="$SPEC_DIR/TODO.md"
if [ -f "$TODO_FILE" ]; then
  echo "<current-task>"

  # Extract first uncompleted task
  NEXT_TASK=$(grep -m1 '^- \[ \]' "$TODO_FILE" 2>/dev/null || echo "")

  if [ -n "$NEXT_TASK" ]; then
    echo "$NEXT_TASK"
  else
    echo "<!-- No uncompleted tasks found -->"
  fi

  echo "</current-task>"
fi
