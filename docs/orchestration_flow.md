# Orchestration Flow

The autopilot system uses a two-layer delegation chain: **command → task-runner**.

## Layer 1: `execute.md` (Command — Lightweight Loop Owner)

The command validates prerequisites, runs setup scripts (`setup-artifacts.sh`, `build-task-queue.sh`), and owns the task loop directly. It parses the task queue from script output, then iterates through tasks sequentially — spawning a fresh `autopilot-task-runner` for each one.

It never reads SPEC.md, PLAN.md, or config files — keeping per-iteration context growth minimal.

## Layer 2: `autopilot-task-runner.md` (Single Task Execution)

Each task runner is self-contained and starts with a clean context window. It runs the inner loop for one task:

```
loop:
    tester (write tests) → Bash: run tests (red) → coder → Bash: run tests (green) → analyzer → refactorer
    if refactorer made no changes → break (task done)
    if category retry limit exceeded → exit with failure
```

On completion, it marks the task `[x]` in TODO.md and outputs structured XML that the execute command parses to determine success/failure.

## Context Continuity Between Tasks

When Task 1 finishes and Task 2 starts, continuity is maintained via:

- **handoff.md** — written by hooks (`on-agent-complete.sh`) after each task, loaded by the next task runner at initialization
- **TODO.md** — the shared state file; completed tasks are checked off, so the execute command knows where to pick up
- **SESSION_SUMMARY.md** — if context limits are hit, the `session-summarizer` compresses context

In short: `execute.md` is a synchronous queue processor. It pops one task, spawns a runner, waits for completion, then pops the next. The sequencing is implicit in the queue order derived from TODO.md.
