#!/usr/bin/env bash
#
# find-active-spec.sh - Find the most recently active spec directory
#
# Searches .specs/ for the spec with the most recently modified
# TODO.md, falling back to any spec directory.
#
# Usage: find-active-spec.sh [specs_root]
#
# Arguments:
#   specs_root  Optional root directory (default: .specs)
#
# Output:
#   FOUND:<spec_dir>:<spec_id>   - Found active spec
#   NOT_FOUND                     - No specs found
#
# Exit codes:
#   0 - Always; a missing specs root prints NOT_FOUND rather than failing
#

set -euo pipefail

SPECS_ROOT="${1:-.specs}"

if [ ! -d "$SPECS_ROOT" ]; then
  echo "NOT_FOUND"
  exit 0
fi

# ============================================================================
# Strategy 1: Find most recently modified TODO.md
# ============================================================================

# Detect the stat flavor once, outside the loop below, rather than
# re-running `stat --version` on every iteration.
if stat --version >/dev/null 2>&1; then
  STAT_IS_GNU=1
else
  STAT_IS_GNU=0
fi

NEWEST_TODO=""
NEWEST_TODO_TIME=0

for todo_file in "$SPECS_ROOT"/*/TODO.md; do
  if [ -f "$todo_file" ]; then
    if [ "$STAT_IS_GNU" -eq 1 ]; then
      # GNU stat (Linux)
      MOD_TIME=$(stat -c '%Y' "$todo_file" 2>/dev/null || echo "0")
    else
      # BSD stat (macOS)
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
# Strategy 2: Fall back to any spec directory
# ============================================================================

# Reached when no TODO.md exists anywhere (or every one shares the same
# mtime). Glob expansion here is alphabetical on every shell this
# script targets, so this is a deterministic-but-arbitrary tiebreak,
# not a "most correct" pick - it only matters for the edge case of
# multiple untouched/tied specs, and a stable, repeatable choice beats
# a heuristic that could vary run to run.
for spec_dir in "$SPECS_ROOT"/*/; do
  if [ -d "$spec_dir" ]; then
    SPEC_DIR="${spec_dir%/}"
    SPEC_ID=$(basename "$SPEC_DIR")
    echo "FOUND:$SPEC_DIR:$SPEC_ID"
    exit 0
  fi
done

echo "NOT_FOUND"
