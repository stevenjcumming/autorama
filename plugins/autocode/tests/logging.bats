#!/usr/bin/env bats
#
# logging.bats - tests for scripts/log-usage.sh and scripts/log-failure.sh:
# both scripts must produce valid JSONL (parseable line-by-line by `jq .`)
# on both the jq-available path and the no-jq printf/json_escape fallback
# path, even when a field contains a double quote.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  LOG_USAGE="$PLUGIN_ROOT/scripts/log-usage.sh"
  LOG_FAILURE="$PLUGIN_ROOT/scripts/log-failure.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/log-bats.XXXXXX")"
  DATA_DIR="$TEST_TMPDIR/data"

  # Build a "no jq on PATH" shadow bin directory containing only the
  # handful of external commands these two scripts (and the lib.sh they
  # source) actually call, so PATH can point ONLY at it and still work,
  # while jq is nowhere to be found.
  NO_JQ_BIN="$TEST_TMPDIR/no-jq-bin"
  mkdir -p "$NO_JQ_BIN"
  for cmd in date mkdir head tr basename dirname cat bash; do
    real="$(command -v "$cmd")"
    ln -s "$real" "$NO_JQ_BIN/$cmd"
  done
  NO_JQ_PATH="$NO_JQ_BIN"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

assert_all_lines_valid_json() {
  local file="$1"
  [ -f "$file" ]
  [ -s "$file" ]
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    printf '%s' "$line" | jq -e . >/dev/null
  done < "$file"
}

# ------------------------------------------------------------------
# sanity: the no-jq shadow PATH really hides jq
# ------------------------------------------------------------------

@test "shadow no-jq PATH hides jq" {
  run env PATH="$NO_JQ_PATH" bash -c "command -v jq"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

# ------------------------------------------------------------------
# log-usage.sh
# ------------------------------------------------------------------

@test "log-usage.sh (jq available): produces valid JSONL with a quoted details field" {
  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_USAGE" "agent_spawn" "task-runner" "ok" 'said "hi" to the user'
  [ "$status" -eq 0 ]
  local f="$DATA_DIR/usage.jsonl"
  assert_all_lines_valid_json "$f"
  [ "$(jq -r '.details' "$f")" = 'said "hi" to the user' ]
  [ "$(jq -r '.type' "$f")" = "agent_spawn" ]
  [ "$(jq -r '.name' "$f")" = "task-runner" ]
  [ "$(jq -r '.status' "$f")" = "ok" ]
  [ "$(jq -r '.project_path' "$f")" != "" ]
}

@test "log-usage.sh (no jq): produces valid JSONL with a quoted details field" {
  run env PATH="$NO_JQ_PATH" CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_USAGE" "agent_spawn" "task-runner" "ok" 'said "hi" to the user'
  [ "$status" -eq 0 ]
  local f="$DATA_DIR/usage.jsonl"
  assert_all_lines_valid_json "$f"
  [ "$(jq -r '.details' "$f")" = 'said "hi" to the user' ]
  [ "$(jq -r '.type' "$f")" = "agent_spawn" ]
}

@test "log-usage.sh (no jq): a backslash in details does not break the JSON" {
  run env PATH="$NO_JQ_PATH" CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_USAGE" "agent_spawn" "task-runner" "ok" 'path\to\thing "quoted"'
  [ "$status" -eq 0 ]
  local f="$DATA_DIR/usage.jsonl"
  assert_all_lines_valid_json "$f"
  [ "$(jq -r '.details' "$f")" = 'path\to\thing "quoted"' ]
}

@test "log-usage.sh: exits silently when CLAUDE_PLUGIN_DATA is unset" {
  run env -u CLAUDE_PLUGIN_DATA "$LOG_USAGE" "agent_spawn" "task-runner" "ok" "details"
  [ "$status" -eq 0 ]
  [ ! -e "$DATA_DIR" ]
}

@test "log-usage.sh: includes a spec field derived from SPEC_DIR when set" {
  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" SPEC_DIR=".specs/my-feature" "$LOG_USAGE" "agent_spawn" "task-runner" "ok" "details"
  [ "$status" -eq 0 ]
  local f="$DATA_DIR/usage.jsonl"
  [ "$(jq -r '.spec' "$f")" = "my-feature" ]
}

# ------------------------------------------------------------------
# log-failure.sh
# ------------------------------------------------------------------

@test "log-failure.sh (jq available): produces valid JSONL with a quoted description field" {
  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_FAILURE" "autocode:task-runner" "test_failure" 'tests said "fail" unexpectedly' "demo-spec"
  [ "$status" -eq 0 ]
  local f="$DATA_DIR/failures.jsonl"
  assert_all_lines_valid_json "$f"
  [ "$(jq -r '.description' "$f")" = 'tests said "fail" unexpectedly' ]
  [ "$(jq -r '.agent' "$f")" = "autocode:task-runner" ]
  [ "$(jq -r '.failure_type' "$f")" = "test_failure" ]
  [ "$(jq -r '.spec' "$f")" = "demo-spec" ]
}

@test "log-failure.sh (no jq): produces valid JSONL with a quoted description field" {
  run env PATH="$NO_JQ_PATH" CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_FAILURE" "autocode:task-runner" "test_failure" 'tests said "fail" unexpectedly' "demo-spec"
  [ "$status" -eq 0 ]
  local f="$DATA_DIR/failures.jsonl"
  assert_all_lines_valid_json "$f"
  [ "$(jq -r '.description' "$f")" = 'tests said "fail" unexpectedly' ]
  [ "$(jq -r '.spec' "$f")" = "demo-spec" ]
}

@test "log-failure.sh (no jq): a backslash-and-quote combo in description does not break the JSON" {
  run env PATH="$NO_JQ_PATH" CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_FAILURE" 'autocode:task-runner' 'test_failure' 'C:\path\to\"file\"' "demo-spec"
  [ "$status" -eq 0 ]
  local f="$DATA_DIR/failures.jsonl"
  assert_all_lines_valid_json "$f"
  [ "$(jq -r '.description' "$f")" = 'C:\path\to\"file\"' ]
}

@test "log-failure.sh: exits silently when required fields are missing" {
  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_FAILURE" "" ""
  [ "$status" -eq 0 ]
  [ ! -e "$DATA_DIR/failures.jsonl" ]
}

@test "both loggers append to the same files across multiple calls without corrupting earlier lines" {
  env CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_USAGE" "type1" "name1" "ok" 'first "one"'
  env PATH="$NO_JQ_PATH" CLAUDE_PLUGIN_DATA="$DATA_DIR" "$LOG_USAGE" "type2" "name2" "fail" 'second\ "two"'
  local f="$DATA_DIR/usage.jsonl"
  [ "$(wc -l < "$f" | tr -d ' ')" = "2" ]
  assert_all_lines_valid_json "$f"
}
