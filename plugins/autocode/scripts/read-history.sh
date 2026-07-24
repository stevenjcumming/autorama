#!/usr/bin/env bash
# Read and summarize execution history from CLAUDE_PLUGIN_DATA.
# Usage: read-history.sh [--project <name>] [--recent <n>] [--failures] [--stats] [--model-stats]
#
# Options:
#   --project <name>   Filter by project name
#   --recent <n>       Show only the last n entries (default: 20)
#   --failures         Show only failure records
#   --stats            Show aggregate statistics instead of individual records
#   --model-stats      Summarize model-selection events (count per rule,
#                      tier distribution, C5 return rate) so the decision
#                      tables in docs/MODEL_SELECTION.md can be tuned on
#                      real data. Read-only, like everything else here.
#
# Outputs condensed context suitable for agent consumption.

set -euo pipefail

usage() {
  echo "Usage: read-history.sh [--project <name>] [--recent <n>] [--failures] [--stats] [--model-stats]"
}

# Require CLAUDE_PLUGIN_DATA
if [ -z "${CLAUDE_PLUGIN_DATA:-}" ]; then
  echo "CLAUDE_PLUGIN_DATA not set. Run /autocode:init to configure."
  exit 0
fi

# Defaults
PROJECT_FILTER=""
RECENT=20
SHOW_FAILURES=false
SHOW_STATS=false
SHOW_MODEL_STATS=false

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      if [ -z "${2:-}" ]; then
        echo "Error: --project requires a value" >&2
        usage >&2
        exit 1
      fi
      PROJECT_FILTER="$2"; shift 2 ;;
    --recent)
      if [[ ! "${2:-}" =~ ^[0-9]+$ ]]; then
        echo "Error: --recent requires a numeric value" >&2
        usage >&2
        exit 1
      fi
      RECENT="$2"; shift 2 ;;
    --failures) SHOW_FAILURES=true; shift ;;
    --stats) SHOW_STATS=true; shift ;;
    --model-stats) SHOW_MODEL_STATS=true; shift ;;
    *)
      echo "Error: unknown option '$1'" >&2
      usage >&2
      exit 1 ;;
  esac
done

# The project filter needs jq; warn once if it will be ignored
if [ -n "$PROJECT_FILTER" ] && ! command -v jq &>/dev/null; then
  echo "Note: --project filter ignored because jq is not installed." >&2
  PROJECT_FILTER=""
fi

USAGE_FILE="$CLAUDE_PLUGIN_DATA/usage.jsonl"
FAILURE_FILE="$CLAUDE_PLUGIN_DATA/failures.jsonl"

if $SHOW_MODEL_STATS; then
  echo "## Model Selection Statistics"
  echo ""

  if [ ! -f "$USAGE_FILE" ]; then
    echo "No usage data found."
    exit 0
  fi

  if ! command -v jq &>/dev/null; then
    # Degraded fallback: rule IDs live inside the escaped details JSON,
    # so count raw substring occurrences on model-selection lines only.
    MS_LINES=$(grep -c '"type":"model-selection"' "$USAGE_FILE" 2>/dev/null || echo 0)
    echo "- Model-selection events: $MS_LINES"
    echo ""
    echo "### Events by rule (substring counts; install jq for exact stats)"
    for rule in P1 P2 P3 C1 C2 C3 C4 C5 R1 R2 R3 R4 M4; do
      count=$(grep '"type":"model-selection"' "$USAGE_FILE" 2>/dev/null | grep -c "rule\\\\\":\\\\\"$rule" || true)
      [ "${count:-0}" -gt 0 ] 2>/dev/null && echo "- $rule: $count"
    done
    exit 0
  fi

  # jq path: details is a JSON-encoded string; fromjson? tolerates
  # malformed payloads by dropping them instead of erroring.
  MS_FILTER='select(.type == "model-selection")'
  if [ -n "$PROJECT_FILTER" ]; then
    MS_FILTER="select(.type == \"model-selection\" and .project == \"$PROJECT_FILTER\")"
  fi

  TOTAL_MS=$(jq -r "$MS_FILTER | .type" "$USAGE_FILE" | wc -l | tr -d ' ')
  echo "- Model-selection events: $TOTAL_MS"

  if [ "$TOTAL_MS" -gt 0 ]; then
    echo ""
    echo "### Events by rule"
    jq -r "$MS_FILTER | (.details | fromjson? | .rule) // \"unparsed\"" "$USAGE_FILE" \
      | sort | uniq -c | sort -rn | while read -r count rule; do
        echo "- $rule: $count"
      done

    echo ""
    echo "### Events by tier"
    jq -r "$MS_FILTER | (.details | fromjson? | .tier) // \"unparsed\"" "$USAGE_FILE" \
      | sort | uniq -c | sort -rn | while read -r count tier; do
        echo "- $tier: $count"
      done

    # C5 return rate: C5 respawns as a share of all coder-role decisions.
    CODER_TOTAL=$(jq -r "$MS_FILTER | select(.name == \"coder\") | .type" "$USAGE_FILE" | wc -l | tr -d ' ')
    C5_COUNT=$(jq -r "$MS_FILTER | select(.name == \"coder\") | (.details | fromjson? | .rule) // empty" "$USAGE_FILE" | grep -c '^C5$' || true)
    echo ""
    echo "### C5 return rate"
    if [ "$CODER_TOTAL" -gt 0 ]; then
      echo "- $C5_COUNT of $CODER_TOTAL coder decisions returned to the generation tier"
    else
      echo "- No coder decisions logged yet"
    fi
  fi

  exit 0
