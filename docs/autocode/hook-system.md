# Hook System

The autocode plugin uses Claude Code hooks to inject behavior at specific points during agent execution. Hooks are shell scripts that run automatically; agents don't call them directly and aren't aware they exist.

> **Restart requirement:** hook configuration changes do not take effect in a running session. After installing the plugin, editing `hooks.json`, or running `/autocode:init`, restart Claude Code (or run `/reload-plugins` for plugin-only changes) before relying on hook behavior.

## Hook I/O Decision

This section records the verified facts the hook architecture is built on (checked against the official hooks reference at code.claude.com/docs/en/hooks). If a hook ever appears to do nothing, re-verify against this table first.

### How hook output reaches Claude

| Mechanism | Events where it works | Used by autocode |
|-----------|----------------------|------------------|
| Plain stdout added to context | `UserPromptSubmit`, `SessionStart` only. **Not** `PreToolUse`, **not** `SubagentStop`; their stdout is shown in transcript mode at most | Nothing (this was the v1 bug: `load-context.sh` echoed XML that never reached the agent) |
| `hookSpecificOutput.updatedInput` (JSON on stdout) | `PreToolUse`; rewrites the intercepted tool call's input | `load-context.sh` appends handoff context to the Task `prompt` field |
| `additionalContext` (JSON on stdout) | Documented as a common output field; reaches Claude's context | `on-agent-complete.sh` emits `<agent-completed>`, `<artifact-audit>`, and context-limit signals |
| `systemMessage` (JSON on stdout) | All events; shown to the user, not the model | `on-agent-complete.sh` artifact warnings |
| Exit 2 with stderr | `PreToolUse` (blocks the call), `PostToolUse` (cannot block, stderr is fed to Claude as feedback), `SubagentStop` (prevents the stop) | `check-edit.sh` uses PostToolUse exit 2 for per-edit analysis feedback |

**Context injection decision:** handoff context is injected on `PreToolUse` for the `Task` tool via `updatedInput`, because that is the only documented way to alter what a spawned subagent sees at spawn time. The full `tool_input` object is emitted with the modified `prompt` (merge semantics for partial objects are not documented, so nothing is left to merging). Fallback behavior: if `jq` is missing, the payload is not JSON, or `read-handoff.sh` produces nothing, the hook exits 0 and the agent is spawned with its original prompt; the task-runner then loads handoff files from disk itself (Step 1), so injection is an optimization, not a correctness requirement.

### Stdin JSON schemas (per event, as consumed)

Every hook receives one JSON object on stdin. Fields autocode parses:

**PreToolUse** (`load-context.sh`, `log-skill-usage.sh`):

```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "hook_event_name": "PreToolUse",
  "tool_name": "Task",
  "tool_input": {
    "subagent_type": "autocode:task-runner",
    "prompt": "Execute task\n\nSPEC_DIR=.specs/...",
    "description": "..."
  }
}
```

Parsed with `jq` first (`.tool_name`, `.tool_input.subagent_type`, `.tool_input.prompt`); text matching (the `SPEC_DIR=` pattern) is applied only to the prompt string, never to the raw payload.

**PostToolUse** (`check-edit.sh`):

```json
{
  "session_id": "...",
  "transcript_path": "...",
  "cwd": "...",
  "hook_event_name": "PostToolUse",
  "tool_name": "Edit",
  "tool_input": { "file_path": "/abs/path/to/file" },
  "tool_output": "..."
}
```

Only `.tool_input.file_path` is consumed.

**SubagentStop** (`on-agent-complete.sh`):

```json
{
  "session_id": "...",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "...",
  "hook_event_name": "SubagentStop",
  "agent_type": "autocode:task-runner",
  "stop_hook_active": false
}
```

The payload does **not** include the subagent's output. The agent name comes from `agent_type` (with a transcript fallback for older CLIs), and the agent's final output is recovered from the transcript JSONL at `transcript_path` (most recent sidechain assistant entry, falling back to the most recent Task tool result).

### Failure observability

Any hook that receives an unparseable payload, or hits a missing dependency it cannot work around, appends a JSONL record to `${CLAUDE_PLUGIN_DATA}/hook-errors.jsonl` (`timestamp`, `hook`, `reason`, truncated `payload`) instead of failing silently. Hooks always exit 0 on internal errors; only `check-edit.sh` intentionally exits 2, and only to deliver analysis feedback.

## Hook Lifecycle

| Hook Type | Matcher | Script | Timeout | Purpose |
|-----------|---------|--------|---------|---------|
| **PreToolUse** | `Task` | `load-context.sh` | 10s | Append handoff context to the spawned agent's prompt via `updatedInput` |
| **PreToolUse** | `Task` | `log-skill-usage.sh` | 5s | Log agent spawns to `usage.jsonl` |
| **PostToolUse** | `Write\|Edit\|MultiEdit` | `check-edit.sh` | 60s | Run per-file static analysis on each edit; exit 2 feeds errors back to Claude |
| **SubagentStop** | (none; the event takes no matcher, the script self-filters) | `on-agent-complete.sh` | 60s | Detect completion/failure, audit artifacts, check context limits |

All hooks are defined in `plugins/autocode/hooks/hooks.json`, referenced from `plugin.json`, and use `${CLAUDE_PLUGIN_ROOT}` so commands resolve to absolute paths.

## Hook Scripts

### `load-context.sh` (PreToolUse on Task)

