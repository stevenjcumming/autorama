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
- `MODEL_OVERRIDE`: second argument (optional) — `opus`, `sonnet`, `haiku`, or `fable`. This is the M4 explicit override from the plugin's `docs/MODEL_SELECTION.md`: when given, it replaces the decision-table results and is passed as an explicit override to every stage below (planning, and generation work during execution). When absent, the P table picks the planning tier and the C table picks per-task coding tiers — there is no issue-metadata heuristic anymore. Reserve `fable` for an issue you already know is unusually hard; the tables never pick it on their own, and it is still capped by `models.ceiling`.

If `ISSUE_URL` is missing, ask the user for it and stop.

## Step 1: Fetch the Issue

```bash
gh issue view {ISSUE_URL} --json number,title,body,url,labels,comments,author
```

If this fails (bad URL, no `gh` auth, issue not found), surface the error and stop.

From the JSON, capture:
- `ISSUE_NUMBER`, `ISSUE_TITLE`, `ISSUE_BODY`, `ISSUE_URL` (canonical), `ISSUE_LABELS` (names), `ISSUE_COMMENTS` (body + author per comment)

## Step 2: Create the Spec

Derive `IDENTIFIER` as `issue-{ISSUE_NUMBER}-{slug}`, where `{slug}` is the issue title lowercased, non-alphanumerics collapsed to single hyphens, trimmed, and truncated to keep the whole identifier reasonably short (~50 chars).

```
Skill(skill: "autocode:new-spec", args: "{IDENTIFIER}")
```

If the skill reports the spec already exists, tell the user and stop — do not overwrite an in-progress spec.

## Step 3: Fill REQUIREMENT.md and SPEC.md

Unlike the manual flow, there is no human to paste requirements in, so write real content directly:

1. Read `.specs/{IDENTIFIER}/REQUIREMENT.md`. Paste the raw issue content — title, full body, and a transcript of the comments (author + body per comment, in order) — verbatim as the main requirements content (below the header comment, where a human would normally paste requirements). Leave this copy-paste; do not summarize it. Then fill the `## Source` section with just the issue URL, the one piece of content that section is meant to hold — not a copy of the body/comments.
2. Read `.specs/{IDENTIFIER}/SPEC.md` and fill in Overview, Summary, Success Metrics, Acceptance Criteria, Assumptions & Constraints, Dependencies, Out of Scope, and Open Questions, synthesized from the issue and comments. This must be real content, not template boilerplate — `create-plan.sh` in the next step validates for exactly that and will refuse to proceed otherwise.

## Step 4: Plan

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/create-plan/scripts/create-plan.sh {IDENTIFIER}
```

Select the planning model exactly as the create-plan skill does (its Step 2 restates the canonical P table from the plugin's `docs/MODEL_SELECTION.md`):

- Read `models.ceiling` from `.claude/autocode.yml` as `CEILING` (`opus` default; only `opus`/`fable` valid, anything else means `opus` plus a one-line warning).
- If `MODEL_OVERRIDE` was given, `PLANNING_MODEL={MODEL_OVERRIDE}` capped by `CEILING` (M4).
- Otherwise apply the P table against SPEC.md: P1 (docs/chore/config-only AND single module AND zero open questions, all positively evidenced) → sonnet; P2 (auth/schema/concurrency/migrations, unresolved open questions, or 3+ modules) → `CEILING`; P3 (everything else) → opus.
- Announce the decision in one line and log it: `bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh model-selection plan-builder ok '{"rule":"P3","tier":"opus","spec":"{IDENTIFIER}"}'` (use the rule that actually fired, or `M4` for an override).

Then spawn the plan builder with the computed tier (its `opus` frontmatter is only the fail-up safe default):

```
Task(
  subagent_type="autocode:plan-builder",
  model="{PLANNING_MODEL}",
  prompt="SPEC_DIR=.specs/{IDENTIFIER}"
)
```

If the agent reports gaps or unresolved risks that look blocking (not just noted for awareness), stop and report them — do not push an unreviewed plan into implementation.

## Step 5: Tasks

```
Skill(skill: "autocode:create-tasks", args: "{IDENTIFIER}")
```

This is pure text conversion from PLAN.md to TODO.md — no model choice applies here, but the conversion carries each task's `(easy|standard|hard)` difficulty rating from PLAN.md into TODO.md, which the C table consumes during execution. (In this unattended flow the usual human ratings checkpoint is skipped; the ratings run as the plan-builder wrote them.)

## Step 6: Execute via Workflow

Build the task queue, then hand the whole implementation loop to a single background Workflow run instead of spawning task-runners one by one from this conversation — that keeps this session's context from growing by one full task transcript per task.

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/setup-artifacts.sh .specs/{IDENTIFIER}
bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/build-task-queue.sh .specs/{IDENTIFIER}
```

