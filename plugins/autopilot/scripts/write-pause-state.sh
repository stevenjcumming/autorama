#!/bin/bash
#
# write-pause-state.sh - Write paused.md for autopilot pause/resume
#
# Gathers current state from TODO.md, state files, and signals,
# then writes a structured paused.md file for later resumption.
#
# Usage: write-pause-state.sh <spec_dir> [reason]
#
# Arguments:
#   spec_dir  Path to the spec directory
#   reason    Optional pause reason (default: "Manual pause requested by user")
#
# Output:
#   pause:<path_to_paused_md>
#
# Exit codes:
#   0 - Success
#   1 - Error (missing arguments, directory not found)
#

set -e

SPEC_DIR="$1"
REASON="${2:-Manual pause requested by user}"

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required"
  echo "Usage: write-pause-state.sh <spec_dir> [reason]"
  exit 1
fi

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec directory not found at $SPEC_DIR"
  exit 1
fi

SPEC_ID=$(basename "$SPEC_DIR")
ISO_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

# ============================================================================
# Gather state from TODO.md
# ============================================================================

TODO_FILE="$SPEC_DIR/TODO.md"
COMPLETED_COUNT=0
REMAINING_COUNT=0
TOTAL_COUNT=0
CURRENT_TASK=""
CURRENT_TASK_ID=""

if [ -f "$TODO_FILE" ]; then
  COMPLETED_COUNT=$(grep -c '^\s*- \[x\]' "$TODO_FILE" 2>/dev/null || echo "0")
  REMAINING_COUNT=$(grep -c '^\s*- \[ \]' "$TODO_FILE" 2>/dev/null || echo "0")
  TOTAL_COUNT=$((COMPLETED_COUNT + REMAINING_COUNT))

  # Find current task (first uncompleted)
  CURRENT_TASK=$(grep -m1 '^\s*- \[ \]' "$TODO_FILE" 2>/dev/null || echo "")
  if [ -n "$CURRENT_TASK" ]; then
    CURRENT_TASK_ID=$(echo "$CURRENT_TASK" | grep -oE '\[T[0-9]+\]' | tr -d '[]' || echo "")
    CURRENT_TASK=$(echo "$CURRENT_TASK" | sed 's/^\s*- \[ \]\s*//')
  fi
fi

# ============================================================================
# Gather state from current.json
# ============================================================================

STATE_FILE="$SPEC_DIR/artifacts/state/current.json"
LAST_AGENT=""
LAST_TASK=""

if [ -f "$STATE_FILE" ] && command -v jq &> /dev/null; then
  LAST_AGENT=$(jq -r '.last_agent // empty' "$STATE_FILE" 2>/dev/null || echo "")
  LAST_TASK=$(jq -r '.last_task // empty' "$STATE_FILE" 2>/dev/null || echo "")
fi

# ============================================================================
# Gather recent signals
# ============================================================================

SIGNALS_DIR="$SPEC_DIR/artifacts/signals"
SIGNALS_SUMMARY=""

if [ -d "$SIGNALS_DIR" ]; then
  SIGNAL_COUNT=$(find "$SIGNALS_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ "$SIGNAL_COUNT" -gt 0 ]; then
    # Get the 5 most recent signal filenames
    RECENT_SIGNALS=$(find "$SIGNALS_DIR" -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | awk '{print $2}' || \
      ls -t "$SIGNALS_DIR"/*.md 2>/dev/null | head -5)

    SIGNALS_SUMMARY="$SIGNAL_COUNT signal(s) recorded."
    if [ -n "$RECENT_SIGNALS" ]; then
      SIGNALS_SUMMARY="$SIGNALS_SUMMARY Recent:"
      while IFS= read -r sig_file; do
        if [ -n "$sig_file" ] && [ -f "$sig_file" ]; then
          SIG_NAME=$(basename "$sig_file" .md)
          SIGNALS_SUMMARY="$SIGNALS_SUMMARY
- $SIG_NAME"
        fi
      done <<< "$RECENT_SIGNALS"
    fi
  else
    SIGNALS_SUMMARY="No signals recorded."
  fi
else
  SIGNALS_SUMMARY="No signals recorded."
fi

# ============================================================================
# Write paused.md
# ============================================================================

STATE_DIR="$SPEC_DIR/artifacts/state"
mkdir -p "$STATE_DIR"

PAUSED_FILE="$STATE_DIR/paused.md"

cat > "$PAUSED_FILE" << EOF
# Autopilot Paused

## Pause Reason
$REASON

## Current State
- **Spec:** $SPEC_ID
- **Current Task:** ${CURRENT_TASK_ID:-unknown} - ${CURRENT_TASK:-No task in progress}
- **Last Agent:** ${LAST_AGENT:-unknown}
- **Timestamp:** $ISO_TIMESTAMP

## Progress
- **Completed:** $COMPLETED_COUNT tasks
- **Remaining:** $REMAINING_COUNT tasks
- **Total:** $TOTAL_COUNT tasks

## Analyzer Signals
$SIGNALS_SUMMARY

## To Resume

Run the following command to continue:

\`\`\`
/autopilot:execute $SPEC_ID
\`\`\`

The next agent will pick up from task ${CURRENT_TASK_ID:-the next uncompleted task}.
EOF

echo "pause:$PAUSED_FILE"
