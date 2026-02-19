#!/bin/bash
#
# read-handoff.sh - Read handoff context for next agent
#
# Reads and combines context from:
# - handoff.md (previous task handoff)
# - TODO.md (next task to execute)
#
# Usage: read-handoff.sh <spec_dir>
#

set -e

SPEC_DIR="$1"

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required"
  echo "Usage: read-handoff.sh <spec_dir>"
  exit 1
fi

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec directory does not exist at $SPEC_DIR"
  exit 1
fi

# ============================================================================
# Handoff Context
# ============================================================================

HANDOFF_FILE="$SPEC_DIR/artifacts/handoff/handoff.md"
if [ -f "$HANDOFF_FILE" ]; then
  echo "<handoff-context>"
  cat "$HANDOFF_FILE"
  echo "</handoff-context>"
  echo ""
fi

# ============================================================================
# Current Task from TODO.md
# ============================================================================

TODO_FILE="$SPEC_DIR/TODO.md"
if [ -f "$TODO_FILE" ]; then
  echo "<current-task>"

  # Extract first uncompleted task
  NEXT_TASK=$(grep -m1 '^- \[ \]' "$TODO_FILE" 2>/dev/null || echo "")

  if [ -n "$NEXT_TASK" ]; then
    echo "$NEXT_TASK"

    # Try to extract task ID and find related context
    TASK_ID=$(echo "$NEXT_TASK" | grep -oE '\[T[0-9]+\]' | head -1 || echo "")
    if [ -n "$TASK_ID" ]; then
      # Get any additional context for this task from TODO.md
      # (subtasks or notes indented under the main task)
      TASK_LINE=$(grep -n "^- \[ \] $TASK_ID" "$TODO_FILE" | head -1 | cut -d: -f1)
      if [ -n "$TASK_LINE" ]; then
        # Get indented lines following the task (subtasks/notes)
        NEXT_LINE=$((TASK_LINE + 1))
        sed -n "${NEXT_LINE},\$p" "$TODO_FILE" | while IFS= read -r line; do
          # Stop at next task or phase header
          if echo "$line" | grep -qE '^- \[|^## '; then
            break
          fi
          # Output indented content
          if echo "$line" | grep -qE '^[[:space:]]+'; then
            echo "$line"
          fi
        done
      fi
    fi
  else
    echo "<!-- No uncompleted tasks found -->"
  fi

  echo "</current-task>"
  echo ""
fi

# ============================================================================
# Summary
# ============================================================================

# Count remaining tasks for context
if [ -f "$TODO_FILE" ]; then
  REMAINING=$(grep -c '^- \[ \]' "$TODO_FILE" 2>/dev/null || echo "0")
  COMPLETED=$(grep -c '^- \[x\]' "$TODO_FILE" 2>/dev/null || echo "0")

  echo "<progress-summary>"
  echo "Tasks completed: $COMPLETED"
  echo "Tasks remaining: $REMAINING"
  echo "</progress-summary>"
fi
