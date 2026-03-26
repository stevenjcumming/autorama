# Agent Architecture

The autopilot plugin delegates work through a tree of specialized agents. Each agent has a defined role, model tier, tool access, and set of sub-agents it can spawn. No agent has visibility into the full tree -- it only knows about its direct children.

## Overview

```
/autopilot:new-spec ─────────────────────────────────────────── (script only, no agent)

/autopilot:create-plan ──── plan-builder (opus)
                    ├── plan-researcher (sonnet)
                    └── plan-analyzer (sonnet)

/autopilot:create-tasks ──── (inline, no agent — command writes TODO.md directly)

/autopilot:execute (command — lightweight loop owner)
                  ├── autopilot-task-runner (opus, fresh per task)
                  │     ├── autopilot-tester (sonnet)
                  │     ├── autopilot-coder (opus)
                  │     ├── autopilot-analyzer (sonnet)
                  │     └── autopilot-refactorer (sonnet)
                  └── session-summarizer (haiku, on context-critical)
```

## Model Tiers

Agents are assigned to model tiers based on the complexity of their work.

| Tier | Model | Agents | Role |
|------|-------|--------|------|
| **Heavy** | Opus | autopilot-task-runner, autopilot-coder, plan-builder | Complex reasoning, code generation, multi-step orchestration |
| **Medium** | Sonnet | autopilot-tester, autopilot-analyzer, autopilot-refactorer, plan-researcher, plan-analyzer | Test writing, structured analysis, pattern matching, sequential tasks |
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

#### `autopilot-task-runner`

Executes a single task through the full test/code/analyze/refactor loop. Spawned fresh by `execute.md` for each task, giving every task its own clean context window.

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read, Edit, Write, Task, Glob, Grep, Bash |
| Spawns | autopilot-tester, autopilot-coder, autopilot-analyzer, autopilot-refactorer |

Inner loop:
```
tester → Bash(red) → coder → Bash(green) → analyzer → refactorer
  ↑                                                         │
  └──────────────────── if changes made ────────────────────┘
```

The tester writes tests, the task-runner executes them via Bash (expecting failure — red phase), the coder implements, the task-runner runs tests again via Bash (expecting pass — green phase), then analysis and refactoring.

After completing the inner loop, the task-runner writes `handoff.md` directly (Step 8) to preserve context for the next task.

Exit conditions: task passes all checks with no refactoring changes (success), or category-specific retry limit exceeded (failure).

#### `autopilot-tester`

Writes tests for a task based on requirements and acceptance criteria. Handles the **Red phase** of TDD — creates failing tests that define expected behavior. Does not run the tests; the task-runner executes them via Bash.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Edit, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Test files |

#### `autopilot-coder`

Implements the task. Generates audit trail artifacts (justifications, decisions, assumptions, risks, debt, review hints).

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read, Edit, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Justifications, decisions, assumptions, risks, debt, review hints |

#### `autopilot-analyzer`

Runs configured static analysis tools and reports blocking issues.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Analysis report with fix instructions |

#### `autopilot-refactorer`

Reviews recent changes and applies cleanup refactoring. If it makes changes, the task-runner loops back to the tester to update tests and re-runs the full cycle. If it makes no changes, the task is considered complete.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Edit, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Refactoring changes or no-op |

### Utility Agents

#### `session-summarizer`

Compresses the full session context into a 500-1000 token summary when context limits are approaching. Triggered by `on-agent-complete.sh` hook when context is critical.

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
- **autopilot-task-runner**: tester → Bash(red) → coder → Bash(green) → analyzer → refactorer
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
- [Autopilot Workflow](workflow-stages/04_autopilot.md)
