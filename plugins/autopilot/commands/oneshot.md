---
description: Use when the user has a blueprint document and wants fully autonomous execution — decomposes the blueprint into ordered specs, runs each through the full pipeline (plan, tasks, TDD loop, review), and creates a feature branch. Supports --resume, --no-questions, --no-human, --dry-run.
allowed-tools: Bash, Read, Edit, Write, Task, Glob, Grep
argument-hint: <blueprint> [--no-questions] [--no-human] [--dry-run] [--resume]
model: opus
---

# Oneshot

Read a blueprint document, decompose it into ordered specs, and execute each through the full pipeline.

## Arguments

- `$ARGUMENTS` contains: `<blueprint> [--no-questions] [--no-human] [--dry-run] [--resume]`
- Parse the arguments to extract:
  - `BLUEPRINT_PATH`: Path to the blueprint document (required)
  - `--no-questions`: Skip the clarifying questions phase
  - `--no-human`: Skip human approval checkpoints between specs
  - `--dry-run`: Generate roadmap only, do not execute
  - `--resume`: Resume from last saved state

## Step 1: Initialize

### 1.1 Read Blueprint

```
Read(BLUEPRINT_PATH)
```

If the file doesn't exist, inform the user and exit.

### 1.2 Check for Resume

If `--resume` flag is set:

```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/oneshot-state.sh load
```

If a state file exists with incomplete specs, resume from the last incomplete spec. Skip decomposition and questions phases.

### 1.3 Create Feature Branch

If not resuming, create a feature branch for all oneshot work:

```bash
BRANCH_NAME="oneshot/$(basename $BLUEPRINT_PATH .md)"
git checkout -b $BRANCH_NAME
```

## Step 2: Decompose

Spawn the `oneshot-decomposer` agent to break the blueprint into ordered specs:

```
Task(
  subagent_type="autopilot:oneshot-decomposer",
  prompt="Decompose blueprint into specs

  BLUEPRINT_PATH={BLUEPRINT_PATH}
  BLUEPRINT_CONTENT={blueprint_content}

  Break this blueprint into ordered spec definitions with dependencies.
  Output structured spec list."
)
```

Parse the decomposer output to extract:
- Spec list with IDs, titles, descriptions, and acceptance criteria
- Dependency graph (which specs depend on which)
- Execution order (topological sort of dependency graph)

## Step 3: Questions (unless --no-questions)

If `--no-questions` is NOT set, spawn the `oneshot-questioner` agent:

```
Task(
  subagent_type="autopilot:oneshot-questioner",
  prompt="Generate clarifying questions

  BLUEPRINT_PATH={BLUEPRINT_PATH}
  BLUEPRINT_CONTENT={blueprint_content}
  SPEC_LIST={decomposed_spec_list}

  Identify ambiguities, priorities, constraints, and scope questions.
  Output structured question list."
)
```

Present questions to the user and await answers. After receiving answers, refine the spec list if needed based on the responses.

## Step 4: Generate Roadmap

Generate `ROADMAP.md` in the current directory with the execution plan:

```markdown
# Oneshot Roadmap

**Blueprint:** {blueprint_path}
**Date:** {date}
**Specs:** {total_count}

## Execution Order

| # | Spec ID | Title | Dependencies | Status |
|---|---------|-------|--------------|--------|
| 1 | {id} | {title} | - | pending |
| 2 | {id} | {title} | {dep_ids} | pending |
...

## Spec Details

### {spec_id}: {title}

**Description:** {description}
**Dependencies:** {deps or "none"}
**Acceptance Criteria:**
- {criterion_1}
- {criterion_2}
```

If `--dry-run` is set, present the roadmap and exit.

## Step 5: Save Initial State

```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/oneshot-state.sh init '{specs_json}'
```

Where `specs_json` is a JSON array of `{"id": "...", "title": "...", "status": "pending"}` objects.

## Step 6: Execute Specs

For each spec in execution order:

### 6.1: Check Dependencies

