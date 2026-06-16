# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.0] - 2026-06-12

### Breaking changes

- **Commands removed in favor of skills**: the `commands/` directory is gone; every former command now lives at `skills/<name>/SKILL.md`. User invocation is unchanged (`/autocode:execute` still works), but anything referencing `plugins/autocode/commands/*.md` paths, or installing around the old layout, must update. The code review checklist moved with its owner: `templates/code-review-checklist.md` is now `skills/code-review/code-review-checklist.md`.
- **Structured failure tag schema**: the task-runner failure tag gained required attributes: `<task-completed task="..." status="failed" category="setup|syntax|timeout|runtime|missing|assertion|unknown" retryable="true|false" reason="..." />`, preceded by a required body with partial results and suggested alternatives. Anything parsing the old two-attribute failure tag breaks. The contract is defined once in `agents/references/failure-categories.md`.
- **Execute loop continuation policy**: the loop no longer halts on the first task failure. `category=setup` stops the loop; any other failure skips only same-phase and dependent tasks and continues independent ones. Automation that relied on "first failure stops everything" must read the new final summary (Completed / Failed / Skipped sections) instead. A missing or unparseable `<task-completed>` tag is now explicitly treated as `status=failed category=unknown`.
- **Tightened agent tools**: coder lost `Bash`; tester lost `Edit` and its `Bash` is scoped to syntax-check commands; analyzer lost `Write`; reviewer lost `Bash`; refactorer disallows `Write`; plan-researcher lost `Bash(find:*)`; task-runner lost `Grep`. Workflows that depended on the previously broad tool access may be affected. Skills got the same treatment (Bash scoped to the specific plugin scripts each one runs).
- **Hook overhaul**: `load-context.sh` now injects handoff context by rewriting the Task prompt via `hookSpecificOutput.updatedInput` (PreToolUse stdout never reached model context; the old echo-XML path was dead). `on-agent-complete.sh` emits JSON (`additionalContext`/`systemMessage`) instead of plain stdout, audits the artifact trail for completed tasks, and logs failures with the tag's category. A new PostToolUse hook (`check-edit.sh`, matcher `Write|Edit|MultiEdit`) runs per-file static analysis and exits 2 with the errors, gated by `static_analysis.on_edit` in autocode.yml (default on).

### Added

- **Per-edit quality gate** (`hooks/check-edit.sh`) with `static_analysis.on_edit.enabled` / `.command` config keys
- **Optional artifact substance judge** (`hooks/judge-artifacts.mjs`): a read-only Agent SDK call gated by `artifact_judge.enabled` (default off; costs tokens and requires node)
- **Hook error observability**: all hooks log unparseable payloads to `${CLAUDE_PLUGIN_DATA}/hook-errors.jsonl` instead of failing silently
- **Scaled code review**: diffs over 10 files or 1000 changed lines split into parallel per-group reviewer passes plus a cross-file integration pass
- **Re-review support**: the reviewer accepts `PREVIOUS_FINDINGS` and reports only new or unaddressed issues; the code-review skill passes any existing report automatically
- **Severity calibration examples**: one concrete code example per severity level in the code review checklist
- **Verbatim Facts block** leading `handoff.md` and `SESSION_SUMMARY.md` (spec ID, task ID, test command, paths, failure categories) so identifiers survive summarization
- **Task-runner retry refinements**: the analysis fix loop passes the specific error text and prior failed fix to the coder; a fixability check escalates spec problems instead of burning retries
- **CLAUDE.md config import**: init offers to append an `@.claude/autocode.yml` import to the project CLAUDE.md
- **Docs**: `github-integration.md` (GitHub app setup, shared checklist, `allowed_tools` warning), settings bootstrap reference in `configuration.md`, hook I/O decision record in `hook-system.md`, context hygiene guidance in the usage guide and help skill

### Changed

