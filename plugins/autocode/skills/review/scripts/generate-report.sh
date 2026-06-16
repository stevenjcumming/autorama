#!/usr/bin/env bash
# Generate summary report of spec artifacts
set -euo pipefail

SPEC_DIR="${1:-}"

if [ -z "$SPEC_DIR" ]; then
    echo "Error: spec directory is required" >&2
    echo "Usage: generate-report.sh <spec_dir>" >&2
    exit 1
fi

if [ ! -d "$SPEC_DIR" ]; then
    echo "Error: spec directory does not exist at $SPEC_DIR" >&2
    echo "Usage: generate-report.sh <spec_dir>" >&2
    exit 1
fi

REPORT="${SPEC_DIR}/SUMMARY.md"

echo "# Spec Summary Report" > "$REPORT"
echo "" >> "$REPORT"
echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$REPORT"
echo "" >> "$REPORT"

# Count artifacts by type
echo "## Artifacts" >> "$REPORT"
echo "" >> "$REPORT"
echo "| Type | Count |" >> "$REPORT"
echo "|------|-------|" >> "$REPORT"

for type in justifications decisions assumptions risks debt review_hints; do
    dir="${SPEC_DIR}/artifacts/${type}"
    if [ -d "$dir" ]; then
        count=$(find "$dir" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    else
        count=0
    fi
    echo "| ${type} | ${count} |" >> "$REPORT"
done

# List deferred debt items
echo "" >> "$REPORT"
echo "## Deferred Issues" >> "$REPORT"
echo "" >> "$REPORT"

debt_dir="${SPEC_DIR}/artifacts/debt"
if [ -d "$debt_dir" ] && [ "$(ls -A "$debt_dir" 2>/dev/null)" ]; then
    for debt in "$debt_dir"/*.md; do
        if [ -f "$debt" ]; then
            # Title comes from the YAML frontmatter (every artifact template has title:)
            title=$(grep -m1 "^title:" "$debt" 2>/dev/null | sed 's/^title:[[:space:]]*//' || true)
            echo "- ${title:-$(basename "$debt" .md)}" >> "$REPORT"
        fi
    done
else
    echo "No deferred issues." >> "$REPORT"
fi

# List review hints
echo "" >> "$REPORT"
echo "## Review Hints" >> "$REPORT"
echo "" >> "$REPORT"

hints_dir="${SPEC_DIR}/artifacts/review_hints"
if [ -d "$hints_dir" ] && [ "$(ls -A "$hints_dir" 2>/dev/null)" ]; then
    for hint in "$hints_dir"/*.md; do
        if [ -f "$hint" ]; then
            # Title comes from the YAML frontmatter (same extraction as review.sh)
            title=$(grep -m1 "^title:" "$hint" 2>/dev/null | sed 's/^title:[[:space:]]*//' || true)
            echo "- ${title:-$(basename "$hint" .md)}" >> "$REPORT"
        fi
    done
else
    echo "No review hints." >> "$REPORT"
fi

echo ""
echo "REPORT:${REPORT}"
