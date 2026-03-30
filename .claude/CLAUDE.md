# CLAUDE.md

## Data Persistence

The plugin uses `${CLAUDE_PLUGIN_DATA}` for cross-session and cross-spec persistence:

- `usage.jsonl` — Event log of command/agent invocations (logged via `log-skill-usage.sh` hook)
- `failures.jsonl` — Failure patterns for cross-spec learning (logged by task-runner on failure)
- Scripts: `log-usage.sh`, `log-failure.sh`, `read-history.sh`

## Frontmatter Requirements

Commands and agents require YAML frontmatter with specific fields:

**Commands** (`plugins/autopilot/commands/*.md`):
```yaml
---
description: Trigger condition describing WHEN to use this command (not a summary)
allowed-tools: Bash(bash $AUTOPILOT_PLUGIN_ROOT/scripts/example.sh:*), Read, Task
argument-hint: [identifier]
model: opus  # optional
---
```

**Agents** (`plugins/autopilot/agents/*.md`):
```yaml
---
name: agent-name
description: When Claude should delegate to this subagent
tools: Read, Edit, Task  # optional, inherits all if omitted
disallowedTools: Write  # optional, tools to deny
model: sonnet  # sonnet, opus, haiku, or inherit
permissionMode: default  # default, acceptEdits, dontAsk, bypassPermissions, plan
skills: skill-name  # skills to load into subagent context
---
```

Key differences:
- Commands: no `name` field, use `allowed-tools`, use `argument-hint` for expected args
- Agents: require `name`, use `tools` (not `allowed-tools`), can specify `permissionMode` and `skills`

## Artifacts

Artifacts are generated per spec in the user's project at `.claude/specs/<SPEC_ID>/artifacts/`. The plugin provides artifact templates at `plugins/autopilot/templates/artifacts/`.

Artifact template files (justifications, risks, etc.) are created on disk by the PostToolUse hook. The `task-runner` fills these in after sub-agents complete their work (Step 2.6).