- **Agent descriptions rewritten as trigger conditions** ("When the task-runner needs...") for reliable delegation
- **Restart requirement documented**: init ends by telling the user to restart Claude Code for hooks and settings to take effect
- **Review command writes REVIEW.md**: `/autocode:review` now persists its findings to `REVIEW.md` instead of only printing them
- **Script hardening**: identifier validation on user-supplied spec/task IDs, safe archive moves (no destructive overwrites), and valid JSONL escaping in the usage and failure logs
- **Template standardization**: all artifact templates now carry `title:` and `date:` frontmatter (replacing `timestamp:`); enum conventions unified across templates
- **Plugin manifest moved**: `plugin.json` now lives at `.claude-plugin/plugin.json`, matching the documented plugin layout

### Fixed

- **Hook prefix and SubagentStop payload fixes**: hooks now match the `autocode:` agent prefix correctly and read the SubagentStop payload fields that Claude Code actually sends
- **BSD sed/grep portability**: scripts no longer rely on GNU-only flags, so they run on stock macOS tooling
- **Agent and reference contract alignment**: `ATTEMPT_HISTORY` input, the `<analysis-result>` tag, and the `none` sentinel for `test-command` are now consistent between agents and their reference docs

### Removed

- **Dependency artifact type**: deleted the orphaned `dependency.md` template and the `dependencies/` directory setup; it had no trigger and was excluded from report generation

### Migration

See [docs/autocode/migrating-to-v2.md](../../docs/autocode/migrating-to-v2.md) for the command-to-skill mapping, failure tag changes, and new config toggles.

## [1.0.0-rc.2] - 2026-04-10

### Changed

- **Plugin renamed from `autopilot` to `autocode`**: The development workflow plugin is now `autocode`. The marketplace and umbrella brand remain `autopilot` (`stevenjcumming/autopilot`).
  - Plugin directory: `plugins/autopilot/` → `plugins/autocode/`
  - Slash commands: `/autopilot:*` → `/autocode:*`
  - Environment variable: `AUTOPILOT_PLUGIN_ROOT` → `AUTOCODE_PLUGIN_ROOT`
  - Config file: `autopilot.yml` → `autocode.yml`
  - Spec archive path: `~/.autopilot/specs/` → `~/.autocode/specs/`
  - Validate script: `validate-autopilot.sh` → `validate-autocode.sh`

> **Early adopter note:** If you set `AUTOPILOT_PLUGIN_ROOT` in your shell profile or settings.local.json, rename it to `AUTOCODE_PLUGIN_ROOT`. If you have an existing `.claude/autopilot.yml`, rename it to `.claude/autocode.yml`.

## [1.0.0-rc.1] - 2026-03-30

### Changed

- **Agent names simplified**: Dropped the `autopilot-` prefix from the six execution agents. Updated `name` frontmatter, `plugin.json` paths, `subagent_type` calls, and all documentation.

## [0.15.0] - 2026-03-29

### Removed

- **Agent overrides and skills removed from configuration**: `agents:` and `*_skills:` keys are no longer supported in `autocode.yml`. The built-in agents are now fixed; `AVAILABLE_SKILLS` and skill selection logic removed from `coder` and `task-runner`. Custom reviewer agent support removed from `/autocode:code-review`.

### Added

- **Static Analysis documented in configuration reference**: `docs/configuration.md` now includes a full `### Static Analysis` section covering the config schema, format options (`auto`/`json`/`text`), blocking behavior, per-rule fix attempt tracking, and debt artifact generation.

## [0.14.3] - 2026-03-28

### Removed

- **Auto-commit and state persistence removed**: Deleted `save-state.sh`, the `state/` artifact template directory, and the PostToolUse hook that triggered them. `on-agent-complete.sh` now only checks context limits; `find-active-spec.sh` uses TODO.md as the primary strategy instead of `current.json`. Updated 11 docs to remove all references.

## [0.14.2] - 2026-03-27

### Fixed

- **`/autocode:sync-pr` updates existing PR descriptions**: When a PR already exists for the current branch, the command now updates the existing description rather than rewriting it from scratch

## [0.14.1] - 2026-03-27

### Fixed

