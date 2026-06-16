#!/usr/bin/env bash
# Log a failure pattern to CLAUDE_PLUGIN_DATA for cross-spec learning.
# Usage: log-failure.sh <agent_name> <failure_type> <description> [spec_id]
#
# Failures are appended to $CLAUDE_PLUGIN_DATA/failures.jsonl.
# read-history.sh consumes these for cross-spec failure summaries.

set -euo pipefail

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
PROJECT_DIR=$(basename "$(pwd)")

if command -v jq &>/dev/null; then
  echo "{}" | jq -c \
    --arg ts "$TIMESTAMP" \
    --arg agent "$AGENT_NAME" \
    --arg type "$FAILURE_TYPE" \
    --arg desc "$DESCRIPTION" \
    --arg project "$PROJECT_DIR" \
    --arg spec "$SPEC_ID" \
    '{timestamp: $ts, agent: $agent, failure_type: $type, description: $desc, project: $project, spec: $spec}' \
    >> "$LOG_FILE"
else
  # Fallback writer: truncate, strip newlines, then escape backslashes
  # and double quotes so the output stays valid JSONL
  SAFE_DESC=$(printf '%s' "$DESCRIPTION" | head -c 500 | tr -d '\n\r' | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')
  printf '{"timestamp":"%s","agent":"%s","failure_type":"%s","description":"%s","project":"%s","spec":"%s"}\n' \
    "$TIMESTAMP" "$AGENT_NAME" "$FAILURE_TYPE" "$SAFE_DESC" "$PROJECT_DIR" "$SPEC_ID" \
    >> "$LOG_FILE"
fi
