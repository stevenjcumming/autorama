# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Autopilot is a Claude Code plugin for AI-autonomous software development. It provides a structured framework with workflows, slash commands, and specialized agents for running safe development loops with human oversight.

## Architecture

### Workflow Pipeline

```
Requirements → Spec → Plan → Tasks → Write Tests → Red → Code → Green → Analysis → Refactor → Review → Submit
```

The following stages have been implemented:

1. **Spec** (`/autopilot:new-spec`) - Creates spec folder with REQUIREMENT.md and SPEC.md
2. **Plan** (`/autopilot:create-plan`) - Generates PLAN.md using research and analysis agents
3. **Tasks** (`/autopilot:create-tasks`) - Converts plan into phased TODO.md checklist
4. **Autopilot** (`/autopilot:execute`) - Executes TDD loop (Write Tests → Red → Code → Green → Analysis → Refactor) autonomously
5. **Review** (`/autopilot:review`) - Generates review summary of changes and artifacts
6. **Submit** (`/autopilot:commit`, `/autopilot:sync-pr`) - Creates commits and syncs with GitHub PRs

### Directory Structure

```
plugins/autopilot/
├── commands/       # Slash command definitions (frontmatter + instructions)
├── agents/         # Agent instruction files (spawned via Task tool)
│   └── references/ # Reference docs for progressive disclosure (read on-demand by agents)
├── scripts/        # Shell scripts for setup/validation/persistence
├── hooks/          # Hook system for agent harness
└── templates/      # Templates for generated files
    └── artifacts/
        ├── handoff/
        └── state/
docs/               # Documentation
.claude-plugin/     # Marketplace manifest
```

### Progressive Disclosure via References

Agents use progressive disclosure to keep their initial prompt lean. Detailed reference material (framework tables, parsing rules, artifact triggers) lives in `agents/references/` and agents read these files on-demand:

- `references/test-frameworks.md` — Framework detection, run commands, syntax checks, file conventions
- `references/artifact-triggers.md` — Trigger conditions, file categories, justification questions, path patterns
- `references/analysis-parsing.md` — Output format detection, JSON/text parsing, severity mapping, fix suggestions
- `references/failure-categories.md` — Test failure categories, retryability, refactoring criteria, safe refactorings
- `references/conventional-commits.md` — Commit message format, types, scope, body guidelines, examples

### Data Persistence

The plugin uses `${CLAUDE_PLUGIN_DATA}` for cross-session and cross-spec persistence:

- `usage.jsonl` — Event log of command/agent invocations (logged via `log-skill-usage.sh` hook)
- `failures.jsonl` — Failure patterns for cross-spec learning (logged by task-runner on failure)
- Scripts: `log-usage.sh`, `log-failure.sh`, `read-history.sh`

### Command Pattern

Commands follow a consistent pattern:
1. **Script** creates template files and validates prerequisites
2. **Agent** is spawned via Task tool to do the work
3. **Command** orchestrates the script + agent

### Agent Composition

Agents can spawn sub-agents for specialized tasks:
- `plan-builder` spawns `plan-researcher` and `plan-analyzer`
- `execute.md` (command) spawns a fresh `autopilot-task-runner` for each task
- `autopilot-task-runner` spawns `autopilot-tester` (writes tests), then runs tests via Bash, spawns `autopilot-coder` (with test files), runs tests via Bash again, then `autopilot-analyzer` and `autopilot-refactorer`. It also writes `handoff.md` directly before exiting.
- `session-summarizer` compresses context when approaching limits
- `create-tasks` command converts PLAN.md to TODO.md inline (no subagent)
- Agents use `model: opus`, `model: sonnet`, or `model: haiku` in frontmatter

### Agent Harness Architecture

The autopilot system uses a hook-based Agent Harness architecture with TDD discipline:

```
/autopilot:execute (command — lightweight loop owner)
    │
    ├── Step 3: setup-artifacts.sh + build-task-queue.sh
    │
    ├── Step 4: Task Loop (for each task in queue)
    │   │
    │   ├── Spawn fresh Task(autopilot-task-runner) per task
    │   │   │
    │   │   ├── PreToolUse Hook: load-context.sh
    │   │   │   └── Loads TODO.md, handoff.md
    │   │   │
    │   │   ├── autopilot-task-runner (clean context)
    │   │   │   ├── 1. tester (writes tests)
    │   │   │   ├── 2. Bash: run tests → expect RED (fail)
    │   │   │   ├── 3. coder (implements to satisfy tests)
    │   │   │   ├── 4. Bash: run tests → expect GREEN (pass)
    │   │   │   ├── 5. analyzer (static analysis)
    │   │   │   ├── 6. refactorer (cleanup)
    │   │   │   └── 7. writes handoff.md directly
    │   │   │
    │   │   └── SubagentStop Hook: on-agent-complete.sh
    │   │       └── Checks context limits
    │   │
    │   └── Parse <task-completed> / <task-failed> status
    │
    └── Step 5: Present final summary
```

Key components:
- **execute.md** - Lightweight loop owner; spawns fresh task-runners
- **autopilot-task-runner** - Executes a single task with TDD loop (write tests → red → code → green → analyze → refactor → handoff) in a fresh context
- **autopilot-tester** - Writes tests based on task requirements (does not run them)
- **autopilot-coder** - Implements code to satisfy pre-written tests
- **session-summarizer** - Compresses context when approaching token limits
- **Hooks** - PreToolUse loads context, SubagentStop checks context limits

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/autopilot:new-spec <id>` | Create new spec folder |
| `/autopilot:create-plan <id>` | Generate implementation plan from spec |
| `/autopilot:create-tasks <id>` | Convert plan to TODO checklist |
| `/autopilot:execute <path>` | Execute TDD loop (Write Tests/Red/Code/Green/Analysis/Refactor) for a spec |
| `/autopilot:review <id>` | Generate review summary of changes and artifacts |
| `/autopilot:commit` | Create a commit with conventional commit message |
| `/autopilot:sync-pr` | Create or update PR for current branch |

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

## Key Files

- `docs/workflows/*.md` - User-facing documentation for each workflow step
- `plugins/autopilot/agents/*.md` - Agent instructions with frontmatter
- `plugins/autopilot/commands/*.md` - Command definitions with frontmatter
- `plugins/autopilot/plugin.json` - Plugin manifest

## Artifacts

Artifacts are generated per spec in the user's project at `.claude/specs/<SPEC_ID>/artifacts/`. The plugin provides artifact templates at `plugins/autopilot/templates/artifacts/`.

Artifact template files (justifications, risks, etc.) are created on disk by the PostToolUse hook. The `autopilot-task-runner` fills these in after sub-agents complete their work (Step 2.6).
