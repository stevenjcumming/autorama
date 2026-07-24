#!/usr/bin/env bash
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
#   spec_dir  Path to the spec directory (e.g., .specs/auth-refactor)
#   filter    Optional: T<n> for single task, P<n> for phase
#
# Output (one per line):
#   TASK:<task_id>:<phase>:<rating>:<description>
#
#   The line is colon-delimited with exactly 4 leading colons; everything
#   after the fourth colon is the description verbatim (it may itself
#   contain colons - do not split on every colon, split on the first 4
#   only and take the remainder as-is). <task_id> is the bare ID without
#   brackets (e.g. "T1"), or the literal string "none" if the checkbox had
#   no [T<n>] tag; <phase> is "P<n>" or "none" likewise. <rating> is the
#   task's difficulty annotation from TODO.md ("easy", "standard", or
#   "hard", written as "- [ ] [T1] (easy) Description"); a missing or
#   unrecognized annotation emits "standard" (tolerant parsing, never an
#   error). Recognized annotations are stripped from the description;
#   unrecognized parenthesized text is left in place. The task-runner's
#   C table (see docs/MODEL_SELECTION.md) consumes the rating.
#
# Exit codes:
#   0 - Success (outputs task lines)
#   1 - Error (missing/invalid arguments, file not found, invalid filter)
#

set -euo pipefail

# shellcheck source=../../../scripts/lib.sh
source "$(dirname "$0")/../../../scripts/lib.sh"

SPEC_DIR="${1:-}"
FILTER="${2:-}"

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required"
  echo "Usage: build-task-queue.sh <spec_dir> [T<n>|P<n>]"
  exit 1
fi

# Validate the identifier component of the path (this script is documented
# as a standalone tool and, unlike its siblings, previously did no
# identifier/path validation at all).
require_identifier "$(basename "$SPEC_DIR")" "Error: invalid spec directory '$SPEC_DIR'"

TODO_FILE="$SPEC_DIR/TODO.md"

if [ ! -f "$TODO_FILE" ]; then
  echo "Error: TODO.md not found at $TODO_FILE"
  exit 1
fi

# ==============================================================================
# is_phase_header_line - detect a TODO.md phase header line and normalize
# its phase ID to the "P<n>" form. Recognizes both "## P1: Foundation" and
# "## Phase 1: Foundation".
#
# This function is intentionally byte-for-byte identical to the copy in
# skills/execute/scripts/validate-autocode.sh - the two scripts must never
# disagree on what counts as a phase header again. Kept as a local copy
# rather than moved into scripts/lib.sh for this change.
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

# ============================================================================
# Parse TODO.md
# ============================================================================

CURRENT_PHASE=""
TASK_COUNT=0

while IFS= read -r line; do
  # Detect phase headers (e.g., "## P1: Foundation" or "## Phase 1: Foundation")
  if is_phase_header_line "$line"; then
    CURRENT_PHASE="$PHASE_HEADER_MATCH"
    continue
  fi

  # Match uncompleted tasks: "- [ ] [T1] Description" or "- [ ] Description"
  if echo "$line" | grep -qE '^[[:space:]]*- \[ \]'; then
    # Strip the checkbox prefix once, anchored to the start of the line,
    # so what remains starts at the task ID (if present) or straight at
    # the description.
    REST=$(printf '%s' "$line" | sed -E 's/^[[:space:]]*- \[ \][[:space:]]*//')

    # Extract the task ID only when it appears immediately at the start
    # of REST (anchored) - an unanchored match could otherwise pick up a
    # `[T2]` mentioned mid-description as if it were the task's own ID
    # (item 37b).
    if [[ "$REST" =~ ^\[T[0-9]+\] ]]; then
      TASK_ID=$(printf '%s' "$REST" | grep -oE '^\[T[0-9]+\]' | tr -d '[]')
      DESCRIPTION=$(printf '%s' "$REST" | sed -E 's/^\[T[0-9]+\][[:space:]]*//')
    else
      TASK_ID=""
      DESCRIPTION="$REST"
    fi

    # Extract the optional difficulty rating annotation, e.g.
    # "(easy) Update README". Only the three recognized ratings are
    # stripped from the description; any other parenthesized text (e.g.
    # "(optional)") is left in the description untouched and the rating
    # falls back to "standard". Tolerant by design: never an error.
    RATING="standard"
    if [[ "$DESCRIPTION" =~ ^\((easy|standard|hard)\)[[:space:]]* ]]; then
      RATING="${BASH_REMATCH[1]}"
      DESCRIPTION=$(printf '%s' "$DESCRIPTION" | sed -E 's/^\((easy|standard|hard)\)[[:space:]]*//')
    fi

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
        echo "Error: Invalid filter '$FILTER'. Use T<n> for tasks or P<n> for phases." >&2
        exit 1
      fi
    fi

    # Output structured task line
    echo "TASK:${TASK_ID:-none}:${CURRENT_PHASE:-none}:${RATING}:${DESCRIPTION}"
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
