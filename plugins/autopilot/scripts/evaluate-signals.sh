#!/bin/bash
#
# evaluate-signals.sh - Evaluate analyzer signals to decide if pause is needed
#
# Checks signals directory for patterns that should trigger an automatic pause:
# - Repeated violations (same rule 3+ times)
# - High severity signals (security, breaking changes)
# - Human review required signals
#
# Usage: evaluate-signals.sh <spec_dir>
#
# Output:
#   CONTINUE - No pause needed
#   PAUSE:<reason>:<details> - Pause needed with reason
#

set -e

SPEC_DIR="$1"

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required"
  echo "Usage: evaluate-signals.sh <spec_dir>"
  exit 1
fi

if [ ! -d "$SPEC_DIR" ]; then
  echo "CONTINUE"
  exit 0
fi

SIGNALS_DIR="$SPEC_DIR/artifacts/signals"

# If no signals directory, continue
if [ ! -d "$SIGNALS_DIR" ]; then
  echo "CONTINUE"
  exit 0
fi

# ============================================================================
# Load pause signal configuration
# ============================================================================

PAUSE_ENABLED="true"
REPEATED_THRESHOLD=3

if command -v yq &> /dev/null && [ -f ".claude/autopilot.yml" ]; then
  # Check if pause_signals section is present (presence = active)
  PS_SECTION=$(yq '.pause_signals // empty' .claude/autopilot.yml 2>/dev/null)
  if [ -z "$PS_SECTION" ] || [ "$PS_SECTION" = "null" ]; then
    PAUSE_ENABLED="false"
  fi

  # Get repeated violation threshold
  THRESHOLD=$(yq -r '.pause_signals.triggers[] | select(.signal == "repeated_violation") | .threshold // empty' .claude/autopilot.yml 2>/dev/null)
  if [ -n "$THRESHOLD" ] && [ "$THRESHOLD" -gt 0 ] 2>/dev/null; then
    REPEATED_THRESHOLD="$THRESHOLD"
  fi
fi

if [ "$PAUSE_ENABLED" != "true" ]; then
  echo "CONTINUE"
  exit 0
fi

# ============================================================================
# Create/check last check marker for incremental checking
# ============================================================================

LAST_CHECK_MARKER="$SIGNALS_DIR/.last_check"

# Function to get signals newer than last check
get_new_signals() {
  if [ -f "$LAST_CHECK_MARKER" ]; then
    find "$SIGNALS_DIR" -name "*.md" -newer "$LAST_CHECK_MARKER" -type f 2>/dev/null
  else
    find "$SIGNALS_DIR" -name "*.md" -type f 2>/dev/null
  fi
}

NEW_SIGNALS=$(get_new_signals)

# If no new signals, continue
if [ -z "$NEW_SIGNALS" ]; then
  echo "CONTINUE"
  exit 0
fi

# ============================================================================
# Check for repeated violations (same rule N+ times)
# ============================================================================

# Extract rule names from signals and count occurrences
REPEATED=""
if [ -n "$NEW_SIGNALS" ]; then
  # Look for rule: or rule_id: patterns in signal files
  REPEATED=$(echo "$NEW_SIGNALS" | xargs grep -h -E '^rule:|^rule_id:' 2>/dev/null | \
    sed 's/^rule[_id]*:\s*//' | \
    sort | uniq -c | \
    awk -v threshold="$REPEATED_THRESHOLD" '$1 >= threshold {print $2}' | \
    head -1)
fi

if [ -n "$REPEATED" ]; then
  echo "PAUSE:repeated_violation:Rule '$REPEATED' violated $REPEATED_THRESHOLD+ times"
  exit 0
fi

# ============================================================================
# Check for high severity signals
# ============================================================================

HIGH_SEVERITY=""
if [ -n "$NEW_SIGNALS" ]; then
  # Look for severity: high or type: security/breaking_change
  HIGH_SEVERITY=$(echo "$NEW_SIGNALS" | while read -r file; do
    if [ -f "$file" ]; then
      # Check for high severity
      if grep -qE '^severity:\s*high' "$file" 2>/dev/null; then
        echo "$file"
        break
      fi
      # Check for security or breaking change type
      if grep -qE '^type:\s*(security|breaking_change)' "$file" 2>/dev/null; then
        echo "$file"
        break
      fi
    fi
  done)
fi

if [ -n "$HIGH_SEVERITY" ]; then
  SIGNAL_NAME=$(basename "$HIGH_SEVERITY" .md)
  echo "PAUSE:high_severity:$SIGNAL_NAME requires attention"
  exit 0
fi

# ============================================================================
# Check for human review needed signals
# ============================================================================

HUMAN_REVIEW=""
if [ -n "$NEW_SIGNALS" ]; then
  HUMAN_REVIEW=$(echo "$NEW_SIGNALS" | while read -r file; do
    if [ -f "$file" ]; then
      # Check for human_review: required or needs_human_review: true
      if grep -qE '^(human_review:\s*required|needs_human_review:\s*true)' "$file" 2>/dev/null; then
        echo "$file"
        break
      fi
    fi
  done)
fi

if [ -n "$HUMAN_REVIEW" ]; then
  SIGNAL_NAME=$(basename "$HUMAN_REVIEW" .md)
  echo "PAUSE:human_review_needed:$SIGNAL_NAME requires human review"
  exit 0
fi

# ============================================================================
# Update last check marker and continue
# ============================================================================

touch "$LAST_CHECK_MARKER"
echo "CONTINUE"
