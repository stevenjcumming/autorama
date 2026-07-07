#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "$0")/../../../scripts/lib.sh"

IDENTIFIER="${1:-}"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: identifier is required" >&2
  echo "Usage: spec-archive.sh <identifier>" >&2
  exit 1
fi

require_identifier "$IDENTIFIER"

SPEC_DIR="$(spec_dir_for "$IDENTIFIER")"

if [ ! -d "$SPEC_DIR" ]; then
  echo "ERROR: Spec directory not found: $SPEC_DIR"
  exit 1
fi

# Determine project name from git remote or directory name
PROJECT_NAME=""
if command -v git &> /dev/null && git rev-parse --is-inside-work-tree &> /dev/null; then
  REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -n "$REMOTE_URL" ]; then
    # Extract repo name from remote URL (handles both HTTPS and SSH)
    PROJECT_NAME=$(basename -s .git "$REMOTE_URL")
  fi
fi

if [ -z "$PROJECT_NAME" ]; then
  PROJECT_NAME=$(basename "$(pwd)")
fi

ARCHIVE_DIR="$HOME/.autocode/specs/$PROJECT_NAME/$IDENTIFIER"

# Never overwrite a prior archive; suffix with a timestamp instead
if [ -d "$ARCHIVE_DIR" ]; then
  ARCHIVE_DIR="${ARCHIVE_DIR}-$(date +%Y%m%d%H%M%S)"
fi

echo "=== Spec Archive ==="
echo ""
echo "Project: $PROJECT_NAME"
echo "Spec: $IDENTIFIER"
echo "Archive: $ARCHIVE_DIR"
echo ""

# Check for REVIEW.md
if [ ! -f "$SPEC_DIR/REVIEW.md" ]; then
  echo "ERROR: REVIEW.md not found in $SPEC_DIR"
  echo "Run /autocode:review $IDENTIFIER first"
  exit 1
fi

# Create archive directory
mkdir -p "$ARCHIVE_DIR"

# Move everything except REVIEW.md to the archive (mv is the safe path:
# no copy-then-delete window where a failed copy loses files)
MOVED=0

for entry in "$SPEC_DIR"/*; do
  [ -e "$entry" ] || continue
  NAME=$(basename "$entry")

  if [ "$NAME" = "REVIEW.md" ]; then
    continue
  fi

  if [ -d "$entry" ]; then
    FILE_COUNT=$(find "$entry" -type f | wc -l | tr -d ' ')
    mv "$entry" "$ARCHIVE_DIR/"
    MOVED=$((MOVED + FILE_COUNT))
    echo "Archived: $NAME/ ($FILE_COUNT files)"
  else
    mv "$entry" "$ARCHIVE_DIR/"
    MOVED=$((MOVED + 1))
    echo "Archived: $NAME"
  fi
done

# item 16 / roadmap 4.10: REVIEW.md is the single most audit-relevant file
# (the durable human sign-off record). Under the default gitignored
# .specs/ layout, it previously survived in neither git nor the archive -
# it stayed only in the working tree, the least durable of the three
# places it could live. Copy (not move) it into the archive too, so a
# full historical record exists in one place even if the working-tree
# copy is later deleted; the working-tree copy stays in place so
# git-diff/PR visibility still works in projects where .specs/ isn't
# fully gitignored.
cp "$SPEC_DIR/REVIEW.md" "$ARCHIVE_DIR/REVIEW.md"
MOVED=$((MOVED + 1))
echo "Archived: REVIEW.md (copied; original preserved in $SPEC_DIR)"

echo ""
echo "=== Archive Complete ==="
echo "Files archived: $MOVED"
echo "Location: $ARCHIVE_DIR"
echo "Preserved: $SPEC_DIR/REVIEW.md (also copied into archive)"
