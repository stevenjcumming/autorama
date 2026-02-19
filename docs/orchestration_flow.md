# Orchestration Flow

The autopilot system uses a three-layer delegation chain: **command → loop-controller → task-runner**.

## Layer 1: `autopilot.md` (Command)

The command does minimal orchestration itself. It validates prerequisites, then spawns a single Task agent using the `loop-controller` agent instructions. It passes `SPEC_DIR` and an optional `FILTER` (e.g., `T3` or `P1`). After the loop-controller returns, it presents a summary.

The command doesn't manage sequencing — it delegates entirely.

## Layer 2: `loop-controller.md` (Sequential Orchestration)

This is where sequential task ordering happens. The key mechanism is a `while` loop with a queue:

```
pending_tasks = parse TODO.md (uncompleted tasks in order)

while pending_tasks.length > 0:
    current_task = pending_tasks.shift()   # Take next task off queue

    # Pre-checks: context limits, pause signals

    # Spawn ONE task runner and WAIT for it
    task_result = spawn_task_runner(current_task)

    # Handle result, then loop to next task
```

Sequential ordering is enforced by:

1. **Parsing TODO.md in order** — tasks are queued in their document order (phases P1 before P2, T1 before T2 within a phase)
2. **One task at a time** — the loop spawns a single `autopilot-task-runner` and blocks until it completes (either via foreground `Task()` or by polling the background agent's output file for `<task-completed />` / `<task-failed />` XML markers)
3. **Only then** does it `shift()` the next task and repeat

Between tasks, the controller also checks pause signals (`evaluate-signals.sh`) and context limits (`check-context.sh`), and can exit early if `single_task_mode` is enabled.

## Layer 3: `autopilot-task-runner.md` (Single Task Execution)

Each task runner is self-contained. It runs the inner loop for one task:

```
loop:
    tester (write tests) → Bash: run tests (red) → coder → Bash: run tests (green) → analyzer → refactorer
    if refactorer made no changes → break (task done)
    if category retry limit exceeded → exit with failure
```

On completion, it marks the task `[x]` in TODO.md and outputs structured XML that the loop controller parses to determine success/failure.

## Context Continuity Between Tasks

When Task 1 finishes and Task 2 starts, continuity is maintained via:

- **handoff.md** — written by hooks (`save-state.sh`) after each task, loaded by the next task runner at initialization
- **TODO.md** — the shared state file; completed tasks are checked off, so the loop controller knows where to pick up
- **SESSION_SUMMARY.md** — if context limits are hit, the `session-summarizer` compresses context

In short: the loop-controller is a synchronous queue processor. It pops one task, spawns a runner, waits for completion, then pops the next. The sequencing is implicit in the queue order derived from TODO.md.
