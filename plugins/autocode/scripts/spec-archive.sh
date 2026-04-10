#!/bin/bash

set -e

IDENTIFIER="$1"

if [ -z "$IDENTIFIER" ]; then
  echo "ERROR: No identifier provided"
  echo "Usage: spec-archive.sh <identifier>"
  exit 1
fi

SPEC_DIR=".claude/specs/$IDENTIFIER"

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

ARCHIVE_DIR="$HOME/.autopilot/specs/$PROJECT_NAME/$IDENTIFIER"

echo "=== Spec Archive ==="
echo ""
echo "Project: $PROJECT_NAME"
echo "Spec: $IDENTIFIER"
echo "Archive: $ARCHIVE_DIR"
echo ""

# Check for REVIEW.md
if [ ! -f "$SPEC_DIR/REVIEW.md" ]; then
  echo "WARNING: REVIEW.md not found in $SPEC_DIR"
  echo "Run /autopilot:review $IDENTIFIER first"
  exit 1
fi

# Create archive directory
mkdir -p "$ARCHIVE_DIR"

# Copy files to archive
COPIED=0

for file in SPEC.md PLAN.md TODO.md; do
  if [ -f "$SPEC_DIR/$file" ]; then
    cp "$SPEC_DIR/$file" "$ARCHIVE_DIR/"
    COPIED=$((COPIED + 1))
    echo "Archived: $file"
  fi
done

# Copy artifacts directory if it exists
if [ -d "$SPEC_DIR/artifacts" ]; then
  cp -r "$SPEC_DIR/artifacts" "$ARCHIVE_DIR/"
  ARTIFACT_COUNT=$(find "$SPEC_DIR/artifacts" -type f | wc -l | tr -d ' ')
  COPIED=$((COPIED + ARTIFACT_COUNT))
  echo "Archived: artifacts/ ($ARTIFACT_COUNT files)"
fi

echo ""

# Remove archived files from spec directory (keep REVIEW.md)
for file in SPEC.md PLAN.md TODO.md; do
  if [ -f "$SPEC_DIR/$file" ]; then
    rm "$SPEC_DIR/$file"
    echo "Removed: $SPEC_DIR/$file"
  fi
done

if [ -d "$SPEC_DIR/artifacts" ]; then
  rm -rf "$SPEC_DIR/artifacts"
  echo "Removed: $SPEC_DIR/artifacts/"
fi

echo ""
echo "=== Archive Complete ==="
echo "Files archived: $COPIED"
echo "Location: $ARCHIVE_DIR"
echo "Preserved: $SPEC_DIR/REVIEW.md"
