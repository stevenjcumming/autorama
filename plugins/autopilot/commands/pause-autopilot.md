---
description: Pause autopilot execution and save current state for later resumption
allowed-tools: Read, Write, Bash, Glob
argument-hint: [identifier]
---

# Pause Autopilot Command

Pause the autopilot execution and save the current state so it can be resumed later.

## Arguments

- `identifier`: The spec identifier (e.g., `auth-refactor`). If not provided, attempts to detect from recent activity.

## Process

### Step 1: Locate Spec Directory

If identifier is provided, set `SPEC_DIR = .claude/specs/{identifier}`.

Otherwise, auto-detect using the find script:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/find-active-spec.sh
```

Parse the output:
- `FOUND:<spec_dir>:<spec_id>` — use the returned `spec_dir`
- `NOT_FOUND` — report error, no active spec found

Validate that SPEC_DIR exists.

### Step 2: Determine Pause Reason

If user provided a reason in the command, use that. Otherwise use `"Manual pause requested by user"`.

### Step 3: Write Pause State

Run the pause state writer to gather all state and write paused.md:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/write-pause-state.sh {SPEC_DIR} "{reason}"
```

The script automatically gathers:
- Progress from TODO.md (completed/remaining counts, current task)
- Agent state from `artifacts/state/current.json`
- Recent analyzer signals from `artifacts/signals/`

Output is `pause:<path_to_paused_md>`.

### Step 4: Output Summary

```markdown
## Autopilot Paused

**Spec:** {spec_id}
**Reason:** {reason}

### Current State
- Task: {task_id} - {task_description}
- Progress: {completed}/{total} tasks complete

### Saved State
State saved to: `{SPEC_DIR}/artifacts/state/paused.md`

### To Resume
\`\`\`
/autopilot:execute {identifier}
\`\`\`
```

## Usage Examples

```
# Pause current autopilot session
/autopilot:pause-autopilot auth-refactor

# Pause with auto-detection (finds most recent spec)
/pause-autopilot
```

## Notes

- The pause state is preserved in the spec's artifacts directory
- Resuming with `/autopilot:execute {identifier}` will load the handoff context
- Any uncommitted changes are preserved (not auto-committed on pause)
- Pause signals from the analyzer can trigger automatic pauses
