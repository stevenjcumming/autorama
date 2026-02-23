#!/bin/bash
#
# on-agent-complete.sh - SubagentStop hook for autopilot task completion
#
# Handles post-task-completion actions:
# 1. Auto-commit changes if enabled
# 2. Generate handoff artifact for next agent
# 3. Signal execute command to continue
#
# Triggered by: SubagentStop hook
#

set -e

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract agent info
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // empty')
AGENT_OUTPUT=$(echo "$INPUT" | jq -r '.agent_output // empty')

# Only trigger for autopilot agents
if [[ "$AGENT_NAME" != autopilot-* ]]; then
  exit 0
fi

# ============================================================================
# Find spec directory using shared utility
# ============================================================================

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
FIND_SPEC_SCRIPT="$PLUGIN_DIR/scripts/find-active-spec.sh"

SPEC_DIR=""
if [ -x "$FIND_SPEC_SCRIPT" ]; then
  FIND_RESULT=$("$FIND_SPEC_SCRIPT" 2>/dev/null || echo "NOT_FOUND")
  if [[ "$FIND_RESULT" == FOUND:* ]]; then
    SPEC_DIR=$(echo "$FIND_RESULT" | cut -d: -f2)
  fi
else
  # Fallback: inline search for recent state file
  for dir in .claude/specs/*/artifacts/state; do
    if [ -f "$dir/current.json" ]; then
      CANDIDATE_STATE="$dir/current.json"
      if [ "$(find "$CANDIDATE_STATE" -mmin -5 2>/dev/null)" ]; then
        SPEC_DIR=$(dirname "$(dirname "$dir")")
        break
      fi
    fi
  done
fi

# If no spec found, exit silently
if [ -z "$SPEC_DIR" ] || [ ! -d "$SPEC_DIR" ]; then
  exit 0
fi

# Build state file path
STATE_FILE="$SPEC_DIR/artifacts/state/current.json"

# Read state from file if available, otherwise extract from agent output.
# This avoids a race condition where SubagentStop fires before PostToolUse
# (save-state.sh) has written current.json.
TASK_COMPLETED="false"
TASK_ID=""

if [ -f "$STATE_FILE" ]; then
  TASK_COMPLETED=$(jq -r '.task_completed // false' "$STATE_FILE")
  TASK_ID=$(jq -r '.last_task // empty' "$STATE_FILE")
fi

# Fallback: extract from agent output when state file is missing or incomplete.
# Match the structured XML tags that autopilot-task-runner always emits,
# plus common prose patterns as a secondary fallback.
if [ "$TASK_COMPLETED" != "true" ] && [ -n "$AGENT_OUTPUT" ]; then
  if echo "$AGENT_OUTPUT" | grep -qE '<task-completed[^>]*status="completed"'; then
    TASK_COMPLETED="true"
  elif echo "$AGENT_OUTPUT" | grep -qiE '## Task Completed|task.*complete'; then
    TASK_COMPLETED="true"
  fi
fi

if [ -z "$TASK_ID" ] && [ -n "$AGENT_OUTPUT" ]; then
  # Try structured tag first, then bracketed ID
  TASK_ID=$(echo "$AGENT_OUTPUT" | grep -oE '<task-completed[^>]*task="[^"]*"' | grep -oE 'task="[^"]*"' | head -1 | tr -d 'task="' || echo "")
  if [ -z "$TASK_ID" ]; then
    TASK_ID=$(echo "$AGENT_OUTPUT" | grep -oE '\[T[0-9]+\]' | head -1 || echo "")
  fi
fi

# Only proceed if task was completed
if [ "$TASK_COMPLETED" != "true" ]; then
  exit 0
fi

# Extract spec_id from path
SPEC_ID=$(basename "$SPEC_DIR")

# ============================================================================
# Load configuration
# ============================================================================

COMMIT_TEMPLATE="feat({spec_id}): complete {task_id} - {task_summary}"

if command -v yq &> /dev/null && [ -f ".claude/autopilot.yml" ]; then
  # Read commit message template
  TEMPLATE=$(yq -r '.auto_commit.message_template // empty' .claude/autopilot.yml 2>/dev/null)
  if [ -n "$TEMPLATE" ]; then
    COMMIT_TEMPLATE="$TEMPLATE"
  fi
fi

# ============================================================================
# Auto-commit if enabled
# ============================================================================

# Always auto-commit changes
{
  # Check if there are changes to commit (staged, unstaged, or untracked)
  UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -1 || true)
  if git diff --quiet && git diff --cached --quiet && [ -z "$UNTRACKED" ]; then
    # No changes to commit
    :
  else
    # Get task summary from TODO.md
    TASK_SUMMARY=""
    if [ -n "$TASK_ID" ] && [ -f "$SPEC_DIR/TODO.md" ]; then
      TASK_SUMMARY=$(grep -F "$TASK_ID" "$SPEC_DIR/TODO.md" | sed 's/.*\] //' | head -1 || echo "task completion")
    fi
    if [ -z "$TASK_SUMMARY" ]; then
      TASK_SUMMARY="task completion"
    fi

    # Build commit message from template
    COMMIT_MSG="$COMMIT_TEMPLATE"
    COMMIT_MSG="${COMMIT_MSG//\{spec_id\}/$SPEC_ID}"
    COMMIT_MSG="${COMMIT_MSG//\{task_id\}/$TASK_ID}"
    COMMIT_MSG="${COMMIT_MSG//\{task_summary\}/$TASK_SUMMARY}"

    # Stage and commit
    git add -A

    # Create commit with Co-Authored-By
    git commit -m "$COMMIT_MSG

Co-Authored-By: Claude <noreply@anthropic.com>" 2>/dev/null || true

    echo "<auto-commit spec=\"$SPEC_ID\" task=\"$TASK_ID\" />"
  fi
}

# ============================================================================
# Signal handoff generation needed
# ============================================================================

# Output directive for the execute command to spawn handoff-writer agent.
# The handoff-writer agent produces richer context-aware handoffs than
# inline shell generation.
TASK_DESC=""
if [ -n "$TASK_ID" ] && [ -f "$SPEC_DIR/TODO.md" ]; then
  TASK_DESC=$(grep -F "$TASK_ID" "$SPEC_DIR/TODO.md" | sed 's/.*\] //' | head -1 || echo "task completion")
fi

echo "<handoff-needed spec_dir=\"$SPEC_DIR\" task_id=\"$TASK_ID\" task_status=\"completed\" agent=\"$AGENT_NAME\" task_desc=\"$TASK_DESC\" />"

# ============================================================================
# Check context limits and trigger session summary if needed
# ============================================================================

CHECK_CONTEXT_SCRIPT="$PLUGIN_DIR/scripts/check-context.sh"

if [ -x "$CHECK_CONTEXT_SCRIPT" ]; then
  CONTEXT_RESULT=$("$CHECK_CONTEXT_SCRIPT" "$SPEC_DIR" 2>/dev/null || echo "OK:0")

  case "$CONTEXT_RESULT" in
    CRITICAL:*)
      # Context is critically high - signal for immediate summarization
      ESTIMATED_TOKENS=$(echo "$CONTEXT_RESULT" | cut -d: -f3)
      echo "<context-critical tokens=\"$ESTIMATED_TOKENS\" spec=\"$SPEC_ID\">"
      echo "  Context usage is critically high. Session summarization required."
      echo "  Consider spawning session-summarizer agent before continuing."
      echo "</context-critical>"
      ;;
    WARNING:*)
      # Context is approaching limit - signal warning
      ESTIMATED_TOKENS=$(echo "$CONTEXT_RESULT" | cut -d: -f3)
      echo "<context-warning tokens=\"$ESTIMATED_TOKENS\" spec=\"$SPEC_ID\" />"
      ;;
    OK:*)
      # Context is fine - no action needed
      ;;
  esac
fi

# ============================================================================
# Signal completion
# ============================================================================

echo "<agent-completed agent=\"$AGENT_NAME\" task=\"$TASK_ID\" spec=\"$SPEC_ID\" />"
