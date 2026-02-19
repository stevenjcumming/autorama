#!/bin/bash

set -e

IDENTIFIER="$1"

if [ -z "$IDENTIFIER" ]; then
  echo "Error: identifier is required"
  echo "Usage: new-spec.sh <identifier>"
  exit 1
fi

SPEC_DIR=".claude/specs/$IDENTIFIER"

if [ -d "$SPEC_DIR" ]; then
  echo "Error: spec '$IDENTIFIER' already exists at $SPEC_DIR"
  exit 1
fi

mkdir -p "$SPEC_DIR"

cat > "$SPEC_DIR/REQUIREMENT.md" << 'EOF'
# Requirements

<!-- 

Copy & paste requirements below. Sources may include:
- PRD / Feature request
- Bug report
- GitHub issue
- User story
- Email / Slack thread
-->

## Source

<!-- Link or reference to original source (e.g., GitHub issue URL, JIRA ticket) -->

EOF

cat > "$SPEC_DIR/SPEC.md" << 'EOF'
# Spec: [Title]

## Overview

<!-- Brief summary: What problem does this solve? Who is it for? -->

## Requirements

See @REQUIREMENT.md

### Summary

<!-- Your distilled interpretation of the requirements -->

## Success Metrics

<!-- How do we know this is successful? -->

-

## Acceptance Criteria

- [ ]

## Assumptions & Constraints

<!-- Known limitations, technical constraints, or unvalidated expectations -->

-

## Dependencies

-

## Out of Scope

-

## Open Questions

- [ ]

## Notes

EOF

echo "Created spec at $SPEC_DIR/SPEC.md"
echo "Created requirements at $SPEC_DIR/REQUIREMENT.md"
