#!/bin/bash
# Capture code quality baseline for refactoring comparison
set -e

SPEC_DIR="${1:-.claude/specs/default}"
BASELINE_DIR="${SPEC_DIR}/artifacts/.baseline"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BASELINE_DIR"

# Get modified files from working tree
MODIFIED_FILES=$(git diff --name-only HEAD 2>/dev/null || echo "")

if [ -z "$MODIFIED_FILES" ]; then
    echo "NO_CHANGES"
    exit 0
fi

# Capture line counts
OUTPUT_FILE="${BASELINE_DIR}/metrics_${TIMESTAMP}.md"
echo "# Baseline Metrics - ${TIMESTAMP}" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| File | Lines | Functions |" >> "$OUTPUT_FILE"
echo "|------|-------|-----------|" >> "$OUTPUT_FILE"

for file in $MODIFIED_FILES; do
    if [ -f "$file" ]; then
        lines=$(wc -l < "$file" | tr -d ' ')
        # Count function-like definitions across common languages
        funcs=$(grep -cE '^\s*(def |function |fn |func |const \w+ = |class )' "$file" 2>/dev/null || echo "0")
        echo "| $file | $lines | $funcs |" >> "$OUTPUT_FILE"
    fi
done

echo "BASELINE:${OUTPUT_FILE}"
