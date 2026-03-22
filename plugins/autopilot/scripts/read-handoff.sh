#!/bin/bash
#
# read-handoff.sh - Read condensed handoff context for next agent
#
# Extracts key fields from handoff.md and outputs a compact summary
# instead of the full file, keeping context injection under ~200 tokens.
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
# Condensed Handoff Context
# ============================================================================

HANDOFF_FILE="$SPEC_DIR/artifacts/handoff/handoff.md"
if [ -f "$HANDOFF_FILE" ]; then
  echo "<handoff-context>"

  # Extract frontmatter fields
  TASK_ID=$(sed -n 's/^task_id:[[:space:]]*//p' "$HANDOFF_FILE" | head -1)
  STATUS=$(sed -n 's/^status:[[:space:]]*//p' "$HANDOFF_FILE" | head -1)

  echo "Previous: $TASK_ID ($STATUS)"

  # Extract key decisions (lines after "## Key Decisions Made" until next heading, skip comments/table headers)
  DECISIONS=$(sed -n '/^## Key Decisions Made/,/^## /{/^## /d;/^$/d;/^<!--/d;/^|--/d;/^| Decision/d;p;}' "$HANDOFF_FILE" | head -3)
  if [ -n "$DECISIONS" ]; then
    echo "Decisions: $DECISIONS"
  fi

  # Extract blockers (lines after "## Blockers" until next heading, skip comments/table headers)
  BLOCKERS=$(sed -n '/^## Blockers/,/^## /{/^## /d;/^$/d;/^<!--/d;/^|--/d;/^| Blocker/d;p;}' "$HANDOFF_FILE" | head -3)
  if [ -n "$BLOCKERS" ]; then
    echo "Blockers: $BLOCKERS"
  fi

  # Extract warnings (lines after "## Warnings for Next Agent" until next heading or EOF, skip comments)
  WARNINGS=$(sed -n '/^## Warnings for Next Agent/,/^## /{/^## /d;/^$/d;/^<!--/d;p;}' "$HANDOFF_FILE" | head -3)
  if [ -n "$WARNINGS" ]; then
    echo "Warnings: $WARNINGS"
  fi

  # Extract next task context (lines after "## Next Task Context" until next heading)
  NEXT_CTX=$(sed -n '/^## Next Task Context/,/^## /{/^## /d;/^$/d;/^<!--/d;p;}' "$HANDOFF_FILE" | head -4)
  if [ -n "$NEXT_CTX" ]; then
    echo "$NEXT_CTX"
  fi

  echo "</handoff-context>"
  echo ""
fi

# ============================================================================
# Current Task from TODO.md
# ============================================================================

TODO_FILE="$SPEC_DIR/TODO.md"
if [ -f "$TODO_FILE" ]; then
  # Extract first uncompleted task
  NEXT_TASK=$(grep -m1 '^- \[ \]' "$TODO_FILE" 2>/dev/null || echo "")

  if [ -n "$NEXT_TASK" ]; then
    echo "<current-task>"
    echo "$NEXT_TASK"
    echo "</current-task>"
  fi

  # Compact progress line
  REMAINING=$(grep -c '^- \[ \]' "$TODO_FILE" 2>/dev/null || echo "0")
  COMPLETED=$(grep -c '^- \[x\]' "$TODO_FILE" 2>/dev/null || echo "0")
  echo "<progress-summary>$COMPLETED done, $REMAINING remaining</progress-summary>"
fi
