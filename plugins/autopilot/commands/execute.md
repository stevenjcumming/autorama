---
description: Execute Test -> Code -> Refactor loop for a spec
allowed-tools: Bash, Read, Edit, Write, Task, Glob, Grep
argument-hint: <identifier> [T<n>|P<n>]
model: sonnet
---

# Autopilot

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
bash $CLAUDE_PLUGIN_ROOT/scripts/validate-autopilot.sh $ARGUMENTS
```

This validates:
- Spec directory exists
- SPEC.md, PLAN.md, and TODO.md are present
- TODO.md has uncompleted tasks
- If filter provided, validates it matches a task/phase in TODO.md

## Step 3: Start Autopilot Loop

Spawn the autopilot agent:

```
Task(
  subagent_type="autopilot",
  prompt="SPEC_DIR=.claude/specs/<identifier>
  FILTER=<filter or empty>"
)
```

The autopilot agent will:
1. Read TODO.md and select tasks based on FILTER:
   - No filter: All uncompleted tasks in order
   - `T3`: Only task T3
   - `P1`: All uncompleted tasks in phase P1
2. Execute the Test -> Code -> Refactor loop:
   - Spawn autopilot-tester to run tests
   - Spawn autopilot-coder to implement the task with artifacts
   - Spawn autopilot-refactorer to clean up code
3. Mark task complete in TODO.md
4. Repeat until filtered tasks done or exit condition met

## Step 4: Handle Exit Conditions

Monitor for exit conditions:

| Condition | Action |
|-----------|--------|
| All tasks completed | Present success summary |
| Test failure loop (category limit exceeded) | Pause and ask for human input |
| Refactor stuck (oscillation) | Accept current state and continue to next task |
| Spec gap discovered | Suggest returning to Spec stage |
| Critical error | Surface error and pause |

## Step 5: Present Results

After autopilot completes, present:

```
Autopilot completed for $ARGUMENTS

Summary:
- Tasks completed: N/M
- Artifacts generated: N

Files updated:
- TODO.md - Task statuses
- .claude/specs/$IDENTIFIER/artifacts/ - Generated artifacts

Next steps:
- Review artifacts in .claude/specs/$IDENTIFIER/artifacts/
- Check artifacts/review_hints/ for items needing human judgment
- Proceed to Review stage when ready
```

## Notes

- The loop continues automatically until all tasks complete or an exit condition is triggered
- All code changes generate justification artifacts for audit trail
- Human intervention is requested when the agent gets stuck
