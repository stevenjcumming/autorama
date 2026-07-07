#!/usr/bin/env bats
#
# update-task-status.bats - tests for scripts/update-task-status.sh: TASK_ID
# validation, checkbox flipping, and the concurrent-write retry behavior.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$PLUGIN_ROOT/scripts/update-task-status.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/uts-bats.XXXXXX")"
  SPEC_DIR="$TEST_TMPDIR/spec"
  mkdir -p "$SPEC_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

write_todo() {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
# TODO

## Phase 1: Foundation

- [ ] [T1] First task description
- [ ] [T2] Second task description
- [x] [T3] Already done task
EOF
}

# ------------------------------------------------------------------
# TASK_ID validation
# ------------------------------------------------------------------

@test "rejects a malformed TASK_ID containing a slash and does not touch TODO.md" {
  write_todo
  before="$(cat "$SPEC_DIR/TODO.md")"
  run "$SCRIPT" "$SPEC_DIR" "T1/2"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid task ID"* ]]
  after="$(cat "$SPEC_DIR/TODO.md")"
  [ "$before" = "$after" ]
}

@test "rejects a malformed TASK_ID containing an asterisk and does not touch TODO.md" {
  write_todo
  before="$(cat "$SPEC_DIR/TODO.md")"
  run "$SCRIPT" "$SPEC_DIR" "T1*"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid task ID"* ]]
  after="$(cat "$SPEC_DIR/TODO.md")"
  [ "$before" = "$after" ]
}

@test "rejects a TASK_ID with no leading T and does not touch TODO.md" {
  write_todo
  before="$(cat "$SPEC_DIR/TODO.md")"
  run "$SCRIPT" "$SPEC_DIR" "1"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid task ID"* ]]
  after="$(cat "$SPEC_DIR/TODO.md")"
  [ "$before" = "$after" ]
}

@test "rejects a TASK_ID containing a backslash and does not touch TODO.md" {
  write_todo
  before="$(cat "$SPEC_DIR/TODO.md")"
  run "$SCRIPT" "$SPEC_DIR" 'T1\'
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid task ID"* ]]
  after="$(cat "$SPEC_DIR/TODO.md")"
  [ "$before" = "$after" ]
}

# ------------------------------------------------------------------
# happy path
# ------------------------------------------------------------------

@test "accepts a valid T<n> ID and flips its checkbox" {
  write_todo
  run "$SCRIPT" "$SPEC_DIR" "T1"
  [ "$status" -eq 0 ]
  [[ "$output" == "UPDATED:T1:First task description" ]]
  grep -qE '^- \[x\] \[T1\] First task description$' "$SPEC_DIR/TODO.md"
  # sibling tasks are untouched
  grep -qE '^- \[ \] \[T2\] Second task description$' "$SPEC_DIR/TODO.md"
}

@test "appends an ISO timestamp comment with --timestamp" {
  write_todo
  run "$SCRIPT" "$SPEC_DIR" "T2" --timestamp
  [ "$status" -eq 0 ]
  grep -qE '^- \[x\] \[T2\] Second task description <!-- completed: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z -->$' "$SPEC_DIR/TODO.md"
}

@test "reports ALREADY_DONE for a task already checked off, without modifying the file" {
  write_todo
  before="$(cat "$SPEC_DIR/TODO.md")"
  run "$SCRIPT" "$SPEC_DIR" "T3"
  [ "$status" -eq 0 ]
  [[ "$output" == "ALREADY_DONE:T3:Already done task" ]]
  after="$(cat "$SPEC_DIR/TODO.md")"
  [ "$before" = "$after" ]
}

@test "reports NOT_FOUND for a well-formed but absent task ID" {
  write_todo
  run "$SCRIPT" "$SPEC_DIR" "T99"
  [ "$status" -eq 1 ]
  [[ "$output" == "NOT_FOUND:T99" ]]
}

@test "errors when TODO.md does not exist" {
  run "$SCRIPT" "$SPEC_DIR" "T1"
  [ "$status" -eq 1 ]
  [[ "$output" == *"TODO.md not found"* ]]
}

@test "errors when spec_dir or task_id argument is missing" {
  run "$SCRIPT" "$SPEC_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"spec directory and task ID are required"* ]]
}

# ------------------------------------------------------------------
# concurrency
# ------------------------------------------------------------------

@test "two concurrent updates to different task IDs both land correctly" {
  write_todo
  "$SCRIPT" "$SPEC_DIR" "T1" > "$TEST_TMPDIR/out1.log" 2>&1 &
  pid1=$!
  "$SCRIPT" "$SPEC_DIR" "T2" > "$TEST_TMPDIR/out2.log" 2>&1 &
  pid2=$!

  wait "$pid1"
  status1=$?
  wait "$pid2"
  status2=$?

  [ "$status1" -eq 0 ]
  [ "$status2" -eq 0 ]

  grep -qE '^- \[x\] \[T1\] First task description$' "$SPEC_DIR/TODO.md"
  grep -qE '^- \[x\] \[T2\] Second task description$' "$SPEC_DIR/TODO.md"
  # Already-done T3 survives the race untouched
  grep -qE '^- \[x\] \[T3\] Already done task$' "$SPEC_DIR/TODO.md"
  # exactly 3 checked boxes, no duplication/corruption
  [ "$(grep -cE '^- \[x\]' "$SPEC_DIR/TODO.md")" = "3" ]
}
