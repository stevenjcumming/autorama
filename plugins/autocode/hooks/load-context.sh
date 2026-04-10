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

# Try to extract SPEC_DIR from structured tool input first, then fall back to prompt parsing
PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty')

# Method 1: Extract from structured env/arguments if available
SPEC_DIR=$(echo "$INPUT" | jq -r '.tool_input.env.SPEC_DIR // empty' 2>/dev/null)

# Method 2: Look for SPEC_DIR=value pattern in prompt (handles both = and : separators)
if [ -z "$SPEC_DIR" ]; then
  # Use grep -oE for POSIX compatibility (grep -oP requires PCRE, unavailable on macOS)
  SPEC_DIR=$(echo "$PROMPT" | grep -oE 'SPEC_DIR[=:][[:space:]]*[^[:space:]]+' | head -1 | sed 's/^SPEC_DIR[=:][[:space:]]*//' || echo "")
fi

# Method 3: Match .claude/specs/<id> path pattern anywhere in prompt
if [ -z "$SPEC_DIR" ]; then
  SPEC_DIR=$(echo "$PROMPT" | grep -oE '\.claude/specs/[^[:space:]/]+' | head -1 || echo "")
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
# Fallback: Condensed context loading
# ============================================================================

# Read condensed handoff summary (not the full file)
HANDOFF_FILE="$SPEC_DIR/artifacts/handoff/handoff.md"
if [ -f "$HANDOFF_FILE" ]; then
  TASK_ID=$(sed -n 's/^task_id:[[:space:]]*//p' "$HANDOFF_FILE" | head -1)
  STATUS=$(sed -n 's/^status:[[:space:]]*//p' "$HANDOFF_FILE" | head -1)
  BLOCKERS=$(sed -n '/^## Blockers/,/^## /{/^## /d;/^$/d;/^<!--/d;/^|--/d;/^| Blocker/d;p;}' "$HANDOFF_FILE" | head -3)
  WARNINGS=$(sed -n '/^## Warnings for Next Agent/,/^## /{/^## /d;/^$/d;/^<!--/d;p;}' "$HANDOFF_FILE" | head -3)

  echo "<handoff-context>"
  echo "Previous: $TASK_ID ($STATUS)"
  [ -n "$BLOCKERS" ] && echo "Blockers: $BLOCKERS"
  [ -n "$WARNINGS" ] && echo "Warnings: $WARNINGS"
  echo "</handoff-context>"
fi

# Read current task from TODO.md
TODO_FILE="$SPEC_DIR/TODO.md"
if [ -f "$TODO_FILE" ]; then
  NEXT_TASK=$(grep -m1 '^- \[ \]' "$TODO_FILE" 2>/dev/null || echo "")
  if [ -n "$NEXT_TASK" ]; then
    echo "<current-task>$NEXT_TASK</current-task>"
  fi
fi
