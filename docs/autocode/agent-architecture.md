# Agent Architecture

The autocode plugin delegates work through a tree of specialized agents. Each agent has a defined role, model tier, tool access, and set of sub-agents it can spawn. No agent has visibility into the full tree -- it only knows about its direct children.

## Overview

```
/autocode:new-spec ─────────────────────────────────────────── (script only, no agent)

/autocode:create-plan ──── plan-builder (dynamic: P table, opus safe default)
                    ├── plan-researcher (sonnet)
                    └── plan-analyzer (sonnet)

/autocode:create-tasks ──── (inline, no agent; skill writes TODO.md directly)

/autocode:execute (skill, lightweight loop owner)
                  ├── task-runner (sonnet, fresh per task)
                  │     ├── tester (opus)
                  │     ├── coder (dynamic: C table, opus safe default)
                  │     ├── analyzer (sonnet)
                  │     └── refactorer (sonnet)
                  └── session-summarizer (sonnet, on context-critical)
```

## Model Tiers

Model selection uses two mechanisms (canonical reference: [`plugins/autocode/docs/MODEL_SELECTION.md`](../../plugins/autocode/docs/MODEL_SELECTION.md)):

- **Fixed roles** pin `model` in frontmatter and never receive a `model` parameter from callers. Their tier follows the role: the tester is opus because the tests it writes are the oracle everything downstream trusts; analyzers and researchers are sonnet because their output feeds a more capable consumer; the task-runner is sonnet because its hardest judgment calls are encoded in the deterministic C-table rules it applies.
- **Dynamic roles** (plan-builder, coder, reviewer) pin opus as a fail-up safe default; the orchestrating skill computes the actual tier per work item from a decision table (P for planning, C for coding, R for review) and passes it on the Task call. The common case runs mostly on sonnet; capability is bought only on evidence, and an omitted parameter can only fail up to opus, never down.

| Assignment | Agents |
|------|--------|
| Fixed opus | tester |
| Fixed sonnet | task-runner, analyzer, refactorer, plan-researcher, plan-analyzer, session-summarizer |
| Dynamic (opus safe default) | plan-builder (P table), coder (C table), reviewer (R table) |

`models.ceiling` in `.claude/autocode.yml` caps dynamic resolutions only (default `opus`; `fable` allowed).

## Agent Reference

### Plan Stage

#### `plan-builder`

Orchestrates plan creation by spawning research and analysis sub-agents, then synthesizing their output into `PLAN.md`.

| Field | Value |
|-------|-------|
| Model | Dynamic (P table); opus safe default |
| Tools | Read, Edit, Task |
| Spawns | plan-researcher, plan-analyzer |

#### `plan-researcher`

Analyzes the spec and researches the codebase for existing patterns, conventions, and relevant code. Returns findings to plan-builder.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Glob, Grep, Bash(wc) |
| Spawns | (none) |

#### `plan-analyzer`

Reviews and validates the draft plan against the spec, checking for gaps, risks, and feasibility issues.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Glob, Grep |
| Spawns | (none) |

### Task Stage

The `create-tasks` skill reads `PLAN.md` and writes `TODO.md` directly (inline) without spawning a separate agent.

### Autorama Stage

#### `task-runner`

Executes a single task through the full test/code/analyze/refactor loop. Spawned fresh by `execute.md` for each task, giving every task its own clean context window.

| Field | Value |
|-------|-------|
| Model | Sonnet (applies the C table to pick each coder spawn's tier) |
| Tools | Read, Edit, Write, Task, Glob, Bash |
| Spawns | tester, coder, analyzer, refactorer |

Inner loop:
```
tester → Bash(red) → coder → Bash(green) → analyzer → refactorer
  ↑                                                         │
  └──────────────────── if changes made ────────────────────┘
```

The tester writes tests, the task-runner executes them via Bash (expecting failure — red phase), the coder implements, the task-runner runs tests again via Bash (expecting pass — green phase), then analysis and refactoring.

After completing the inner loop, the task-runner writes `handoff.md` directly (Step 8) to preserve context for the next task.

Exit conditions: task passes all checks with no refactoring changes (success), or category-specific retry limit exceeded (failure).

#### `tester`

Writes tests for a task based on requirements and acceptance criteria. Handles the **Red phase** of TDD — creates failing tests that define expected behavior. Does not run the tests; the task-runner executes them via Bash.

| Field | Value |
|-------|-------|
| Model | Opus (fixed; oracle-defining work) |
| Tools | Read, Write, Glob, Grep, Bash (scoped to syntax checks) |
| Spawns | (none) |
| Produces | Test files |

#### `coder`

Implements the task. Generates audit trail artifacts (justifications, decisions, assumptions, risks, debt, review hints).

| Field | Value |
|-------|-------|
| Model | Dynamic (C table: easy=sonnet, standard=opus, hard=ceiling; repairs=sonnet); opus safe default |
| Tools | Read, Edit, Write, Glob, Grep |
| Spawns | (none) |
| Produces | Justifications, decisions, assumptions, risks, debt, review hints |

#### `analyzer`

Runs configured static analysis tools and reports blocking issues.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Analysis report with fix instructions |

#### `refactorer`

Reviews recent changes and applies cleanup refactoring. If it makes changes, the task-runner loops back to the tester to update tests and re-runs the full cycle. If it makes no changes, the task is considered complete.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Edit, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Refactoring changes or no-op |

### Utility Agents

#### `session-summarizer`

Compresses the full session context into a 500-1000 token summary when context limits are approaching. Triggered when `on-agent-complete.sh` hook emits `<context-critical>`.

| Field | Value |
|-------|-------|
| Model | Sonnet (a lossy handoff silently degrades every later task) |
| Tools | Read, Glob, Bash |
| Spawns | (none) |
| Output | `SESSION_SUMMARY.md` |

## Delegation Patterns

### Sequential Delegation

Used when sub-agent outputs feed into each other. The parent spawns one child, waits for its result, then spawns the next.

- **plan-builder**: researcher first (gather data), then analyzer (validate plan)
- **task-runner**: tester → Bash(red) → coder → Bash(green) → analyzer → refactorer
- **execute.md**: task N must complete before task N+1 starts

### Fire-and-Forget

Utility agents like session-summarizer produce a file and exit. The caller doesn't need their return value beyond confirming the file was written.

## Tool Access Principles

- **Orchestrators** (execute.md command, plan-builder) delegate work — they don't implement
- **Implementers** (coder, refactorer) get `Edit` to modify files. The coder also gets `Write` (for new files) but no `Bash`; the refactorer disallows `Write` so it only edits existing files
- **Test writers** (tester) get `Read`, `Write`, `Glob`, `Grep`, and `Bash` scoped to syntax checks -- they create test files but do not edit existing ones or run the suite
- **Analyzers** (analyzer, researcher) get `Read`, `Grep`, `Glob`, `Bash` -- they observe and report (the analyzer has no `Write`)
- **Generators** (session-summarizer) get `Write` for their specific output files
- No agent gets tools it doesn't need

## Related Documentation

- [Orchestration Flow](orchestration_flow.md)
- [Agent Handoff](agent-handoff.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Execute Workflow](workflow-stages/04_execute.md)
