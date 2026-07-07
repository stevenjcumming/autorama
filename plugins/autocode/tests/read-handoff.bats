#!/usr/bin/env bats
#
# read-handoff.bats - tests for scripts/read-handoff.sh: extraction of
# Blockers/Warnings for Next Agent/Next Task Context sections from a
# handoff.md fixture matching the real template's heading text, and the
# item-43 rule that usage/error output goes to stderr, never stdout.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$PLUGIN_ROOT/scripts/read-handoff.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/rh-bats.XXXXXX")"
  SPEC_DIR="$TEST_TMPDIR/spec"
  mkdir -p "$SPEC_DIR/artifacts/handoff"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

write_handoff() {
  # Headings copied verbatim from templates/artifacts/handoff/handoff.md
  cat > "$SPEC_DIR/artifacts/handoff/handoff.md" << 'EOF'
---
task_id: T4
status: completed
timestamp: 2026-07-01T12:00:00Z
spec_id: demo-spec
agent: autocode:task-runner
---

# Task Handoff

## Facts (never summarize, never paraphrase; copy exactly)

- Spec ID: demo-spec
- Current task ID: T4

## Key Decisions Made

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| Used sed over awk | simpler | awk |

## Next Task Context

- **Next Task ID:** T5
- **Next Task Description:** Wire up the retry logic
- **Relevant Files:** scripts/foo.sh
- **Dependencies:** none

## Blockers

| Blocker | Severity | Details |
|---------|----------|---------|
| Flaky CI runner | medium | intermittent timeout |

## Warnings for Next Agent

- Watch out for the race in update-task-status.sh
- Config file may be missing yq

## Artifacts Generated

| Type | Path | Summary |
|------|------|---------|
| decision | artifacts/decisions/d1.md | chose sed |
EOF
}

write_todo() {
  cat > "$SPEC_DIR/TODO.md" << 'EOF'
# TODO

## Phase 1: Foundation

- [x] [T4] Done task
- [ ] [T5] Next pending task
EOF
}

# ------------------------------------------------------------------
# section extraction
# ------------------------------------------------------------------

@test "extracts the Blockers section" {
  write_handoff
  write_todo
  run "$SCRIPT" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Blockers:"* ]]
  [[ "$output" == *"Flaky CI runner"* ]]
}

@test "extracts the Warnings for Next Agent section" {
  write_handoff
  write_todo
  run "$SCRIPT" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warnings:"* ]]
  [[ "$output" == *"Watch out for the race in update-task-status.sh"* ]]
}

@test "extracts the Next Task Context section" {
  write_handoff
  write_todo
  run "$SCRIPT" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Next Task ID:"* ]]
  [[ "$output" == *"T5"* ]]
  [[ "$output" == *"Wire up the retry logic"* ]]
}

@test "extracts task_id/status from frontmatter and the current task/progress summary" {
  write_handoff
  write_todo
  run "$SCRIPT" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Previous: T4 (completed)"* ]]
  [[ "$output" == *"<current-task>"* ]]
  [[ "$output" == *"[T5] Next pending task"* ]]
  [[ "$output" == *"1 done, 1 remaining"* ]]
}

@test "handles a spec dir with no handoff.md gracefully (no <handoff-context> block)" {
  write_todo
  run "$SCRIPT" "$SPEC_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" != *"<handoff-context>"* ]]
  [[ "$output" == *"<current-task>"* ]]
}

# ------------------------------------------------------------------
# stderr-only errors (item 43)
# ------------------------------------------------------------------

@test "missing spec_dir argument: usage goes to stderr, stdout is empty, exit 1" {
  run --separate-stderr "$SCRIPT"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"Error: spec directory is required"* ]]
  [[ "$stderr" == *"Usage: read-handoff.sh <spec_dir>"* ]]
}

@test "nonexistent spec_dir: error goes to stderr, stdout is empty, exit 1" {
  run --separate-stderr "$SCRIPT" "$TEST_TMPDIR/does-not-exist"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"Error: spec directory does not exist"* ]]
}
