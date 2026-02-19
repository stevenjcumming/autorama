#!/bin/bash
# review.sh - Gather review data for the Review stage
# Usage: bash $PLUGIN_DIR/scripts/review.sh <spec-identifier>

set -e

SPEC_ID="${1:-}"

if [ -z "$SPEC_ID" ]; then
    echo "Error: Spec identifier required"
    echo "Usage: bash $PLUGIN_DIR/scripts/review.sh <spec-identifier>"
    exit 1
fi

SPEC_DIR=".claude/specs/$SPEC_ID"

if [ ! -d "$SPEC_DIR" ]; then
    echo "Error: Spec directory not found at $SPEC_DIR"
    exit 1
fi

ARTIFACTS_DIR="$SPEC_DIR/artifacts"

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "         REVIEW STAGE SUMMARY"
echo "=========================================="
echo ""
echo -e "${BLUE}Spec:${NC} $SPEC_ID"
echo -e "${BLUE}Artifacts:${NC} $ARTIFACTS_DIR"
echo ""

# 1. Summary of changes
echo -e "${BLUE}## Changes Summary${NC}"
echo ""

if git rev-parse --git-dir > /dev/null 2>&1; then
    # Check if there's a base branch to compare against
    BASE_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

    # Get changed files
    CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "")

    if [ -n "$CHANGED_FILES" ]; then
        FILE_COUNT=$(echo "$CHANGED_FILES" | wc -l | tr -d ' ')
        echo "Files changed: $FILE_COUNT"
        echo ""
        echo "Changed files:"
        echo "$CHANGED_FILES" | while read -r file; do
            if [ -n "$file" ]; then
                echo "  - $file"
            fi
        done
    else
        # Check for uncommitted changes
        UNCOMMITTED=$(git status --porcelain 2>/dev/null || echo "")
        if [ -n "$UNCOMMITTED" ]; then
            echo "Uncommitted changes:"
            git status --short
        else
            echo "No changes detected."
        fi
    fi
else
    echo "Not a git repository. Unable to summarize changes."
fi

echo ""
echo "=========================================="
echo ""

# 2. Summary of artifacts created
echo -e "${BLUE}## Artifacts Summary${NC}"
echo ""

if [ -d "$ARTIFACTS_DIR" ]; then
    echo "| Type | Count |"
    echo "|------|-------|"

    for dir in "$ARTIFACTS_DIR"/*/; do
        if [ -d "$dir" ]; then
            TYPE=$(basename "$dir")
            COUNT=$(find "$dir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [ "$COUNT" -gt 0 ]; then
                echo "| $TYPE | $COUNT |"
            fi
        fi
    done

    TOTAL=$(find "$ARTIFACTS_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo ""
    echo "Total artifacts: $TOTAL"
else
    echo "No artifacts directory found at $ARTIFACTS_DIR"
fi

echo ""
echo "=========================================="
echo ""

# 3. List high-risk items
echo -e "${RED}## High-Risk Items${NC}"
echo ""

HIGH_RISK_FOUND=0

if [ -d "$ARTIFACTS_DIR" ]; then
    # Search for high risk in justifications
    while IFS= read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            HIGH_RISK_FOUND=1
            echo -e "${RED}[HIGH RISK]${NC} $(basename "$file")"
            echo "  File: $file"
            # Extract the justification title if present
            TITLE=$(grep -m1 "^##\|^title:" "$file" 2>/dev/null | head -1 || echo "")
            if [ -n "$TITLE" ]; then
                echo "  $TITLE"
            fi
            echo ""
        fi
    done < <(grep -ril "risk.*high\|high.*risk\|overall_risk:.*high\|overall_risk:.*critical\|priority:.*high\|priority:.*critical" "$ARTIFACTS_DIR" 2>/dev/null || true)
fi

if [ "$HIGH_RISK_FOUND" -eq 0 ]; then
    echo -e "${GREEN}No high-risk items found.${NC}"
fi

echo ""
echo "=========================================="
echo ""

# 4. Review hints with file locations
echo -e "${YELLOW}## Review Hints${NC}"
echo ""

REVIEW_HINTS_DIR="$ARTIFACTS_DIR/review_hints"

if [ -d "$REVIEW_HINTS_DIR" ]; then
    HINT_FILES=$(find "$REVIEW_HINTS_DIR" -name "*.md" -type f 2>/dev/null)

    if [ -n "$HINT_FILES" ]; then
        echo "$HINT_FILES" | while read -r hint_file; do
            if [ -n "$hint_file" ] && [ -f "$hint_file" ]; then
                echo -e "${YELLOW}### $(basename "$hint_file" .md)${NC}"
                echo "Location: $hint_file"
                echo ""

                # Extract title
                TITLE=$(grep -m1 "^title:" "$hint_file" 2>/dev/null | sed 's/title: *//' || echo "")
                if [ -n "$TITLE" ]; then
                    echo "Title: $TITLE"
                fi

                # Extract priority
                PRIORITY=$(grep -m1 "^priority:" "$hint_file" 2>/dev/null | sed 's/priority: *//' || echo "")
                if [ -n "$PRIORITY" ]; then
                    echo "Priority: $PRIORITY"
                fi

                # Extract files to review table
                echo ""
                echo "Files to Review:"
                # Look for the table after "## Files to Review"
                awk '/^## Files to Review/,/^##/{if(/^\|/ && !/File.*Lines.*Focus/) print}' "$hint_file" 2>/dev/null || true

                # Extract specific questions
                echo ""
                echo "Questions:"
                awk '/^## Specific Questions/,/^##/{if(/^[0-9]+\./) print "  "$0}' "$hint_file" 2>/dev/null || true

                echo ""
                echo "---"
                echo ""
            fi
        done
    else
        echo "No review hints found."
    fi
else
    echo "No review_hints directory found."
fi

echo ""
echo "=========================================="
echo ""

# Final summary
echo -e "${BLUE}## Next Steps${NC}"
echo ""
echo "1. Review the high-risk items above"
echo "2. Address all review hints"
echo "3. Check artifacts in $ARTIFACTS_DIR/"
echo "4. Run: git diff to see full code changes"
echo "5. When satisfied, proceed to Reflect stage"
echo ""
