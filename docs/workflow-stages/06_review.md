# Workflow: Review

## Purpose

Provide a human checkpoint by summarizing code changes and artifacts generated during implementation. This stage ensures human oversight before proceeding to Reflect and Submit stages.

## Command

```
/autopilot:review
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| None | - | No arguments required |

## Examples

```bash
# Generate review summary
/autopilot:review
```

## Prerequisites

- Implementation work should be completed (autopilot or manual coding)
- Artifacts may exist in `.claude/specs/<identifier>/artifacts/` (optional but recommended)
- Git repository recommended for change detection

## What It Does

1. **Runs review script**: Gathers summary data from git and artifacts
2. **Presents changes summary**: Shows files modified and nature of changes
3. **Summarizes artifacts**: Lists artifact types and counts
4. **Highlights high-risk items**: Surfaces items marked as high risk or critical
5. **Shows review hints**: Presents questions requiring human judgment
6. **Provides checklist**: Gives structured review guide
7. **Awaits decision**: Asks whether to proceed, request changes, or reject

## Review Process

```
/autopilot:review
├── Run review.sh (gather data)
│   ├── Summarize git changes
│   ├── Count artifacts by type
│   ├── Find high-risk items
│   └── Extract review hints
├── Present enhanced summary
│   ├── Changes summary with context
│   ├── Artifacts summary with titles
│   ├── High-risk items with details
│   └── Review hints with questions
├── Show review checklist
└── Await human decision
```

## Summary Sections

### Changes Summary

Shows files changed during implementation:
- File count and file list
- Uncommitted changes if present
- Nature of changes (new features, bug fixes, refactoring)
- Files requiring extra attention (security, config, API)

### Artifacts Summary

Lists generated artifacts by type:

| Type | Description |
|------|-------------|
| justifications | Why flagged files were modified |
| decisions | Choices made between approaches |
| assumptions | Inferred requirements |
| risks | Potential problems identified |
| review_hints | Questions for human judgment |
| debt | Technical shortcuts taken |

### High-Risk Items

Surfaces artifacts marked as high risk or critical:
- Reads full artifact content
- Summarizes the risk and why it's flagged
- Shows mitigation strategy if documented

### Review Hints

Presents questions requiring human judgment:
- Files and lines to review
- Specific questions to answer
- Context for decision-making

## Review Checklist

The command presents this checklist for the reviewer:

```
## Review Checklist

### Artifacts
- [ ] Justifications reviewed for flagged files
- [ ] Assumptions validated or corrected
- [ ] Decisions approved
- [ ] Technical debt is acceptable

### Code
- [ ] Code changes match stated intent
- [ ] No security or quality concerns
- [ ] Tests are passing

### High-Risk Items
- [ ] All high-risk items reviewed and accepted

### Ready to Proceed
- [ ] Approved to continue to Reflect stage
- [ ] Needs changes (return to implementation)
- [ ] Fundamental issues (return to Spec)
```

## Human Decision

After presenting the summary, the reviewer chooses:

| Decision | Action |
|----------|--------|
| **Approve** | Proceed to Reflect stage |
| **Request changes** | Return to implementation with specific fixes |
| **Reject** | Return to Spec stage for fundamental issues |

## Directory Structure

```
.claude/
├── commands/
│   └── review.md              # Command definition
├── scripts/
│   └── review.sh              # Data gathering script
├── artifacts/                  # Curated/promoted artifacts (user-managed)
│   └── ...
└── specs/
    └── <identifier>/
        └── artifacts/          # Input for review (per-spec, gitignored)
            ├── justifications/
            ├── decisions/
            ├── assumptions/
            ├── risks/
            ├── review_hints/
            └── debt/
```

## Output

The command provides:
- Summary of code changes with file counts
- Artifacts summary with counts by type
- Detailed view of high-risk items
- Review hints with questions and file locations
- Structured checklist for review
- Prompt for human decision

## Key Characteristics

- **Human checkpoint**: All information is for review, not automatic action
- **Read-only**: Does not modify code or artifacts
- **Interactive**: Requires human decision to proceed
- **Comprehensive**: Surfaces all relevant information for informed review

## Best Practices

1. **Review all high-risk items**: These require explicit acceptance before proceeding
2. **Address review hints**: Answer the questions before moving forward
3. **Validate assumptions**: Incorrect assumptions should be corrected
4. **Check technical debt**: Ensure shortcuts are documented and acceptable
5. **Run tests**: Verify tests pass before approving

## Next Steps

After review completes:

1. If **Approved**: Run `/autopilot:reflect` to analyze session and propose improvements
2. If **Changes needed**: Return to implementation or `/autopilot:execute`
3. If **Rejected**: Return to `/autopilot:new-spec` or `/autopilot:create-plan` to address fundamental issues
