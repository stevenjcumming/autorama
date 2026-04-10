#!/bin/bash
#
# build-task-queue.sh - Parse TODO.md and build a filtered task queue
#
# Parses TODO.md to extract uncompleted tasks, optionally filtering by
# task ID (T<n>) or phase (P<n>). Outputs one task per line in a
# structured format for consumption by agents and other scripts.
#
# Usage: build-task-queue.sh <spec_dir> [filter]
#
# Arguments:
#   spec_dir  Path to the spec directory (e.g., .claude/specs/auth-refactor)
#   filter    Optional: T<n> for single task, P<n> for phase
#
# Output (one per line):
#   TASK:<task_id>:<phase>:<description>
#
# Exit codes:
#   0 - Success (outputs task lines)
#   1 - Error (missing arguments, file not found, invalid filter)
#

set -e

SPEC_DIR="$1"
FILTER="$2"

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required"
  echo "Usage: build-task-queue.sh <spec_dir> [T<n>|P<n>]"
  exit 1
fi

TODO_FILE="$SPEC_DIR/TODO.md"

if [ ! -f "$TODO_FILE" ]; then
  echo "Error: TODO.md not found at $TODO_FILE"
  exit 1
fi

# ============================================================================
# Parse TODO.md
# ============================================================================

CURRENT_PHASE=""
TASK_COUNT=0

while IFS= read -r line; do
  # Detect phase headers (e.g., "## P1: Foundation" or "## Phase 1: Foundation")
  if echo "$line" | grep -qE '^## (P[0-9]+|Phase [0-9]+)'; then
    # Extract phase ID (normalize "Phase 1" to "P1")
    CURRENT_PHASE=$(echo "$line" | grep -oE '(P[0-9]+|Phase [0-9]+)' | head -1)
    CURRENT_PHASE=$(echo "$CURRENT_PHASE" | sed 's/Phase /P/')
    continue
  fi

  # Match uncompleted tasks: "- [ ] [T1] Description" or "- [ ] Description"
  if echo "$line" | grep -qE '^\s*- \[ \]'; then
    # Extract task ID if present (e.g., [T1], [T2])
    TASK_ID=$(echo "$line" | grep -oE '\[T[0-9]+\]' | tr -d '[]' || echo "")

    # Extract description (strip checkbox and task ID)
    DESCRIPTION=$(echo "$line" | sed 's/^\s*- \[ \]\s*//' | sed 's/\[T[0-9]*\]\s*//')

    # Apply filter
    if [ -n "$FILTER" ]; then
      if [[ "$FILTER" =~ ^T[0-9]+$ ]]; then
        # Task filter: only include matching task
        if [ "$TASK_ID" != "$FILTER" ]; then
          continue
        fi
      elif [[ "$FILTER" =~ ^P[0-9]+$ ]]; then
        # Phase filter: only include tasks in matching phase
        if [ "$CURRENT_PHASE" != "$FILTER" ]; then
          continue
        fi
      else
        echo "Error: Invalid filter '$FILTER'. Use T<n> for tasks or P<n> for phases."
        exit 1
      fi
    fi

    # Output structured task line
    echo "TASK:${TASK_ID:-none}:${CURRENT_PHASE:-none}:${DESCRIPTION}"
    TASK_COUNT=$((TASK_COUNT + 1))
  fi
done < "$TODO_FILE"

# Summary line
echo "TOTAL:$TASK_COUNT"

if [ "$TASK_COUNT" -eq 0 ]; then
  if [ -n "$FILTER" ]; then
    echo "Warning: No uncompleted tasks matching filter '$FILTER'" >&2
  else
    echo "Warning: No uncompleted tasks found" >&2
  fi
fi
