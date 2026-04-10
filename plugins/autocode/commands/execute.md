---
description: Use when the user wants to run the autonomous TDD loop (Write Tests / Red / Code / Green / Analysis / Refactor) for a spec that already has SPEC.md, PLAN.md, and TODO.md. Optionally filter by task ID (T<n>) or phase (P<n>).
allowed-tools: Bash, Read, Edit, Write, Task, Glob, Grep
argument-hint: <identifier> [T<n>|P<n>]
model: sonnet
---

# Autocode

Execute the Test -> Code -> Refactor loop autonomously until all tasks are complete.

## Arguments

- `$ARGUMENTS` contains: `<identifier> [filter]`
- Parse the arguments to extract:
  - `IDENTIFIER`: First argument (required) - spec identifier (e.g., `auth-refactor`)
  - `FILTER`: Second argument (optional) - task ID (e.g., `T3`) or phase ID (e.g., `P1`)

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:
- `IDENTIFIER`: The spec identifier (first argument, e.g., `auth-refactor`)
- `FILTER`: Optional task/phase filter (second argument, e.g., `T3` or `P1`)
- Construct `SPEC_DIR` as `.claude/specs/$IDENTIFIER`

## Step 2: Validate Prerequisites

Run the validation script with both arguments:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/validate-autocode.sh $ARGUMENTS
```

This validates:
- Spec directory exists
- SPEC.md, PLAN.md, and TODO.md are present
- TODO.md has uncompleted tasks
- If filter provided, validates it matches a task/phase in TODO.md

## Step 3: Setup

Log execution start and check for relevant history from previous runs:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh "command" "execute" "started" "$IDENTIFIER"
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
bash $AUTOCODE_PLUGIN_ROOT/scripts/build-task-queue.sh {SPEC_DIR} {FILTER}
```

Parse the output:
- Each `TASK:<task_id>:<phase>:<description>` line is one queued task
- The `TOTAL:<count>` line gives the total number of tasks
- If `TOTAL:0`, output "No uncompleted tasks found for the given filter." and exit

Build an ordered queue from the `TASK:` lines.

## Step 4: Task Loop

For each task in the queue:

### 4.1: Spawn Task Runner

Spawn a fresh `task-runner` agent for each task. Each runner gets its own clean context — it loads SPEC.md, PLAN.md, TODO.md, and handoff context independently.

```
Task(
  subagent_type="autocode:task-runner",
  prompt="Execute task

  SPEC_DIR={SPEC_DIR}
  TASK=[{task_id}] {description}
  TASK_ID={task_id}

  Run full write-tests -> red -> code -> green -> analyze -> refactor loop for this task.
  Output structured completion status when done."
)
```

### 4.2: Parse Result

Inspect the task-runner result for status tags:
- `<task-completed task="{task_id}" status="completed" type="{commit_type}" />` — task succeeded (type is the conventional commit type chosen by the task-runner)
- `<task-completed task="{task_id}" status="failed" reason="{reason}" />` — task failed

Also check for the artifact generation tag:
- `<artifacts-generated count="N" />` — indicates N artifacts were written/filled by the task-runner's Step 3

If the task succeeded (`status="completed"`) but the `<artifacts-generated>` tag is missing or `count="0"`, log a warning:
```
⚠ Warning: Task {task_id} completed but no artifacts were generated. Check task-runner output.
```

This is an observability signal, not a hard gate — do not fail the task or spawn a fallback agent. The task-runner is opus and should reliably execute artifact generation as a numbered step.

### 4.3: Handle Failure

If the task failed:
1. Output failure message:
   ```markdown
   ## Autocode Stopped

   **Reason:** Task {task_id} failed
   **Details:** {reason}

   ### Current State
   - Task: {task_id} - {description}
   - Progress: {completed}/{total} tasks complete

   ### To Resume
   Address the issue and run:
   ```
   /autocode:execute {IDENTIFIER}
   ```
   ```
2. Exit the loop

### 4.4: Continue

Move to the next task in the queue.

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

### Next Steps
1. Review artifacts in `{SPEC_DIR}/artifacts/`
2. Run `/autocode:review {IDENTIFIER}` to generate a review summary
3. Run `/autocode:commit` to commit changes
```

## Key Principles

- **Minimal context per iteration** — The execute command never reads SPEC.md, PLAN.md, or config files. It only reads script output and task-runner status tags. This keeps per-iteration context growth minimal.
- **Fresh context per task** — Each task-runner is a fresh agent with its own clean context window, preventing context accumulation across tasks.
- **Hooks still fire** — Hooks trigger on Task tool usage, so handoff generation and context checks all work as before.

## Notes

- The loop continues automatically until all tasks complete or an exit condition is triggered
- All code changes generate justification artifacts for audit trail
- Human intervention is requested when the agent gets stuck
