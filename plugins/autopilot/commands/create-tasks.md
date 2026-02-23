---
allowed-tools: Bash, Read, Task
description: Convert implementation plan into phased TODO checklist
argument-hint: <identifier>
---

# Create Tasks

Convert an implementation plan into an actionable TODO checklist.

**This command marks the end of the planning phase. Do NOT start implementation.**

## Step 1: Create TODO.md Template

Run the create-tasks script:

```bash
bash $AUTOPILOT_PLUGIN_ROOT/scripts/create-tasks.sh $ARGUMENTS
```

## Step 2: Build the Task List

Spawn the task-builder agent:

```
Task(
  subagent_type="autopilot:task-builder",
  prompt="SPEC_DIR=.claude/specs/$ARGUMENTS"
)
```

The task-builder agent will:
1. Read PLAN.md to extract phases and changes
2. Convert each change into an actionable task
3. Order tasks by dependency within each phase
4. Write the complete task list to TODO.md
5. Return a summary with task counts

## Step 3: Present Results

After the agent completes, present:

```
Planning complete. Generated TODO.md with N tasks across M phases.

Files:
- .claude/specs/<identifier>/PLAN.md - Implementation plan
- .claude/specs/<identifier>/TODO.md - Task checklist

When you're ready to implement, start with:
- [ ] <First task>
```

## Step 4: STOP

**Do NOT begin implementation.** The user must review and approve the task list first.

## Notes

- If PLAN.md is empty or has only template content, tell the user to complete the plan first
- Each task should be completable in one focused session
- Tasks are ordered by dependency (models -> services -> controllers -> tests)