- **`/autocode:sync-pr` detects default branch dynamically**: Context now detects the default branch via `gh repo view` instead of hardcoding `main`; added `Bash(gh repo view:*)` to allowed-tools
- **Commits and diff gathered at execution time**: Commits and diff are no longer in the context section (which would fail before the command runs); they're now gathered in step 5 using the detected default branch
- **PR targets correct branch**: `gh pr create` explicitly sets `--base <default-branch>` so the PR targets the right branch

## [0.14.0] - 2026-03-27

### Added

- **Code review workflow docs** (`docs/workflow-stages/07_code_review.md`): Covers command usage with all argument combinations, full review process flow (diff → checklist → agent → report), severity level definitions with examples, checklist configuration (3-tier priority resolution), custom reviewer agent section (why, how, input contract, example), and comparison table between `/autocode:code-review` vs `/autocode:review`

### Changed

- **Renumbered submit docs**: `07_submit.md` → `08_submit.md` to accommodate the new code review stage
- **Updated evaluation pipeline docs** (`docs/evaluation_pipeline.md`): Fixed submit link and added code review doc reference

## [0.13.0] - 2026-03-26

### Changed

- **Updated README**: Improved "Quick Start" steps
- **handoff-writer agent removed**: `handoff.md` is now written directly by `task-runner` (Step 8) instead of spawning a separate agent; `on-agent-complete.sh` no longer emits `<handoff-needed>` signals
- **task-builder agent removed**: The `create-tasks` command now reads `PLAN.md` and writes `TODO.md` directly (inline) instead of spawning a `task-builder` subagent
- **Conventional commits for auto-commits**: `on-agent-complete.sh` now generates commits following the [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) spec with a required body for long-term context. The commit type (feat, fix, refactor, test, etc.) is chosen by the task-runner and passed via the `type` attribute on `<task-completed>` tags
- **Task-runner outputs commit type**: `<task-completed>` tag now includes `type="{commit_type}"` attribute; the task-runner evaluates what the task did and selects the appropriate conventional commit type
- **`/autocode:commit` reads conventional commits reference**: The commit command now reads `agents/references/conventional-commits.md` before creating commits, ensuring consistent format with required body

### Added

- **`conventional-commits.md` reference**: Progressive disclosure reference at `agents/references/` with commit structure, type table, scope rules, body guidelines, and examples. Used by the commit command and task-runner
- Add LICENSE.md: Add MIT license

### Removed

- **`commit.sh` hook removed**: The PostToolUse hook on `Write|Edit|Bash` that emitted `<skill-invoke skill="commit">` directives has been deleted. It was counterproductive: subagents couldn't act on skill invocations, wasting context tokens. Auto-commits are handled solely by `on-agent-complete.sh` (SubagentStop)
- **`auto_commit.message_template` config removed**: The configurable commit template in `autocode.yml` has been replaced by the standardized conventional commits format. Removed from `on-agent-complete.sh`, docs, and config references
- **Co-Authored-By trailer removed**: Auto-commits no longer append `Co-Authored-By: Claude` footer; users can configure this via their git config and Claude settings
- **Delete single_task_mode references**: Removed references to `single_task_mode` from README.md and docs

## [0.12.1] - 2026-02-23

### Fixed

- **Agent names properly scoped with plugin prefix**: All `subagent_type` references in Task calls now use fully qualified names (e.g., `autopilot:task-runner` instead of `task-runner`) across commands, agents, and config templates

## [0.12.0] - 2026-02-23

### Changed