Parse the `TASK:<id>:<phase>:<rating>:<description>` lines into a JSON array of `{id, phase, rating, description}` (split on the first 4 colons only, per the script's own doc comment; `rating` is `easy`, `standard`, or `hard`). If `TOTAL:0`, report "No tasks to execute" and skip to Step 8 (there is nothing to review or commit).

The Workflow call spawns a fresh background subagent that is not guaranteed to inherit this session's `$AUTOCODE_PLUGIN_ROOT` — resolve it now so it can be passed through explicitly:

```bash
echo "$AUTOCODE_PLUGIN_ROOT"
```

Run the workflow script shipped at `$AUTOCODE_PLUGIN_ROOT/skills/ticket/scripts/ticket-execute.workflow.js`, passing that resolved path as `pluginRoot`:

```
Workflow(
  scriptPath: "$AUTOCODE_PLUGIN_ROOT/skills/ticket/scripts/ticket-execute.workflow.js",
  args: { specDir: ".specs/{IDENTIFIER}", ceiling: "{CEILING}", modelOverride: "{MODEL_OVERRIDE or null}", tasks: {parsed task array}, pluginRoot: "{resolved AUTOCODE_PLUGIN_ROOT}" }
)
```

The workflow spawns each task-runner with no `model` parameter (its sonnet frontmatter governs) and passes `RATING`, `CEILING`, and — only when given — `MODEL={MODEL_OVERRIDE}` in the prompt, so the task-runner resolves each sub-agent spawn via the C table.

This call runs in the background; you'll be notified when it completes. Do not poll for it — continue only once the result arrives.

## Step 7: Report Task Results

Summarize the Workflow's `results` array: completed / failed / skipped counts, and for each failure its category and reason. If anything with `category="setup"` failed, stop here and report — an environment problem needs a human before continuing. Otherwise proceed even if some tasks failed or were skipped; partial progress is still worth reviewing and shipping.

## Step 8: Review — end here

`ticket` stops at the review checkpoint. It never commits and never opens a PR.

```
Skill(skill: "autocode:review", args: "{IDENTIFIER}")
```

This generates `SUMMARY.md` and presents the changes, artifacts, high-risk items, and review hints, and — per its own Step 4 — records the user's decision (approve / request changes / reject) into `REVIEW.md` for the audit trail. Follow its instructions as-is. Once the decision is recorded, `ticket`'s job is done; do not chain into `autocode:commit` or `autocode:sync-pr` regardless of the decision — those are separate commands the user runs themselves when ready.

## Step 9: Final Report

Present:
- Spec: `.specs/{IDENTIFIER}`
- Model decisions: the P-table rule and tier used for planning, the per-task ratings that drove the C table during execution, and whether an M4 override (`MODEL_OVERRIDE`) or a non-default `models.ceiling` was in play
- Task results (completed/failed/skipped, with reasons)
- The review summary (high-risk items and review hints from `SUMMARY.md`, called out clearly) and the recorded decision
- Next steps: if approved, `/autocode:commit` then `/autocode:sync-pr` (mention including `Closes #{ISSUE_NUMBER}` in the PR description); if not, `/autocode:execute {IDENTIFIER}` or a manual fix, then re-review
