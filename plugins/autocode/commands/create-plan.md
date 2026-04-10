---
allowed-tools: Bash, Read, Task
description: Use when the user has a completed SPEC.md and wants to generate a detailed implementation plan. Spawns research and analysis agents to build PLAN.md with phases, risks, and testing strategy.
argument-hint: <identifier>
---

# Create Plan

Create an implementation plan from an existing spec.

## Step 1: Create PLAN.md Template

Run the create-plan script:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/create-plan.sh $ARGUMENTS
```

## Step 2: Build the Plan

Spawn the plan-builder agent:

```
Task(
  subagent_type="autopilot:plan-builder",
  prompt="SPEC_DIR=.claude/specs/$ARGUMENTS"
)
```

The plan-builder agent will:
1. Read REQUIREMENT.md and SPEC.md
2. Spawn plan-researcher to analyze the codebase
3. Write the implementation plan to PLAN.md
4. Spawn plan-analyzer to validate the plan
5. Return a summary with analysis

## Step 3: Present Results

After the agent completes, present:
- Location of PLAN.md
- Research summary
- Plan analysis with gaps/risks/suggestions
- Next steps for the user

The user should review the plan and address any identified issues before implementation.
