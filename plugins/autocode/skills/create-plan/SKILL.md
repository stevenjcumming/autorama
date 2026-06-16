---
name: create-plan
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/create-plan/scripts/create-plan.sh:*), Read, Task
description: Use when the user has a completed SPEC.md and wants to generate a detailed implementation plan. Spawns research and analysis agents to build PLAN.md with phases, risks, and testing strategy.
argument-hint: <identifier>
---

# Create Plan

Create an implementation plan from an existing spec.

## Arguments

- `$ARGUMENTS` contains: `<identifier>`
- Parse the arguments to extract:
  - `IDENTIFIER`: The spec identifier (e.g., `auth-refactor`)
- Construct `SPEC_DIR` as `.specs/{IDENTIFIER}`

## Step 1: Create PLAN.md Template

Run the create-plan script:

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/create-plan/scripts/create-plan.sh {IDENTIFIER}
```

If the script fails, do not proceed to Step 2:
- **Missing spec or SPEC.md**: surface the script's error message to the user and stop.
- **PLAN.md already exists**: tell the user and ask whether to keep the existing plan or regenerate it. Only if they choose to regenerate, delete the existing PLAN.md and re-run the script; otherwise stop.

## Step 2: Check the Spec

Read `{SPEC_DIR}/SPEC.md`. If it is empty or has only template content (unfilled placeholders and comments), tell the user to complete the spec first and stop.

## Step 3: Build the Plan

Spawn the plan-builder agent:

```
Task(
  subagent_type="autocode:plan-builder",
  prompt="SPEC_DIR={SPEC_DIR}"
)
```

The plan-builder agent will:
1. Read REQUIREMENT.md and SPEC.md
2. Spawn plan-researcher to analyze the codebase
3. Write the implementation plan to PLAN.md
4. Spawn plan-analyzer to validate the plan
5. Return a summary with analysis

## Step 4: Present Results

After the agent completes, present:
- Location of PLAN.md
- Research summary
- Plan analysis with gaps/risks/suggestions
- Next steps for the user

The user should review the plan and address any identified issues before implementation.
