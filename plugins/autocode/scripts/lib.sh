#!/usr/bin/env bash
#
# lib.sh - Shared bash helpers for the autocode plugin.
#
# This file is meant to be *sourced*, never executed directly. It has no
# top-level side effects and does not set `set -e`/`set -u`/`set -o
# pipefail` itself, so sourcing it never changes the caller's shell
# options. Functions that need strict internal behavior guard for it
# locally instead of relying on the caller's `set -e`.
#
# How to source it (path depends on how deep the call site is under the
# plugin root; both are known, fixed layouts today):
#
#   Skill scripts at skills/<name>/scripts/foo.sh (3 levels down):
#     source "$(dirname "$0")/../../../scripts/lib.sh"
#
#   Hooks at hooks/foo.sh (1 level down):
#     source "$(dirname "$0")/../scripts/lib.sh"
#
# NOTE: both forms assume the caller stays within the plugin tree at that
# exact depth. This is a known, unhardened assumption (no realpath/find-up
# resolution) - if a script moves to a different depth, its relative
# source path must be updated by hand.
#
# Compatibility: written for bash 3.2+ (macOS's shipped bash) as well as
# modern GNU bash. No associative arrays, no `mapfile`/`readarray`, no
# other bash-4-only features.
#
# Functions provided:
#   validate_identifier <id>
#   require_identifier <id> [usage_message]
#   spec_dir_for <id>
#   json_escape <string>
#   log_hook_error <hook_name> <message> [raw_payload]
#   extract_spec_dir <transcript_path> [subagent_type_filter]

# ==============================================================================
# validate_identifier - check a spec/task identifier against the shared
# convention used across the plugin's skill scripts: letters, digits,
# '.', '_', '-' only, and not made up entirely of dots (so "." and ".."
# can't be used to escape .specs/).
#
# Returns 0 (true) if valid, 1 (false) otherwise. Never exits/prints.
# ==============================================================================
validate_identifier() {
  local id="${1:-}"
  [[ "$id" =~ ^[A-Za-z0-9._-]+$ ]] && [[ ! "$id" =~ ^\.+$ ]]
}

# ==============================================================================
# require_identifier - validate_identifier, but exits the calling script
# with an error message on failure. Intended for scripts that currently
# start with a hand-rolled "if [[ ! ... ]]; then echo ...; exit 1; fi"
# block.
#
# Usage: require_identifier "$IDENTIFIER" ["$usage_message"]
#
# If usage_message is omitted, falls back to the exact wording shared by
# every current call site (create-plan.sh, create-tasks.sh,
# validate-autocode.sh, new-spec.sh, review.sh, spec-archive.sh):
#   "Error: invalid identifier '<id>' (allowed: letters, digits, '.',
#   '_', '-'; must not be only dots)"
#
# Callers that want a custom/additional usage line (e.g. "Usage: foo.sh
# <identifier>") should pass their own message.
# ==============================================================================
require_identifier() {
  local id="${1:-}"
  local usage_message="${2:-}"

  if ! validate_identifier "$id"; then
    if [ -n "$usage_message" ]; then
      echo "$usage_message" >&2
    else
      echo "Error: invalid identifier '$id' (allowed: letters, digits, '.', '_', '-'; must not be only dots)" >&2
    fi
    exit 1
  fi

  return 0
}

# ==============================================================================
# spec_dir_for - centralize the ".specs/<id>" path construction so a
# future layout change is a one-line edit.
#
# Usage: SPEC_DIR="$(spec_dir_for "$IDENTIFIER")"
# ==============================================================================
spec_dir_for() {
  local id="${1:-}"
  printf '.specs/%s\n' "$id"
}

