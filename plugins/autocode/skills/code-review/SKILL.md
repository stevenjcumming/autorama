---
name: code-review
description: Use when the user wants a structured code review of recent changes against a quality checklist (security, testing, error handling, performance). Works standalone or scoped to a spec. Outputs severity-bucketed findings.
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git merge-base:*), Bash(mkdir -p:*), Bash(rm .specs/*/artifacts/CODE_REVIEW.md.group-*.md), Bash(rm .claude/CODE_REVIEW.md.group-*.md), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/read-history.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh:*), Read, Glob, Task
argument-hint: "[identifier] [--ref <ref>]"
model: sonnet # orchestration: gather the diff, decide by the R table, spawn reviewer(s) at the computed tier, present their output; see docs/MODEL_SELECTION.md
---

# Code Review

Perform a structured code review against a configurable checklist, producing severity-bucketed findings.

## Arguments

- `$ARGUMENTS` may contain: `<identifier> [--ref <ref>]`
- Parse the arguments to extract:
  - `IDENTIFIER`: Optional spec identifier (e.g., `auth-refactor`)
  - `REF`: Optional git ref to diff against (default: use spec branch or HEAD~1)
- If `IDENTIFIER` is provided, before constructing `SPEC_DIR`, verify it matches `^[A-Za-z0-9._-]+$`. If it does not match, stop immediately and report an error to the user (e.g., "Invalid identifier: must contain only letters, numbers, dots, hyphens, and underscores.") — do not proceed to construct or use `SPEC_DIR`.
- If `IDENTIFIER` is provided and passes validation, construct `SPEC_DIR` as `.specs/$IDENTIFIER`
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

## Step 2: Load Checklist and Model Override

Load the code review checklist in this priority order:

1. Check config path in `.claude/autocode.yml` under `code_review.checklist` (optional config; most projects will not have this key set)
2. Check for `.claude/code-review-checklist.md` in the project
3. Fall back to shipped default: `$AUTOCODE_PLUGIN_ROOT/skills/code-review/code-review-checklist.md`

Read the checklist file.

Also check `.claude/autocode.yml` for two model keys:
- `code_review.model` (e.g. `code_review: { model: opus }`): the M4 explicit override from the plugin's `docs/MODEL_SELECTION.md`. If set, it replaces the R-table result computed in Step 3 (capped by `models.ceiling`). If unset, the R table governs.
- `models.ceiling` (`opus` default; only `opus`/`fable` valid, anything else means `opus` plus a one-line warning): caps the resolution.

## Step 3: Select the Review Model

Compute `REVIEW_MODEL` for the reviewer spawns. The canonical table lives in the plugin's `docs/MODEL_SELECTION.md` (R table); it is restated here because this skill applies it.

Gather the evidence:

1. **Execution record** — check for C5 escalations or failures during this change's execution:
   ```bash
   bash $AUTOCODE_PLUGIN_ROOT/scripts/read-history.sh --model-stats
   ```
   In spec mode, look for `model-selection` events with rule `C5` and any logged failures for this spec. **Treat an unavailable or empty record as not-clean** — R4 requires positive evidence of a clean run.
2. **Diff size and spread** — from the Step 1 diff stat: total changed lines and how many top-level modules/directories are touched.
3. **Sensitive paths** — does the diff touch auth, input handling/validation, SQL/queries, crypto, or secrets/credentials (by path or by content)?

Apply the R table, first match wins:

| # | Condition | Model |
|---|---|---|
| R1 | Any task escalated via C5 or failed during execution | opus |
| R2 | Diff touches security-sensitive paths (auth, input handling, SQL, crypto, secrets) | opus |
| R3 | Diff over ~300 lines or spanning 3+ modules | opus |
| R4 | Small diff, no sensitive paths, clean execution record | sonnet |

If `code_review.model` is set (Step 2), it replaces the table result (M4). Either way, cap the final resolution at `models.ceiling`.

Announce the decision in one line (e.g. `Reviewing on opus via R2: diff touches auth paths`) and log it:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh model-selection reviewer ok '{"rule":"R2","tier":"opus","spec":"{IDENTIFIER or none}"}'
```

Pass `REVIEW_MODEL` as the `model` argument on **every** `Task(autocode:reviewer, ...)` call below — the reviewer's `opus` frontmatter is only the fail-up safe default.

## Step 4: Determine Output Path

- **Spec mode** (identifier provided): `{SPEC_DIR}/artifacts/CODE_REVIEW.md`
- **Standalone mode** (no identifier): `.claude/CODE_REVIEW.md`

In spec mode, ensure the artifacts directory exists before the reviewer writes its report:

```bash
mkdir -p {SPEC_DIR}/artifacts
```

## Step 5: Load Previous Findings (re-review support)

If a report already exists at `OUTPUT_PATH`, read it and pass it to the reviewer(s) as `PREVIOUS_FINDINGS`. The reviewer then reports only new or still-unaddressed issues instead of duplicating the first run's findings. If no report exists, omit the tag.

## Step 6: Spawn Reviewer Agent(s)

Count the diff size from the diff stat. Choose the review architecture by threshold: **more than 10 changed files or more than 1000 changed lines** means a single pass would dilute attention across files, so split it.

### Small diff (at or under threshold): single pass

```
Task(autocode:reviewer, model={REVIEW_MODEL},
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
Task(autocode:reviewer, model={REVIEW_MODEL},
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
Task(autocode:reviewer, model={REVIEW_MODEL},
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

4. Delete the intermediate `{OUTPUT_PATH}.group-*.md` files after the merged report is written:

```bash
rm {OUTPUT_PATH}.group-*.md
```

(this expands to `rm .specs/<id>/artifacts/CODE_REVIEW.md.group-*.md` in spec mode or `rm .claude/CODE_REVIEW.md.group-*.md` in standalone mode — do not `rm` any other path).

## Step 7: Present Results

Read `OUTPUT_PATH` and display the review summary to the user with finding counts per severity level. Highlight any CRITICAL or HIGH findings, and the Cross-File Issues section when the review was split.
