---
name: execute
description: Use when the user wants to run the autonomous TDD loop (Write Tests / Red / Code / Green / Analysis / Refactor) for a spec that already has SPEC.md, PLAN.md, and TODO.md. Optionally filter by task ID (T<n>) or phase (P<n>).
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/validate-autocode.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/read-history.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/setup-artifacts.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/build-task-queue.sh:*), Read, Task
argument-hint: <identifier> [T<n>|P<n>] [model]
model: sonnet # orchestration: the loop only parses script output and status tags, reads config, and spawns task-runners; sonnet keeps the long loop cheap; see docs/MODEL_SELECTION.md
---

# Autocode

Execute the Test -> Code -> Refactor loop autonomously until all tasks are complete.

## Arguments

- `$ARGUMENTS` contains: `<identifier> [T<n>|P<n>] [model]`
- Parse the arguments to extract:
  - `IDENTIFIER`: First argument (required) - spec identifier (e.g., `auth-refactor`)
  - `FILTER`: Optional task ID (e.g., `T3`) or phase ID (e.g., `P1`)
  - `MODEL`: Optional explicit model override - `opus`, `sonnet`, `haiku`, or `fable`. This is the M4 override from the plugin's `docs/MODEL_SELECTION.md`: it replaces the C-table result for **generation** work only (repairs still run the cheap repair rules), not a uniform cascade over every agent. Without it, each task's `(easy|standard|hard)` rating in TODO.md picks the coder tier. Reserve `fable` for a task you already expect to be unusually hard; it's the most expensive tier and is still capped by `models.ceiling`.

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:
- `IDENTIFIER`: The spec identifier (first argument, e.g., `auth-refactor`)
- Among the remaining arguments (order-independent, `FILTER` and `MODEL` are each optional and may appear in either order):
  - An argument matching `^[TP]\d+$` (e.g. `T3`, `P1`) is `FILTER`
  - An argument matching `opus`, `sonnet`, `haiku`, or `fable` is `MODEL`
  - If `MODEL` is not given, leave it unset — the task-runner's C table resolves tiers from each task's rating
- Construct `SPEC_DIR` as `.specs/{IDENTIFIER}`

Also read `.claude/autocode.yml` (if present) and capture `models.ceiling` as `CEILING`: `opus` when the file or key is absent; `opus` plus a one-line warning when the value is anything other than `opus` or `fable`.

## Step 2: Validate Prerequisites

Run the validation script with the parsed arguments from Step 1 (validate-autocode.sh takes `<identifier> [filter]`, not a `SPEC_DIR` path):

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/validate-autocode.sh {IDENTIFIER} {FILTER}
```

This validates:
- Spec directory exists
- SPEC.md, PLAN.md, and TODO.md are present
- TODO.md has uncompleted tasks
- If filter provided, validates it matches a task/phase in TODO.md

## Step 3: Setup

Log execution start and check for relevant history from previous runs:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh "command" "execute" "started" "{IDENTIFIER}"
```

