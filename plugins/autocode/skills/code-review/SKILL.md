---
name: code-review
description: Use when the user wants a structured code review of recent changes against a quality checklist (security, testing, error handling, performance). Works standalone or scoped to a spec. Outputs severity-bucketed findings.
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(mkdir -p:*), Bash(rm:*), Read, Glob, Task
argument-hint: [identifier] [--ref <ref>]
---

# Code Review

Perform a structured code review against a configurable checklist, producing severity-bucketed findings.

## Arguments

- `$ARGUMENTS` may contain: `<identifier> [--ref <ref>]`
- Parse the arguments to extract:
  - `IDENTIFIER`: Optional spec identifier (e.g., `auth-refactor`)
  - `REF`: Optional git ref to diff against (default: use spec branch or HEAD~1)
- If `IDENTIFIER` is provided, construct `SPEC_DIR` as `.specs/$IDENTIFIER`
- If `IDENTIFIER` is provided, verify `SPEC_DIR` exists before proceeding. If it does not, tell the user the spec was not found and stop.

## Step 1: Gather Diff

Get the code changes to review. The default scope is uncommitted work plus untracked files, since the execute loop produces both before anything is committed:

```bash
git diff HEAD
```

```bash
git status --porcelain
```

For each untracked file (`??` lines in the porcelain output), read its contents and include it in the review scope as new-file content.

If `--ref` was provided, use that ref instead:
```bash
git diff {REF}...HEAD
```

If no ref and an identifier was provided, diff against the branch point:
```bash
git diff "$(git merge-base <default-branch> HEAD)"
```

(where `<default-branch>` is `main`, `master`, or whatever the repo uses), still including untracked files as above.

Also gather the diff stat for a summary:
```bash
git diff --stat HEAD
```

## Step 2: Load Checklist

Load the code review checklist in this priority order:

1. Check config path in `.claude/autocode.yml` under `code_review.checklist` (optional config; most projects will not have this key set)
2. Check for `.claude/code-review-checklist.md` in the project
3. Fall back to shipped default: `$AUTOCODE_PLUGIN_ROOT/skills/code-review/code-review-checklist.md`

Read the checklist file.

## Step 3: Determine Output Path

- **Spec mode** (identifier provided): `{SPEC_DIR}/artifacts/CODE_REVIEW.md`
- **Standalone mode** (no identifier): `.claude/CODE_REVIEW.md`

In spec mode, ensure the artifacts directory exists before the reviewer writes its report:

```bash
mkdir -p {SPEC_DIR}/artifacts
```

## Step 4: Load Previous Findings (re-review support)

If a report already exists at `OUTPUT_PATH`, read it and pass it to the reviewer(s) as `PREVIOUS_FINDINGS`. The reviewer then reports only new or still-unaddressed issues instead of duplicating the first run's findings. If no report exists, omit the tag.

## Step 5: Spawn Reviewer Agent(s)

Count the diff size from the diff stat. Choose the review architecture by threshold: **more than 10 changed files or more than 1000 changed lines** means a single pass would dilute attention across files, so split it.

### Small diff (at or under threshold): single pass

```
Task(autocode:reviewer,
  "Review code changes against checklist.
  SPEC_DIR={SPEC_DIR} OUTPUT_PATH={OUTPUT_PATH}
  <diff>{DIFF}</diff>
  <diff-stat>{DIFF_STAT}</diff-stat>
  <checklist>{CHECKLIST}</checklist>
  <previous-findings>{PREVIOUS_FINDINGS}</previous-findings>
  Evaluate every checklist item against the diff. Write the review report to OUTPUT_PATH.")
```

### Large diff (over threshold): per-group passes plus integration pass

1. **Group the files.** Split the diff into logical groups (same directory, same layer, or same feature; one large file may be its own group). Target 1-5 files per group.
2. **Spawn one reviewer per group, all in parallel (single message with multiple Task calls).** Each gets only its group's diff hunks, the full `DIFF_STAT` for context, the checklist, and any `PREVIOUS_FINDINGS`. Each writes to its own path `{OUTPUT_PATH}.group-{n}.md`:

```
Task(autocode:reviewer,
  "Review one file group against checklist (part of a split review).
  SPEC_DIR={SPEC_DIR} OUTPUT_PATH={OUTPUT_PATH}.group-{n}.md
  <diff>{group diff hunks only}</diff>
  <diff-stat>{DIFF_STAT}</diff-stat>
  <checklist>{CHECKLIST}</checklist>
  <previous-findings>{PREVIOUS_FINDINGS}</previous-findings>
  Evaluate every checklist item against this group's diff only. Write the report to OUTPUT_PATH.")
```

3. **Integration pass.** After all group reviewers complete, read the group reports and spawn one final reviewer over the combined findings to catch what per-file passes cannot see:

```
Task(autocode:reviewer,
  "Integration pass over a split review. Look ONLY for cross-file issues:
  inconsistent patterns between files, broken contracts (caller/callee or
  producer/consumer mismatches across groups), duplicated logic introduced
  in different files, and conflicting findings between group reports.
  SPEC_DIR={SPEC_DIR} OUTPUT_PATH={OUTPUT_PATH}
  <diff-stat>{DIFF_STAT}</diff-stat>
  <checklist>{CHECKLIST}</checklist>
  <combined-findings>{concatenated group reports}</combined-findings>
  Merge the group findings plus your cross-file findings into one report
  at OUTPUT_PATH, deduplicated, with a '## Cross-File Issues' section.")
```

4. Delete the intermediate `{OUTPUT_PATH}.group-*.md` files after the merged report is written.

## Step 6: Present Results

Read `OUTPUT_PATH` and display the review summary to the user with finding counts per severity level. Highlight any CRITICAL or HIGH findings, and the Cross-File Issues section when the review was split.
