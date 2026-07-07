#!/usr/bin/env bash
#
# on-agent-complete.sh - SubagentStop hook for autocode agent completion
#
# SubagentStop fires for EVERY subagent stop in any project; hooks.json
# cannot express a matcher for this event, so this script self-filters
# and exits fast (well under the 60s hook timeout) for non-autocode
# agents.
#
# Payload (stdin JSON): session_id, transcript_path, cwd,
# hook_event_name, agent_type (recent CLIs), stop_hook_active. The
# payload does NOT include the subagent's output, so it is recovered
# from the transcript JSONL at transcript_path: the agent name comes
# from agent_type when present (most recent Task tool invocation
# otherwise), and the agent's final output from the most recent
# sidechain assistant entry (falling back to the most recent Task
# tool result).
#
# Output mechanism (see docs/autocode/hook-system.md "Hook I/O
# Decision"): plain stdout from SubagentStop is NOT added to model
# context, so signals are emitted as JSON with `additionalContext`
# (reaches Claude) and `systemMessage` (shown to the user).
#
# Behaviors for autocode agents:
# 1. Detect task completion or failure from the agent's final output
#    using the structured contract in references/failure-categories.md
# 2. Log task failures to failures.jsonl as a deterministic backstop
#    (the task-runner normally logs them itself)
# 3. Verify the artifact audit trail exists for completed tasks and
#    emit a structured warning when it is missing (deterministic
#    enforcement; the execute loop's check is prompt-based)
# 4. Optionally judge artifact substance via a read-only Agent SDK call
#    (gated by artifact_judge.enabled in autocode.yml, default off)
# 5. Check context limits via check-context.sh and signal if high
# 6. Emit <agent-completed> additional context for the parent session
#
# Every failure mode exits 0 silently; this hook must never block.
#

set -euo pipefail

HOOK_NAME="on-agent-complete"

# Shared helpers (item 8/23 fixes: extract_spec_dir, read_config_value).
# Sourced early, before the local log_hook_error definition below, so
# that local definition - which uses this hook's existing single-arg
# call convention (relying on the global $INPUT for the payload rather
# than lib.sh's log_hook_error(hook, message, payload) signature) -
# intentionally shadows the one lib.sh provides. This keeps every
# existing log_hook_error call site in this file working unchanged.
# Never fails: a missing lib.sh degrades to the functions being absent,
# and every call site below tolerates that via `|| true`.
source "$(dirname "$0")/../scripts/lib.sh" 2>/dev/null || true
source "$(dirname "$0")/../scripts/read-config.sh" 2>/dev/null || true

# Log unparseable/unexpected payloads so hook failures are observable
# instead of silent. Never fails the hook.
log_hook_error() {
  [ -z "${CLAUDE_PLUGIN_DATA:-}" ] && return 0
  mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || return 0
  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
  if command -v jq &> /dev/null; then
    jq -cn --arg ts "$ts" --arg hook "$HOOK_NAME" --arg reason "$1" --arg payload "${INPUT:-}" \
      '{timestamp: $ts, hook: $hook, reason: $reason, payload: $payload[0:2000]}' \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  else
    printf '{"timestamp":"%s","hook":"%s","reason":"%s"}\n' "$ts" "$HOOK_NAME" "$1" \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  fi
  return 0
}

# Check for jq dependency (required for parsing JSON input and transcript)
if ! command -v jq &> /dev/null; then
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Validate the payload is JSON; log and bail if not
if ! echo "$INPUT" | jq -e . >/dev/null 2>&1; then
  log_hook_error "stdin payload is not valid JSON"
  exit 0
fi

# Do nothing if another stop hook is already active (prevents loops)
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false' 2>/dev/null || true)
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
  exit 0
fi

TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // empty' 2>/dev/null || true)
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -r "$TRANSCRIPT_PATH" ]; then
  log_hook_error "transcript_path missing or unreadable"
  exit 0
fi

# ============================================================================
# Recover agent name and output from the transcript JSONL
# ============================================================================

# Bound the work: only inspect the tail of the transcript. A few hundred
# lines is enough to cover the latest Task invocation and the agent's
# final output, and keeps runtime negligible on long sessions.
TRANSCRIPT_TAIL=$(tail -n 400 "$TRANSCRIPT_PATH" 2>/dev/null || true)
if [ -z "$TRANSCRIPT_TAIL" ]; then
  exit 0
fi

