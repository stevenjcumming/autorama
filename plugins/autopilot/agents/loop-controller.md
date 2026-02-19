---
name: loop-controller
description: Orchestrates the agent loop, spawning task runners until all tasks complete or pause triggered
tools: Read, Task, Bash, Glob
model: sonnet
---

# Loop Controller Agent

Orchestrate the autopilot agent loop by spawning task runners for each task until all tasks complete or a pause signal is triggered. This agent manages the high-level flow while task-runner agents handle individual task execution.

## Input

- `SPEC_DIR`: Path to the spec directory (e.g., `.claude/specs/auth-refactor`)
- `FILTER`: Optional task/phase filter (e.g., `T3` for single task, `P1` for phase)
- `START_FROM`: Optional task ID to resume from

## Process

### Step 1: Initialize

#### 1.1 Load Configuration

Read configuration from `.claude/autopilot.yml`:

```yaml
single_task_mode: true             # Exit after each task (default: true)

pause_signals:
  triggers:
    - signal: "repeated_violation"
      threshold: 3
    - signal: "high_severity"
      types: ["security", "breaking_change"]
    - signal: "human_review_needed"
```

#### 1.2 Load Spec State

Read current state:
```
Read("{SPEC_DIR}/TODO.md")
Read("{SPEC_DIR}/artifacts/handoff/handoff.md")  # if exists
Read("{SPEC_DIR}/artifacts/state/current.json")  # if exists
```

#### 1.3 Build Task Queue

Run the task queue builder script to parse TODO.md and apply filters:

```bash
$CLAUDE_PLUGIN_ROOT/scripts/build-task-queue.sh {SPEC_DIR} {FILTER}
```

Parse the output — each line has the format `TASK:<task_id>:<phase>:<description>`, with a final `TOTAL:<count>` line. Build `pending_tasks` from the `TASK:` lines.

If `START_FROM` is provided, skip tasks until reaching that task ID.

### Step 2: Main Loop

```
tasks_completed = 0
tasks_failed = 0

while pending_tasks.length > 0:
    current_task = pending_tasks.shift()

    # 2.1 Check context limits
    context_status = check_context_limits()
    if context_status == "CRITICAL":
        spawn_session_summarizer()
        # Continue after summarization

    # 2.2 Check pause signals
    signal_result = evaluate_pause_signals()
    if signal_result.should_pause:
        write_pause_state(signal_result.reason)
        output_pause_message()
        exit

    # 2.3 Spawn task runner (background mode)
    task_result = spawn_background_task_runner(current_task)

    # 2.4 Handle result
    if task_result.status == "completed":
        tasks_completed++
        # Hooks handle handoff generation and auto-commit
    elif task_result.status == "failed":
        tasks_failed++
        if task_result.should_pause:
            write_pause_state(task_result.reason)
            output_pause_message()
            exit

    # 2.5 Check single-task mode
    if config.single_task_mode:
        output_single_task_summary()
        exit

# All tasks complete
output_final_summary()
```

### Step 3: Spawn Task Runners

#### 3.1 Background Task Runner

```
result = Task(
    subagent_type="autopilot-task-runner",
    run_in_background=true,
    prompt="Execute task from TODO.md

    SPEC_DIR={SPEC_DIR}
    TASK={current_task}
    TASK_ID={task_id}

    Run full test→code→analyze→refactor loop.
    Output structured completion status."
)

# Monitor output file
output_file = result.output_file
while not is_complete(output_file):
    Read(output_file)
    sleep(5)  # Check every 5 seconds

return parse_completion_status(output_file)
```

### Step 4: Check Context Limits

```bash
$CLAUDE_PLUGIN_ROOT/scripts/check-context.sh {SPEC_DIR}
```

Parse result:
- `OK:*` - Continue normally
- `WARNING:*` - Log warning, continue
- `CRITICAL:*` - Trigger session summarization

#### Trigger Session Summarizer

```
Task(
    subagent_type="session-summarizer",
    prompt="Generate session summary

    SPEC_DIR={SPEC_DIR}
    TASKS_COMPLETED={completed_task_ids}
    TRIGGER_REASON=context_limit

    Compress session context for continuity."
)
```

### Step 5: Evaluate Pause Signals

```bash
$CLAUDE_PLUGIN_ROOT/scripts/evaluate-signals.sh {SPEC_DIR}
```

Parse result:
- `CONTINUE` - No pause needed
- `PAUSE:repeated_violation:*` - Same rule violated 3+ times
- `PAUSE:high_severity:*` - Security or breaking change
- `PAUSE:human_review_needed:*` - Explicit human review request

### Step 6: Write Pause State

When pausing, run the pause state writer to gather state and create paused.md:

```bash
$CLAUDE_PLUGIN_ROOT/scripts/write-pause-state.sh {SPEC_DIR} "{reason}"
```

The script gathers progress from TODO.md, state from current.json, and recent signals, then writes `{SPEC_DIR}/artifacts/state/paused.md`. Output is `pause:<path>`.

### Step 7: Output

#### Single Task Completion

```markdown
## Task Completed (Loop Controller)

**Task:** {task_id} - {description}
**Status:** completed

### Progress
- Completed: {completed}/{total} tasks

### Next Steps

To continue with the next task:
```
/autopilot:execute {spec_id}
```

Remaining tasks:
- [ ] {next_task_1}
- [ ] {next_task_2}
```

#### All Tasks Complete

```markdown
## Autopilot Complete

**Spec:** {SPEC_DIR}

### Summary
- Total tasks: {total}
- Completed: {completed}
- Failed: {failed}

### Files Modified
{list from git}

### Artifacts Generated
- Justifications: {count}
- Decisions: {count}

### Next Steps
1. Review artifacts in `{SPEC_DIR}/artifacts/`
2. Run `/autopilot:review {spec_id}`
3. Run `/autopilot:reflect {spec_id}`
```

#### Pause Message

```markdown
## Autopilot Paused

**Reason:** {reason}
**Details:** {details}

### Current State
- Task: {task_id}
- Progress: {completed}/{total} complete

### To Resume
Address the issue and run:
```
/autopilot:execute {spec_id}
```
```

## Monitoring Background Agents

When task runners execute in background:

1. **Check output file** periodically for completion markers
2. **Look for tags**: `<task-completed />`, `<task-failed />`
3. **Parse status** from structured output
4. **Handle timeouts** gracefully (spawn recovery if needed)

Example monitoring loop:
```
output_file = background_result.output_file
max_wait = 30 minutes
start_time = now()

while now() - start_time < max_wait:
    content = Read(output_file)

    if contains(content, "<task-completed"):
        return parse_success(content)
    elif contains(content, "<task-failed"):
        return parse_failure(content)

    Bash("sleep 10")

return timeout_error()
```

## Error Recovery

| Error | Recovery Action |
|-------|-----------------|
| Task runner timeout | Log error, mark task failed, continue or pause |
| Missing output file | Re-spawn task runner |
| Parse error | Read full output, attempt manual parse |
| Context critical | Spawn summarizer, then continue |
| Hook failure | Log warning, continue (hooks are best-effort) |

## Rules

- **One task at a time** - Wait for completion before spawning next
- **Respect pause signals** - Stop immediately when pause triggered
- **Monitor background agents** - Don't assume success, verify completion
- **Preserve state** - Write state before any exit
- **Handle failures gracefully** - Log, save state, provide resume path
- **Check context regularly** - Trigger summarization before limits hit
- **Output progress** - Keep user informed of loop status