Verify all dependency specs have status `completed` in the state file:

```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/oneshot-state.sh check-deps {spec_id}
```

If dependencies are not met, skip this spec and log a warning.

### 6.2: Run Full Pipeline

Execute each pipeline step by running the scripts and spawning agents directly (same mechanism as the individual commands):

**a) New Spec**
```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/new-spec.sh {spec_id}
```

Then write the SPEC.md with the decomposed spec content:
```
Write(".claude/specs/{spec_id}/SPEC.md", spec_content)
```

**b) Create Plan**
```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/create-plan.sh {spec_id}
```

Then spawn the plan-builder agent:
```
Task(
  subagent_type="autopilot:plan-builder",
  prompt="Create implementation plan
  SPEC_DIR=.claude/specs/{spec_id}
  ..."
)
```

**c) Create Tasks**
```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/create-tasks.sh {spec_id}
```

Then spawn the task-builder agent:
```
Task(
  subagent_type="autopilot:task-builder",
  prompt="Convert plan to tasks
  SPEC_DIR=.claude/specs/{spec_id}
  ..."
)
```

**d) Execute**

Run the validation and setup scripts, then execute the task loop (same as execute.md):
```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/validate-autopilot.sh {spec_id}
bash $AUTOPILOT_PLUGIN_ROOT/scripts/setup-artifacts.sh .claude/specs/{spec_id}
bash $AUTOPILOT_PLUGIN_ROOT/scripts/build-task-queue.sh .claude/specs/{spec_id}
```

For each task in the queue, spawn a fresh `autopilot-task-runner`:
```
Task(
  subagent_type="autopilot:autopilot-task-runner",
  prompt="Execute task
  SPEC_DIR=.claude/specs/{spec_id}
  TASK=[{task_id}] {description}
  TASK_ID={task_id}
  ..."
)
```

**e) Review**
```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/review.sh {spec_id}
bash $AUTOPILOT_PLUGIN_ROOT/scripts/generate-report.sh .claude/specs/{spec_id}
```

**f) Commit**

Stage and commit changes for this spec.

### 6.3: Update State

```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/oneshot-state.sh update {spec_id} completed
```

### 6.4: Human Checkpoint (unless --no-human)

If `--no-human` is NOT set, present the spec results and ask:

"Spec **{spec_id}** completed. Review the changes and decide:"
1. **Continue** — Proceed to next spec
2. **Pause** — Stop here, resume later with `--resume`
3. **Abort** — Stop the oneshot entirely

If the user chooses "Pause" or "Abort", save state and exit.

### 6.5: Handle Failure

If any pipeline step fails:
1. Update state: `bash $AUTOPILOT_PLUGIN_ROOT/scripts/oneshot-state.sh update {spec_id} failed`
2. Log the failure
3. Present the failure to the user
4. If `--no-human`: continue to next spec (skip dependents)
5. If human mode: ask whether to retry, skip, or abort

## Step 7: Generate Summary

After all specs are processed, generate `ONESHOT_SUMMARY.md`:

```markdown
# Oneshot Summary

**Blueprint:** {blueprint_path}
**Date:** {date}
**Branch:** {branch_name}

## Results

| Spec ID | Title | Status | Tasks | Duration |
|---------|-------|--------|-------|----------|
| {id} | {title} | {status} | {task_count} | {duration} |
...

## Statistics
- Total specs: {total}
- Completed: {completed}
- Failed: {failed}
- Skipped: {skipped}

## Next Steps
1. Review all changes on branch `{branch_name}`
2. Run `/autopilot:sync-pr` to create a pull request
3. Address any failed specs manually
```

Present the summary to the user.

## Key Design Decisions

- The command itself owns the orchestration loop (like execute.md owns the task loop)
- Each pipeline step invokes existing scripts and agents directly — no subprocess nesting
- Human checkpoints between specs are the default safety mechanism
- State file enables resumability after failure or interruption
- Each spec gets its own directory under `.claude/specs/`
