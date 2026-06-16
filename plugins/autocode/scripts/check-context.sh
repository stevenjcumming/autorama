#!/usr/bin/env bash
#
# check-context.sh - Estimate context usage and warn if approaching limits
#
# This script provides a heuristic estimate of context usage based on:
# - Artifact files in the spec directory
# - Spec files (SPEC.md, PLAN.md, TODO.md)
# - Recent session activity
#
# Usage: check-context.sh <spec_dir> [threshold]
#
# Output (single status line on stdout):
#   OK:<estimated_tokens>           - Under threshold
#   WARNING:context_limit:<tokens>  - Approaching limit
#   CRITICAL:context_limit:<tokens> - Over critical threshold
#
# Exit codes:
#   0 - Always, for any status result (OK, WARNING, or CRITICAL);
#       consumers must parse the status prefix, not the exit code
#   1 - Usage error only (missing argument or nonexistent spec directory)
#

set -euo pipefail

SPEC_DIR="${1:-}"
THRESHOLD="${2:-150000}"  # ~150k tokens warning threshold
CRITICAL_THRESHOLD=$((THRESHOLD + 50000))  # ~200k critical threshold

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required" >&2
  echo "Usage: check-context.sh <spec_dir> [threshold]" >&2
  exit 1
fi

# Validate spec directory
if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec directory does not exist at $SPEC_DIR" >&2
  echo "Usage: check-context.sh <spec_dir> [threshold]" >&2
  exit 1
fi

# ============================================================================
# Count characters in relevant files
# ============================================================================

# Count spec files
SPEC_SIZE=0
for file in "$SPEC_DIR/SPEC.md" "$SPEC_DIR/PLAN.md" "$SPEC_DIR/TODO.md"; do
  if [ -f "$file" ]; then
    FILE_SIZE=$(wc -c < "$file")
    SPEC_SIZE=$((SPEC_SIZE + FILE_SIZE))
  fi
done

# Count all artifacts
ARTIFACT_SIZE=0
if [ -d "$SPEC_DIR/artifacts" ]; then
  ARTIFACT_SIZE=$(find "$SPEC_DIR/artifacts" -name "*.md" -type f -exec cat {} + | wc -c)
fi

# Count project rules/instructions
PROJECT_RULES_SIZE=0
if [ -f "CLAUDE.md" ]; then
  PROJECT_RULES_SIZE=$(wc -c < "CLAUDE.md")
fi
if [ -d ".claude/rules" ]; then
  RULES_SIZE=$(find ".claude/rules" -name "*.md" -type f -exec cat {} + | wc -c)
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
  exit 0
elif [ "$ESTIMATED_TOKENS" -gt "$THRESHOLD" ]; then
  echo "WARNING:context_limit:$ESTIMATED_TOKENS"
  exit 0
else
  echo "OK:$ESTIMATED_TOKENS"
  exit 0
fi