Optionally, check for past failures on this spec to inform the run:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/read-history.sh --failures --project "$(basename $(pwd))" --recent 5
```

If there are recent failures for this spec's agents, note them as context for the task loop (e.g., if the tester agent frequently fails with syntax errors, the task-runner should be aware).

Run setup and build the task queue:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/setup-artifacts.sh {SPEC_DIR}
```

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/execute/scripts/build-task-queue.sh {SPEC_DIR} {FILTER}
```

Parse the output:
- Each `TASK:<task_id>:<phase>:<rating>:<description>` line is one queued task. The line has exactly 4 leading colons; `<description>` is everything after the fourth colon, taken verbatim (it may itself contain colons - split on the first 4 only, not on every colon in the line). `<rating>` is the task's difficulty rating (`easy`, `standard`, or `hard`; the script already normalized missing/unrecognized annotations to `standard`).
- The `TOTAL:<count>` line gives the total number of tasks
- If `TOTAL:0`, output "No uncompleted tasks found for the given filter." and exit

Build an ordered queue from the `TASK:` lines, keeping each task's rating.

## Step 4: Task Loop

For each task in the queue:

### 4.1: Spawn Task Runner

Spawn a fresh `task-runner` agent for each task. Each runner gets its own clean context — it loads SPEC.md, PLAN.md, TODO.md, and handoff context independently. **Never pass a `model` parameter on this Task call** — the task-runner's sonnet frontmatter governs the orchestration itself. Instead pass the task's `RATING` (from the queue) and `CEILING` (from Step 1) in the prompt; the task-runner resolves each sub-agent spawn from its C table (see the plugin's `docs/MODEL_SELECTION.md`). If `MODEL` was parsed in Step 1, forward it in the prompt as `MODEL=` — the M4 override for generation spawns.

```
Task(
  subagent_type="autocode:task-runner",
  prompt="Execute task

  SPEC_DIR={SPEC_DIR}
  TASK=[{task_id}] {description}
  TASK_ID={task_id}
  RATING={rating}
  CEILING={CEILING}
  MODEL={MODEL}  # omit this line entirely when MODEL was not given

  Run full write-tests -> red -> code -> green -> analyze -> refactor loop for this task.
  Output structured completion status when done."
)
```

### 4.2: Parse Result

Inspect the task-runner result for the structured status tag defined in `$AUTOCODE_PLUGIN_ROOT/references/failure-categories.md`:
- `<task-completed task="{task_id}" status="completed" type="{commit_type}" />` — task succeeded (type is the conventional commit type chosen by the task-runner)
- `<task-completed task="{task_id}" status="failed" category="{category}" retryable="{true|false}" reason="{reason}" />` — task failed; the body above the tag carries partial results and suggested alternatives

**Missing or unparseable tag:** if the result contains no `<task-completed>` tag, or the tag cannot be parsed (agent died, context exhausted, malformed output), treat the task as `status="failed" category="unknown"`. Never treat a missing tag as success. Include the raw last ~20 lines of the runner output in the failure report so the cause is visible.

Also check for the artifact generation tag:
- `<artifacts-generated count="N" />` — indicates N artifacts were written/filled by the task-runner's Step 6

If the task succeeded (`status="completed"`) but the `<artifacts-generated>` tag is missing or `count="0"`, log a warning:
```
⚠ Warning: Task {task_id} completed but no artifacts were generated. Check task-runner output.
```

This is an observability signal, not a hard gate — do not fail the task or spawn a fallback agent. Artifact generation is a numbered step in the task-runner's process and should execute reliably.

### 4.3: Handle Failure

Do not exit the loop on every failure. Assess the failure category from the tag and apply this policy:

**`category="setup"` — stop the loop.** An environment problem (missing dependency, broken config) will hit every subsequent task identically. Output:

```markdown
## Autocode Stopped (setup failure)

**Reason:** Task {task_id} failed
**Category:** setup (environment problem — every remaining task would hit the same wall)
**Details:** {reason}

### Preserved Progress
Completed tasks (work is on disk, nothing is rolled back):
- [x] [{task_id}] {description}
- ...

### Failure Details
{partial results and suggested alternatives from the task-runner's failure body}

### To Resume
Fix the environment issue, then run:
/autocode:execute {IDENTIFIER}
```

**Any other category (task-specific failure) — skip dependents, continue independents:**
1. Record the task as failed (keep the reason, category, and the runner's partial results for the final summary).
2. Determine which queued tasks to skip:
   - Tasks in the **same phase** after the failed task (within a phase, ordering is dependency order, so later tasks likely build on the failed one).
   - Tasks in later phases that **explicitly depend on the failed task** (their description references the failed task's files or output).
3. Mark those tasks as skipped (do not spawn runners for them) and continue the loop with the remaining independent tasks.

### 4.4: Continue

Move to the next non-skipped task in the queue.

## Step 5: Present Results

Log execution completion:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh "command" "execute" "completed" "{completed_count}/{total} tasks"
```

After all tasks in the queue have been processed, present a final summary:

```markdown
## Autocode Complete

**Spec:** {SPEC_DIR}

### Summary
- Total tasks: {total}
- Completed: {completed_count}
- Failed: {failed_count}
- Skipped (dependent on a failed task): {skipped_count}

### Completed Tasks (preserved progress)
- [x] [{task_id}] {description}
- ...

### Failed Tasks
- [ ] [{task_id}] {description} — category={category}, {reason}
  - Partial results: {from the runner's failure body}
  - Suggested alternatives: {from the runner's failure body}

### Skipped Tasks
- [ ] [{task_id}] {description} — skipped because {failed_task_id} failed

### Next Steps
1. Review artifacts in `{SPEC_DIR}/artifacts/`
2. Address failed tasks (see suggested alternatives), then re-run `/autocode:execute {IDENTIFIER}` to pick up failed and skipped tasks
3. Run `/autocode:review {IDENTIFIER}` to generate a review summary
4. Run `/autocode:commit` to commit changes
```

Omit the Failed/Skipped sections when every task completed.

## Key Principles

- **Minimal context per iteration** — The execute command never reads SPEC.md or PLAN.md. It reads `.claude/autocode.yml` once (for `models.ceiling`) and otherwise only script output and task-runner status tags. This keeps per-iteration context growth minimal.
- **Fresh context per task** — Each task-runner is a fresh agent with its own clean context window, preventing context accumulation across tasks.
- **Hooks still fire** — Hooks trigger on Task tool usage, so handoff generation and context checks all work as before.

## Notes

- The loop continues automatically until all tasks complete or an exit condition is triggered
- All code changes generate justification artifacts for audit trail
- Human intervention is requested when the agent gets stuck
