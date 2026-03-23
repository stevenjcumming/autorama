# Hook System

The autopilot plugin uses Claude Code hooks to inject behavior at specific points during agent execution. Hooks are shell scripts that run automatically -- agents don't call them directly and aren't aware they exist.

## Overview

```
Agent spawned
    │
    ├── PreToolUse (Task) ── load-context.sh ── Injects handoff context into prompt
    ├── PreToolUse (Task) ── log-skill-usage.sh ── Logs agent spawn to usage.jsonl
    │
    ├── (agent executes)
    │
    ├── PostToolUse (Task) ── save-state.sh ── Writes current.json state tracker
    ├── PostToolUse (Write|Edit|Bash) ── commit.sh ── Triggers auto-commit prompt
    │
    └── SubagentStop ── on-agent-complete.sh ── Auto-commits, signals handoff, checks context
```

## Hook Lifecycle

Three hook types fire at different points in the tool lifecycle. Some types have multiple hooks with different matchers.

| Hook Type | Matcher | Script | Timeout |
|-----------|---------|--------|---------|
| **PreToolUse** | Task | `load-context.sh` | 10s |
| **PreToolUse** | Task | `log-skill-usage.sh` | 5s |
| **PostToolUse** | Task | `save-state.sh` | 30s |
| **PostToolUse** | Write\|Edit\|Bash | `commit.sh` | 10s |
| **SubagentStop** | (none) | `on-agent-complete.sh` | 60s |

All hooks are defined in `plugins/autopilot/hooks/hooks.json` and referenced from `plugin.json`.

## Hook Definitions

### `hooks.json` Structure

Hooks are grouped by lifecycle type. Each type contains an array of matcher/hooks pairs:

```json
{
  "description": "Autopilot agent harness hooks for context loading, state persistence, and auto-commit",
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/load-context.sh",
            "timeout": 10
          },
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/log-skill-usage.sh",
            "timeout": 5
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/save-state.sh",
            "timeout": 30
          }
        ]
      },
      {
        "matcher": "Write|Edit|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/commit.sh",
            "timeout": 10
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/on-agent-complete.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

**Fields:**
- Top-level keys -- Hook lifecycle point (PreToolUse, PostToolUse, SubagentStop)
- `matcher` -- Tool name filter (pipe-delimited). Only fires when the matched tool is used. SubagentStop has no matcher (fires for all agents)
- `type` -- Hook type (`command` for shell scripts)
- `command` -- Shell command to execute. `$CLAUDE_PLUGIN_ROOT` resolves to the plugin root
- `timeout` -- Maximum execution time in seconds. Script is killed if exceeded

### Matcher Behavior

- PreToolUse and PostToolUse hooks use matchers to scope which tools trigger them
- The `Task` matcher fires for Task tool invocations. Within the scripts, further filtering narrows to `autopilot-*` subagent types -- the hooks silently exit for non-autopilot agents
- The `Write|Edit|Bash` matcher fires for file modification tools, enabling auto-commits during agent execution
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

**Dependencies:** Requires `jq` for JSON parsing. Exits silently without it.

### `log-skill-usage.sh` (PreToolUse)

Fires alongside `load-context.sh` before each Task agent is spawned. Logs agent spawn events to `${CLAUDE_PLUGIN_DATA}/usage.jsonl` for cross-session analytics.

**Activation guard:** Only runs for `autopilot:*` subagent types. Requires `CLAUDE_PLUGIN_DATA` to be set. Exits silently otherwise.

**Process:**
1. Extracts subagent type from JSON input
2. Strips the `autopilot:` prefix
3. Delegates to `scripts/log-usage.sh` to append a JSONL entry

**Dependencies:** Requires `jq` for JSON parsing and `CLAUDE_PLUGIN_DATA` environment variable.

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

Always auto-commits when there are uncommitted changes:
- Reads task summary from `TODO.md`
- Builds commit message from template (default: `feat({spec_id}): complete {task_id} - {task_summary}`, configurable via `auto_commit.message_template` in `.claude/autopilot.yml`)
- Stages all changes with `git add -A`
- Creates commit with `Co-Authored-By: Claude` footer
- Emits `<auto-commit>`

#### 2. Signal Handoff Generation

- Emits `<handoff-needed>` directive with spec directory, task ID, status, and agent name
- The execute command uses this signal to spawn the `handoff-writer` agent, which produces the actual `handoff.md` file

#### 3. Check Context Limits

- Calls `check-context.sh` to estimate token usage
- Emits `<context-warning>` if approaching limit
- Emits `<context-critical>` if over critical threshold
- Always emits `<agent-completed>` as final signal

### `commit.sh` (PostToolUse — Write|Edit|Bash)

Fires after Write, Edit, or Bash tool calls. Detects uncommitted changes and triggers the `/autopilot:commit` skill.

**Activation guard:** Skips git commands, read-only Bash commands, and changes only in `.claude/` directories. Exits silently if not in a git repo or no uncommitted changes exist.

**Process:**
1. Filters tool calls — only continues for file-modifying operations
2. Checks for uncommitted changes (staged, unstaged, or untracked) outside `.claude/`
3. Emits a `<skill-invoke>` directive to trigger the commit skill

**Output:** `<skill-invoke skill="commit">` when uncommitted changes are detected.

**Dependencies:** Requires `jq` and `git`.

## Supporting Scripts

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
Feature sections are active when present. To disable a feature, remove the section entirely.

## Adding New Hooks

To add a hook:

1. Create a shell script in `plugins/autopilot/hooks/`
2. Add a matcher/hooks entry under the appropriate lifecycle type in `hooks.json` (see structure above)
3. The script receives tool input as JSON on stdin (PreToolUse/PostToolUse) or agent metadata (SubagentStop)
4. Output to stdout is injected into the agent's context (PreToolUse) or logged (PostToolUse/SubagentStop)
5. Non-zero exit codes are treated as warnings, not errors -- hooks should not block execution

## Related Documentation

- [Agent Handoff](agent-handoff.md)
- [Agent Architecture](agent-architecture.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Configuration](configuration.md)
