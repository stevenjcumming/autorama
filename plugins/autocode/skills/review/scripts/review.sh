#!/usr/bin/env bash
# review.sh - Gather review data for the Review stage and write SUMMARY.md
# Usage: review.sh <spec-identifier>
#
# Writes <spec_dir>/SUMMARY.md (changes summary, artifact counts, high-risk
# scan, deferred issues, review hints, next steps) and prints a short
# pointer line. No ANSI color codes: the summary is consumed by the model
# via Read, so terminal styling would only waste tokens.

set -euo pipefail

source "$(dirname "$0")/../../../scripts/lib.sh"

SPEC_ID="${1:-}"

require_identifier "$SPEC_ID" "Usage: bash $0 <spec-identifier>"

SPEC_DIR="$(spec_dir_for "$SPEC_ID")"

if [ ! -d "$SPEC_DIR" ]; then
    echo "Error: Spec directory not found at $SPEC_DIR" >&2
    exit 1
fi

ARTIFACTS_DIR="$SPEC_DIR/artifacts"
REPORT="$SPEC_DIR/SUMMARY.md"

# Single source of truth for artifact types, kept in sync with the
# directories setup-artifacts.sh creates (including handoff, which an
# earlier hardcoded copy of this list omitted).
ARTIFACT_TYPES=(justifications decisions assumptions risks review_hints debt handoff)

# Gather all git state up front, before SUMMARY.md is opened for writing.
# git status/diff/ls-files must run before the report file exists on disk:
# `{ ... } > "$REPORT"` creates/truncates $REPORT as soon as the block
# starts, and if the git queries ran *inside* the block, `git ls-files
# --others` would then see the freshly-created (and still-untracked)
# SUMMARY.md and list it as one of its own untracked files.
IS_GIT_REPO=0
BASE_BRANCH=""
CURRENT_BRANCH=""
BASE_STATUS_NOTE=""
COMMITTED_FILES=""
UNCOMMITTED_FILES=""
UNTRACKED_FILES=""
TOTAL_ARTIFACTS=0
HIGH_RISK_COUNT=0

if git rev-parse --git-dir > /dev/null 2>&1; then
    IS_GIT_REPO=1

    # Find a base branch to compare against: origin/HEAD when resolvable,
    # then origin/main, then a local main
    if ORIGIN_HEAD=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null); then
        BASE_BRANCH="origin/${ORIGIN_HEAD#refs/remotes/origin/}"
    elif git rev-parse --verify --quiet origin/main > /dev/null 2>&1; then
        BASE_BRANCH="origin/main"
    elif git rev-parse --verify --quiet main > /dev/null 2>&1; then
        BASE_BRANCH="main"
    fi

    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

    if [ -z "$BASE_BRANCH" ]; then
        BASE_STATUS_NOTE="_No base branch found (origin/HEAD, origin/main, or main); showing uncommitted/untracked changes only._"
    elif [ "$CURRENT_BRANCH" = "${BASE_BRANCH#origin/}" ]; then
        BASE_STATUS_NOTE="_Currently on the base branch ($CURRENT_BRANCH), so there is no branch diff._"
    else
        COMMITTED_FILES=$(git diff --name-only "$BASE_BRANCH"...HEAD 2>/dev/null || echo "")
    fi

    UNCOMMITTED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null || echo "")
fi

