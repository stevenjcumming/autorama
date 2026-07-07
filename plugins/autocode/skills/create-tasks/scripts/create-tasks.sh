#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/../../../scripts/lib.sh"

IDENTIFIER="${1:-}"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: identifier is required" >&2
  echo "Usage: create-tasks.sh <identifier>" >&2
  exit 1
fi

require_identifier "$IDENTIFIER"

SPEC_DIR="$(spec_dir_for "$IDENTIFIER")"

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec '$IDENTIFIER' does not exist at $SPEC_DIR"
  echo "Run '/autocode:new-spec $IDENTIFIER' first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/PLAN.md" ]; then
  echo "Error: PLAN.md not found in $SPEC_DIR"
  echo "Run '/autocode:create-plan $IDENTIFIER' first"
  exit 1
fi

# ==============================================================================
# item 21 / roadmap 4.2: validate PLAN.md has real content BEFORE
# scaffolding TODO.md - same stuck-state bug and fix shape as
# create-plan.sh's SPEC.md check (see that script for the full rationale).
#
# Heuristic mirrors create-plan.sh's, tuned to the shipped PLAN.md template
# (see create-plan/scripts/create-plan.sh's heredoc). Beyond HTML comments,
# headings, horizontal rules, and bare list/checkbox/numbered markers, the
# PLAN.md template also has a handful of literal (non-comment) boilerplate
# lines - those are filtered out explicitly below.
# ==============================================================================
plan_has_real_content() {
  local file="$1"
  local remaining
  remaining=$(sed -E 's/<!--.*-->//g' "$file" \
    | grep -vE '^[[:space:]]*#' \
    | grep -vE '^[[:space:]]*-{3,}[[:space:]]*$' \
    | grep -vE '^[[:space:]]*(-|[0-9]+\.)[[:space:]]*(\[[[:space:]]*\])?[[:space:]]*$' \
    | grep -vFx -- '**File:** `path/to/file.ext`' \
    | grep -vFx -- '**Changes:**' \
    | grep -vFx -- '- Reference: `pattern-file.ext:line`' \
    | grep -vFx -- '- Spec: `SPEC.md`' \
    | grep -vFx -- '- Requirements: `REQUIREMENT.md`' \
    | grep -vE '^[[:space:]]*$') || true
  [ -n "$remaining" ]
}

if ! plan_has_real_content "$SPEC_DIR/PLAN.md"; then
  echo "Error: PLAN.md in $SPEC_DIR is empty or has only unfilled template content"
  echo "Fill in PLAN.md with a real implementation plan before running create-tasks"
  exit 1
fi

if [ -f "$SPEC_DIR/TODO.md" ]; then
  echo "Error: TODO.md already exists at $SPEC_DIR/TODO.md"
  exit 1
fi

cat > "$SPEC_DIR/TODO.md" << 'EOF'
# TODO

<!-- Task checklist generated from PLAN.md -->

## Phase 1: [Name]

- [ ] Task description
- [ ] Write tests for [component]
EOF

echo "Created tasks template at $SPEC_DIR/TODO.md"
