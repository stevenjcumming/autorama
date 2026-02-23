# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] - 2026-02-23

### Changed

- **Agent Harness refactored** — `execute.md` command now owns the task loop directly instead of delegating to intermediate orchestrator agents, with fresh context per task to prevent quality degradation on multi-task specs
- **Artifact system reduced from 7 to 6 types** — Removed signals; remaining types are justifications, decisions, assumptions, risks, debt, and review hints
- **Trigger-based artifact generation** — Artifacts are now generated only when specific trigger conditions are met, driven by `autopilot.yml` config instead of being mandatory for every task
- **Dedicated artifact generation step in task-runner** — Task-runner generates all artifact types directly from TDD context with an `<artifacts-generated>` completion tag for observability
- **Workflow pipeline reduced from 8 to 7 stages** — Removed Reflect; review now flows directly to Submit
- **Handoff generation uses `handoff-writer` agent** — Replaced inline shell-generated handoff with a richer context-aware agent-based approach
- **Justifications always enabled** — Removed the `is_justification_enabled` config toggle; justifications run unconditionally on file modifications
- **Plugin root env var bootstrapped via `/autopilot:init`** — Commands and agents now use `AUTOPILOT_PLUGIN_ROOT` set as a real env var instead of relying on `$CLAUDE_PLUGIN_ROOT`

### Added

- **`/autopilot:help` command** — Displays all available commands in workflow order with a typical workflow summary
- **`commit.sh` hook registered** — Added as a PostToolUse hook on `Write|Edit|Bash` in `hooks.json`
- **`generate-report.sh` integrated** — Called by `/autopilot:review` to produce a `SUMMARY.md` with artifact counts, deferred issues, and review hints

### Removed

- **Signals artifact type** — Removed signal generation from all agents, deleted the signal template, and removed `signals/` from artifact directory setup and report generation
- **Reflect stage** — Removed the `/autopilot:reflect` command, `reflect.sh` script, `rules-builder` agent, and `evaluate-signals.sh` script
- **`artifact-prompt.sh` hook** — Artifact generation now handled entirely by the task-runner's dedicated artifact step
- **`/autopilot:pause-autopilot` command** — Removed the pause command and related scripts/templates
- **Deprecated agent stubs** — Deleted the `autopilot.md` and `loop-controller.md` agents superseded by `execute.md`

### Fixed

- **Artifact justifications now filled in** — Task-runner fills empty sections after sub-agents complete instead of relying on unreachable hook stdout
- **Handoff generation between task-runner instances** — Fixed `$STATE_FILE` reference and race condition fallback in `on-agent-complete.sh`
- **Multiple hook bugs** — Fixed subshell `return` scope, duplicate prompt cache using per-process PID, `get_category` return code check, indented task validation, and auto-commit missing untracked files
- **Documentation accuracy** — Corrected template locations, hook references, and removed references to non-functional config options

## [0.11.0] - 2026-02-21

### Changed

- **Agent Harness refactored** — `execute.md` command now owns the task loop directly instead of delegating to intermediate orchestrator agents, reducing context accumulation across tasks
- **Fresh context per task** — Each task spawns a fresh `autopilot-task-runner` agent with its own clean context window, preventing quality degradation on multi-task specs
- **Skills loading moved** — Skill description loading relocated from the deprecated `autopilot` agent to `autopilot-task-runner` (Step 1.5), keeping skill context scoped per task

### Removed

- Removed `autopilot.md` and `loop-controller.md` from the registered agents list in `plugin.json` (14 → 12 registered agents)

## [0.10.0] - 2025-02-19

Initial public release of Autopilot -- a Claude Code plugin for AI-autonomous software development with structured workflows and human oversight guardrails.

> **Note:** This is version 0.10.0 (not 1.0.0) because the plugin has not been fully tested.

### Added

- **7 workflow stages**: Spec, Plan, Tasks, Autopilot, Review, Submit, Skills
- **8 slash commands**: `/new-spec`, `/create-plan`, `/create-tasks`, `/execute`, `/review`, `/commit`, `/sync-pr`, `/init`
- **14 specialized agents** across three model tiers (opus, sonnet, haiku) for planning, coding, testing, analysis, refactoring, and context management
- **Agent Harness architecture** with hook-based orchestration, background task execution, and sequential queue processing
- **Agent handoff system** with handoff.md, session summarization, and pause/resume state preservation
- **Hook system** with PreToolUse (context loading), PostToolUse (state saving), and SubagentStop (auto-commit, handoff generation, context limit checks)
- **7 artifact types**: justifications, decisions, assumptions, risks, debt, review hints, signals
- **Justification system** requiring written rationale for modifications to flagged file categories (tests, migrations, dependencies, config, API, security)
- **Evaluation pipeline** with artifact generation and structured review checklist
- **Signals feedback loop**: test failures become signals, signals inform future tasks
- **Configuration** via `.claude/autopilot.yml` for agent overrides, skills, loop behavior, auto-commit, handoff, justification categories, and static analysis
- **17 utility scripts**, **14 templates**, and **21 documentation files**