# ==============================================================================
# json_escape - escape a string for safe embedding as a JSON string value
# (i.e. the content that goes between the quotes). Escapes backslash,
# double-quote, newline, carriage return, and tab.
#
# Safe under `set -e`/`set -u`: never fails, handles unset/empty input.
#
# Usage: escaped="$(json_escape "$raw")"
# ==============================================================================
json_escape() {
  local s="${1:-}"
  # Backslash must be escaped first, or the backslashes introduced by the
  # later substitutions would themselves get re-escaped.
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# ==============================================================================
# log_hook_error - append a structured JSON line describing a hook
# failure to ${CLAUDE_PLUGIN_DATA}/hook-errors.jsonl. Never fails: always
# returns 0, even if CLAUDE_PLUGIN_DATA is unset or the write fails.
#
# Usage: log_hook_error "$HOOK_NAME" "$message" ["$raw_payload"]
#
# Fields written: timestamp (UTC, date -u +%Y-%m-%dT%H:%M:%SZ), hook,
# message, and - only when a payload is passed - payload (truncated to
# ~500 bytes). Every field is passed through json_escape, which is the
# item-38 fix over the previous copies of this function (those only
# escaped one field, e.g. via jq's --arg for the payload, and the
# no-jq fallback branch didn't escape anything).
# ==============================================================================
log_hook_error() {
  local hook_name="${1:-}"
  local message="${2:-}"
  local payload="${3:-}"

  [ -z "${CLAUDE_PLUGIN_DATA:-}" ] && return 0
  mkdir -p "$CLAUDE_PLUGIN_DATA" 2>/dev/null || return 0

  local ts
  ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")

  local esc_hook esc_message
  esc_hook=$(json_escape "$hook_name")
  esc_message=$(json_escape "$message")

  if [ -n "$payload" ]; then
    local truncated esc_payload
    truncated=$(printf '%s' "$payload" | head -c 500)
    esc_payload=$(json_escape "$truncated")
    printf '{"timestamp":"%s","hook":"%s","message":"%s","payload":"%s"}\n' \
      "$ts" "$esc_hook" "$esc_message" "$esc_payload" \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  else
    printf '{"timestamp":"%s","hook":"%s","message":"%s"}\n' \
      "$ts" "$esc_hook" "$esc_message" \
      >> "$CLAUDE_PLUGIN_DATA/hook-errors.jsonl" 2>/dev/null || true
  fi

  return 0
}

# ==============================================================================
# extract_spec_dir - recover a SPEC_DIR from a transcript JSONL file by
# looking at Task tool invocations, using the same 3-method extraction
# load-context.sh uses on a single Task tool_input payload:
#
#   Method 1: tool_input.env.SPEC_DIR (structured)
#   Method 2: a "SPEC_DIR=value" / "SPEC_DIR:value" pattern in the prompt
#   Method 3: the first ".specs/<id>" path pattern anywhere in the prompt
#
# followed by load-context.sh's trailing-punctuation strip (prompts often
# wrap the path in backticks/quotes/trailing punctuation).
#
# Unlike load-context.sh (which only ever sees one Task tool_input at a
# time, live, via PreToolUse stdin), this operates over a whole
# transcript that may contain many Task invocations, so it walks matches
# most-recent-first and returns the first one that yields a SPEC_DIR.
#
# Usage: extract_spec_dir "$TRANSCRIPT_PATH" ["$SUBAGENT_TYPE_FILTER"]
# Prints the discovered SPEC_DIR (no trailing newline processing beyond
# a single terminator) and returns 0 on success; prints nothing and
# returns 1 if nothing could be recovered (missing transcript, no jq,
# no matching Task call, or no SPEC_DIR pattern found).
#
# When subagent_type_filter is omitted (the default, matching
# load-context.sh's behavior, which has no concept of filtering), every
# Task invocation is considered regardless of subagent_type.
# ==============================================================================
extract_spec_dir() {
  local transcript_path="${1:-}"
  local subagent_filter="${2:-}"

  if [ -z "$transcript_path" ] || [ ! -r "$transcript_path" ]; then
    return 1
  fi
  if ! command -v jq &>/dev/null; then
    return 1
  fi

  # Bound the work the same way on-agent-complete.sh does: the tail of
  # the transcript is enough to cover recent Task invocations.
  local inputs_json
  inputs_json=$(tail -n 400 "$transcript_path" 2>/dev/null | jq -Rc --arg filt "$subagent_filter" '
    fromjson? | .message.content[]? |
    select(.type? == "tool_use" and .name? == "Task") |
    select($filt == "" or (.input.subagent_type? == $filt)) |
    (.input // {})
  ' 2>/dev/null || true)

  if [ -z "$inputs_json" ]; then
    return 1
  fi

  # Collect matches into an array (bash 3.2-safe: no mapfile/readarray).
  local -a task_inputs=()
  local line
  while IFS= read -r line; do
    [ -n "$line" ] && task_inputs+=("$line")
  done <<< "$inputs_json"

  local spec_dir=""
  local i
  for (( i=${#task_inputs[@]}-1; i>=0; i-- )); do
    line="${task_inputs[$i]}"

    local prompt env_spec_dir
    env_spec_dir=$(echo "$line" | jq -r '.env.SPEC_DIR // empty' 2>/dev/null || true)
    prompt=$(echo "$line" | jq -r '.prompt // empty' 2>/dev/null || true)

    # Method 1: structured env.SPEC_DIR
    spec_dir="$env_spec_dir"

    # Method 2: SPEC_DIR=value / SPEC_DIR:value pattern in the prompt
    if [ -z "$spec_dir" ]; then
      spec_dir=$(echo "$prompt" | grep -oE 'SPEC_DIR[=:][[:space:]]*[^[:space:]]+' | head -1 | sed 's/^SPEC_DIR[=:][[:space:]]*//' || true)
    fi

    # Method 3: .specs/<id> path pattern anywhere in the prompt
    if [ -z "$spec_dir" ]; then
      spec_dir=$(echo "$prompt" | grep -oE '\.specs/[^[:space:]/]+' | head -1 || true)
    fi

    if [ -n "$spec_dir" ]; then
      break
    fi
  done

  # Strip trailing punctuation/backticks that prompts may wrap around the path
  spec_dir=$(printf '%s' "$spec_dir" | sed "s/[\`'\".,;:)]*\$//")

  if [ -z "$spec_dir" ]; then
    return 1
  fi

  printf '%s\n' "$spec_dir"
  return 0
}