- **Agent Harness refactored**: `execute.md` command now owns the task loop directly instead of delegating to intermediate orchestrator agents, with fresh context per task to prevent quality degradation on multi-task specs
- **Artifact system reduced from 7 to 6 types**: Removed signals; remaining types are justifications, decisions, assumptions, risks, debt, and review hints
- **Trigger-based artifact generation**: Artifacts are now generated only when specific trigger conditions are met, driven by `autocode.yml` config instead of being mandatory for every task
- **Dedicated artifact generation step in task-runner**: Task-runner generates all artifact types directly from TDD context with an `<artifacts-generated>` completion tag for observability
- **Workflow pipeline reduced from 8 to 7 stages**: Removed Reflect; review now flows directly to Submit
- **Handoff generation uses `handoff-writer` agent**: Replaced inline shell-generated handoff with a richer context-aware agent-based approach
- **Justifications always enabled**: Removed the `is_justification_enabled` config toggle; justifications run unconditionally on file modifications
- **Plugin root env var bootstrapped via `/autocode:init`**: Commands and agents now use `AUTOCODE_PLUGIN_ROOT` set as a real env var instead of relying on `$CLAUDE_PLUGIN_ROOT`

### Added

- **`/autocode:help` command**: Displays all available commands in workflow order with a typical workflow summary
- **`generate-report.sh` integrated**: Called by `/autocode:review` to produce a `SUMMARY.md` with artifact counts, deferred issues, and review hints

### Removed

- **Signals artifact type**: Removed signal generation from all agents, deleted the signal template, and removed `signals/` from artifact directory setup and report generation
- **Reflect stage**: Removed the `/autocode:reflect` command, `reflect.sh` script, `rules-builder` agent, and `evaluate-signals.sh` script
- **`artifact-prompt.sh` hook**: Artifact generation now handled entirely by the task-runner's dedicated artifact step
- **`/autocode:pause-autopilot` command**: Removed the pause command and related scripts/templates
- **Deprecated agent stubs**: Deleted the `autopilot.md` and `loop-controller.md` agents superseded by `execute.md`

### Fixed

- **Artifact justifications now filled in**: Task-runner fills empty sections after sub-agents complete instead of relying on unreachable hook stdout
- **Handoff generation between task-runner instances**: Fixed `$STATE_FILE` reference and race condition fallback in `on-agent-complete.sh`
- **Multiple hook bugs**: Fixed subshell `return` scope, duplicate prompt cache using per-process PID, `get_category` return code check, indented task validation, and auto-commit missing untracked files
- **Documentation accuracy**: Corrected template locations, hook references, and removed references to non-functional config options

## [0.11.0] - 2026-02-21

### Changed

- **Agent Harness refactored**: `execute.md` command now owns the task loop directly instead of delegating to intermediate orchestrator agents, reducing context accumulation across tasks
- **Fresh context per task**: Each task spawns a fresh `task-runner` agent with its own clean context window, preventing quality degradation on multi-task specs
- **Skills loading moved**: Skill description loading relocated from the deprecated `autopilot` agent to `task-runner` (Step 1.5), keeping skill context scoped per task

### Removed

- Removed `autopilot.md` and `loop-controller.md` from the registered agents list in `plugin.json` (14 → 12 registered agents)

## [0.10.0] - 2026-02-19

Initial public release of Autopilot

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
- **Configuration** via `.claude/autocode.yml` for agent overrides, skills, loop behavior, auto-commit, handoff, justification categories, and static analysis
- **17 utility scripts**, **14 templates**, and **21 documentation files**

<!-- No git tags exist yet, so version links point to the repository root.
     Once releases are tagged, switch these to compare/tag URLs. -->

[Unreleased]: https://github.com/stevenjcumming/autopilot
[1.0.0-rc.2]: https://github.com/stevenjcumming/autopilot
[1.0.0-rc.1]: https://github.com/stevenjcumming/autopilot
[0.15.0]: https://github.com/stevenjcumming/autopilot
[0.14.3]: https://github.com/stevenjcumming/autopilot
[0.14.2]: https://github.com/stevenjcumming/autopilot
[0.14.1]: https://github.com/stevenjcumming/autopilot
[0.14.0]: https://github.com/stevenjcumming/autopilot
[0.13.0]: https://github.com/stevenjcumming/autopilot
[0.12.1]: https://github.com/stevenjcumming/autopilot
[0.12.0]: https://github.com/stevenjcumming/autopilot
[0.11.0]: https://github.com/stevenjcumming/autopilot
[0.10.0]: https://github.com/stevenjcumming/autopilot
