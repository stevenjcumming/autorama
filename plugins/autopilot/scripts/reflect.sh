#!/bin/bash
# reflect.sh - Gather data for the Reflect stage
# Usage: bash $PLUGIN_DIR/scripts/reflect.sh <spec-identifier>

set -e

SPEC_ID="${1:-}"

if [ -z "$SPEC_ID" ]; then
    echo "Error: Spec identifier required"
    echo "Usage: bash $PLUGIN_DIR/scripts/reflect.sh <spec-identifier>"
    exit 1
fi

SPEC_DIR=".claude/specs/$SPEC_ID"

if [ ! -d "$SPEC_DIR" ]; then
    echo "Error: Spec directory not found at $SPEC_DIR"
    exit 1
fi

ARTIFACTS_DIR="$SPEC_DIR/artifacts"
SIGNALS_DIR="$ARTIFACTS_DIR/signals"
RULES_DIR=".claude/rules"

# Colors for output
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo "=========================================="
echo "         REFLECT STAGE"
echo "=========================================="
echo ""

# Create signals directory if needed
if [ ! -d "$SIGNALS_DIR" ]; then
    mkdir -p "$SIGNALS_DIR"
    echo -e "${GREEN}Created:${NC} $SIGNALS_DIR"
fi

# Create rules directory if needed
if [ ! -d "$RULES_DIR" ]; then
    mkdir -p "$RULES_DIR"
    echo -e "${GREEN}Created:${NC} $RULES_DIR"
fi

echo ""
echo "=========================================="
echo ""

# Count signals
echo -e "${BLUE}## Signals Available${NC}"
echo ""

SIGNAL_COUNT=0
if [ -d "$SIGNALS_DIR" ]; then
    SIGNAL_COUNT=$(find "$SIGNALS_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$SIGNAL_COUNT" -gt 0 ]; then
    echo "Found $SIGNAL_COUNT signal(s) in $SIGNALS_DIR"
    echo ""
    echo "| Signal Type | Count |"
    echo "|-------------|-------|"

    # Count by signal type
    for type in correction rejection repetition approval clarification praise; do
        TYPE_COUNT=$(grep -ril "signal_type: $type" "$SIGNALS_DIR" 2>/dev/null | wc -l | tr -d ' ')
        if [ "$TYPE_COUNT" -gt 0 ]; then
            echo "| $type | $TYPE_COUNT |"
        fi
    done
else
    echo -e "${YELLOW}No signals found in $SIGNALS_DIR${NC}"
    echo "Signals are generated during /autopilot:execute execution."
fi

echo ""
echo "=========================================="
echo ""

# Count existing artifacts for analysis
echo -e "${BLUE}## Artifacts Available${NC}"
echo ""

TOTAL=0
if [ -d "$ARTIFACTS_DIR" ]; then
    echo "| Artifact Type | Count |"
    echo "|---------------|-------|"

    for dir in decisions assumptions review_hints risks debt; do
        if [ -d "$ARTIFACTS_DIR/$dir" ]; then
            COUNT=$(find "$ARTIFACTS_DIR/$dir" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [ "$COUNT" -gt 0 ]; then
                echo "| $dir | $COUNT |"
                TOTAL=$((TOTAL + COUNT))
            fi
        fi
    done

    if [ "$TOTAL" -eq 0 ]; then
        echo -e "${YELLOW}No artifacts found${NC}"
    fi
else
    echo -e "${YELLOW}No artifacts directory found${NC}"
fi

echo ""
echo "=========================================="
echo ""

# Count existing rules
echo -e "${BLUE}## Existing Rules${NC}"
echo ""

RULE_COUNT=0
if [ -d "$RULES_DIR" ]; then
    RULE_COUNT=$(find "$RULES_DIR" -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

if [ "$RULE_COUNT" -gt 0 ]; then
    echo "Found $RULE_COUNT existing rule(s) in $RULES_DIR:"
    find "$RULES_DIR" -name "*.md" -type f 2>/dev/null | while read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            echo "  - $(basename "$file")"
        fi
    done
else
    echo "No existing rules in $RULES_DIR"
fi

echo ""
echo "=========================================="
echo ""

# Spec context
echo -e "${BLUE}## Spec Context${NC}"
echo ""
echo "Spec: $SPEC_ID"
echo "Path: $SPEC_DIR"
echo "Artifacts: $ARTIFACTS_DIR"

if [ -f "$SPEC_DIR/SPEC.md" ]; then
    # Extract title from spec
    SPEC_TITLE=$(grep -m1 "^# " "$SPEC_DIR/SPEC.md" 2>/dev/null | sed 's/^# //' || echo "")
    if [ -n "$SPEC_TITLE" ]; then
        echo "Title: $SPEC_TITLE"
    fi
fi
echo ""
echo "=========================================="
echo ""

# Summary
echo -e "${CYAN}## Summary${NC}"
echo ""
echo "- Spec: $SPEC_ID"
echo "- Signals to analyze: $SIGNAL_COUNT"
echo "- Artifacts to review: $TOTAL"
echo "- Existing rules: $RULE_COUNT"
echo ""
echo "Ready for signal and artifact analysis."