Fires before each autocode Task agent is spawned.

**Activation guard:** `tool_name == "Task"` and `tool_input.subagent_type` starting with `autocode:`. Exits silently otherwise.

**Process:**
1. Validates the stdin payload is JSON (logs to `hook-errors.jsonl` if not)
2. Extracts `SPEC_DIR` from `tool_input.env.SPEC_DIR`, then the `SPEC_DIR=` pattern in the prompt, then a `.specs/<id>` path match
3. Runs `read-handoff.sh <spec_dir>` for the condensed handoff context (about 200 tokens: previous task, decisions, next task, progress)
4. Emits `hookSpecificOutput.updatedInput` with the context appended to the Task prompt

### `log-skill-usage.sh` (PreToolUse on Task)

Logs agent spawn events to `${CLAUDE_PLUGIN_DATA}/usage.jsonl` via `scripts/log-usage.sh`. Requires `CLAUDE_PLUGIN_DATA` and `jq`; logs unparseable payloads to `hook-errors.jsonl`.

### `check-edit.sh` (PostToolUse on Write|Edit|MultiEdit)

The per-edit quality gate. Resolves a per-file analysis command from `.claude/autocode.yml` (`static_analysis.on_edit.command`, falling back to the first simple string in `static_analysis.commands`), runs it against the edited file, and exits 2 with the error output on failure so Claude fixes the problem immediately. The analyzer agent still performs the full-project pass during the execute loop.

**Configuration:** gated by `static_analysis.on_edit.enabled` (default on; set `false` for slow linters). Skips files under `.specs/` and `.claude/`.

### `on-agent-complete.sh` (SubagentStop)

Fires on every subagent stop; self-filters to `autocode:*` agents.

**Process:**
1. Recovers the agent name (`agent_type` field, transcript fallback) and final output (transcript JSONL)
2. Parses the structured `<task-completed>` tag (contract: `plugins/autocode/references/failure-categories.md`)
3. On failure: logs to `failures.jsonl` with the tag's `category` as a deterministic backstop
4. On completion by a task-runner: audits `{SPEC_DIR}/artifacts/` for a non-empty `handoff.md` and non-empty `{task_id}_*` files; emits an `<artifact-audit>` warning (and a user-visible `systemMessage`) when the trail is missing or incomplete
5. Optionally runs `judge-artifacts.mjs` (see below)
6. Runs `check-context.sh` and emits `<context-warning>` or `<context-critical>` when usage is high
7. Emits everything as one JSON object: `additionalContext` (for Claude) plus `systemMessage` (for the user)

**Output tags (inside additionalContext):**

| Tag | Meaning |
|-----|---------|
| `<agent-completed>` | Agent finished (always emitted for completed autocode agents) |
| `<artifact-audit status="missing\|incomplete\|insubstantial">` | Audit trail problem for the completed task |
| `<context-warning>` / `<context-critical>` | Context usage thresholds crossed |

### `judge-artifacts.mjs` (optional, called by on-agent-complete.sh)

A read-only Agent SDK call (`allowedTools: ["Read", "Glob"]`) that judges whether the completed task's artifacts are substantive or template stubs, returning `{"pass": bool, "reason": "..."}`. Gated by `artifact_judge.enabled` in `autocode.yml` (default **off**: costs tokens and requires `node` with `@anthropic-ai/claude-agent-sdk`). Every failure mode degrades to pass so a missing SDK never blocks the loop.

## Supporting Scripts

### `check-context.sh`

Estimates context token usage by measuring file sizes across spec files, artifacts, and rules. Always exits 0 and prints a single line: `OK:<tokens>`, `WARNING:context_limit:<tokens>`, or `CRITICAL:context_limit:<tokens>` (warning at 150k, critical at 200k; 4 chars per token plus 30% overhead).

### `read-handoff.sh`

Standalone utility that assembles the condensed handoff context (`<handoff-context>`, `<current-task>`, `<progress-summary>` blocks). Used by `load-context.sh` but callable directly: `read-handoff.sh <spec_dir>`.

## Configuration

Hooks read configuration from `.claude/autocode.yml`:

| Key | Default | Used By |
|-----|---------|---------|
| `static_analysis.on_edit.enabled` | `true` | `check-edit.sh` toggle |
| `static_analysis.on_edit.command` | (empty; falls back to first `commands:` entry) | `check-edit.sh` per-file command |
| `artifact_judge.enabled` | `false` | `on-agent-complete.sh` SDK judge gate |

## Adding New Hooks

1. Create a shell script in `plugins/autocode/hooks/`
2. Add a matcher/hooks entry under the appropriate lifecycle type in `hooks.json`
3. Parse documented JSON stdin fields with `jq` first; fall back to text matching only for values embedded inside a field; log unparseable payloads to `${CLAUDE_PLUGIN_DATA}/hook-errors.jsonl`
4. To reach the model, emit JSON output (`updatedInput` for PreToolUse, `additionalContext` otherwise, exit 2 stderr for PostToolUse feedback); plain stdout does not enter context for these events
5. Exit 0 on internal errors; hooks must never block the loop accidentally
6. Restart Claude Code (or `/reload-plugins`) to pick up the change, then verify with a debug hook (`jq . > /tmp/hook-payload.json` pattern) before writing logic

## Related Documentation

- [Agent Handoff](agent-handoff.md)
- [Agent Architecture](agent-architecture.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Configuration](configuration.md)
