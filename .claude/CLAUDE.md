# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Autopilot is a Claude Code plugin for AI-autonomous software development. It provides a structured framework with workflows, slash commands, and specialized agents for running safe development loops with human oversight.

## Architecture

### Workflow Pipeline

```
Requirements → Spec → Plan → Tasks → Write Tests → Red → Code → Green → Analysis → Refactor → Review → Reflect → Submit
```

The following stages have been implemented:

1. **Spec** (`/autopilot:new-spec`) - Creates spec folder with REQUIREMENT.md and SPEC.md
2. **Plan** (`/autopilot:create-plan`) - Generates PLAN.md using research and analysis agents
3. **Tasks** (`/autopilot:create-tasks`) - Converts plan into phased TODO.md checklist
4. **Autopilot** (`/autopilot:execute`) - Executes TDD loop (Write Tests → Red → Code → Green → Analysis → Refactor) autonomously
5. **Review** (`/autopilot:review`) - Generates review summary of changes and artifacts
6. **Reflect** (`/autopilot:reflect`) - Analyzes session signals and proposes rules
7. **Submit** (`/autopilot:commit`, `/autopilot:sync-pr`) - Creates commits and syncs with GitHub PRs

### Directory Structure

```
plugins/autopilot/
├── commands/       # Slash command definitions (frontmatter + instructions)
├── agents/         # Agent instruction files (spawned via Task tool)
├── scripts/        # Shell scripts for setup/validation
├── hooks/          # Hook system for agent harness
└── templates/      # Templates for generated files
    └── artifacts/
        ├── handoff/
        └── state/
docs/               # Documentation
.claude-plugin/     # Marketplace manifest
```

### Command Pattern

Commands follow a consistent pattern:
1. **Script** creates template files and validates prerequisites
2. **Agent** is spawned via Task tool to do the work
3. **Command** orchestrates the script + agent

### Agent Composition

Agents can spawn sub-agents for specialized tasks:
- `plan-builder` spawns `plan-researcher` and `plan-analyzer`
- `loop-controller` spawns `autopilot-task-runner` for each task
- `autopilot-task-runner` spawns `autopilot-tester` (writes tests), then runs tests via Bash, spawns `autopilot-coder` (with test files), runs tests via Bash again, then `autopilot-analyzer` and `autopilot-refactorer`
- `handoff-writer` generates handoff artifacts after task completion
- `session-summarizer` compresses context when approaching limits
- Agents use `model: opus`, `model: sonnet`, or `model: haiku` in frontmatter

### Agent Harness Architecture

The autopilot system uses a hook-based Agent Harness architecture with TDD discipline:

```
/autopilot:execute
    └── Loop Controller
            │
            ├── PreToolUse Hook: load-context.sh
            │   └── Loads TODO.md, handoff.md
            │
            ├── Task Agent (background)
            │   └── autopilot-task-runner
            │       ├── 1. tester (writes tests)
            │       ├── 2. Bash: run tests → expect RED (fail)
            │       ├── 3. coder (implements to satisfy tests)
            │       ├── 4. Bash: run tests → expect GREEN (pass)
            │       ├── 5. analyzer (static analysis)
            │       └── 6. refactorer (cleanup)
            │
            └── PostToolUse Hook: save-state.sh
                └── Updates TODO.md, writes handoff.md, commits
```

Key components:
- **loop-controller** - Orchestrates the agent loop until all tasks complete
- **autopilot-task-runner** - Executes a single task with TDD loop (write tests → red → code → green → analyze → refactor)
- **autopilot-tester** - Writes tests based on task requirements (does not run them)
- **autopilot-coder** - Implements code to satisfy pre-written tests
- **handoff-writer** - Generates handoff.md for context preservation
- **session-summarizer** - Compresses context when approaching token limits
- **Hooks** - PreToolUse loads context, PostToolUse saves state and commits

## Slash Commands

| Command | Purpose |
|---------|---------|
| `/autopilot:new-spec <id>` | Create new spec folder |
| `/autopilot:create-plan <id>` | Generate implementation plan from spec |
| `/autopilot:create-tasks <id>` | Convert plan to TODO checklist |
| `/autopilot:execute <path>` | Execute TDD loop (Write Tests/Red/Code/Green/Analysis/Refactor) for a spec |
| `/autopilot:pause-autopilot <id>` | Pause autopilot and save current state |
| `/autopilot:review <id>` | Generate review summary of changes and artifacts |
| `/autopilot:reflect <id>` | Analyze session signals and propose rules |
| `/autopilot:commit` | Create a commit with conventional commit message |
| `/autopilot:sync-pr` | Create or update PR for current branch |

## Frontmatter Requirements

Commands and agents require YAML frontmatter with specific fields:

**Commands** (`plugins/autopilot/commands/*.md`):
```yaml
---
description: Short description for command list
allowed-tools: Bash(bash $CLAUDE_PLUGIN_ROOT/scripts/example.sh:*), Read, Task
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

Respond immediately to any `<*-required>` XML prompts from hooks (e.g., `<justification-required>`). Follow the instructions within the prompt, then edit the output file specified.
