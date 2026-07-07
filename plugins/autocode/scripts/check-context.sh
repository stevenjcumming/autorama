#!/usr/bin/env bash
#
# check-context.sh - Estimate context usage and warn if approaching limits
#
# This script provides a heuristic estimate of context usage based on:
# - Artifact files in the spec directory
# - Spec files (SPEC.md, PLAN.md, TODO.md)
# - Project rules/instructions (CLAUDE.md, .claude/rules/*.md)
# - The caller's transcript, if supplied (see TRANSCRIPT parameter below)
#
# Usage: check-context.sh <spec_dir> [transcript] [threshold]
#
#   <spec_dir>    Required. Path to the spec directory.
#   [transcript]  Optional. Either a path to an existing file (its byte size
#                 is measured) or a raw byte count (a positive integer).
#                 Pass this so the estimate reflects the actual conversation,
#                 not just spec markdown — see "Why a transcript parameter"
#                 below. Omit (or pass 0 / empty) to fall back to the
#                 spec-files-only estimate this script originally shipped
#                 with.
#   [threshold]   Optional. Overrides the default WARNING token threshold
#                 (see calibration note below). CRITICAL is threshold+60000.
#
# Expected call sites:
#   - hooks/on-agent-complete.sh (SubagentStop hook) has the real transcript
#     path for the agent that just stopped (available in the hook payload)
#     and should pass it as the second argument. Wiring that through is
#     tracked separately — see the hooks owner — this script only needs to
#     consume the parameter correctly once supplied.
#   - agents/task-runner.md's Step 8.5 calls this after each task; it does
#     not have a reliable way to read its own transcript file today, so it
#     currently omits the parameter and relies on the spec-files-only
#     fallback (documented there as a known gap).
#
# Why a transcript parameter (item 12 / roadmap 3.5):
#   The original version of this script only summed SPEC.md/PLAN.md/TODO.md,
#   artifacts, and CLAUDE.md. Reaching the old 150k-token warning threshold
#   from spec markdown alone would require ~460KB of it, which essentially
#   never happens — the WARNING/CRITICAL branches were dead code in
#   practice. The transcript (the actual back-and-forth of sub-agent calls,
#   tool output, and retries) is the dominant real consumer of context, so
#   it must be counted for these thresholds to ever fire.
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
TRANSCRIPT="${2:-}"
# Calibration note (best-effort, pending a real measurement pass per the
# roadmap): with the transcript now factored in, typical single-task-runner
# transcripts commonly run from tens of KB (a clean task, no retries) to a
# few hundred KB (several coder/analysis/refactor retries, each returning a
# few KB of sub-agent output). A 200k-token model context window needs
# headroom left for the remaining steps plus a session-summarizer run, so
# WARNING is set well below that ceiling and CRITICAL leaves roughly one
# more round-trip of margin. Revisit these two numbers once a real
# execute-loop transcript has been measured.
THRESHOLD="${3:-80000}"  # ~80k tokens warning threshold (see calibration note above)
CRITICAL_THRESHOLD=$((THRESHOLD + 60000))  # ~140k critical threshold

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required" >&2
  echo "Usage: check-context.sh <spec_dir> [transcript] [threshold]" >&2
  exit 1
fi

# Validate spec directory
if [ ! -d "$SPEC_DIR" ]; then
  echo "Error: spec directory does not exist at $SPEC_DIR" >&2
  echo "Usage: check-context.sh <spec_dir> [transcript] [threshold]" >&2
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

# Measure the transcript, if one was supplied. Accept either an existing
# file path (measure its byte size) or a raw numeric byte count.
TRANSCRIPT_SIZE=0
if [ -n "$TRANSCRIPT" ]; then
  if [ -f "$TRANSCRIPT" ]; then
    TRANSCRIPT_SIZE=$(wc -c < "$TRANSCRIPT")
  elif [[ "$TRANSCRIPT" =~ ^[0-9]+$ ]]; then
    TRANSCRIPT_SIZE="$TRANSCRIPT"
  fi
  # Anything else (unparseable, negative, non-numeric) is silently treated
  # as 0 rather than failing the whole estimate — a bad transcript argument
  # should degrade to the pre-item-12 behavior, not abort the caller.
fi

# ============================================================================
# Calculate totals
# ============================================================================

TOTAL_CHARS=$((SPEC_SIZE + ARTIFACT_SIZE + PROJECT_RULES_SIZE + TRANSCRIPT_SIZE))

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
