---
name: ticket
allowed-tools: Bash(gh issue view:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/new-spec/scripts/new-spec.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/create-plan/scripts/create-plan.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/create-tasks/scripts/create-tasks.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/validate-autocode.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/build-task-queue.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/review/scripts/review.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/setup-artifacts.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh:*), Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git fetch:*), Read, Edit, Write, Task, Workflow, Skill
description: Use when the user gives a GitHub issue URL and wants it turned into a reviewable spec + implementation with minimal manual steps. Fetches the issue and comments, scaffolds and fills a spec, plans it, breaks it into tasks, runs the implementation loop as a background Workflow, then generates a review summary and stops — commit and PR are always separate, manual commands.
argument-hint: <github-issue-url> [model-override]
model: opus
disable-model-invocation: true
user-invocable: true
---

# Ticket

Take a GitHub issue through the full Autocode pipeline — spec, plan, tasks, implementation — unattended, then **end at the review checkpoint**. This command is meant to be invoked deliberately by a user who wants an issue implemented without babysitting each stage; it is not triggered automatically by anything else, and it never commits or opens a PR itself — `/autocode:commit` and `/autocode:sync-pr` are always separate, manual next steps once the user is happy with the review.

## Arguments

- `$ARGUMENTS` contains: `<github-issue-url> [model-override]`
- `ISSUE_URL`: first argument (required)
- `MODEL_OVERRIDE`: second argument (optional) — `opus`, `sonnet`, or `haiku`. When given, skip the model-selection heuristic in Step 2 and use this for every agent spawned below.

If `ISSUE_URL` is missing, ask the user for it and stop.

## Step 1: Fetch the Issue

```bash
gh issue view {ISSUE_URL} --json number,title,body,url,labels,comments,author
```

If this fails (bad URL, no `gh` auth, issue not found), surface the error and stop.

From the JSON, capture:
- `ISSUE_NUMBER`, `ISSUE_TITLE`, `ISSUE_BODY`, `ISSUE_URL` (canonical), `ISSUE_LABELS` (names), `ISSUE_COMMENTS` (body + author per comment)

## Step 2: Select a Model

Skip this step if `MODEL_OVERRIDE` was given — use that for everything below instead.

Otherwise pick `MODEL` using this heuristic, most specific rule first:

1. Labels match `good first issue`, `docs`, `documentation`, `chore`, or `typo` → **sonnet**
2. A `bug` label, body under ~500 characters, and no comments (small, well-scoped fix) → **sonnet**
3. Labels match `epic`, `enhancement`, `feature`, `architecture`, or `refactor`, OR body over ~1500 characters, OR more than 3 comments (real design discussion happened) → **opus**
4. Otherwise → **sonnet** (default; cheaper, and most issues are routine)

State which tier was chosen and why in one line before continuing.

## Step 3: Create the Spec

Derive `IDENTIFIER` as `issue-{ISSUE_NUMBER}-{slug}`, where `{slug}` is the issue title lowercased, non-alphanumerics collapsed to single hyphens, trimmed, and truncated to keep the whole identifier reasonably short (~50 chars).

```
Skill(skill: "autocode:new-spec", args: "{IDENTIFIER}")
```

If the skill reports the spec already exists, tell the user and stop — do not overwrite an in-progress spec.

## Step 4: Fill REQUIREMENT.md and SPEC.md

Unlike the manual flow, there is no human to paste requirements in, so write real content directly:

1. Read `.specs/{IDENTIFIER}/REQUIREMENT.md` and replace the `## Source` section with the issue URL, title, full body, and a transcript of the comments (author + body per comment, in order).
2. Read `.specs/{IDENTIFIER}/SPEC.md` and fill in Overview, Summary, Success Metrics, Acceptance Criteria, Assumptions & Constraints, Dependencies, Out of Scope, and Open Questions, synthesized from the issue and comments. This must be real content, not template boilerplate — `create-plan.sh` in the next step validates for exactly that and will refuse to proceed otherwise.

## Step 5: Plan

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/create-plan/scripts/create-plan.sh {IDENTIFIER}
```

Then spawn the plan builder with the model chosen in Step 2, overriding its `opus` frontmatter default when `MODEL` is `sonnet`:

```
Task(
  subagent_type="autocode:plan-builder",
  model="{MODEL}",
  prompt="SPEC_DIR=.specs/{IDENTIFIER}"
)
```

If the agent reports gaps or unresolved risks that look blocking (not just noted for awareness), stop and report them — do not push an unreviewed plan into implementation.

## Step 6: Tasks

```
Skill(skill: "autocode:create-tasks", args: "{IDENTIFIER}")
```

This is pure text conversion from PLAN.md to TODO.md — no model choice applies here.

## Step 7: Execute via Workflow

Build the task queue, then hand the whole implementation loop to a single background Workflow run instead of spawning task-runners one by one from this conversation — that keeps this session's context from growing by one full task transcript per task.

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/setup-artifacts.sh .specs/{IDENTIFIER}
bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/build-task-queue.sh .specs/{IDENTIFIER}
```

Parse the `TASK:<id>:<phase>:<description>` lines into a JSON array of `{id, phase, description}` (split on the first 3 colons only, per the script's own doc comment). If `TOTAL:0`, report "No tasks to execute" and skip to Step 9 (there is nothing to review or commit).

The Workflow call spawns a fresh background subagent that is not guaranteed to inherit this session's `$AUTOCODE_PLUGIN_ROOT` — resolve it now so it can be passed through explicitly:

```bash
echo "$AUTOCODE_PLUGIN_ROOT"
```

Run the workflow script shipped at `$AUTOCODE_PLUGIN_ROOT/skills/ticket/scripts/ticket-execute.workflow.js`, passing that resolved path as `pluginRoot`:

```
Workflow(
  scriptPath: "$AUTOCODE_PLUGIN_ROOT/skills/ticket/scripts/ticket-execute.workflow.js",
  args: { specDir: ".specs/{IDENTIFIER}", model: "{MODEL}", tasks: {parsed task array}, pluginRoot: "{resolved AUTOCODE_PLUGIN_ROOT}" }
)
```

This call runs in the background; you'll be notified when it completes. Do not poll for it — continue only once the result arrives.

## Step 8: Report Task Results

Summarize the Workflow's `results` array: completed / failed / skipped counts, and for each failure its category and reason. If anything with `category="setup"` failed, stop here and report — an environment problem needs a human before continuing. Otherwise proceed even if some tasks failed or were skipped; partial progress is still worth reviewing and shipping.

## Step 9: Review — end here

`ticket` stops at the review checkpoint. It never commits and never opens a PR.

```
Skill(skill: "autocode:review", args: "{IDENTIFIER}")
```

This generates `SUMMARY.md` and presents the changes, artifacts, high-risk items, and review hints, and — per its own Step 4 — records the user's decision (approve / request changes / reject) into `REVIEW.md` for the audit trail. Follow its instructions as-is. Once the decision is recorded, `ticket`'s job is done; do not chain into `autocode:commit` or `autocode:sync-pr` regardless of the decision — those are separate commands the user runs themselves when ready.

## Step 10: Final Report

Present:
- Spec: `.specs/{IDENTIFIER}`
- Model tier used and why
- Task results (completed/failed/skipped, with reasons)
- The review summary (high-risk items and review hints from `SUMMARY.md`, called out clearly) and the recorded decision
- Next steps: if approved, `/autocode:commit` then `/autocode:sync-pr` (mention including `Closes #{ISSUE_NUMBER}` in the PR description); if not, `/autocode:execute {IDENTIFIER}` or a manual fix, then re-review
