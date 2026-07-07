#!/usr/bin/env bats
#
# on-agent-complete.bats - focused tests for hooks/on-agent-complete.sh,
# driven via a synthetic transcript JSONL fixture and a JSON payload on
# stdin, rather than a full SubagentStop integration (per the plugin's
# test-suite scope: this hook is complex, so tests target the pieces
# that can be driven deterministically - bracket-stripped TASK_ID
# extraction, extract_spec_dir-based spec attribution with its mtime
# fallback, the artifact-audit trail check, and early self-filtering).

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  HOOK="$PLUGIN_ROOT/hooks/on-agent-complete.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/oac-bats.XXXXXX")"
  DATA_DIR="$TEST_TMPDIR/data"
  PROJECT_DIR="$TEST_TMPDIR/project"
  mkdir -p "$PROJECT_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

make_stdin() {
  # Args: transcript_path, agent_type (may be ""), stop_hook_active (true/false)
  local transcript="$1" agent_type="$2" stop_active="$3"
  jq -nc --arg tp "$transcript" --arg at "$agent_type" --argjson sha "$stop_active" --arg cwd "$PROJECT_DIR" \
    '{transcript_path: $tp, agent_type: $at, stop_hook_active: $sha, cwd: $cwd}'
}

# ------------------------------------------------------------------
# fast self-filtering paths
# ------------------------------------------------------------------

