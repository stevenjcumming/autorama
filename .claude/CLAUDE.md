# CLAUDE.md

## Data Persistence

The plugin uses `${CLAUDE_PLUGIN_DATA}` for cross-session and cross-spec persistence:

- `usage.jsonl`: Event log of agent spawns (logged via the `log-skill-usage.sh` PreToolUse hook on Task calls)
- `failures.jsonl`: Failure patterns for cross-spec learning (logged by task-runner on failure)
- Scripts: `log-usage.sh`, `log-failure.sh`, `read-history.sh`

## Frontmatter Requirements

Skills and agents require YAML frontmatter with specific fields:

**Skills** (`plugins/autocode/skills/<name>/SKILL.md`):
```yaml
---
name: skill-name
description: Trigger condition describing WHEN to use this skill (not a summary)
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/example.sh:*), Read, Task
argument-hint: [identifier]
model: opus  # optional
---
```

**Agents** (`plugins/autocode/agents/*.md`):
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
- Skills: use `allowed-tools` and `argument-hint`; supporting files live in the skill's directory
- Agents: use `tools` (not `allowed-tools`), can specify `permissionMode` and `skills`

## Model Selection

`plugins/autocode/docs/MODEL_SELECTION.md` is the canonical reference for which model each agent/skill runs on. Fixed roles pin `model` in frontmatter and never receive a `model` parameter from callers. Dynamic roles (plan-builder, coder, reviewer) pin `opus` as a fail-up safe default; the orchestrating skill computes the actual tier from the P/C/R decision tables and passes it on the Task call. When editing frontmatter `model` fields or Task spawn instructions, keep them consistent with that doc; the tables are restated inline in the skills that apply them, and any change starts in MODEL_SELECTION.md.

## Artifacts

Artifacts are generated per spec in the user's project at `.specs/<SPEC_ID>/artifacts/`. The plugin provides artifact templates at `plugins/autocode/templates/artifacts/`.

Artifact directories are created by `scripts/setup-artifacts.sh` (run by the execute skill and again, idempotently, by the task-runner). The `task-runner` writes and fills artifact files itself (Step 6: Generate Artifacts). The SubagentStop hook (`on-agent-complete.sh`) then audits that the trail exists and emits a structured warning when it is missing. The only PostToolUse hook is `check-edit.sh` (per-edit static analysis); it does not create artifacts.
