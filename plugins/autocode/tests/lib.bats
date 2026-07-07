#!/usr/bin/env bats
#
# lib.bats - tests for scripts/lib.sh: validate_identifier, require_identifier,
# spec_dir_for, json_escape, log_hook_error, extract_spec_dir.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  LIB="$PLUGIN_ROOT/scripts/lib.sh"
  source "$LIB"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/lib-bats.XXXXXX")"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ------------------------------------------------------------------
# validate_identifier
# ------------------------------------------------------------------

@test "validate_identifier: accepts letters, digits, dot, underscore, dash" {
  run validate_identifier "my-spec_v2.1"
  [ "$status" -eq 0 ]
}

@test "validate_identifier: accepts simple alnum id" {
  run validate_identifier "abc123"
  [ "$status" -eq 0 ]
}

@test "validate_identifier: rejects empty string" {
  run validate_identifier ""
  [ "$status" -ne 0 ]
}

@test "validate_identifier: rejects dots-only id (single dot)" {
  run validate_identifier "."
  [ "$status" -ne 0 ]
}

@test "validate_identifier: rejects dots-only id (double dot)" {
  run validate_identifier ".."
  [ "$status" -ne 0 ]
}

@test "validate_identifier: rejects dots-only id (many dots)" {
  run validate_identifier "...."
  [ "$status" -ne 0 ]
}

@test "validate_identifier: rejects path separator" {
  run validate_identifier "foo/bar"
  [ "$status" -ne 0 ]
}

@test "validate_identifier: rejects special characters" {
  run validate_identifier 'foo*bar'
  [ "$status" -ne 0 ]
  run validate_identifier 'foo bar'
  [ "$status" -ne 0 ]
  run validate_identifier 'foo$bar'
  [ "$status" -ne 0 ]
}

# ------------------------------------------------------------------
# require_identifier
# ------------------------------------------------------------------

@test "require_identifier: valid id returns 0 and prints nothing" {
  run require_identifier "valid-id.1"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "require_identifier: invalid id exits 1 with default message on stderr" {
  run --separate-stderr require_identifier "bad/id"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [[ "$stderr" == *"Error: invalid identifier 'bad/id'"* ]]
  [[ "$stderr" == *"must not be only dots"* ]]
}

@test "require_identifier: invalid id with custom usage message uses it instead of default" {
  run --separate-stderr require_identifier "bad/id" "Usage: foo.sh <identifier>"
  [ "$status" -eq 1 ]
  [ "$stderr" = "Usage: foo.sh <identifier>" ]
}

# ------------------------------------------------------------------
# spec_dir_for
# ------------------------------------------------------------------

@test "spec_dir_for: builds .specs/<id> path" {
  run spec_dir_for "my-feature"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/my-feature" ]
}

# ------------------------------------------------------------------
# json_escape
# ------------------------------------------------------------------

@test "json_escape: escapes double quotes" {
  run json_escape 'say "hi"'
  [ "$output" = 'say \"hi\"' ]
}

@test "json_escape: escapes backslash" {
  run json_escape 'a\b'
  [ "$output" = 'a\\b' ]
}

@test "json_escape: escapes backslash before quote escaping is applied (order matters)" {
  run json_escape 'a\"b'
  [ "$output" = 'a\\\"b' ]
}

@test "json_escape: escapes newline" {
  input="$(printf 'line1\nline2')"
  run json_escape "$input"
  [ "$output" = 'line1\nline2' ]
}

@test "json_escape: escapes carriage return and tab" {
  input="$(printf 'a\tb\rc')"
  run json_escape "$input"
  [ "$output" = 'a\tb\rc' ]
}

@test "json_escape: empty input produces empty output" {
  run json_escape ""
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "json_escape: round-trips into valid JSON via jq" {
  input='he said "hi" \ and left'
  escaped="$(json_escape "$input")"
  json_line="{\"msg\":\"$escaped\"}"
  printf '%s' "$json_line" > "$TEST_TMPDIR/round.json"
  run jq -e . "$TEST_TMPDIR/round.json"
  [ "$status" -eq 0 ]
  decoded="$(jq -r '.msg' "$TEST_TMPDIR/round.json")"
  [ "$decoded" = "$input" ]
}

# ------------------------------------------------------------------
# log_hook_error
# ------------------------------------------------------------------

@test "log_hook_error: writes a valid JSONL line without a payload" {
  export CLAUDE_PLUGIN_DATA="$TEST_TMPDIR/data"
  log_hook_error "test-hook" "something went wrong"
  local f="$CLAUDE_PLUGIN_DATA/hook-errors.jsonl"
  [ -f "$f" ]
  [ "$(wc -l < "$f" | tr -d ' ')" = "1" ]
  run jq -e . "$f"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.hook' "$f")" = "test-hook" ]
  [ "$(jq -r '.message' "$f")" = "something went wrong" ]
}

@test "log_hook_error: escapes a payload containing a quote and backslash" {
  export CLAUDE_PLUGIN_DATA="$TEST_TMPDIR/data"
  log_hook_error "test-hook" "bad payload" 'raw "quoted" \ text'
  local f="$CLAUDE_PLUGIN_DATA/hook-errors.jsonl"
  run jq -e . "$f"
  [ "$status" -eq 0 ]
  [ "$(jq -r '.payload' "$f")" = 'raw "quoted" \ text' ]
}

@test "log_hook_error: does nothing (but still returns 0) when CLAUDE_PLUGIN_DATA is unset" {
  unset CLAUDE_PLUGIN_DATA
  run log_hook_error "test-hook" "msg"
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_TMPDIR/data" ]
}

@test "log_hook_error: appends multiple lines, each independently valid JSON" {
  export CLAUDE_PLUGIN_DATA="$TEST_TMPDIR/data"
  log_hook_error "hook-a" "first"
  log_hook_error "hook-b" "second" 'with "quotes"'
  local f="$CLAUDE_PLUGIN_DATA/hook-errors.jsonl"
  [ "$(wc -l < "$f" | tr -d ' ')" = "2" ]
  while IFS= read -r line; do
    printf '%s' "$line" | jq -e . >/dev/null
  done < "$f"
}

# ------------------------------------------------------------------
# extract_spec_dir
# ------------------------------------------------------------------

make_transcript_line() {
  # Build one transcript JSONL line containing a single Task tool_use
  # content block. Args: subagent_type, prompt, env_spec_dir (may be "")
  local subagent="$1" prompt="$2" env_spec_dir="$3"
  if [ -n "$env_spec_dir" ]; then
    jq -nc --arg sa "$subagent" --arg p "$prompt" --arg sd "$env_spec_dir" \
      '{type:"assistant", message:{content:[{type:"tool_use", name:"Task", input:{subagent_type:$sa, prompt:$p, env:{SPEC_DIR:$sd}}}]}}'
  else
    jq -nc --arg sa "$subagent" --arg p "$prompt" \
      '{type:"assistant", message:{content:[{type:"tool_use", name:"Task", input:{subagent_type:$sa, prompt:$p}}]}}'
  fi
}

@test "extract_spec_dir: method 1, structured env.SPEC_DIR" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  make_transcript_line "autocode:task-runner" "do the thing" ".specs/env-spec" > "$t"
  run extract_spec_dir "$t"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/env-spec" ]
}

@test "extract_spec_dir: method 2, SPEC_DIR=value pattern in prompt" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  make_transcript_line "autocode:task-runner" "Please work. SPEC_DIR=.specs/eq-spec now go" "" > "$t"
  run extract_spec_dir "$t"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/eq-spec" ]
}