{
    echo "# Spec Summary Report"
    echo ""
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""
    echo "Spec: $SPEC_ID"
    echo "Artifacts: $ARTIFACTS_DIR"
    echo ""

    # 1. Changes Summary - always show all three sections regardless of
    # branch state, so uncommitted/untracked work from a fresh execute run
    # is never invisible just because a branch diff also exists (or doesn't).
    echo "## Changes Summary"
    echo ""

    if [ "$IS_GIT_REPO" -eq 1 ]; then
        if [ -n "$BASE_STATUS_NOTE" ]; then
            echo "$BASE_STATUS_NOTE"
            echo ""
        fi

        echo "### Committed on Branch"
        echo ""
        if [ -n "$COMMITTED_FILES" ]; then
            echo "- ${COMMITTED_FILES//$'\n'/$'\n'- }"
        else
            echo "None."
        fi
        echo ""

        echo "### Uncommitted"
        echo ""
        if [ -n "$UNCOMMITTED_FILES" ]; then
            echo "- ${UNCOMMITTED_FILES//$'\n'/$'\n'- }"
        else
            echo "None."
        fi
        echo ""

        echo "### Untracked"
        echo ""
        if [ -n "$UNTRACKED_FILES" ]; then
            echo "- ${UNTRACKED_FILES//$'\n'/$'\n'- }"
        else
            echo "None."
        fi
        echo ""
    else
        echo "Not a git repository. Unable to summarize changes."
        echo ""
    fi

    # 2. Artifacts Summary - one authoritative type list drives both the
    # per-type count and the total, so they cannot drift apart.
    echo "## Artifacts"
    echo ""
    echo "| Type | Count |"
    echo "|------|-------|"

    for type in "${ARTIFACT_TYPES[@]}"; do
        dir="$ARTIFACTS_DIR/$type"
        if [ -d "$dir" ]; then
            count=$(find "$dir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
        else
            count=0
        fi
        echo "| $type | $count |"
        TOTAL_ARTIFACTS=$((TOTAL_ARTIFACTS + count))
    done
    echo ""
    echo "Total artifacts: $TOTAL_ARTIFACTS"
    echo ""

    # 3. High-Risk Scan - match structured YAML frontmatter fields only
    # (overall_risk: from risk.md, priority: from review_hint.md), not a
    # loose substring match, so prose like "reduces risk... high-level
    # design" doesn't false-flag.
    echo "## High-Risk Items"
    echo ""

    HIGH_RISK_FILES=""
    if [ -d "$ARTIFACTS_DIR" ]; then
        HIGH_RISK_FILES=$(grep -rilE '^(overall_risk|priority):[[:space:]]*(high|critical)' "$ARTIFACTS_DIR" 2>/dev/null || true)
    fi

    if [ -n "$HIGH_RISK_FILES" ]; then
        while IFS= read -r file; do
            [ -z "$file" ] && continue
            [ -f "$file" ] || continue
            HIGH_RISK_COUNT=$((HIGH_RISK_COUNT + 1))
            echo "### $(basename "$file")"
            echo ""
            echo "File: $file"
            TITLE=$(grep -m1 "^title:" "$file" 2>/dev/null | sed 's/^title:[[:space:]]*//' || true)
            if [ -n "$TITLE" ]; then
                echo "Title: $TITLE"
            fi
            echo ""
        done <<< "$HIGH_RISK_FILES"
    else
        echo "No high-risk items found."
        echo ""
    fi

    # 4. Deferred Issues (debt)
    echo "## Deferred Issues"
    echo ""

    debt_dir="$ARTIFACTS_DIR/debt"
    if [ -d "$debt_dir" ] && [ -n "$(find "$debt_dir" -name '*.md' -type f 2>/dev/null)" ]; then
        for debt in "$debt_dir"/*.md; do
            if [ -f "$debt" ]; then
                title=$(grep -m1 "^title:" "$debt" 2>/dev/null | sed 's/^title:[[:space:]]*//' || true)
                echo "- ${title:-$(basename "$debt" .md)}"
            fi
        done
    else
        echo "No deferred issues."
    fi
    echo ""

    # 5. Review Hints
    echo "## Review Hints"
    echo ""

    hints_dir="$ARTIFACTS_DIR/review_hints"
    if [ -d "$hints_dir" ] && [ -n "$(find "$hints_dir" -name '*.md' -type f 2>/dev/null)" ]; then
        for hint_file in "$hints_dir"/*.md; do
            if [ -f "$hint_file" ]; then
                echo "### $(basename "$hint_file" .md)"
                echo ""
                echo "Location: $hint_file"
                echo ""

                TITLE=$(grep -m1 "^title:" "$hint_file" 2>/dev/null | sed 's/^title:[[:space:]]*//' || true)
                if [ -n "$TITLE" ]; then
                    echo "Title: $TITLE"
                fi

                PRIORITY=$(grep -m1 "^priority:" "$hint_file" 2>/dev/null | sed 's/^priority:[[:space:]]*//' || true)
                if [ -n "$PRIORITY" ]; then
                    echo "Priority: $PRIORITY"
                fi

                echo ""
                echo "Files to Review:"
                echo ""
                # Print table rows between "## Files to Review" and the next
                # heading (flag-based: an awk range pattern would start and
                # end on the same line and never print). Skip both the
                # header row and the |---|---| separator row beneath it.
                awk '/^## Files to Review/{flag=1; next} /^##/{flag=0} flag && /^\|/ && !/File.*Lines.*Focus/ && !/^\|[-: ]+\|/' "$hint_file" 2>/dev/null || true

                echo ""
                echo "Questions:"
                awk '/^## Specific Questions/{flag=1; next} /^##/{flag=0} flag && /^[0-9]+\./{print "  "$0}' "$hint_file" 2>/dev/null || true

                echo ""
                echo "---"
                echo ""
            fi
        done
    else
        echo "No review hints found."
    fi
    echo ""

    # 6. Next Steps
    echo "## Next Steps"
    echo ""
    echo "1. Review the high-risk items above"
    echo "2. Address all review hints"
    echo "3. Check artifacts in $ARTIFACTS_DIR/"
    echo "4. Run: git diff to see full code changes"
    echo "5. When satisfied, proceed to Submit stage"
} > "$REPORT"

FILES_CHANGED_COUNT=$(printf '%s\n%s\n%s\n' "$COMMITTED_FILES" "$UNCOMMITTED_FILES" "$UNTRACKED_FILES" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')

echo "Wrote $REPORT - $FILES_CHANGED_COUNT file(s) changed, $TOTAL_ARTIFACTS artifact(s), $HIGH_RISK_COUNT high-risk item(s) flagged."
