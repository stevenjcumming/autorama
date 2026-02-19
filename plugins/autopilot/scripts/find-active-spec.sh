#!/bin/bash
#
# find-active-spec.sh - Find the most recently active spec directory
#
# Searches .claude/specs/ for the spec with the most recently modified
# state file (current.json), falling back to most recently modified
# TODO.md if no state files exist.
#
# Usage: find-active-spec.sh [specs_root]
#
# Arguments:
#   specs_root  Optional root directory (default: .claude/specs)
#
# Output:
#   FOUND:<spec_dir>:<spec_id>   - Found active spec
#   NOT_FOUND                     - No specs found
#
# Exit codes:
#   0 - Success (spec found or not found)
#   1 - Error (specs root doesn't exist)
#

set -e

SPECS_ROOT="${1:-.claude/specs}"

if [ ! -d "$SPECS_ROOT" ]; then
  echo "NOT_FOUND"
  exit 0
fi

# ============================================================================
# Strategy 1: Find most recently modified state file
# ============================================================================

NEWEST_STATE=""
NEWEST_STATE_TIME=0

for state_file in "$SPECS_ROOT"/*/artifacts/state/current.json; do
  if [ -f "$state_file" ]; then
    # Get modification time (portable across macOS and Linux)
    if stat --version &>/dev/null 2>&1; then
      # GNU stat (Linux)
      MOD_TIME=$(stat -c '%Y' "$state_file" 2>/dev/null || echo "0")
    else
      # BSD stat (macOS)
      MOD_TIME=$(stat -f '%m' "$state_file" 2>/dev/null || echo "0")
    fi

    if [ "$MOD_TIME" -gt "$NEWEST_STATE_TIME" ] 2>/dev/null; then
      NEWEST_STATE_TIME="$MOD_TIME"
      NEWEST_STATE="$state_file"
    fi
  fi
done

if [ -n "$NEWEST_STATE" ]; then
  # Extract spec_dir: go up from artifacts/state/current.json
  SPEC_DIR=$(dirname "$(dirname "$(dirname "$NEWEST_STATE")")")
  SPEC_ID=$(basename "$SPEC_DIR")
  echo "FOUND:$SPEC_DIR:$SPEC_ID"
  exit 0
fi

# ============================================================================
# Strategy 2: Fall back to most recently modified TODO.md
# ============================================================================

NEWEST_TODO=""
NEWEST_TODO_TIME=0

for todo_file in "$SPECS_ROOT"/*/TODO.md; do
  if [ -f "$todo_file" ]; then
    if stat --version &>/dev/null 2>&1; then
      MOD_TIME=$(stat -c '%Y' "$todo_file" 2>/dev/null || echo "0")
    else
      MOD_TIME=$(stat -f '%m' "$todo_file" 2>/dev/null || echo "0")
    fi

    if [ "$MOD_TIME" -gt "$NEWEST_TODO_TIME" ] 2>/dev/null; then
      NEWEST_TODO_TIME="$MOD_TIME"
      NEWEST_TODO="$todo_file"
    fi
  fi
done

if [ -n "$NEWEST_TODO" ]; then
  SPEC_DIR=$(dirname "$NEWEST_TODO")
  SPEC_ID=$(basename "$SPEC_DIR")
  echo "FOUND:$SPEC_DIR:$SPEC_ID"
  exit 0
fi

# ============================================================================
# Strategy 3: Fall back to any spec directory
# ============================================================================

for spec_dir in "$SPECS_ROOT"/*/; do
  if [ -d "$spec_dir" ]; then
    SPEC_DIR="${spec_dir%/}"
    SPEC_ID=$(basename "$SPEC_DIR")
    echo "FOUND:$SPEC_DIR:$SPEC_ID"
    exit 0
  fi
done

echo "NOT_FOUND"
