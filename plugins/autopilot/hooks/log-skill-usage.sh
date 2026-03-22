#!/usr/bin/env bash
# PreToolUse hook: Log when autopilot skills/agents are invoked.
# Triggered on Task tool calls to track agent spawning.
#
# Reads tool_input from stdin (JSON with subagent_type, prompt).
# Logs to CLAUDE_PLUGIN_DATA/usage.jsonl via log-usage.sh.

set -euo pipefail

# Require CLAUDE_PLUGIN_DATA
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  exit 0
fi

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$(dirname "$0")")}"

# Read hook input from stdin
INPUT=$(cat)

# Extract agent name from subagent_type if present
AGENT_NAME=""
if command -v jq &>/dev/null; then
  AGENT_NAME=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null || true)
fi

# Only log autopilot agent spawns
if [ -z "$AGENT_NAME" ] || [[ "$AGENT_NAME" != autopilot:* ]]; then
  exit 0
fi

# Strip prefix
SHORT_NAME="${AGENT_NAME#autopilot:}"

# Extract SPEC_DIR from prompt if present
SPEC_DIR=""
if command -v jq &>/dev/null; then
  PROMPT=$(echo "$INPUT" | jq -r '.tool_input.prompt // empty' 2>/dev/null || true)
  SPEC_DIR=$(echo "$PROMPT" | grep -oP 'SPEC_DIR=\K[^\s]+' 2>/dev/null || true)
fi

export SPEC_DIR
bash "$PLUGIN_ROOT/scripts/log-usage.sh" "agent_spawn" "$SHORT_NAME" "ok" ""
