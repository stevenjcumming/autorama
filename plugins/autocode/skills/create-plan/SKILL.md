---
name: create-plan
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/create-plan/scripts/create-plan.sh:*), Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh:*), Read, Task
description: Use when the user has a completed SPEC.md and wants to generate a detailed implementation plan. Spawns research and analysis agents to build PLAN.md with phases, risks, and testing strategy.
argument-hint: <identifier>
model: sonnet # orchestration: parse the spec, decide by the P table, spawn the plan-builder; the planning judgment runs in the plan-builder at the computed tier; see docs/MODEL_SELECTION.md
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

The script validates upstream content (does SPEC.md exist and have real content, not just unfilled template boilerplate?) *before* scaffolding PLAN.md, so a failed check never leaves a stale, empty PLAN.md behind. If the script fails, do not proceed to Step 2:
- **Missing spec or SPEC.md**: surface the script's error message to the user and stop.
- **SPEC.md is empty or has only unfilled template content**: surface the script's error message and tell the user to complete SPEC.md first, then stop.
- **PLAN.md already exists**: tell the user and ask whether to keep the existing plan or regenerate it. Only if they choose to regenerate, delete the existing PLAN.md and re-run the script; otherwise stop.

## Step 2: Select the Planning Model

Compute the plan-builder's model tier before spawning it. The canonical table lives in the plugin's `docs/MODEL_SELECTION.md` (P table); it is restated here because this skill applies it.

1. **Read the ceiling.** Read `.claude/autocode.yml` and take `models.ceiling` (`opus` or `fable`). If the file or key is absent, `CEILING=opus`. If the value is anything other than `opus` or `fable`, warn the user in one line and use `opus`.
2. **Read `{SPEC_DIR}/SPEC.md`** and apply the P table, first match wins:

| # | Condition | Model |
|---|---|---|
| P1 | Spec is docs/chore/config-only, single module, no open questions | sonnet |
| P2 | Spec touches auth, schema, concurrency, or migrations, OR has unresolved open questions, OR spans 3+ modules | `{CEILING}` |
| P3 | Everything else | opus |

P1 requires **positive evidence of all three conditions** (docs/chore/config-only scope, single module, zero open questions). Any ambiguity resolves to P3 (opus) — never down to sonnet by prediction.

3. **Announce the decision in one line**, naming the rule and the evidence, e.g. `Planning on sonnet via P1: docs-only spec, single module` or `Planning on opus via P3`.
4. **Log the decision:**

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh model-selection plan-builder ok '{"rule":"P1","tier":"sonnet","spec":"{IDENTIFIER}"}'
```

## Step 3: Build the Plan

Spawn the plan-builder agent, passing the tier computed in Step 2 (the agent's `opus` frontmatter is only the fail-up safe default):

```
Task(
  subagent_type="autocode:plan-builder",
  model="{PLANNING_MODEL}",
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
