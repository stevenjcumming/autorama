#!/usr/bin/env bash
# Log usage events to CLAUDE_PLUGIN_DATA for cross-session analytics.
# Usage: log-usage.sh <event_type> <event_name> [status] [details]
#
# Events are appended to $CLAUDE_PLUGIN_DATA/usage.jsonl as newline-delimited JSON.
# If CLAUDE_PLUGIN_DATA is not set, exits silently (graceful degradation).

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

EVENT_TYPE="${1:-}"
EVENT_NAME="${2:-}"
STATUS="${3:-ok}"
DETAILS="${4:-}"

# Require CLAUDE_PLUGIN_DATA
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  exit 0
fi

# Require event type and name
if [ -z "$EVENT_TYPE" ] || [ -z "$EVENT_NAME" ]; then
  exit 0
fi

# Ensure data directory exists
mkdir -p "$CLAUDE_PLUGIN_DATA"

LOG_FILE="$CLAUDE_PLUGIN_DATA/usage.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Log both the basename (human-friendly) and the full path (item 38):
# basename alone conflates two repos checked out under the same
# directory name (e.g. two "autorama" clones on the same machine).
PROJECT_NAME=$(basename "$(pwd)")
PROJECT_PATH="$(pwd)"

# Get spec ID from SPEC_DIR if available
SPEC_ID=""
if [ -n "${SPEC_DIR:-}" ]; then
  SPEC_ID=$(basename "$SPEC_DIR")
fi

# Truncate consistently (item 38) so a single JSONL line can't exceed
# PIPE_BUF and interleave with other writers under parallel task
# runners; 500 chars matches log_hook_error's payload truncation in
# lib.sh.
DETAILS_TRUNCATED=$(printf '%s' "$DETAILS" | head -c 500)

# Build JSON line: jq when available, printf fallback otherwise
if command -v jq &>/dev/null; then
  echo "{}" | jq -c \
    --arg ts "$TIMESTAMP" \
    --arg type "$EVENT_TYPE" \
    --arg name "$EVENT_NAME" \
    --arg status "$STATUS" \
    --arg details "$DETAILS_TRUNCATED" \
    --arg project "$PROJECT_NAME" \
    --arg project_path "$PROJECT_PATH" \
    --arg spec "$SPEC_ID" \
    '{timestamp: $ts, type: $type, name: $name, status: $status, details: $details, project: $project, project_path: $project_path, spec: $spec}' \
    >> "$LOG_FILE"
else
  # Fallback writer (item 38): every interpolated field is routed
  # through json_escape (lib.sh), not just details as before - a `"` or
  # `\` in a project path or spec ID used to produce invalid JSONL.
  SAFE_DETAILS=$(json_escape "$(printf '%s' "$DETAILS_TRUNCATED" | tr -d '\n\r')")
  SAFE_TYPE=$(json_escape "$EVENT_TYPE")
  SAFE_NAME=$(json_escape "$EVENT_NAME")
  SAFE_STATUS=$(json_escape "$STATUS")
  SAFE_PROJECT=$(json_escape "$PROJECT_NAME")
  SAFE_PROJECT_PATH=$(json_escape "$PROJECT_PATH")
  SAFE_SPEC=$(json_escape "$SPEC_ID")
  printf '{"timestamp":"%s","type":"%s","name":"%s","status":"%s","details":"%s","project":"%s","project_path":"%s","spec":"%s"}\n' \
    "$TIMESTAMP" "$SAFE_TYPE" "$SAFE_NAME" "$SAFE_STATUS" "$SAFE_DETAILS" "$SAFE_PROJECT" "$SAFE_PROJECT_PATH" "$SAFE_SPEC" \
    >> "$LOG_FILE"
fi
