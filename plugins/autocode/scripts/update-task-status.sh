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
#   task_id     Task ID to mark complete (e.g., T1, T3) - must match ^T[0-9]+$
#   --timestamp Append ISO timestamp after the task line
#
# Output:
#   UPDATED:<task_id>:<description>   - Task was marked complete
#   NOT_FOUND:<task_id>               - Task ID not found in TODO.md
#   ALREADY_DONE:<task_id>            - Task was already completed
#
# Exit codes:
#   0 - Success (task updated or already done)
#   1 - Error (missing/invalid arguments, file not found, task not found,
#       or the file could not be updated after retrying concurrent writers)
#
# Concurrency:
#   Two task-runners can race to update the same TODO.md. There is no
#   flock here - it is not reliably available on macOS/Darwin (the primary
#   dev platform) without an extra install. Instead this script uses an
#   optimistic-concurrency pattern: snapshot the file, build the new
#   content in a temp file in the same directory (so the final `mv` is an
#   atomic same-filesystem rename), then re-snapshot the file immediately
#   before the `mv` as a cheap pre-check. That pre-check alone is not
#   sufficient though: two writers can both pass it (each reads the same
#   starting content and neither sees the other's write before its own
#   check) and then race on the `mv` itself, in which case the writer that
#   `mv`s last silently wins and the other's change is lost. To close that
#   gap, after the `mv` this script re-reads TODO_FILE and confirms ITS OWN
#   checkbox actually landed; if not (another writer's `mv` clobbered it
#   in the tiny window around our own), that counts as a conflict too and
#   the whole read-check-modify-verify cycle is retried (up to
#   MAX_ATTEMPTS times) rather than silently losing the update.
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

# Task IDs are always "T" followed by digits (e.g., T1, T23). Reject
# anything else before it is interpolated into the grep/sed patterns
# below - an ID containing '/', '.', '*', '&', or '\' would otherwise
# break or mis-match those patterns.
if [[ ! "$TASK_ID" =~ ^T[0-9]+$ ]]; then
  echo "Error: invalid task ID '$TASK_ID' (expected form: T<n>, e.g. T1, T23)"
  exit 1
fi

TODO_FILE="$SPEC_DIR/TODO.md"

if [ ! -f "$TODO_FILE" ]; then
  echo "Error: TODO.md not found at $TODO_FILE"
  exit 1
fi

# Look for the task ID in brackets (e.g., [T1]). Safe to interpolate now
# that TASK_ID is validated against ^T[0-9]+$ above.
TASK_PATTERN="\[$TASK_ID\]"

# ============================================================================
# snapshot - cheap content fingerprint of TODO_FILE used to detect
# concurrent writers between the moment we read the file and the moment
# we commit our own change.
# ============================================================================
snapshot() {
  cksum "$TODO_FILE" 2>/dev/null
}

MAX_ATTEMPTS=5
attempt=1

while :; do
  BEFORE_SNAPSHOT="$(snapshot)"

  # ==========================================================================
  # Check if task exists and its current status (re-checked on every
  # attempt in case a concurrent writer changed the task's status too).
  # ==========================================================================

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

  # ==========================================================================
  # Extract description before modifying
  # ==========================================================================

  DESCRIPTION=$(grep "^[[:space:]]*- \[ \] $TASK_PATTERN" "$TODO_FILE" | sed "s/.*${TASK_PATTERN}[[:space:]]*//" | head -1)

  # ==========================================================================
  # Build the new content in a temp file (same directory as TODO_FILE, so
  # the later `mv` is an atomic same-filesystem rename). Nothing here
  # mutates TODO_FILE itself yet.
  # ==========================================================================

  TMP_FILE=$(mktemp "${TODO_FILE}.tmp.XXXXXX")

  if [ "$FLAG" = "--timestamp" ]; then
    ISO_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    # Replace checkbox and append timestamp
    sed "s/^\([[:space:]]*\)- \[ \] \($TASK_PATTERN\)/\1- [x] \2/" "$TODO_FILE" \
      | sed "s/^\([[:space:]]*- \[x\] $TASK_PATTERN.*\)\$/\1 <!-- completed: $ISO_TIMESTAMP -->/" \
      > "$TMP_FILE"
  else
    # Just replace the checkbox
    sed "s/^\([[:space:]]*\)- \[ \] \($TASK_PATTERN\)/\1- [x] \2/" "$TODO_FILE" > "$TMP_FILE"
  fi

  # ==========================================================================
  # Pre-mv check: has TODO_FILE changed since we snapshotted it above? If
  # so, a concurrent writer already won the race - discard our temp file
  # and retry the whole cycle rather than clobbering their update. This is
  # a cheap fast path; it does not catch every race (see below), but it
  # avoids an unnecessary mv+re-read when we already know we're stale.
  # ==========================================================================

  AFTER_SNAPSHOT="$(snapshot)"

  RETRY=0
  if [ "$BEFORE_SNAPSHOT" != "$AFTER_SNAPSHOT" ]; then
    RETRY=1
  else
    mv "$TMP_FILE" "$TODO_FILE"

    # ========================================================================
    # Post-mv verification: confirm OUR checkbox actually landed (sed
    # exits 0 even when nothing matched, and a concurrent writer's mv can
    # still clobber ours in the narrow window right around this one). If
    # our mark isn't there, treat it exactly like a detected conflict
    # above and retry rather than silently losing the update.
    # ========================================================================
    if ! grep -q "^[[:space:]]*- \[x\] $TASK_PATTERN" "$TODO_FILE"; then
      RETRY=1
    fi
  fi

  rm -f "$TMP_FILE"

  if [ "$RETRY" -eq 1 ]; then
    attempt=$((attempt + 1))
    if [ "$attempt" -gt "$MAX_ATTEMPTS" ]; then
      echo "Error: failed to update $TODO_FILE after $MAX_ATTEMPTS attempts due to concurrent writers" >&2
      exit 1
    fi
    sleep 0.2
    continue
  fi

  break
done

echo "UPDATED:$TASK_ID:$DESCRIPTION"
