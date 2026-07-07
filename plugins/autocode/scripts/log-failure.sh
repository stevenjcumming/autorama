#!/usr/bin/env bash
# Log a failure pattern to CLAUDE_PLUGIN_DATA for cross-spec learning.
# Usage: log-failure.sh <agent_name> <failure_type> <description> [spec_id]
#
# Failures are appended to $CLAUDE_PLUGIN_DATA/failures.jsonl.
# read-history.sh consumes these for cross-spec failure summaries.

set -euo pipefail

# shellcheck source=lib.sh
source "$(dirname "$0")/lib.sh"

AGENT_NAME="${1:-}"
FAILURE_TYPE="${2:-}"
DESCRIPTION="${3:-}"
SPEC_ID="${4:-}"

# Require CLAUDE_PLUGIN_DATA
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  exit 0
fi

# Require fields
if [ -z "$AGENT_NAME" ] || [ -z "$FAILURE_TYPE" ]; then
  exit 0
fi

mkdir -p "$CLAUDE_PLUGIN_DATA"

LOG_FILE="$CLAUDE_PLUGIN_DATA/failures.jsonl"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Log both the basename and the full path (item 38): basename alone
# conflates two repos checked out under the same directory name.
PROJECT_NAME=$(basename "$(pwd)")
PROJECT_PATH="$(pwd)"

# Truncate consistently (item 38; matches log-usage.sh and
# log_hook_error's 500 char payload truncation in lib.sh) so a long
# description can't exceed PIPE_BUF and interleave with other writers
# under parallel task-runners.
DESCRIPTION_TRUNCATED=$(printf '%s' "$DESCRIPTION" | head -c 500)

if command -v jq &>/dev/null; then
  echo "{}" | jq -c \
    --arg ts "$TIMESTAMP" \
    --arg agent "$AGENT_NAME" \
    --arg type "$FAILURE_TYPE" \
    --arg desc "$DESCRIPTION_TRUNCATED" \
    --arg project "$PROJECT_NAME" \
    --arg project_path "$PROJECT_PATH" \
    --arg spec "$SPEC_ID" \
    '{timestamp: $ts, agent: $agent, failure_type: $type, description: $desc, project: $project, project_path: $project_path, spec: $spec}' \
    >> "$LOG_FILE"
else
  # Fallback writer (item 38): every interpolated field is routed
  # through json_escape (lib.sh), not just description as before.
  SAFE_DESC=$(json_escape "$(printf '%s' "$DESCRIPTION_TRUNCATED" | tr -d '\n\r')")
  SAFE_AGENT=$(json_escape "$AGENT_NAME")
  SAFE_TYPE=$(json_escape "$FAILURE_TYPE")
  SAFE_PROJECT=$(json_escape "$PROJECT_NAME")
  SAFE_PROJECT_PATH=$(json_escape "$PROJECT_PATH")
  SAFE_SPEC=$(json_escape "$SPEC_ID")
  printf '{"timestamp":"%s","agent":"%s","failure_type":"%s","description":"%s","project":"%s","project_path":"%s","spec":"%s"}\n' \
    "$TIMESTAMP" "$SAFE_AGENT" "$SAFE_TYPE" "$SAFE_DESC" "$SAFE_PROJECT" "$SAFE_PROJECT_PATH" "$SAFE_SPEC" \
    >> "$LOG_FILE"
fi
