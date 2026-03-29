---
description: Use when the user wants a structured code review of recent changes against a quality checklist (security, testing, error handling, performance). Works standalone or scoped to a spec. Outputs severity-bucketed findings.
allowed-tools: Bash, Read, Write, Glob, Task
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

## Step 3: Determine Output Path

- **Spec mode** (identifier provided): `{SPEC_DIR}/artifacts/CODE_REVIEW.md`
- **Standalone mode** (no identifier): `.claude/CODE_REVIEW.md`

## Step 4: Spawn Reviewer Agent

Spawn the reviewer agent via Task, passing all inputs:

```
Task(autopilot:autopilot-reviewer,
  "Review code changes against checklist.
  SPEC_DIR={SPEC_DIR} OUTPUT_PATH={OUTPUT_PATH}
  <diff>{DIFF}</diff>
  <diff-stat>{DIFF_STAT}</diff-stat>
  <checklist>{CHECKLIST}</checklist>
  Evaluate every checklist item against the diff. Write the review report to OUTPUT_PATH.")
```

The agent is responsible for:
- Analyzing the diff against the checklist
- Exploring codebase context as needed
- Writing the structured report to `OUTPUT_PATH`

## Step 5: Present Results

Read `OUTPUT_PATH` and display the review summary to the user with finding counts per severity level. Highlight any CRITICAL or HIGH findings.
