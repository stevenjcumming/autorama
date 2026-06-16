#!/bin/bash
# Generate summary report of spec artifacts
set -e

SPEC_DIR="${1:-.specs/default}"
REPORT="${SPEC_DIR}/SUMMARY.md"

echo "# Spec Summary Report" > "$REPORT"
echo "" >> "$REPORT"
echo "Generated: $(date)" >> "$REPORT"
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
            title=$(head -20 "$debt" | grep "^## " | head -1 | sed 's/^## //')
            tool=$(head -20 "$debt" | grep "^tool:" | sed 's/^tool: //')
            echo "- **${tool}**: ${title}" >> "$REPORT"
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
            title=$(head -1 "$hint" | sed 's/^# //')
            echo "- ${title}" >> "$REPORT"
        fi
    done
else
    echo "No review hints." >> "$REPORT"
fi

echo ""
echo "REPORT:${REPORT}"
