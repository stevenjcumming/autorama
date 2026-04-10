#!/bin/bash
#
# check-context.sh - Estimate context usage and warn if approaching limits
#
# This script provides a heuristic estimate of context usage based on:
# - Artifact files in the spec directory
# - Spec files (SPEC.md, PLAN.md, TODO.md)
# - Recent session activity
#
# Usage: check-context.sh <SPEC_DIR> [THRESHOLD]
#
# Output:
#   OK:<estimated_tokens>           - Under threshold
#   WARNING:context_limit:<tokens>  - Approaching limit
#   CRITICAL:context_limit:<tokens> - Over critical threshold
#
# Exit codes:
#   0 - OK or WARNING (can continue)
#   1 - CRITICAL (should summarize immediately)
#

set -e

SPEC_DIR="${1:-.claude/specs/default}"
THRESHOLD="${2:-150000}"  # ~150k tokens warning threshold
CRITICAL_THRESHOLD=$((THRESHOLD + 50000))  # ~200k critical threshold

# Validate spec directory
if [ ! -d "$SPEC_DIR" ]; then
  echo "ERROR:invalid_spec_dir:$SPEC_DIR"
  exit 1
fi

# ============================================================================
# Count characters in relevant files
# ============================================================================

# Count spec files
SPEC_SIZE=0
for file in "$SPEC_DIR/SPEC.md" "$SPEC_DIR/PLAN.md" "$SPEC_DIR/TODO.md"; do
  if [ -f "$file" ]; then
    FILE_SIZE=$(wc -c < "$file" 2>/dev/null || echo 0)
    SPEC_SIZE=$((SPEC_SIZE + FILE_SIZE))
  fi
done

# Count all artifacts
ARTIFACT_SIZE=0
if [ -d "$SPEC_DIR/artifacts" ]; then
  ARTIFACT_SIZE=$(find "$SPEC_DIR/artifacts" -name "*.md" -type f -exec cat {} + 2>/dev/null | wc -c || echo 0)
fi

# Count project rules/instructions
PROJECT_RULES_SIZE=0
if [ -f "CLAUDE.md" ]; then
  PROJECT_RULES_SIZE=$(wc -c < "CLAUDE.md" 2>/dev/null || echo 0)
fi
if [ -d ".claude/rules" ]; then
  RULES_SIZE=$(find ".claude/rules" -name "*.md" -type f -exec cat {} + 2>/dev/null | wc -c || echo 0)
  PROJECT_RULES_SIZE=$((PROJECT_RULES_SIZE + RULES_SIZE))
fi

# ============================================================================
# Calculate totals
# ============================================================================

TOTAL_CHARS=$((SPEC_SIZE + ARTIFACT_SIZE + PROJECT_RULES_SIZE))

# Rough token estimation: 4 chars ≈ 1 token
ESTIMATED_TOKENS=$((TOTAL_CHARS / 4))

# Add buffer for conversation overhead (estimated at 30% of measured content)
OVERHEAD=$((ESTIMATED_TOKENS * 30 / 100))
ESTIMATED_TOKENS=$((ESTIMATED_TOKENS + OVERHEAD))

# ============================================================================
# Determine status
# ============================================================================

if [ "$ESTIMATED_TOKENS" -gt "$CRITICAL_THRESHOLD" ]; then
  echo "CRITICAL:context_limit:$ESTIMATED_TOKENS"
  exit 1
elif [ "$ESTIMATED_TOKENS" -gt "$THRESHOLD" ]; then
  echo "WARNING:context_limit:$ESTIMATED_TOKENS"
  exit 0
else
  echo "OK:$ESTIMATED_TOKENS"
  exit 0
fi
