#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/../../../scripts/lib.sh"

IDENTIFIER="${1:-}"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: identifier is required" >&2
  echo "Usage: create-plan.sh <identifier>" >&2
  exit 1
fi

require_identifier "$IDENTIFIER"

SPEC_DIR="$(spec_dir_for "$IDENTIFIER")"

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec '$IDENTIFIER' does not exist at $SPEC_DIR"
  echo "Run '/autocode:new-spec $IDENTIFIER' first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/SPEC.md" ]; then
  echo "Error: SPEC.md not found in $SPEC_DIR"
  exit 1
fi

# ==============================================================================
# item 21 / roadmap 4.2: validate that SPEC.md has real content BEFORE
# scaffolding PLAN.md. Previously PLAN.md was scaffolded first and this
# check ran afterward (in create-plan/SKILL.md's Step 2); if the check
# failed, the empty PLAN.md was left behind and the *next* invocation hit
# the "PLAN.md already exists" guard below - a stuck state needing manual
# cleanup. Checking here, before anything is written, means a failed
# check leaves nothing to clean up.
#
# Heuristic: strip everything that is boilerplate in the shipped SPEC.md
# template (see new-spec/scripts/new-spec.sh's heredoc) - HTML comments,
# headings, horizontal rules, bare list/checkbox/numbered markers, and the
# one literal non-comment boilerplate line ("See @REQUIREMENT.md") - and
# see if anything is left. If nothing survives, SPEC.md is still just the
# unfilled scaffold.
# ==============================================================================
spec_has_real_content() {
  local file="$1"
  local remaining
  remaining=$(sed -E 's/<!--.*-->//g' "$file" \
    | grep -vE '^[[:space:]]*#' \
    | grep -vE '^[[:space:]]*-{3,}[[:space:]]*$' \
    | grep -vE '^[[:space:]]*(-|[0-9]+\.)[[:space:]]*(\[[[:space:]]*\])?[[:space:]]*$' \
    | grep -vFx -- 'See @REQUIREMENT.md' \
    | grep -vE '^[[:space:]]*$') || true
  [ -n "$remaining" ]
}

if ! spec_has_real_content "$SPEC_DIR/SPEC.md"; then
  echo "Error: SPEC.md in $SPEC_DIR is empty or has only unfilled template content"
  echo "Fill in SPEC.md with real requirements before running create-plan"
  exit 1
fi

if [ -f "$SPEC_DIR/PLAN.md" ]; then
  echo "Error: PLAN.md already exists at $SPEC_DIR/PLAN.md"
  exit 1
fi

cat > "$SPEC_DIR/PLAN.md" << 'EOF'
# Implementation Plan

## Overview

<!-- 1-2 sentence summary of what we're implementing and why -->

## Current State Analysis

<!-- What exists now, what's missing, key constraints discovered -->

### Key Discoveries

- <!-- Important finding with file:line reference -->
- <!-- Pattern to follow -->
- <!-- Constraint to work within -->

## Desired End State

<!-- Specification of the desired end state after this plan is complete -->

### Verification

<!-- How to verify the end state has been achieved -->

## What We're NOT Doing

<!-- Explicitly list out-of-scope items to prevent scope creep -->

-

## Implementation Approach

<!-- High-level strategy and reasoning for the chosen approach -->

---

## Phase 1: [Name]

### Goal

<!-- What this phase accomplishes -->

### Changes

#### 1. [Component/File]

**File:** `path/to/file.ext`

**Changes:**
- <!-- Specific change details -->
- Reference: `pattern-file.ext:line`

### Success Criteria

#### Automated
- [ ] <!-- Command to verify: `make test`, `npm run lint`, etc. -->

#### Manual
- [ ] <!-- Manual verification step -->

---

## Phase 2: [Name]

### Goal

<!-- What this phase accomplishes -->

### Changes

#### 1. [Component/File]

**File:** `path/to/file.ext`

**Changes:**
- <!-- Details -->

### Success Criteria

#### Automated
- [ ]

#### Manual
- [ ]

---

## Testing Strategy

### Unit Tests
- <!-- Components to test -->

### Integration Tests
- <!-- Flows to test -->

### Manual Testing
1. <!-- Specific step to verify -->

## Risks & Considerations

- <!-- Potential issue and mitigation -->

## References

- Spec: `SPEC.md`
- Requirements: `REQUIREMENT.md`
- <!-- Related files: `path/to/file.ext:line` -->
EOF

echo "Created plan at $SPEC_DIR/PLAN.md"
