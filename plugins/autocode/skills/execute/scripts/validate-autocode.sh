#!/usr/bin/env bash

set -euo pipefail

# ==============================================================================
# is_phase_header_line - detect a TODO.md phase header line and normalize
# its phase ID to the "P<n>" form. Recognizes both "## P1: Foundation" and
# "## Phase 1: Foundation", matching what build-task-queue.sh accepts.
#
# This function is intentionally byte-for-byte identical to the copy in
# skills/execute/scripts/build-task-queue.sh - the two scripts must never
# disagree on what counts as a phase header again (a TODO.md using the
# "Phase 1" form previously failed validation here even though the queue
# builder already handled it). Kept as a local copy rather than moved into
# scripts/lib.sh for this change.
#
# Usage: if is_phase_header_line "$line"; then phase="$PHASE_HEADER_MATCH"; fi
# Sets PHASE_HEADER_MATCH to the normalized "P<n>" ID on success. Returns 0
# if the line is a phase header, 1 otherwise.
# ==============================================================================
is_phase_header_line() {
  local line="$1"
  if echo "$line" | grep -qE '^## (P[0-9]+|Phase [0-9]+)'; then
    PHASE_HEADER_MATCH=$(echo "$line" | grep -oE '(P[0-9]+|Phase [0-9]+)' | head -1)
    PHASE_HEADER_MATCH="${PHASE_HEADER_MATCH/Phase /P}"
    return 0
  fi
  return 1
}

IDENTIFIER="${1:-}"
FILTER="${2:-}"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: spec identifier is required"
  echo "Usage: validate-autocode.sh <identifier> [T<n>|P<n>]"
  exit 1
fi

if [[ ! "$IDENTIFIER" =~ ^[A-Za-z0-9._-]+$ ]] || [[ "$IDENTIFIER" =~ ^\.+$ ]]; then
  echo "Error: invalid identifier '$IDENTIFIER' (allowed: letters, digits, '.', '_', '-'; must not be only dots)"
  exit 1
fi

SPEC_DIR=".specs/$IDENTIFIER"

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec directory does not exist at $SPEC_DIR"
  echo "Run '/autocode:new-spec $IDENTIFIER' to create it first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/SPEC.md" ]; then
  echo "Error: SPEC.md not found in $SPEC_DIR"
  echo "Run '/autocode:new-spec' to create the spec first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/PLAN.md" ]; then
  echo "Error: PLAN.md not found in $SPEC_DIR"
  echo "Run '/autocode:create-plan' to create the plan first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/TODO.md" ]; then
  echo "Error: TODO.md not found in $SPEC_DIR"
  echo "Run '/autocode:create-tasks' to create the task list first"
  exit 1
fi

# Check for uncompleted tasks (lines with "- [ ]", including indented sub-tasks)
UNCOMPLETED_TASKS=$(grep -cE '^[[:space:]]*- \[ \]' "$SPEC_DIR/TODO.md" || true)

if [ "$UNCOMPLETED_TASKS" -eq "0" ]; then
  echo "Error: No uncompleted tasks found in $SPEC_DIR/TODO.md"
  echo "All tasks appear to be completed"
  exit 1
fi

# Validate filter if provided
if [ -n "$FILTER" ]; then
  if [[ "$FILTER" =~ ^T[0-9]+$ ]]; then
    # Task filter (e.g., T1, T3, T12)
    if ! grep -q "\[$FILTER\]" "$SPEC_DIR/TODO.md"; then
      echo "Error: Task $FILTER not found in TODO.md"
      exit 1
    fi
    if ! grep -qE "^[[:space:]]*- \[ \] \[$FILTER\]" "$SPEC_DIR/TODO.md"; then
      echo "Error: Task $FILTER is already completed"
      exit 1
    fi
    echo "Filter: Task $FILTER"
  elif [[ "$FILTER" =~ ^P[0-9]+$ ]]; then
    # Phase filter (e.g., P1, P2). Accepts both "## P1: Name" and
    # "## Phase 1: Name" headers via the shared is_phase_header_line
    # matcher, so this stays in sync with build-task-queue.sh.
    FOUND_PHASE="false"
    while IFS= read -r line; do
      if is_phase_header_line "$line" && [ "$PHASE_HEADER_MATCH" = "$FILTER" ]; then
        FOUND_PHASE="true"
        break
      fi
    done < "$SPEC_DIR/TODO.md"
    if [ "$FOUND_PHASE" != "true" ]; then
      echo "Error: Phase $FILTER not found in TODO.md"
      exit 1
    fi
    echo "Filter: Phase $FILTER"
  else
    echo "Error: Invalid filter '$FILTER'"
    echo "Use T<number> for tasks (e.g., T1) or P<number> for phases (e.g., P1)"
    exit 1
  fi
fi

echo "Validation passed for $SPEC_DIR"
echo "Found $UNCOMPLETED_TASKS uncompleted task(s)"
