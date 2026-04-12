# Hook System

The autocode plugin uses Claude Code hooks to inject behavior at specific points during agent execution. Hooks are shell scripts that run automatically -- agents don't call them directly and aren't aware they exist.

## Overview

```
Agent spawned
    │
    ├── PreToolUse (Task) ── load-context.sh ── Injects handoff context into prompt
    ├── PreToolUse (Task) ── log-skill-usage.sh ── Logs agent spawn to usage.jsonl
    │
    ├── (agent executes)
    │
    └── SubagentStop ── on-agent-complete.sh ── Checks context limits
```

## Hook Lifecycle

Two hook types fire at different points in the tool lifecycle. Some types have multiple hooks with different matchers.

| Hook Type | Matcher | Script | Timeout |
|-----------|---------|--------|---------|
| **PreToolUse** | Task | `load-context.sh` | 10s |
| **PreToolUse** | Task | `log-skill-usage.sh` | 5s |
| **SubagentStop** | (none) | `on-agent-complete.sh` | 60s |

All hooks are defined in `plugins/autocode/hooks/hooks.json` and referenced from `plugin.json`.

## Hook Definitions

### `hooks.json` Structure

Hooks are grouped by lifecycle type. Each type contains an array of matcher/hooks pairs:

```json
{
  "description": "Autopilot agent harness hooks for context loading and context limit checks",
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
- Top-level keys -- Hook lifecycle point (PreToolUse, SubagentStop)
- `matcher` -- Tool name filter (pipe-delimited). Only fires when the matched tool is used. SubagentStop has no matcher (fires for all agents)
- `type` -- Hook type (`command` for shell scripts)
- `command` -- Shell command to execute. `$CLAUDE_PLUGIN_ROOT` resolves to the plugin root
- `timeout` -- Maximum execution time in seconds. Script is killed if exceeded

### Matcher Behavior

- PreToolUse hooks use matchers to scope which tools trigger them
- The `Task` matcher fires for Task tool invocations. Within the scripts, further filtering narrows to `autocode-*` subagent types -- the hooks silently exit for non-autocode agents
- SubagentStop has no matcher and fires for all subagent completions. The script checks the agent type internally

## Hook Scripts

### `load-context.sh` (PreToolUse)

Fires before each autocode Task agent is spawned. Loads context from the previous task into the new agent's prompt.

**Activation guard:** Only runs for `autocode-*` subagent types. Exits silently otherwise.

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

**Activation guard:** Only runs for `autocode:*` subagent types. Requires `CLAUDE_PLUGIN_DATA` to be set. Exits silently otherwise.

**Process:**
1. Extracts subagent type from JSON input
2. Strips the `autocode:` prefix
3. Delegates to `scripts/log-usage.sh` to append a JSONL entry

**Dependencies:** Requires `jq` for JSON parsing and `CLAUDE_PLUGIN_DATA` environment variable.

### `on-agent-complete.sh` (SubagentStop)

Fires when a subagent finishes. Checks context limits and signals task completion.

**Process:**
1. Detects task completion from agent output (`<task-completed>` tag or prose patterns)
2. Calls `check-context.sh` to estimate token usage
3. Emits context limit signals if needed
4. Emits `<agent-completed>` as final signal

**Output tags:**

| Tag | Meaning |
|-----|---------|
| `<context-warning>` | Context usage is high |
| `<context-critical>` | Context usage is critical, summarization needed |
| `<agent-completed>` | Agent finished (always emitted) |

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

Hooks read their configuration from `.claude/autocode.yml`:

| Key | Default | Used By |
|-----|---------|---------|
Feature sections are active when present. To disable a feature, remove the section entirely.

## Adding New Hooks

To add a hook:

1. Create a shell script in `plugins/autocode/hooks/`
2. Add a matcher/hooks entry under the appropriate lifecycle type in `hooks.json` (see structure above)
3. The script receives tool input as JSON on stdin (PreToolUse) or agent metadata (SubagentStop)
4. Output to stdout is injected into the agent's context (PreToolUse) or logged (SubagentStop)
5. Non-zero exit codes are treated as warnings, not errors -- hooks should not block execution

## Related Documentation

- [Agent Handoff](agent-handoff.md)
- [Agent Architecture](agent-architecture.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Configuration](configuration.md)
