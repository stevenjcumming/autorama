# Orchestration Flow

The autocode system uses a two-layer delegation chain: **skill → task-runner**.

## Layer 1: `skills/execute/SKILL.md` (Skill, Lightweight Loop Owner)

The execute skill validates prerequisites, runs setup scripts (`setup-artifacts.sh`, `build-task-queue.sh`), and owns the task loop directly. It parses the task queue from script output, then iterates through tasks sequentially, spawning a fresh `task-runner` for each one.

It never reads SPEC.md, PLAN.md, or config files — keeping per-iteration context growth minimal.

## Layer 2: `task-runner.md` (Single Task Execution)

Each task runner is self-contained and starts with a clean context window. It runs the inner loop for one task:

```
loop:
    tester (write tests) → Bash: run tests (red) → coder → Bash: run tests (green) → analyzer → refactorer
    if refactorer made no changes → break (task done)
    if category retry limit exceeded → exit with failure
```

On completion, it marks the task `[x]` in TODO.md and emits exactly one `<task-completed>` tag (defined in `agents/references/failure-categories.md`) that the execute skill parses to determine success/failure. A missing or unparseable tag is treated as `status=failed category=unknown`, surfacing the raw tail of the runner output.

## Context Continuity Between Tasks

When Task 1 finishes and Task 2 starts, continuity is maintained via:

- **handoff.md** — written directly by the `task-runner` as its final step (Step 8) before completing; loaded by the next task runner at initialization
- **TODO.md**: the shared state file; completed tasks are checked off, so the execute skill knows where to pick up
- **SESSION_SUMMARY.md** — if context limits are hit, the `session-summarizer` compresses context

In short: the execute skill is a synchronous queue processor. It pops one task, spawns a runner, waits for completion, then pops the next. It does not halt on the first failure: a `category=setup` failure stops the loop, while any other failure skips only the remaining same-phase tasks after the failed one plus tasks that explicitly depend on it, then continues with independent tasks. The sequencing is implicit in the queue order derived from TODO.md.
