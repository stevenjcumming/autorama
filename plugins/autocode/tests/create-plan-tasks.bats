#!/usr/bin/env bats
#
# create-plan-tasks.bats - tests for skills/create-plan/scripts/create-plan.sh
# and skills/create-tasks/scripts/create-tasks.sh: the validate-before-scaffold
# ordering (item 21 / roadmap 4.2) and the "is this just an unfilled
# template" heuristic, including that a rejected run leaves no scaffolded
# file behind so a retry can succeed cleanly.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  CREATE_PLAN="$PLUGIN_ROOT/skills/create-plan/scripts/create-plan.sh"
  CREATE_TASKS="$PLUGIN_ROOT/skills/create-tasks/scripts/create-tasks.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/cpt-bats.XXXXXX")"
  PROJECT_DIR="$TEST_TMPDIR/project"
  mkdir -p "$PROJECT_DIR/.specs/demo"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

write_unfilled_spec() {
  cat > "$PROJECT_DIR/.specs/demo/SPEC.md" << 'EOF'
# Spec

<!-- fill this in -->

## Overview

-

See @REQUIREMENT.md
EOF
}

write_real_spec() {
  cat > "$PROJECT_DIR/.specs/demo/SPEC.md" << 'EOF'
# Spec

## Overview

This feature adds a retry mechanism to the widget importer so transient
network failures during CSV upload no longer abort the whole batch.
EOF
}

write_unfilled_plan() {
  cat > "$PROJECT_DIR/.specs/demo/PLAN.md" << 'EOF'
# Implementation Plan

## Overview

<!-- 1-2 sentence summary -->

---

## Phase 1: [Name]

### Changes

#### 1. [Component/File]

**File:** `path/to/file.ext`

**Changes:**
- Reference: `pattern-file.ext:line`

### Success Criteria

#### Automated
- [ ]

## References

- Spec: `SPEC.md`
- Requirements: `REQUIREMENT.md`
EOF
}

write_real_plan() {
  cat > "$PROJECT_DIR/.specs/demo/PLAN.md" << 'EOF'
# Implementation Plan

## Overview

Add exponential backoff retry around the CSV upload call in
importer/widgets.rb, capped at 3 attempts, logging each retry.

## Phase 1: Retry Wrapper

### Changes

#### 1. Retry helper

**File:** `importer/widgets.rb`

**Changes:**
- Wrap `upload_csv` in a retry loop with exponential backoff
EOF
}

# ------------------------------------------------------------------
# create-plan.sh
# ------------------------------------------------------------------

@test "create-plan.sh rejects an unfilled SPEC.md and leaves no PLAN.md behind" {
  cd "$PROJECT_DIR"
  write_unfilled_spec
  run "$CREATE_PLAN" "demo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty or has only unfilled template content"* ]]
  [ ! -f ".specs/demo/PLAN.md" ]
}

@test "create-plan.sh succeeds once SPEC.md, and a retry after fixing SPEC.md works cleanly" {
  cd "$PROJECT_DIR"
  write_unfilled_spec
  run "$CREATE_PLAN" "demo"
  [ "$status" -eq 1 ]
  [ ! -f ".specs/demo/PLAN.md" ]

  write_real_spec
  run "$CREATE_PLAN" "demo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created plan at .specs/demo/PLAN.md"* ]]
  [ -f ".specs/demo/PLAN.md" ]
}

@test "create-plan.sh refuses to overwrite an existing PLAN.md" {
  cd "$PROJECT_DIR"
  write_real_spec
  echo "existing plan" > ".specs/demo/PLAN.md"
  run "$CREATE_PLAN" "demo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PLAN.md already exists"* ]]
  [ "$(cat .specs/demo/PLAN.md)" = "existing plan" ]
}

# ------------------------------------------------------------------
# create-tasks.sh
# ------------------------------------------------------------------

@test "create-tasks.sh rejects an unfilled PLAN.md and leaves no TODO.md behind" {
  cd "$PROJECT_DIR"
  write_unfilled_plan
  run "$CREATE_TASKS" "demo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"empty or has only unfilled template content"* ]]
  [ ! -f ".specs/demo/TODO.md" ]
}

@test "create-tasks.sh succeeds once PLAN.md has real content, and a retry after fixing PLAN.md works cleanly" {
  cd "$PROJECT_DIR"
  write_unfilled_plan
  run "$CREATE_TASKS" "demo"
  [ "$status" -eq 1 ]
  [ ! -f ".specs/demo/TODO.md" ]

  write_real_plan
  run "$CREATE_TASKS" "demo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Created tasks template at .specs/demo/TODO.md"* ]]
  [ -f ".specs/demo/TODO.md" ]
}

@test "create-tasks.sh refuses to overwrite an existing TODO.md" {
  cd "$PROJECT_DIR"
  write_real_plan
  echo "existing todo" > ".specs/demo/TODO.md"
  run "$CREATE_TASKS" "demo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"TODO.md already exists"* ]]
  [ "$(cat .specs/demo/TODO.md)" = "existing todo" ]
}

@test "create-tasks.sh requires PLAN.md to exist first" {
  cd "$PROJECT_DIR"
  write_real_spec
  run "$CREATE_TASKS" "demo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"PLAN.md not found"* ]]
}

@test "both scripts reject an invalid identifier before touching the filesystem" {
  cd "$PROJECT_DIR"
  run --separate-stderr "$CREATE_PLAN" "bad/id"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"invalid identifier"* ]]

  run --separate-stderr "$CREATE_TASKS" "bad/id"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"invalid identifier"* ]]
}