fi

if $SHOW_STATS; then
  echo "## Execution Statistics"
  echo ""

  if [ -f "$USAGE_FILE" ]; then
    TOTAL=$(wc -l < "$USAGE_FILE" | tr -d ' ')
    echo "- Total events logged: $TOTAL"

    if command -v jq &>/dev/null; then
      echo ""
      echo "### Events by type"
      jq -r '.type' "$USAGE_FILE" | sort | uniq -c | sort -rn | head -10 | while read -r count type; do
        echo "- $type: $count"
      done

      echo ""
      echo "### Events by status"
      jq -r '.status' "$USAGE_FILE" | sort | uniq -c | sort -rn | while read -r count status; do
        echo "- $status: $count"
      done

      echo ""
      echo "### Most active specs"
      jq -r 'select(.spec != "") | .spec' "$USAGE_FILE" | sort | uniq -c | sort -rn | head -5 | while read -r count spec; do
        echo "- $spec: $count events"
      done
    fi
  else
    echo "No usage data found."
  fi

  if [ -f "$FAILURE_FILE" ]; then
    FAIL_TOTAL=$(wc -l < "$FAILURE_FILE" | tr -d ' ')
    echo ""
    echo "### Failure Summary"
    echo "- Total failures: $FAIL_TOTAL"

    if command -v jq &>/dev/null; then
      echo ""
      echo "### Failures by agent"
      jq -r '.agent' "$FAILURE_FILE" | sort | uniq -c | sort -rn | while read -r count agent; do
        echo "- $agent: $count"
      done

      echo ""
      echo "### Failures by type"
      jq -r '.failure_type' "$FAILURE_FILE" | sort | uniq -c | sort -rn | while read -r count type; do
        echo "- $type: $count"
      done
    fi
  fi

  exit 0
fi

if $SHOW_FAILURES; then
  if [ ! -f "$FAILURE_FILE" ]; then
    echo "No failure data found."
    exit 0
  fi

  echo "## Recent Failures"
  echo ""

  if [ -n "$PROJECT_FILTER" ]; then
    # jq -c keeps each record on one line so tail counts records, not lines
    jq -c --arg project "$PROJECT_FILTER" 'select(.project == $project)' "$FAILURE_FILE" | tail -n "$RECENT"
  else
    tail -n "$RECENT" "$FAILURE_FILE"
  fi

  exit 0
fi

# Default: show recent usage
if [ ! -f "$USAGE_FILE" ]; then
  echo "No usage data found. Data will be logged as you use autocode commands."
  exit 0
fi

echo "## Recent Activity"
echo ""

if [ -n "$PROJECT_FILTER" ]; then
  # jq -c keeps each record on one line so tail counts records, not lines
  jq -c --arg project "$PROJECT_FILTER" 'select(.project == $project)' "$USAGE_FILE" | tail -n "$RECENT"
else
  tail -n "$RECENT" "$USAGE_FILE"
fi