@test "extract_spec_dir: method 2, SPEC_DIR: value pattern in prompt" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  make_transcript_line "autocode:task-runner" "Context. SPEC_DIR: .specs/colon-spec please continue" "" > "$t"
  run extract_spec_dir "$t"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/colon-spec" ]
}

@test "extract_spec_dir: method 3, bare .specs/<id> path pattern in prompt" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  make_transcript_line "autocode:task-runner" "Read the spec at \`.specs/bare-spec/SPEC.md\` and continue." "" > "$t"
  run extract_spec_dir "$t"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/bare-spec" ]
}

@test "extract_spec_dir: strips trailing punctuation wrapping the path" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  make_transcript_line "autocode:task-runner" "See SPEC_DIR=.specs/punct-spec, thanks." "" > "$t"
  run extract_spec_dir "$t"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/punct-spec" ]
}

@test "extract_spec_dir: walks most-recent-first across multiple Task calls" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  {
    make_transcript_line "autocode:task-runner" "SPEC_DIR=.specs/first-spec" ""
    make_transcript_line "autocode:task-runner" "SPEC_DIR=.specs/second-spec" ""
  } > "$t"
  run extract_spec_dir "$t"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/second-spec" ]
}

@test "extract_spec_dir: subagent_type filter selects only matching Task calls" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  {
    make_transcript_line "autocode:coder" "SPEC_DIR=.specs/coder-spec" ""
    make_transcript_line "autocode:task-runner" "SPEC_DIR=.specs/runner-spec" ""
  } > "$t"
  run extract_spec_dir "$t" "autocode:coder"
  [ "$status" -eq 0 ]
  [ "$output" = ".specs/coder-spec" ]
}

@test "extract_spec_dir: subagent_type filter with no match returns 1" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  make_transcript_line "autocode:coder" "SPEC_DIR=.specs/coder-spec" "" > "$t"
  run extract_spec_dir "$t" "autocode:nonexistent"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "extract_spec_dir: returns 1 for missing transcript path" {
  run extract_spec_dir "$TEST_TMPDIR/does-not-exist.jsonl"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "extract_spec_dir: returns 1 when no Task tool_use is present" {
  local t="$TEST_TMPDIR/transcript.jsonl"
  jq -nc '{type:"assistant", message:{content:[{type:"text", text:"hello"}]}}' > "$t"
  run extract_spec_dir "$t"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}
