---
description: Use when the user wants a structured code review of recent changes against a quality checklist (security, testing, error handling, performance). Works standalone or scoped to a spec. Outputs severity-bucketed findings.
allowed-tools: Bash, Read, Write, Glob
argument-hint: [identifier] [--ref <ref>]
---

# Code Review

Perform a structured code review against a configurable checklist, producing severity-bucketed findings.

## Arguments

- `$ARGUMENTS` may contain: `<identifier> [--ref <ref>]`
- Parse the arguments to extract:
  - `IDENTIFIER`: Optional spec identifier (e.g., `auth-refactor`)
  - `REF`: Optional git ref to diff against (default: use spec branch or HEAD~1)
- If `IDENTIFIER` is provided, construct `SPEC_DIR` as `.claude/specs/$IDENTIFIER`

## Step 1: Gather Diff

Get the code changes to review:

```bash
git diff HEAD
```

If `--ref` was provided, use that ref:
```bash
git diff {REF}...HEAD
```

If no ref and an identifier was provided, diff against the branch point.

Also gather the diff stat for a summary:
```bash
git diff --stat HEAD
```

## Step 2: Load Checklist

Load the code review checklist in this priority order:

1. Check config path in `.claude/autopilot.yml` under `code_review.checklist`
2. Check for `.claude/code-review-checklist.md` in the project
3. Fall back to shipped default: `$AUTOPILOT_PLUGIN_ROOT/templates/code-review-checklist.md`

Read the checklist file.

## Step 3: Perform Review

Analyze the diff against each checklist item. For each violation found, create a finding with:

- **Severity**: CRITICAL / HIGH / MEDIUM / LOW
- **Title**: Short description of the finding
- **Description**: What was found, with specific file paths and line numbers
- **Impact**: What could go wrong if this isn't addressed
- **Fix**: Suggested resolution
- **Checklist Reference**: Which checklist item this relates to

### Severity Definitions

- **CRITICAL**: Security vulnerabilities, data loss risks, authentication/authorization bypasses, injection flaws
- **HIGH**: Bugs causing incorrect behavior, significant regressions, race conditions, resource leaks
- **MEDIUM**: Code quality issues — missing error handling, poor naming, insufficient validation, duplicated logic
- **LOW**: Style issues, minor improvements, documentation gaps, non-idiomatic patterns

## Step 4: Write Output

Format the findings as a structured markdown report:

```markdown
# Code Review

**Date:** {date}
**Ref:** {diff_ref}
**Files Changed:** {file_count}

## Summary

- CRITICAL: {count}
- HIGH: {count}
- MEDIUM: {count}
- LOW: {count}

## CRITICAL

### {finding_title}
**File:** `{file_path}:{line}`
**Description:** {description}
**Impact:** {impact}
**Fix:** {fix}
**Checklist:** {checklist_item}

## HIGH
...

## MEDIUM
...

## LOW
...

## Checklist Coverage

Items checked with no findings:
- {item_1}
- {item_2}
```

Write the output to:
- **Spec mode** (identifier provided): `{SPEC_DIR}/artifacts/CODE_REVIEW.md`
- **Standalone mode** (no identifier): `.claude/CODE_REVIEW.md`

## Step 5: Present Results

Display the review summary to the user with finding counts per severity level and highlight any CRITICAL or HIGH findings.
