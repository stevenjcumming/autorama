#!/bin/bash

set -e

IDENTIFIER="$1"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: identifier is required"
  echo "Usage: create-plan.sh <identifier>"
  exit 1
fi

SPEC_DIR=".claude/specs/$IDENTIFIER"

if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec '$IDENTIFIER' does not exist at $SPEC_DIR"
  echo "Run '/autopilot:new-spec $IDENTIFIER' first"
  exit 1
fi

if [ ! -f "$SPEC_DIR/SPEC.md" ]; then
  echo "Error: SPEC.md not found in $SPEC_DIR"
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
