#!/usr/bin/env bats
#
# build-task-queue.bats - tests for skills/execute/scripts/build-task-queue.sh:
# TASK: line parsing, anchored [T<n>] extraction, and phase-header parity
# with skills/execute/scripts/validate-autocode.sh.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  BUILD_QUEUE="$PLUGIN_ROOT/skills/execute/scripts/build-task-queue.sh"
  VALIDATE="$PLUGIN_ROOT/skills/execute/scripts/validate-autocode.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/btq-bats.XXXXXX")"
  SPEC_DIR="$TEST_TMPDIR/spec"
  mkdir -p "$SPEC_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ------------------------------------------------------------------
# TASK: line parsing
# ------------------------------------------------------------------

@test "TASK: line preserves a colon inside the description verbatim" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] Fix bug: edge case in parser
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T1:P1:standard:Fix bug: edge case in parser"* ]]
}

@test "anchored [T2] extraction is not fooled by a mid-line [T2] mention" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] Some description mentioning [T2] elsewhere in the text
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  # No task ID extracted (not anchored at the start), full text kept as description
  [[ "$output" == *"TASK:none:P1:standard:Some description mentioning [T2] elsewhere in the text"* ]]
}

@test "anchored [T1] extraction at the true start of the task line works normally" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] Real task with a mention of [T2] in its own description
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T1:P1:standard:Real task with a mention of [T2] in its own description"* ]]
}

@test "tasks without a [T<n>] tag report task ID 'none'" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] Untagged task description
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:none:P1:standard:Untagged task description"* ]]
}

@test "completed tasks ([x]) are excluded from the queue" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [x] [T1] Done already
- [ ] [T2] Still pending
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"T1"* ]]
  [[ "$output" == *"TASK:T2:P1:standard:Still pending"* ]]
  [[ "$output" == *"TOTAL:1"* ]]
}

# ------------------------------------------------------------------
# difficulty rating annotation: "(easy|standard|hard)" after the task ID
# ------------------------------------------------------------------

@test "recognized rating annotations are emitted and stripped from the description" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] (easy) Update README install steps
- [ ] [T2] (standard) Add validation to OrderController
- [ ] [T3] (hard) Rework concurrency in the job queue
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T1:P1:easy:Update README install steps"* ]]
  [[ "$output" == *"TASK:T2:P1:standard:Add validation to OrderController"* ]]
  [[ "$output" == *"TASK:T3:P1:hard:Rework concurrency in the job queue"* ]]
}

@test "missing rating annotation defaults to standard" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] Task with no rating
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T1:P1:standard:Task with no rating"* ]]
}

@test "unrecognized annotation defaults to standard and stays in the description" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] (medium) Task with a bogus rating
- [ ] [T2] (optional) Task with a non-rating annotation
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T1:P1:standard:(medium) Task with a bogus rating"* ]]
  [[ "$output" == *"TASK:T2:P1:standard:(optional) Task with a non-rating annotation"* ]]
}

@test "rating annotation works on tasks without a [T<n>] tag" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] (hard) Untagged but rated task
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:none:P1:hard:Untagged but rated task"* ]]
}

# ------------------------------------------------------------------
# phase-header forms: "## P1:" and "## Phase 1:" recognized identically
# ------------------------------------------------------------------

@test "both '## P1:' and '## Phase 2:' header forms normalize to P<n> in build-task-queue.sh" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] Task in P1 form

## Phase 2: Follow-up

- [ ] [T2] Task in Phase form
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T1:P1:standard:Task in P1 form"* ]]
  [[ "$output" == *"TASK:T2:P2:standard:Task in Phase form"* ]]
}

@test "P<n> filter matches tasks under a 'Phase N:' header form" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## Phase 1: Foundation

- [ ] [T1] Task under Phase form

## P2: Next

- [ ] [T2] Task under P form
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR" "P1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T1:P1:standard:Task under Phase form"* ]]
  [[ "$output" != *"T2"* ]]
}

@test "T<n> filter selects only the matching task" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] First
- [ ] [T2] Second
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR" "T2"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TASK:T2:P1:standard:Second"* ]]
  [[ "$output" != *"TASK:T1"* ]]
}

@test "invalid filter is rejected" {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] First
EOF
  run "$BUILD_QUEUE" "$SPEC_DIR" "X9"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Invalid filter"* ]]
}

@test "rejects an invalid spec directory identifier" {
  run "$BUILD_QUEUE" "$TEST_TMPDIR/bad;dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid spec directory"* ]]
}

# ------------------------------------------------------------------
# cross-check: validate-autocode.sh recognizes the same two phase-header
# forms identically (same is_phase_header_line implementation).
# validate-autocode.sh hardcodes SPEC_DIR=".specs/<identifier>" relative
# to cwd, so these tests cd into a scratch project directory.
# ------------------------------------------------------------------

@test "validate-autocode.sh accepts a P<n> filter against a 'Phase N:' header" {
  cd "$TEST_TMPDIR"
  mkdir -p ".specs/myid"
  echo "spec" > ".specs/myid/SPEC.md"
  echo "plan" > ".specs/myid/PLAN.md"
  cat > ".specs/myid/TODO.md" << 'EOF'
## Phase 1: Foundation

- [ ] [T1] Task under Phase form
EOF
  run "$VALIDATE" "myid" "P1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Filter: Phase P1"* ]]
}

@test "validate-autocode.sh accepts a P<n> filter against a '## P1:' header" {
  cd "$TEST_TMPDIR"
  mkdir -p ".specs/myid"
  echo "spec" > ".specs/myid/SPEC.md"
  echo "plan" > ".specs/myid/PLAN.md"
  cat > ".specs/myid/TODO.md" << 'EOF'
## P1: Foundation

- [ ] [T1] Task under P form
EOF
  run "$VALIDATE" "myid" "P1"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Filter: Phase P1"* ]]
}
