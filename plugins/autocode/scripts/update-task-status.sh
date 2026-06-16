#!/usr/bin/env bash
#
# update-task-status.sh - Mark a task as completed in TODO.md
#
# Finds a task by ID or description in TODO.md and changes its checkbox
# from "- [ ]" to "- [x]". Optionally appends a timestamp comment.
#
# Usage: update-task-status.sh <spec_dir> <task_id> [--timestamp]
#
# Arguments:
#   spec_dir    Path to the spec directory
#   task_id     Task ID to mark complete (e.g., T1, T3)
#   --timestamp Append ISO timestamp after the task line
#
# Output:
#   UPDATED:<task_id>:<description>   - Task was marked complete
#   NOT_FOUND:<task_id>               - Task ID not found in TODO.md
#   ALREADY_DONE:<task_id>            - Task was already completed
#
# Exit codes:
#   0 - Success (task updated or already done)
#   1 - Error (missing arguments, file not found, task not found)
#

set -euo pipefail

SPEC_DIR="${1:-}"
TASK_ID="${2:-}"
FLAG="${3:-}"

if [ -z "$SPEC_DIR" ] || [ -z "$TASK_ID" ]; then
  echo "Error: spec directory and task ID are required"
  echo "Usage: update-task-status.sh <spec_dir> <task_id> [--timestamp]"
  exit 1
fi

TODO_FILE="$SPEC_DIR/TODO.md"

if [ ! -f "$TODO_FILE" ]; then
  echo "Error: TODO.md not found at $TODO_FILE"
  exit 1
fi

# ============================================================================
# Check if task exists and its current status
# ============================================================================

# Look for the task ID in brackets (e.g., [T1])
TASK_PATTERN="\[$TASK_ID\]"

if ! grep -q "$TASK_PATTERN" "$TODO_FILE"; then
  echo "NOT_FOUND:$TASK_ID"
  exit 1
fi

# Check if already completed
if grep -q "^[[:space:]]*- \[x\] $TASK_PATTERN" "$TODO_FILE"; then
  DESCRIPTION=$(grep "$TASK_PATTERN" "$TODO_FILE" | sed "s/.*${TASK_PATTERN}[[:space:]]*//" | head -1)
  echo "ALREADY_DONE:$TASK_ID:$DESCRIPTION"
  exit 0
fi

# Check if it's an uncompleted task
if ! grep -q "^[[:space:]]*- \[ \] $TASK_PATTERN" "$TODO_FILE"; then
  # Task ID exists but not as a checkbox item
  echo "NOT_FOUND:$TASK_ID"
  exit 1
fi

# ============================================================================
# Extract description before modifying
# ============================================================================

DESCRIPTION=$(grep "^[[:space:]]*- \[ \] $TASK_PATTERN" "$TODO_FILE" | sed "s/.*${TASK_PATTERN}[[:space:]]*//" | head -1)

# ============================================================================
# Update the task status
# ============================================================================

if [ "$FLAG" = "--timestamp" ]; then
  ISO_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
  # Replace checkbox and append timestamp
  sed -i.bak "s/^\([[:space:]]*\)- \[ \] \($TASK_PATTERN\)/\1- [x] \2/" "$TODO_FILE"
  # Add timestamp comment on the same line (after description)
  sed -i.bak "s/^\([[:space:]]*- \[x\] $TASK_PATTERN.*\)$/\1 <!-- completed: $ISO_TIMESTAMP -->/" "$TODO_FILE"
else
  # Just replace the checkbox
  sed -i.bak "s/^\([[:space:]]*\)- \[ \] \($TASK_PATTERN\)/\1- [x] \2/" "$TODO_FILE"
fi

# Clean up backup file created by sed -i
rm -f "$TODO_FILE.bak"

# Verify the rewrite actually happened (sed exits 0 even when nothing matched)
if ! grep -q "^[[:space:]]*- \[x\] $TASK_PATTERN" "$TODO_FILE"; then
  echo "Error: failed to mark task $TASK_ID complete in $TODO_FILE" >&2
  exit 1
fi

echo "UPDATED:$TASK_ID:$DESCRIPTION"
