#!/usr/bin/env bats
#
# spec-archive.bats - tests for skills/spec-archive/scripts/spec-archive.sh:
# REVIEW.md must end up copied into the archive AND still present,
# byte-identical, in the working tree; everything else is moved.
#
# spec-archive.sh always archives under $HOME/.autocode/specs/..., so
# every test overrides HOME to a scratch directory to avoid touching the
# real user's home.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$PLUGIN_ROOT/skills/spec-archive/scripts/spec-archive.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/archive-bats.XXXXXX")"
  PROJECT_DIR="$TEST_TMPDIR/project"
  SCRATCH_HOME="$TEST_TMPDIR/home"
  mkdir -p "$PROJECT_DIR" "$SCRATCH_HOME"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

write_spec() {
  mkdir -p "$PROJECT_DIR/.specs/demo/artifacts/decisions"
  echo "# Spec" > "$PROJECT_DIR/.specs/demo/SPEC.md"
  echo "# Plan" > "$PROJECT_DIR/.specs/demo/PLAN.md"
  printf '# Review\n\nApproved with no notes.\n' > "$PROJECT_DIR/.specs/demo/REVIEW.md"
  echo "decision content" > "$PROJECT_DIR/.specs/demo/artifacts/decisions/d1.md"
}

archive_dir_from_output() {
  # Parses the "Archive: <path>" line spec-archive.sh prints.
  printf '%s\n' "$1" | grep -m1 '^Archive: ' | sed 's/^Archive: //'
}

@test "REVIEW.md ends up in both the archive and the working tree, byte-identical" {
  cd "$PROJECT_DIR"
  write_spec
  run env HOME="$SCRATCH_HOME" "$SCRIPT" "demo"
  [ "$status" -eq 0 ]

  local archive_dir
  archive_dir="$(archive_dir_from_output "$output")"
  [ -n "$archive_dir" ]

  [ -f "$archive_dir/REVIEW.md" ]
  [ -f "$PROJECT_DIR/.specs/demo/REVIEW.md" ]
  cmp -s "$archive_dir/REVIEW.md" "$PROJECT_DIR/.specs/demo/REVIEW.md"
}

@test "everything except REVIEW.md is moved out of the working spec dir" {
  cd "$PROJECT_DIR"
  write_spec
  run env HOME="$SCRATCH_HOME" "$SCRIPT" "demo"
  [ "$status" -eq 0 ]

  local archive_dir
  archive_dir="$(archive_dir_from_output "$output")"

  [ -f "$archive_dir/SPEC.md" ]
  [ -f "$archive_dir/PLAN.md" ]
  [ -f "$archive_dir/artifacts/decisions/d1.md" ]

  [ ! -f "$PROJECT_DIR/.specs/demo/SPEC.md" ]
  [ ! -f "$PROJECT_DIR/.specs/demo/PLAN.md" ]
  [ ! -d "$PROJECT_DIR/.specs/demo/artifacts" ]
}

@test "requires REVIEW.md to exist before archiving anything" {
  cd "$PROJECT_DIR"
  mkdir -p "$PROJECT_DIR/.specs/demo"
  echo "# Spec" > "$PROJECT_DIR/.specs/demo/SPEC.md"
  run env HOME="$SCRATCH_HOME" "$SCRIPT" "demo"
  [ "$status" -eq 1 ]
  [[ "$output" == *"REVIEW.md not found"* ]]
  [ -f "$PROJECT_DIR/.specs/demo/SPEC.md" ]
}

@test "a second archive run for the same spec suffixes the archive dir instead of overwriting" {
  cd "$PROJECT_DIR"
  write_spec
  run env HOME="$SCRATCH_HOME" "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  local first_archive_dir
  first_archive_dir="$(archive_dir_from_output "$output")"

  # Recreate a spec dir with the same identifier and archive again. The
  # collision-avoidance suffix is a second-resolution timestamp, so sleep
  # past the second boundary to avoid a flaky same-second collision.
  sleep 1.1
  write_spec
  run env HOME="$SCRATCH_HOME" "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  local second_archive_dir
  second_archive_dir="$(archive_dir_from_output "$output")"

  [ "$first_archive_dir" != "$second_archive_dir" ]
  [ -d "$first_archive_dir" ]
  [ -d "$second_archive_dir" ]
  [ -f "$first_archive_dir/REVIEW.md" ]
  [ -f "$second_archive_dir/REVIEW.md" ]
}

@test "rejects an invalid spec identifier" {
  cd "$PROJECT_DIR"
  run --separate-stderr env HOME="$SCRATCH_HOME" "$SCRIPT" "bad/id"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"invalid identifier"* ]]
}
