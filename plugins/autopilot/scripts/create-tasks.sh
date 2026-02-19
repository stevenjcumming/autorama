#!/bin/bash

set -e

IDENTIFIER="$1"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: identifier is required"
  echo "Usage: create-tasks.sh <identifier>"
  exit 1
fi

SPEC_DIR=".claude/specs/$IDENTIFIER"

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec '$IDENTIFIER' does not exist at $SPEC_DIR"
  echo "Run '/autopilot:new-spec $IDENTIFIER' first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/PLAN.md" ]; then
  echo "Error: PLAN.md not found in $SPEC_DIR"
  echo "Run '/autopilot:create-plan $IDENTIFIER' first"
  exit 1
fi

if [ -f "$SPEC_DIR/TODO.md" ]; then
  echo "Error: TODO.md already exists at $SPEC_DIR/TODO.md"
  exit 1
fi

cat > "$SPEC_DIR/TODO.md" << 'EOF'
# TODO

<!-- Task checklist generated from PLAN.md -->
<!-- Move completed tasks to the Completed section at the bottom -->

## Phase 1: [Name]

- [ ] Task description
- [ ] Write tests for [component]

---

## Completed

<!-- Move completed tasks here with [x] -->
EOF

echo "Created tasks template at $SPEC_DIR/TODO.md"
