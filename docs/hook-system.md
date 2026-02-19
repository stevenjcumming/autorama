# Hook System

The autopilot plugin uses Claude Code hooks to inject behavior at specific points during agent execution. Hooks are shell scripts that run automatically -- agents don't call them directly and aren't aware they exist.

## Overview

```
Agent spawned
    │
    ├── PreToolUse ── load-context.sh ── Injects handoff context into prompt
    │
    ├── (agent executes)
    │
    ├── PostToolUse ── save-state.sh ── Writes current.json state tracker
    │
    └── SubagentStop ── on-agent-complete.sh ── Auto-commits, generates handoff, checks context
```

## Hook Lifecycle

Three hook types fire at different points in the Task tool lifecycle.

| Hook Type | When It Fires | Script | Timeout |
|-----------|--------------|--------|---------|
| **PreToolUse** | Before a Task agent is spawned | `load-context.sh` | 10s |
| **PostToolUse** | After a Task agent completes | `save-state.sh` | 30s |
| **SubagentStop** | When a subagent finishes execution | `on-agent-complete.sh` | 60s |

All hooks are defined in `plugins/autopilot/hooks/hooks.json` and referenced from `plugin.json`.

## Hook Definitions

### `hooks.json` Structure

```json
{
  "hooks": [
    {
      "type": "PreToolUse",
      "matcher": "Task",
      "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/load-context.sh",
      "timeout": 10000
    },
    {
      "type": "PostToolUse",
      "matcher": "Task",
      "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/save-state.sh",
      "timeout": 30000
    },
    {
      "type": "SubagentStop",
      "command": "bash $CLAUDE_PLUGIN_ROOT/hooks/on-agent-complete.sh",
      "timeout": 60000
    }
  ]
}
```

**Fields:**
- `type` -- Hook lifecycle point (PreToolUse, PostToolUse, SubagentStop)
- `matcher` -- Tool name filter. Only fires when the matched tool is used. SubagentStop has no matcher (fires for all agents)
- `command` -- Shell command to execute. `$CLAUDE_PLUGIN_ROOT` resolves to the plugin root
- `timeout` -- Maximum execution time in milliseconds. Script is killed if exceeded

### Matcher Behavior

- PreToolUse and PostToolUse hooks use `"matcher": "Task"` to fire only for Task tool invocations
- Within the scripts, further filtering narrows to `autopilot-*` subagent types -- the hooks silently exit for non-autopilot agents
- SubagentStop has no matcher and fires for all subagent completions. The script checks the agent type internally

## Hook Scripts

### `load-context.sh` (PreToolUse)

Fires before each autopilot Task agent is spawned. Loads context from the previous task into the new agent's prompt.

**Activation guard:** Only runs for `autopilot-*` subagent types. Exits silently otherwise.

**Process:**
1. Extracts `SPEC_DIR` from the Task tool's prompt argument
2. Delegates to `read-handoff.sh` if the script exists
3. Falls back to manual file reads if the script is missing

**Output blocks injected into agent prompt:**

| XML Tag | Source | Content |
|---------|--------|---------|
| `<handoff-context>` | `handoff.md` | Previous task summary, decisions, warnings |
| `<current-task>` | `TODO.md` | Next uncompleted task with subtasks |
| `<progress-summary>` | `TODO.md` | Completed/remaining counts |

**Dependencies:** Prefers `jq` for config parsing, `yq` for YAML. Falls back gracefully without either.

### `save-state.sh` (PostToolUse)

Fires after each autopilot Task agent completes. Writes lightweight state to disk.

**Process:**
1. Extracts tool name and subagent type from JSON input
2. Extracts `SPEC_DIR` from the task prompt
3. Detects task completion from output (looks for "Task Completed" markers)
4. Writes `{SPEC_DIR}/artifacts/state/current.json`

**State file contents:**

```json
{
  "last_agent": "autopilot-task-runner",
  "last_task": "T1",
  "task_completed": true,
  "timestamp": "2025-01-15T10:30:00Z",
  "spec_dir": ".claude/specs/my-feature"
}
```

**Output signal:** Emits `<task-completed>` if the task was marked done.

### `on-agent-complete.sh` (SubagentStop)

Fires when a subagent finishes. Handles the heavier post-task operations.

**Three responsibilities:**

#### 1. Auto-Commit

If `auto_commit` section is present in `.claude/autopilot.yml`:
- Reads task summary from `TODO.md`
- Builds commit message from template (default: `feat({spec_id}): complete {task_id} - {task_summary}`)
- Stages all changes with `git add -A`
- Creates commit with `Co-Authored-By: Claude` footer
- Emits `<auto-commit>`

#### 2. Generate Handoff

- Creates `{SPEC_DIR}/artifacts/handoff/handoff.md`
- Includes task metadata, files modified (from `git diff HEAD~1`), next task context, blockers
- Emits `<handoff-generated>`

#### 3. Check Context Limits

- Calls `check-context.sh` to estimate token usage
- Emits `<context-warning>` if approaching limit
- Emits `<context-critical>` if over critical threshold
- Always emits `<agent-completed>` as final signal

## Supporting Scripts

### `evaluate-signals.sh`

Evaluates analyzer signals to determine if the autopilot should pause.

**Pause triggers:**

| Trigger | Condition |
|---------|-----------|
| Repeated violation | Same rule violated 3+ times (configurable) |
| High severity | Signal severity is "high" or type is "security"/"breaking_change" |
| Human review needed | Signal has `human_review: required` or `needs_human_review: true` |

**Output:** `PAUSE:<reason>:<details>` or `CONTINUE`

Uses a `.last_check` marker file for incremental checking -- only evaluates signals newer than the last check.

### `check-context.sh`

Estimates context token usage by measuring file sizes across spec files, artifacts, and rules.

**Token estimation:** 4 characters = 1 token, plus 30% overhead for conversation.

**Thresholds:**

| Status | Token Count | Exit Code | Output |
|--------|-------------|-----------|--------|
| OK | < 150k | 0 | `OK:<tokens>` |
| Warning | 150k-200k | 0 | `WARNING:context_limit:<tokens>` |
| Critical | > 200k | 1 | `CRITICAL:context_limit:<tokens>` |

### `read-handoff.sh`

Standalone utility that assembles handoff context. Used by `load-context.sh` but callable directly.

**Usage:** `read-handoff.sh <spec_dir>`

**Behavior:**
1. Reads `handoff.md` from the spec's artifact directory
2. Parses `TODO.md` for the first uncompleted task with subtasks
3. Outputs all context in XML-tagged blocks

## Configuration

Hooks read their configuration from `.claude/autopilot.yml`:

| Key | Default | Used By |
|-----|---------|---------|
| `auto_commit.message_template` | conventional | `on-agent-complete.sh` |
| `pause_signals.triggers` | (see config doc) | `evaluate-signals.sh` |

Feature sections are active when present. To disable a feature, remove the section entirely.

## Adding New Hooks

To add a hook:

1. Create a shell script in `plugins/autopilot/hooks/`
2. Add an entry to `hooks.json` with the hook type, matcher, command, and timeout
3. The script receives tool input as JSON on stdin (PreToolUse/PostToolUse) or agent metadata (SubagentStop)
4. Output to stdout is injected into the agent's context (PreToolUse) or logged (PostToolUse/SubagentStop)
5. Non-zero exit codes are treated as warnings, not errors -- hooks should not block execution

## Related Documentation

- [Agent Handoff](agent-handoff.md)
- [Agent Architecture](agent-architecture.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Configuration](configuration.md)
