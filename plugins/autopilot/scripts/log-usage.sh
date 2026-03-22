#!/usr/bin/env bash
# Log usage events to CLAUDE_PLUGIN_DATA for cross-session analytics.
# Usage: log-usage.sh <event_type> <event_name> [status] [details]
#
# Events are appended to $CLAUDE_PLUGIN_DATA/usage.jsonl as newline-delimited JSON.
# If CLAUDE_PLUGIN_DATA is not set, exits silently (graceful degradation).

set -euo pipefail

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
PROJECT_DIR=$(basename "$(pwd)")

# Get spec ID from SPEC_DIR if available
SPEC_ID=""
if [ -n "${SPEC_DIR:-}" ]; then
  SPEC_ID=$(basename "$SPEC_DIR")
fi

# Build JSON line (no jq dependency — printf is sufficient for structured fields)
if command -v jq &>/dev/null; then
  echo "{}" | jq -c \
    --arg ts "$TIMESTAMP" \
    --arg type "$EVENT_TYPE" \
    --arg name "$EVENT_NAME" \
    --arg status "$STATUS" \
    --arg details "$DETAILS" \
    --arg project "$PROJECT_DIR" \
    --arg spec "$SPEC_ID" \
    '{timestamp: $ts, type: $type, name: $name, status: $status, details: $details, project: $project, spec: $spec}' \
    >> "$LOG_FILE"
else
  # Fallback: escape quotes in details
  SAFE_DETAILS=$(printf '%s' "$DETAILS" | sed 's/"/\\"/g' | head -c 500)
  printf '{"timestamp":"%s","type":"%s","name":"%s","status":"%s","details":"%s","project":"%s","spec":"%s"}\n' \
    "$TIMESTAMP" "$EVENT_TYPE" "$EVENT_NAME" "$STATUS" "$SAFE_DETAILS" "$PROJECT_DIR" "$SPEC_ID" \
    >> "$LOG_FILE"
fi
