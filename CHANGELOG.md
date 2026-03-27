# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.14.0] - 2026-03-27

### Added

- **Code review workflow docs** (`docs/workflow-stages/07_code_review.md`) — Covers command usage with all argument combinations, full review process flow (diff → checklist → agent → report), severity level definitions with examples, checklist configuration (3-tier priority resolution), custom reviewer agent section (why, how, input contract, example), and comparison table between `/autopilot:code-review` vs `/autopilot:review`

### Changed

- **Renumbered submit docs** — `07_submit.md` → `08_submit.md` to accommodate the new code review stage
- **Updated evaluation pipeline docs** (`docs/evaluation_pipeline.md`) — Fixed submit link and added code review doc reference

## [0.13.0] - 2026-03-26

### Changed

- **Updated README** — Improved "Quick Start" steps
- **handoff-writer agent removed** — `handoff.md` is now written directly by `autopilot-task-runner` (Step 8) instead of spawning a separate agent; `on-agent-complete.sh` no longer emits `<handoff-needed>` signals
- **task-builder agent removed** — The `create-tasks` command now reads `PLAN.md` and writes `TODO.md` directly (inline) instead of spawning a `task-builder` subagent
- **Conventional commits for auto-commits** — `on-agent-complete.sh` now generates commits following the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) spec with a required body for long-term context. The commit type (feat, fix, refactor, test, etc.) is chosen by the task-runner and passed via the `type` attribute on `<task-completed>` tags
- **Task-runner outputs commit type** — `<task-completed>` tag now includes `type="{commit_type}"` attribute; the task-runner evaluates what the task did and selects the appropriate conventional commit type
- **`/autopilot:commit` reads conventional commits reference** — The commit command now reads `agents/references/conventional-commits.md` before creating commits, ensuring consistent format with required body

### Added

- **`conventional-commits.md` reference** — Progressive disclosure reference at `agents/references/` with commit structure, type table, scope rules, body guidelines, and examples. Used by the commit command and task-runner
- Add LICENSE.md — Add MIT license

### Removed

- **`commit.sh` hook removed** — The PostToolUse hook on `Write|Edit|Bash` that emitted `<skill-invoke skill="commit">` directives has been deleted. It was counterproductive: subagents couldn't act on skill invocations, wasting context tokens. Auto-commits are handled solely by `on-agent-complete.sh` (SubagentStop)
- **`auto_commit.message_template` config removed** — The configurable commit template in `autopilot.yml` has been replaced by the standardized conventional commits format. Removed from `on-agent-complete.sh`, docs, and config references
- **Co-Authored-By trailer removed** — Auto-commits no longer append `Co-Authored-By: Claude` footer; users can configure this via their git config and Claude settings
- **Delete single_task_mode references** — Removed references to `single_task_mode` from README.md and docs

## [0.12.1] - 2026-02-23

### Fixed

- **Agent names properly scoped with plugin prefix** — All `subagent_type` references in Task calls now use fully qualified names (e.g., `autopilot:autopilot-task-runner` instead of `autopilot-task-runner`) across commands, agents, and config templates

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
