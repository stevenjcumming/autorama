# Agent Architecture

The autopilot plugin delegates work through a tree of specialized agents. Each agent has a defined role, model tier, tool access, and set of sub-agents it can spawn. No agent has visibility into the full tree -- it only knows about its direct children.

## Overview

```
/autopilot:new-spec ─────────────────────────────────────────── spec-writer (leaf)

/autopilot:create-plan ──── plan-builder (opus)
                    ├── plan-researcher (sonnet)
                    └── plan-analyzer (sonnet)

/autopilot:create-tasks ──── task-builder (sonnet, leaf)

/autopilot:execute ──── loop-controller (sonnet)
                  ├── autopilot-task-runner (opus)
                  │     ├── autopilot-tester (sonnet)
                  │     ├── autopilot-coder (opus)
                  │     ├── autopilot-analyzer (sonnet)
                  │     └── autopilot-refactorer (sonnet)
                  └── session-summarizer (haiku)

/autopilot:reflect ──── rules-builder (sonnet, leaf)

(hooks) ──── handoff-writer (haiku, leaf)
```

## Model Tiers

Agents are assigned to model tiers based on the complexity of their work.

| Tier | Model | Agents | Role |
|------|-------|--------|------|
| **Heavy** | Opus | autopilot-task-runner, autopilot-coder, plan-builder | Complex reasoning, code generation, multi-step orchestration |
| **Medium** | Sonnet | loop-controller, autopilot-tester, autopilot-analyzer, autopilot-refactorer, plan-researcher, plan-analyzer, task-builder, rules-builder | Test writing, structured analysis, pattern matching, sequential tasks |
| **Light** | Haiku | handoff-writer, session-summarizer | Template filling, text compression |

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

#### `task-builder`

Converts `PLAN.md` into a phased `TODO.md` checklist with task IDs, dependencies, and acceptance criteria.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Edit |
| Spawns | (none) |

### Autopilot Stage

#### `loop-controller`

Sequential queue processor. Parses `TODO.md`, spawns one task runner at a time, waits for completion, checks pause signals and context limits, then moves to the next task.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Task, Bash, Glob |
| Spawns | autopilot-task-runner, session-summarizer |

Does not write code. Its job is sequencing and monitoring.

#### `autopilot-task-runner`

Executes a single task through the full test/code/analyze/refactor loop. Designed for background execution with structured XML output markers.

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

Exit conditions: task passes all checks with no refactoring changes (success), or category-specific retry limit exceeded (failure).

#### `autopilot-tester`

Writes tests for a task based on requirements and acceptance criteria. Handles the **Red phase** of TDD — creates failing tests that define expected behavior. Does not run the tests; the task-runner executes them via Bash.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Edit, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Test files, signals |

#### `autopilot-coder`

Implements the task. Generates audit trail artifacts (justifications, decisions, assumptions, risks, debt, review hints).

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read, Edit, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Justifications, decisions, assumptions, risks, debt, review hints |
| Hooks | PostToolUse on Edit/Write triggers `justify.sh` |

#### `autopilot-analyzer`

Runs configured static analysis tools and reports blocking issues.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Write, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Signals |

#### `autopilot-refactorer`

Reviews recent changes and applies cleanup refactoring. If it makes changes, the task-runner loops back to the tester to update tests and re-runs the full cycle. If it makes no changes, the task is considered complete.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Edit, Glob, Grep, Bash |
| Spawns | (none) |
| Produces | Signals |

### Utility Agents

#### `session-summarizer`

Compresses the full session context into a 500-1000 token summary when context limits are approaching. Spawned by the loop-controller.

| Field | Value |
|-------|-------|
| Model | Haiku |
| Tools | Read, Glob, Bash |
| Spawns | (none) |
| Output | `SESSION_SUMMARY.md` |

#### `handoff-writer`

Generates rich `handoff.md` artifacts by analyzing git diffs, artifacts, and decisions. Invoked by hooks or manually when deeper context preservation is needed.

| Field | Value |
|-------|-------|
| Model | Haiku |
| Tools | Read, Write, Glob, Bash |
| Spawns | (none) |
| Output | `handoff.md` |

### Reflect Stage

#### `rules-builder`

Creates rule files in `.claude/rules/` from proposals generated during the reflect stage. Supports both global and path-specific rules.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Write, Glob |
| Spawns | (none) |
| Output | `.claude/rules/*.md` |

## Delegation Patterns

### Sequential Delegation

Used when sub-agent outputs feed into each other. The parent spawns one child, waits for its result, then spawns the next.

- **plan-builder**: researcher first (gather data), then analyzer (validate plan)
- **autopilot-task-runner**: tester → Bash(red) → coder → Bash(green) → analyzer → refactorer
- **loop-controller**: task N must complete before task N+1 starts

### Background Delegation

The loop-controller can spawn task runners in background mode (`run_in_background=true`). It monitors the output file for XML completion markers (`<task-completed />` or `<task-failed />`), polling until the agent finishes.

### Fire-and-Forget

Utility agents like session-summarizer and handoff-writer produce a file and exit. The caller doesn't need their return value beyond confirming the file was written.

## Tool Access Principles

- **Orchestrators** (loop-controller, plan-builder) get `Task` but limited file tools -- they delegate, not implement
- **Implementers** (coder, refactorer) get `Edit` and `Write` -- they modify files
- **Test writers** (tester) get `Read`, `Edit`, `Write`, `Glob`, `Grep`, `Bash` -- they create test files
- **Analyzers** (analyzer, researcher) get `Read`, `Grep`, `Glob`, `Bash` -- they observe and report
- **Generators** (handoff-writer, session-summarizer) get `Write` for their specific output files
- No agent gets tools it doesn't need

## Related Documentation

- [Orchestration Flow](orchestration_flow.md)
- [Agent Handoff](agent-handoff.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Autopilot Workflow](workflow-stages/04_autopilot.md)
