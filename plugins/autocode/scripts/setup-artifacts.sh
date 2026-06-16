#!/usr/bin/env bash
#
# setup-artifacts.sh - Create artifact directory structure for a spec
#
# Ensures all required artifact subdirectories exist for a given spec.
# Safe to call multiple times (mkdir -p is idempotent).
#
# Usage: setup-artifacts.sh <spec_dir>
#
# Arguments:
#   spec_dir  Path to the spec directory (e.g., .specs/auth-refactor)
#
# Output:
#   CREATED:<spec_dir>/artifacts
#
# Exit codes:
#   0 - Success
#   1 - Error (missing arguments)
#

set -euo pipefail

SPEC_DIR="${1:-}"

if [ -z "$SPEC_DIR" ]; then
  echo "Error: spec directory is required"
  echo "Usage: setup-artifacts.sh <spec_dir>"
  exit 1
fi

ARTIFACTS_DIR="$SPEC_DIR/artifacts"

mkdir -p \
  "$ARTIFACTS_DIR/justifications" \
  "$ARTIFACTS_DIR/decisions" \
  "$ARTIFACTS_DIR/assumptions" \
  "$ARTIFACTS_DIR/risks" \
  "$ARTIFACTS_DIR/review_hints" \
  "$ARTIFACTS_DIR/debt" \
  "$ARTIFACTS_DIR/handoff"

echo "CREATED:$ARTIFACTS_DIR"