# Agent name: prefer the documented agent_type payload field; fall back
# to the subagent_type of the most recent Task tool invocation in the
# transcript. fromjson? makes malformed lines yield nothing.
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_type // empty' 2>/dev/null || true)
if [ -z "$AGENT_NAME" ]; then
  AGENT_NAME=$(printf '%s\n' "$TRANSCRIPT_TAIL" | jq -Rr '
    fromjson? | .message.content[]? |
    select(.type? == "tool_use" and .name? == "Task") |
    .input.subagent_type // empty
  ' 2>/dev/null | tail -n 1 || true)
fi

# Shared convention (also used by load-context.sh and log-skill-usage.sh):
# an autocode agent is one spawned with subagent_type "autocode:<name>".
if [ -z "$AGENT_NAME" ] || [[ "$AGENT_NAME" != autocode:* ]]; then
  exit 0
fi

# Agent output: text of the most recent sidechain assistant entry
AGENT_OUTPUT=$(printf '%s\n' "$TRANSCRIPT_TAIL" | jq -Rrs '
  [split("\n")[] | fromjson? | select(.type? == "assistant" and .isSidechain? == true)]
  | last
  | if . == null then ""
    else ([.message.content[]? | select(.type? == "text") | .text] | join("\n"))
    end
' 2>/dev/null || true)

# Fallback: the most recent Task tool result in the parent chain
if [ -z "$AGENT_OUTPUT" ]; then
  AGENT_OUTPUT=$(printf '%s\n' "$TRANSCRIPT_TAIL" | jq -Rrs '
    [split("\n")[] | fromjson? | .message.content[]? | select(.type? == "tool_result")]
    | last
    | if . == null then ""
      else (.content
            | if type == "array" then ([.[] | select(.type? == "text") | .text] | join("\n"))
              elif type == "string" then .
              else "" end)
      end
  ' 2>/dev/null || true)
fi

# If the output cannot be recovered, log it (observable, per the
# missing-tag fallback rule) and exit
if [ -z "$AGENT_OUTPUT" ]; then
  log_hook_error "could not recover output for $AGENT_NAME from transcript"
  exit 0
fi

# ============================================================================
# Find spec directory using shared utility
# ============================================================================

PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-${AUTOCODE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}}"
FIND_SPEC_SCRIPT="$PLUGIN_DIR/scripts/find-active-spec.sh"

# Primary: recover SPEC_DIR from the transcript's most recent Task
# invocation whose subagent_type matches this agent (AGENT_NAME, e.g.
# "autocode:task-runner"), via lib.sh's extract_spec_dir. This replaces
# the old "most recently modified TODO.md" mtime heuristic as the
# primary source of attribution: with two active specs or parallel
# task-runners, mtime alone can pick the wrong spec's TODO.md for a
# completion/failure/artifact-audit that belongs to a different spec
# (item 8 / roadmap 3.3). The mtime heuristic (find-active-spec.sh)
# below is now only a last-resort fallback for when the transcript
# yields nothing (e.g. extract_spec_dir/jq unavailable, or the Task
# invocation used a prompt shape none of its 3 extraction methods
# recognize).
SPEC_DIR=""
if command -v extract_spec_dir >/dev/null 2>&1; then
  EXTRACTED_SPEC_DIR=$(extract_spec_dir "$TRANSCRIPT_PATH" "$AGENT_NAME" 2>/dev/null || true)
  if [ -n "$EXTRACTED_SPEC_DIR" ] && [ -d "$EXTRACTED_SPEC_DIR" ]; then
    SPEC_DIR="$EXTRACTED_SPEC_DIR"
  fi
fi

if [ -z "$SPEC_DIR" ] && [ -x "$FIND_SPEC_SCRIPT" ]; then
  FIND_RESULT=$("$FIND_SPEC_SCRIPT" 2>/dev/null || echo "NOT_FOUND")
  if [[ "$FIND_RESULT" == FOUND:* ]]; then
    SPEC_DIR=$(echo "$FIND_RESULT" | cut -d: -f2)
  fi
elif [ -z "$SPEC_DIR" ]; then
  # Fallback: find any spec directory with a TODO.md
  for todo_file in .specs/*/TODO.md; do
    if [ -f "$todo_file" ]; then
      SPEC_DIR=$(dirname "$todo_file")
      break
    fi
  done
fi

# If no spec found, exit silently
if [ -z "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
  exit 0
fi

# Extract spec_id from path
SPEC_ID=$(basename "$SPEC_DIR")

# ============================================================================
# Detect task completion or failure from agent output
# (contract: references/failure-categories.md)
# ============================================================================

TASK_COMPLETED="false"
TASK_FAILED="false"
TASK_ID=""

if echo "$AGENT_OUTPUT" | grep -qE '<task-completed[^>]*status="completed"'; then
  TASK_COMPLETED="true"
elif echo "$AGENT_OUTPUT" | grep -qE '^##[[:space:]]+Task Completed[[:space:]]*$'; then
  # Anchored heading only; loose phrases like "task could not be
  # completed" must not count as completion.
  TASK_COMPLETED="true"
elif echo "$AGENT_OUTPUT" | grep -qE '<task-completed[^>]*status="failed"'; then
  TASK_FAILED="true"
fi

# Try structured tag first, then bracketed ID
TASK_ID=$(echo "$AGENT_OUTPUT" | grep -oE '<task-completed[^>]*task="[^"]*"' | grep -oE 'task="[^"]*"' | head -1 | sed 's/^task="//; s/"$//' || true)
if [ -z "$TASK_ID" ]; then
  TASK_ID=$(echo "$AGENT_OUTPUT" | grep -oE '\[T[0-9]+\]' | head -1 || true)
fi

# Strip brackets: the fallback pattern matches "[T1]" verbatim, but
# "[...]" is a glob character class, so an unstripped TASK_ID silently
# breaks the `find -name "${TASK_ID}_*"` glob below (item 3 / roadmap
# 1.2) and would otherwise leak into the audit tag / failure log.
TASK_ID=${TASK_ID//[\[\]]/}

# ============================================================================
# Log failures for cross-spec learning (backstop for the task-runner)
# ============================================================================

if [ "$TASK_FAILED" = "true" ]; then
  REASON=$(echo "$AGENT_OUTPUT" | grep -oE '<task-completed[^>]*reason="[^"]*"' | grep -oE 'reason="[^"]*"' | head -1 | sed 's/^reason="//; s/"$//' || true)
  CATEGORY=$(echo "$AGENT_OUTPUT" | grep -oE '<task-completed[^>]*category="[^"]*"' | grep -oE 'category="[^"]*"' | head -1 | sed 's/^category="//; s/"$//' || true)
  LOG_FAILURE_SCRIPT="$PLUGIN_DIR/scripts/log-failure.sh"
  if [ -x "$LOG_FAILURE_SCRIPT" ]; then
    "$LOG_FAILURE_SCRIPT" "$AGENT_NAME" "${CATEGORY:-task_failed}" "${REASON:-${TASK_ID:-unknown}}" "$SPEC_ID" >/dev/null 2>&1 || true
  fi
  exit 0
fi

# Only proceed if task was completed
if [ "$TASK_COMPLETED" != "true" ]; then
  exit 0
fi

# Accumulators for the JSON output emitted at the end
CONTEXT_OUT=""
SYS_MSG=""

append_context() {
  if [ -z "$CONTEXT_OUT" ]; then
    CONTEXT_OUT="$1"
  else
    CONTEXT_OUT="$CONTEXT_OUT
$1"
  fi
}

# ============================================================================
# Verify the artifact audit trail (deterministic enforcement)
# ============================================================================

# Only the task-runner owns artifact generation (its Step 6); auditing
# other agents would produce noise.
if [ "$AGENT_NAME" = "autocode:task-runner" ]; then
  HANDOFF_FILE="$SPEC_DIR/artifacts/handoff/handoff.md"
  TASK_ARTIFACT_COUNT=0
  if [ -n "$TASK_ID" ] && [ -d "$SPEC_DIR/artifacts" ]; then
    TASK_ARTIFACT_COUNT=$(find "$SPEC_DIR/artifacts" -type f -name "${TASK_ID}_*" -size +1c 2>/dev/null | wc -l | tr -d ' ')
  fi

  AUDIT_STATUS=""
  AUDIT_DETAIL=""
  if [ ! -s "$HANDOFF_FILE" ] && [ "$TASK_ARTIFACT_COUNT" -eq 0 ]; then
    AUDIT_STATUS="missing"
    AUDIT_DETAIL="no non-empty handoff.md and no non-empty ${TASK_ID:-task}-scoped artifact files"
  elif [ ! -s "$HANDOFF_FILE" ]; then
    AUDIT_STATUS="incomplete"
    AUDIT_DETAIL="handoff.md is missing or empty"
  fi

  if [ -n "$AUDIT_STATUS" ]; then
    append_context "<artifact-audit task=\"$TASK_ID\" spec=\"$SPEC_ID\" status=\"$AUDIT_STATUS\" detail=\"$AUDIT_DETAIL\" />"
    SYS_MSG="autocode: task $TASK_ID completed but its artifact audit trail is $AUDIT_STATUS ($AUDIT_DETAIL)"
  fi

  # Optional: judge artifact substance with a read-only Agent SDK call.
  # Gated behind artifact_judge.enabled in .claude/autocode.yml (default
  # off: costs tokens and requires node with @anthropic-ai/claude-agent-sdk).
  CONFIG_FILE=".claude/autocode.yml"
  # item 23/2.4 fix: read_config_value's indentation-anchored parser
  # replaces the old `grep -A3 '^artifact_judge:'` window, which broke
  # the moment a comment line separated the key from `enabled:` or any
  # other `enabled:` key fell inside the grepped window. Default "false"
  # matches the previous fallback (judge is opt-in).
  if command -v read_config_value >/dev/null 2>&1; then
    JUDGE_ENABLED=$(read_config_value "$CONFIG_FILE" "artifact_judge.enabled" "false")
  else
    JUDGE_ENABLED="false"
  fi

  JUDGE_SCRIPT="$PLUGIN_DIR/hooks/judge-artifacts.mjs"
  if [ "$JUDGE_ENABLED" = "true" ] && [ -z "$AUDIT_STATUS" ] && command -v node &>/dev/null && [ -f "$JUDGE_SCRIPT" ]; then
    # Pin a cheap model for the judge (item 7 / roadmap 3.4) so an
    # unconfigured project never has it silently run on an expensive
    # default model; configurable via artifact_judge.model.
    if command -v read_config_value >/dev/null 2>&1; then
      JUDGE_MODEL=$(read_config_value "$CONFIG_FILE" "artifact_judge.model" "claude-haiku-4-5-20251001")
    else
      JUDGE_MODEL="claude-haiku-4-5-20251001"
    fi
    JUDGE_RESULT=$(AUTOCODE_JUDGE_MODEL="$JUDGE_MODEL" node "$JUDGE_SCRIPT" "$SPEC_DIR" "$TASK_ID" 2>/dev/null || true)
    JUDGE_PASS=$(echo "$JUDGE_RESULT" | jq -r '.pass // empty' 2>/dev/null || true)
    JUDGE_REASON=$(echo "$JUDGE_RESULT" | jq -r '.reason // empty' 2>/dev/null || true)
    if [ "$JUDGE_PASS" = "false" ]; then
      append_context "<artifact-audit task=\"$TASK_ID\" spec=\"$SPEC_ID\" status=\"insubstantial\" detail=\"$JUDGE_REASON\" />"
      SYS_MSG="autocode: artifact judge flagged task $TASK_ID artifacts as insubstantial: $JUDGE_REASON"
    fi
  fi
fi

# ============================================================================
# Check context limits and trigger session summary if needed
# ============================================================================

CHECK_CONTEXT_SCRIPT="$PLUGIN_DIR/scripts/check-context.sh"

if [ -x "$CHECK_CONTEXT_SCRIPT" ]; then
  # Contract: check-context.sh always exits 0 and prints a single line
  # prefixed OK:, WARNING:, or CRITICAL:. The || true only tolerates a
  # broken or unexecutable script.
  CONTEXT_RESULT=$("$CHECK_CONTEXT_SCRIPT" "$SPEC_DIR" 2>/dev/null || true)

  case "$CONTEXT_RESULT" in
    CRITICAL:*)
      # Context is critically high - signal for immediate summarization
      ESTIMATED_TOKENS=$(echo "$CONTEXT_RESULT" | cut -d: -f3)
      append_context "<context-critical tokens=\"$ESTIMATED_TOKENS\" spec=\"$SPEC_ID\">
  Context usage is critically high. Session summarization required.
  Consider spawning session-summarizer agent before continuing.
</context-critical>"
      ;;
    WARNING:*)
      # Context is approaching limit - signal warning
      ESTIMATED_TOKENS=$(echo "$CONTEXT_RESULT" | cut -d: -f3)
      append_context "<context-warning tokens=\"$ESTIMATED_TOKENS\" spec=\"$SPEC_ID\" />"
      ;;
    *)
      # OK, empty, or unparseable - no action needed
      ;;
  esac
fi

# ============================================================================
# Signal completion
# ============================================================================

append_context "<agent-completed agent=\"$AGENT_NAME\" task=\"$TASK_ID\" spec=\"$SPEC_ID\" />"

# Plain stdout from SubagentStop never reaches model context; emit the
# documented JSON output instead. additionalContext reaches Claude,
# systemMessage is shown to the user.
jq -cn --arg ctx "$CONTEXT_OUT" --arg msg "$SYS_MSG" '
  {additionalContext: $ctx}
  + (if $msg != "" then {systemMessage: $msg} else {} end)
' 2>/dev/null || log_hook_error "failed to build JSON output"

exit 0
