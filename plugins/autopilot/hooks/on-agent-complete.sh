#!/bin/bash
#
# on-agent-complete.sh - SubagentStop hook for autopilot task completion
#
# Handles post-task-completion actions:
# 1. Check context limits and signal if summarization needed
# 2. Signal completion to execute command
#
# Triggered by: SubagentStop hook
#

set -e

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract agent info
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // empty')
AGENT_OUTPUT=$(echo "$INPUT" | jq -r '.agent_output // empty')

# Only trigger for autopilot agents
if [[ "$AGENT_NAME" != autopilot-* ]]; then
  exit 0
fi

# ============================================================================
# Find spec directory using shared utility
# ============================================================================

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
FIND_SPEC_SCRIPT="$PLUGIN_DIR/scripts/find-active-spec.sh"

SPEC_DIR=""
if [ -x "$FIND_SPEC_SCRIPT" ]; then
  FIND_RESULT=$("$FIND_SPEC_SCRIPT" 2>/dev/null || echo "NOT_FOUND")
  if [[ "$FIND_RESULT" == FOUND:* ]]; then
    SPEC_DIR=$(echo "$FIND_RESULT" | cut -d: -f2)
  fi
else
  # Fallback: find any spec directory with a TODO.md
  for todo_file in .claude/specs/*/TODO.md; do
    if [ -f "$todo_file" ]; then
      SPEC_DIR=$(dirname "$todo_file")
      break
    fi
  done
fi

# If no spec found, exit silently
if [ -z "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
  exit 0
fi

# ============================================================================
# Detect task completion from agent output
# ============================================================================

TASK_COMPLETED="false"
TASK_ID=""

if [ -n "$AGENT_OUTPUT" ]; then
  if echo "$AGENT_OUTPUT" | grep -qE '<task-completed[^>]*status="completed"'; then
    TASK_COMPLETED="true"
  elif echo "$AGENT_OUTPUT" | grep -qiE '## Task Completed|task.*complete'; then
    TASK_COMPLETED="true"
  fi

  # Try structured tag first, then bracketed ID
  TASK_ID=$(echo "$AGENT_OUTPUT" | grep -oE '<task-completed[^>]*task="[^"]*"' | grep -oE 'task="[^"]*"' | head -1 | tr -d 'task="' || echo "")
  if [ -z "$TASK_ID" ]; then
    TASK_ID=$(echo "$AGENT_OUTPUT" | grep -oE '\[T[0-9]+\]' | head -1 || echo "")
  fi
fi

# Only proceed if task was completed
if [ "$TASK_COMPLETED" != "true" ]; then
  exit 0
fi

# Extract spec_id from path
SPEC_ID=$(basename "$SPEC_DIR")

# ============================================================================
# Check context limits and trigger session summary if needed
# ============================================================================

CHECK_CONTEXT_SCRIPT="$PLUGIN_DIR/scripts/check-context.sh"

if [ -x "$CHECK_CONTEXT_SCRIPT" ]; then
  CONTEXT_RESULT=$("$CHECK_CONTEXT_SCRIPT" "$SPEC_DIR" 2>/dev/null || echo "OK:0")

  case "$CONTEXT_RESULT" in
    CRITICAL:*)
      # Context is critically high - signal for immediate summarization
      ESTIMATED_TOKENS=$(echo "$CONTEXT_RESULT" | cut -d: -f3)
      echo "<context-critical tokens=\"$ESTIMATED_TOKENS\" spec=\"$SPEC_ID\">"
      echo "  Context usage is critically high. Session summarization required."
      echo "  Consider spawning session-summarizer agent before continuing."
      echo "</context-critical>"
      ;;
    WARNING:*)
      # Context is approaching limit - signal warning
      ESTIMATED_TOKENS=$(echo "$CONTEXT_RESULT" | cut -d: -f3)
      echo "<context-warning tokens=\"$ESTIMATED_TOKENS\" spec=\"$SPEC_ID\" />"
      ;;
    OK:*)
      # Context is fine - no action needed
      ;;
  esac
fi

# ============================================================================
# Signal completion
# ============================================================================

echo "<agent-completed agent=\"$AGENT_NAME\" task=\"$TASK_ID\" spec=\"$SPEC_ID\" />"