@test "exits 0 silently when stop_hook_active is true" {
  local transcript="$TEST_TMPDIR/transcript.jsonl"
  echo '{}' > "$transcript"
  local stdin_json
  stdin_json="$(jq -nc --arg tp "$transcript" '{transcript_path:$tp, stop_hook_active:true}')"
  run bash -c "printf '%s' '$stdin_json' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently on invalid (non-JSON) stdin payload" {
  run bash -c "printf 'not json at all' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently when transcript_path is missing or unreadable" {
  run bash -c "printf '%s' '{\"transcript_path\":\"/no/such/file.jsonl\"}' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "exits 0 silently for a non-autocode agent_type" {
  local transcript="$TEST_TMPDIR/transcript.jsonl"
  jq -nc '{type:"assistant", isSidechain:true, message:{content:[{type:"text", text:"## Task Completed"}]}}' > "$transcript"
  local stdin_json
  stdin_json="$(make_stdin "$transcript" "some-other-agent" false)"
  run bash -c "printf '%s' '$stdin_json' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ------------------------------------------------------------------
# bracket-stripped TASK_ID extraction + spec attribution + artifact audit
# ------------------------------------------------------------------

@test "extracts SPEC_DIR from the transcript's Task prompt, strips [T<n>] brackets, and flags a missing artifact trail" {
  cd "$PROJECT_DIR"
  mkdir -p ".specs/demo-spec"
  touch ".specs/demo-spec/TODO.md"

  local transcript="$TEST_TMPDIR/transcript.jsonl"
  {
    jq -nc '{type:"assistant", message:{content:[{type:"tool_use", name:"Task", input:{subagent_type:"autocode:task-runner", prompt:"Work on SPEC_DIR=.specs/demo-spec please"}}]}}'
    jq -nc '{type:"assistant", isSidechain:true, message:{content:[{type:"text", text:"## Task Completed\n\nFinished [T7] successfully."}]}}'
  } > "$transcript"

  local stdin_json
  stdin_json="$(make_stdin "$transcript" "autocode:task-runner" false)"

  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" bash -c "printf '%s' '$stdin_json' | '$HOOK'"
  [ "$status" -eq 0 ]

  # additionalContext must contain the bracket-stripped task id (task="T7", not "[T7]")
  ctx="$(printf '%s' "$output" | jq -r '.additionalContext')"
  [[ "$ctx" == *'task="T7"'* ]]
  [[ "$ctx" != *'[T7]'* ]]
  [[ "$ctx" == *'spec="demo-spec"'* ]]
  # no handoff.md and no artifacts dir at all -> audit status "missing"
  [[ "$ctx" == *'<artifact-audit'* ]]
  [[ "$ctx" == *'status="missing"'* ]]

  msg="$(printf '%s' "$output" | jq -r '.systemMessage')"
  [[ "$msg" == *"T7"* ]]
  [[ "$msg" == *"missing"* ]]
}

@test "does not flag the artifact audit when handoff.md is present and non-empty" {
  cd "$PROJECT_DIR"
  mkdir -p ".specs/demo-spec/artifacts/handoff"
  touch ".specs/demo-spec/TODO.md"
  echo "task_id: T7" > ".specs/demo-spec/artifacts/handoff/handoff.md"

  local transcript="$TEST_TMPDIR/transcript.jsonl"
  {
    jq -nc '{type:"assistant", message:{content:[{type:"tool_use", name:"Task", input:{subagent_type:"autocode:task-runner", prompt:"Work on SPEC_DIR=.specs/demo-spec please"}}]}}'
    jq -nc '{type:"assistant", isSidechain:true, message:{content:[{type:"text", text:"## Task Completed\n\nFinished [T7] successfully."}]}}'
  } > "$transcript"

  local stdin_json
  stdin_json="$(make_stdin "$transcript" "autocode:task-runner" false)"

  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" bash -c "printf '%s' '$stdin_json' | '$HOOK'"
  [ "$status" -eq 0 ]

  ctx="$(printf '%s' "$output" | jq -r '.additionalContext')"
  [[ "$ctx" != *"<artifact-audit"* ]]
  [[ "$ctx" == *'<agent-completed agent="autocode:task-runner" task="T7" spec="demo-spec" />'* ]]
}

# ------------------------------------------------------------------
# spec attribution mtime fallback (extract_spec_dir yields nothing)
# ------------------------------------------------------------------

@test "falls back to the mtime-based active-spec search when the transcript yields no SPEC_DIR" {
  cd "$PROJECT_DIR"
  mkdir -p ".specs/only-spec"
  touch ".specs/only-spec/TODO.md"

  local transcript="$TEST_TMPDIR/transcript.jsonl"
  {
    # Task prompt has no SPEC_DIR=, SPEC_DIR:, or .specs/ pattern at all.
    jq -nc '{type:"assistant", message:{content:[{type:"tool_use", name:"Task", input:{subagent_type:"autocode:task-runner", prompt:"Please handle the assigned task carefully."}}]}}'
    jq -nc '{type:"assistant", isSidechain:true, message:{content:[{type:"text", text:"## Task Completed\n\nDid [T2]."}]}}'
  } > "$transcript"

  # No agent_type on stdin either, forcing AGENT_NAME to fall back to the
  # transcript's own Task subagent_type.
  local stdin_json
  stdin_json="$(make_stdin "$transcript" "" false)"

  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" bash -c "printf '%s' '$stdin_json' | '$HOOK'"
  [ "$status" -eq 0 ]

  ctx="$(printf '%s' "$output" | jq -r '.additionalContext')"
  [[ "$ctx" == *'spec="only-spec"'* ]]
  [[ "$ctx" == *'task="T2"'* ]]
}

# ------------------------------------------------------------------
# failure logging backstop
# ------------------------------------------------------------------

@test "logs a failure to failures.jsonl when the agent output signals a failed task" {
  cd "$PROJECT_DIR"
  mkdir -p ".specs/demo-spec"
  touch ".specs/demo-spec/TODO.md"

  local transcript="$TEST_TMPDIR/transcript.jsonl"
  {
    jq -nc '{type:"assistant", message:{content:[{type:"tool_use", name:"Task", input:{subagent_type:"autocode:task-runner", prompt:"SPEC_DIR=.specs/demo-spec"}}]}}'
    jq -nc '{type:"assistant", isSidechain:true, message:{content:[{type:"text", text:"<task-completed status=\"failed\" reason=\"tests failed\" category=\"test_failure\"/>"}]}}'
  } > "$transcript"

  local stdin_json
  stdin_json="$(make_stdin "$transcript" "autocode:task-runner" false)"

  run env CLAUDE_PLUGIN_DATA="$DATA_DIR" bash -c "printf '%s' '$stdin_json' | '$HOOK'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]

  local f="$DATA_DIR/failures.jsonl"
  [ -f "$f" ]
  [ "$(jq -r '.failure_type' "$f")" = "test_failure" ]
  [ "$(jq -r '.description' "$f")" = "tests failed" ]
  [ "$(jq -r '.spec' "$f")" = "demo-spec" ]
}
