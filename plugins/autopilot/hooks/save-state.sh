#!/bin/bash
#
# save-state.sh - PostToolUse hook for saving agent state
#
# Saves state after Task tool completes for autopilot agents.
# This hook is a lightweight state tracker - the main commit and
# handoff logic is handled by on-agent-complete.sh (SubagentStop hook).
#
# Triggered by: PostToolUse hook on Task tool
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
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty')

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
# Extract task completion status
# ============================================================================

# Check if task was completed (look for completion markers in output)
TASK_COMPLETED=false
if echo "$TOOL_OUTPUT" | grep -qiE 'Task Completed|task.*complete|## Task Completed'; then
  TASK_COMPLETED=true
fi

# Extract task ID from output if available
TASK_ID=$(echo "$TOOL_OUTPUT" | grep -oE '\[T[0-9]+\]' | head -1 || echo "")

# ============================================================================
# Update state tracking file
# ============================================================================

STATE_DIR="$SPEC_DIR/artifacts/state"
mkdir -p "$STATE_DIR"

STATE_FILE="$STATE_DIR/current.json"
ISO_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# Create or update state file
if command -v jq &> /dev/null; then
  # Build state JSON
  cat > "$STATE_FILE" << EOF
{
  "last_agent": "$SUBAGENT_TYPE",
  "last_task": "$TASK_ID",
  "task_completed": $TASK_COMPLETED,
  "timestamp": "$ISO_TIMESTAMP",
  "spec_dir": "$SPEC_DIR"
}
EOF
fi

# ============================================================================
# Signal task completion
# ============================================================================

if [ "$TASK_COMPLETED" = "true" ] && [ -n "$TASK_ID" ]; then
  echo "<task-completed task=\"$TASK_ID\" agent=\"$SUBAGENT_TYPE\" />"
fi
