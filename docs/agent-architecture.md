# Agent Architecture

The autocode plugin delegates work through a tree of specialized agents. Each agent has a defined role, model tier, tool access, and set of sub-agents it can spawn. No agent has visibility into the full tree -- it only knows about its direct children.

## Overview

```
/autocode:new-spec ─────────────────────────────────────────── (script only, no agent)

/autocode:create-plan ──── plan-builder (opus)
                    ├── plan-researcher (sonnet)
                    └── plan-analyzer (sonnet)

/autocode:create-tasks ──── (inline, no agent — command writes TODO.md directly)

/autocode:execute (command — lightweight loop owner)
                  ├── task-runner (opus, fresh per task)
                  │     ├── tester (sonnet)
                  │     ├── coder (opus)
                  │     ├── analyzer (sonnet)
                  │     └── refactorer (sonnet)
                  └── session-summarizer (haiku, on context-critical)
```

## Model Tiers

Agents are assigned to model tiers based on the complexity of their work.

| Tier | Model | Agents | Role |
|------|-------|--------|------|
| **Heavy** | Opus | task-runner, coder, plan-builder | Complex reasoning, code generation, multi-step orchestration |
| **Medium** | Sonnet | tester, analyzer, refactorer, plan-researcher, plan-analyzer | Test writing, structured analysis, pattern matching, sequential tasks |
| **Light** | Haiku | session-summarizer | Text compression |

The general rule: agents that write code or make architectural decisions use Opus. Agents that analyze, search, or follow structured procedures use Sonnet. Agents that produce formulaic output use Haiku.

## Agent Reference

### Plan Stage

#### `plan-builder`

Orchestrates plan creation by spawning research and analysis sub-agents, then synthesizing their output into `PLAN.md`.

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read, Edit, Task |
| Spawns | plan-researcher, plan-analyzer |

#### `plan-researcher`

Analyzes the spec and researches the codebase for existing patterns, conventions, and relevant code. Returns findings to plan-builder.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Glob, Grep, Bash(find, wc) |
| Spawns | (none) |

#### `plan-analyzer`

Reviews and validates the draft plan against the spec, checking for gaps, risks, and feasibility issues.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Glob, Grep |
| Spawns | (none) |

### Task Stage

The `create-tasks` command reads `PLAN.md` and writes `TODO.md` directly (inline) without spawning a separate agent.

### Autopilot Stage

#### `task-runner`

Executes a single task through the full test/code/analyze/refactor loop. Spawned fresh by `execute.md` for each task, giving every task its own clean context window.

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read, Edit, Write, Task, Glob, Grep, Bash |
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
| Model | Sonnet |
| Tools | Read, Edit, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Test files |

#### `coder`

Implements the task. Generates audit trail artifacts (justifications, decisions, assumptions, risks, debt, review hints).

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read, Edit, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Justifications, decisions, assumptions, risks, debt, review hints |

#### `analyzer`

Runs configured static analysis tools and reports blocking issues.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Write, Glob, Grep, Bash |
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
| Model | Haiku |
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
- **Implementers** (coder, refactorer) get `Edit` and `Write` -- they modify files
- **Test writers** (tester) get `Read`, `Edit`, `Write`, `Glob`, `Grep`, `Bash` -- they create test files
- **Analyzers** (analyzer, researcher) get `Read`, `Grep`, `Glob`, `Bash` -- they observe and report
- **Generators** (session-summarizer) get `Write` for their specific output files
- No agent gets tools it doesn't need

## Related Documentation

- [Orchestration Flow](orchestration_flow.md)
- [Agent Handoff](agent-handoff.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Autocode Workflow](workflow-stages/04_autocode.md)
