---
name: review
description: Use after autocode execution completes to review code changes, artifacts, risks, and review hints before committing. Provides a human checkpoint with approval/reject workflow.
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/review/scripts/review.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/review/scripts/generate-report.sh:*), Read, Write, Glob, Grep
argument-hint: <identifier>
---

# Review

Generate a review summary for human oversight before proceeding to the Submit stage.

## Arguments

- `$ARGUMENTS` contains: `<identifier>`
- Parse the arguments to extract:
  - `IDENTIFIER`: The spec identifier (e.g., `auth-refactor`)
- Construct `SPEC_DIR` as `.specs/$IDENTIFIER`
- Artifacts are located at `.specs/$IDENTIFIER/artifacts/`

## Overview

This command provides a human checkpoint by summarizing:
1. Code changes made during implementation
2. Artifacts generated during the Test → Code → Refactor loop
3. High-risk items requiring attention
4. Review hints flagged for human judgment

## Step 1: Run Review Scripts

Execute the review script with the spec identifier to gather summary data, then generate the summary report:

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/review/scripts/review.sh $ARGUMENTS
```

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/review/scripts/generate-report.sh .specs/$IDENTIFIER
```

The `generate-report.sh` script creates a `SUMMARY.md` file in the spec directory with artifact counts, deferred issues, and review hints.

## Step 2: Present the Summary

Read the generated `SUMMARY.md` and present its contents to the reviewer as-is. Do not re-summarize it; the script output and SUMMARY.md already cover changes and artifact counts. Then add depth only where human judgment is needed:

### High-Risk Items
For each high-risk item found:
1. Read the full artifact file
2. Summarize the risk and why it's flagged as high
3. Note the mitigation strategy if documented

### Review Hints
For each review hint:
1. Read the full artifact file
2. Present the questions that need human judgment
3. Show the specific files and lines to review

## Step 3: Provide Review Checklist

Present this checklist for the human reviewer:

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
- [ ] Approved to continue to Submit stage
- [ ] Needs changes (return to implementation)
- [ ] Fundamental issues (return to Spec)
```

## Step 4: Await Human Decision

After presenting the summary, ask the reviewer:

"Please review the summary above. What would you like to do?"

Options:
1. **Approve** - Proceed to Submit stage
2. **Request changes** - Return to implementation (specify what needs fixing)
3. **Reject** - Return to Spec stage (fundamental issues found)

## Step 5: Record the Decision

After the reviewer responds, write their decision to `.specs/{IDENTIFIER}/REVIEW.md` using this template. This file is required by `/autocode:spec-archive`, so do not skip this step.

```markdown
# Review

- **Decision:** {approve | request-changes | reject}
- **Date:** {YYYY-MM-DD}
- **Spec:** {IDENTIFIER}

## Checklist Outcomes

{The review checklist from Step 3, with each item marked [x] or [ ] based on the review}

## Reviewer Notes

{The reviewer's comments, requested changes, or rationale; "None" if not provided}
```

If the decision is **Request changes** or **Reject**, still write REVIEW.md (capturing what needs fixing), then point the user back to the appropriate stage.

## Notes

- This is a human checkpoint - all information is for review, not automatic action
- The review script shows a quick summary; use Read to dive deeper into specific artifacts
- High-risk items should always be reviewed before proceeding
- Review hints contain questions that require human judgment
