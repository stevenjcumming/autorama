#!/bin/bash

set -e

IDENTIFIER="$1"
FILTER="$2"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: spec identifier is required"
  echo "Usage: validate-autocode.sh <identifier> [T<n>|P<n>]"
  exit 1
fi

SPEC_DIR=".claude/specs/$IDENTIFIER"

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec directory does not exist at $SPEC_DIR"
  echo "Run '/autopilot:new-spec $IDENTIFIER' to create it first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/SPEC.md" ]; then
  echo "Error: SPEC.md not found in $SPEC_DIR"
  echo "Run '/new-spec' to create the spec first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/PLAN.md" ]; then
  echo "Error: PLAN.md not found in $SPEC_DIR"
  echo "Run '/create-plan' to create the plan first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/TODO.md" ]; then
  echo "Error: TODO.md not found in $SPEC_DIR"
  echo "Run '/create-tasks' to create the task list first"
  exit 1
fi

# Check for uncompleted tasks (lines with "- [ ]", including indented sub-tasks)
UNCOMPLETED_TASKS=$(grep -cE '^\s*- \[ \]' "$SPEC_DIR/TODO.md" 2>/dev/null || echo "0")

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
    if ! grep -qE "^\s*- \[ \] \[$FILTER\]" "$SPEC_DIR/TODO.md"; then
      echo "Error: Task $FILTER is already completed"
      exit 1
    fi
    echo "Filter: Task $FILTER"
  elif [[ "$FILTER" =~ ^P[0-9]+$ ]]; then
    # Phase filter (e.g., P1, P2)
    if ! grep -q "^## $FILTER:" "$SPEC_DIR/TODO.md"; then
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
