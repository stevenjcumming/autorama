# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.2.0] - 2026-07-23

Dynamic model selection: capability follows the work item (spec, task, diff) for planning, coding, and code review; every other role gets a fixed frontmatter pin. Backward compatible: a missing `models` key, unrated TODO files, and existing specs all resolve to safe defaults.

### Added

- **`docs/MODEL_SELECTION.md`**: canonical reference for the two selection mechanisms, the P/C/R decision tables, the M1-M4 modifiers, fixed frontmatter assignments, the fail-up rule, and user best practices. Skills restate the tables inline where they apply them; any change starts in this doc.
- **`models.ceiling` config key** in `templates/autocode.yml` (default `opus`; `fable` allowed): caps dynamic model resolution only. Fixed frontmatter pins ignore it, so lowering it for cost control cannot starve the tester or other fixed roles. `fable` is never a default and is only reachable via the ceiling plus a ceiling rule (P2, C3) or an explicit override.
- **Task difficulty ratings**: the plan-builder now rates each task `easy`/`standard`/`hard` and writes a short per-task design contract (owning module, interface, pattern to mirror, do-not-touch boundaries) into PLAN.md. create-tasks carries ratings into TODO.md as `(easy)` annotations on task lines, human-editable before `/autocode:execute`. `build-task-queue.sh` parses the annotation tolerantly (missing/unrecognized means `standard`) and emits a new 4th field: `TASK:<id>:<phase>:<rating>:<description>`.
- **Decision logging**: every P/C/R application (including C5 returns and M4 overrides) logs a `model-selection` event with the rule that fired via `log-usage.sh`, and is announced in one line as it happens. `read-history.sh --model-stats` summarizes rule counts, tier distribution, and the C5 return rate for table tuning.

### Changed

- **Dynamic planning**: `create-plan` selects the plan-builder tier from the P table (trivial spec with positive evidence: sonnet; auth/schema/concurrency/migrations, open questions, or 3+ modules: ceiling; else opus). The `ticket` skill's issue-metadata heuristic is deleted; ticket inherits the P table at its plan step and the C table during execution, with `MODEL_OVERRIDE` surviving as an explicit override passed to every stage.
- **Dynamic coding**: the task-runner's uniform MODEL cascade is replaced by per-spawn C-table resolution. New `RATING` and `CEILING` inputs; generation spawns resolve C1/C2/C3 by rating, repairs run at sonnet (C4) with a return-to-generation-tier rule (C5) after two failed repairs or a structural fix. Tester, analyzer, and refactorer spawns never receive a `model` parameter. `MODEL` remains as an explicit override for generation spawns only, so an opus override no longer makes every retry expensive. The execute skill passes `RATING`/`CEILING` in the prompt and no longer passes `model` on the task-runner spawn itself.
- **Dynamic review**: `code-review` selects the reviewer tier from the R table using the execution record (C5 escalations or failures force opus; an unavailable record counts as not-clean), diff size and module spread, and sensitive-path matches. `code_review.model` keeps its meaning as an explicit override of the table result.
- **Frontmatter pins**: tester sonnet to opus (oracle-defining work is silent-failure work); task-runner opus to sonnet (its judgment moved into the deterministic C-table rules); session-summarizer haiku to sonnet (a lossy handoff silently degrades every later task); reviewer sonnet to opus (safe default for a dynamic role). plan-builder and coder stay opus as fail-up safe defaults. Previously unpinned skills get explicit pins: commit, sync-pr, new-spec, create-tasks, review, init, create-plan (sonnet) and spec-archive (haiku).

## [2.1.1] - 2026-07-22

### Added

- **`/autocode:ticket <issue-url> [model-override]`**: takes a GitHub issue straight through spec creation, planning, task breakdown, and implementation unattended, then stops at the `autocode:review` checkpoint. Fetches the issue and its comments via `gh issue view`, synthesizes `REQUIREMENT.md`/`SPEC.md` directly from them, picks a model tier (`sonnet`/`opus`) from a labels/size/discussion-depth heuristic (overridable), and runs the task queue through a dedicated Workflow script (`skills/ticket/scripts/ticket-execute.workflow.js`) so the full task-runner transcript history stays out of the calling session's context. Never commits or opens a PR itself — `/autocode:commit` and `/autocode:sync-pr` remain separate, manual steps after the review.
- **`pr_template_path` config key** in `templates/autocode.yml`: lets a project point `/autocode:sync-pr` at a custom PR description template (e.g. `.github/PULL_REQUEST_TEMPLATE.md`) instead of the shipped default, checked before the existing `.claude/templates/pr_description.md` convention.

## [2.1.0] - 2026-07-07

Implements Phases 1-4 and 6 of [`.specs/AUTOCODE_POST_MVP_ROADMAP.md`](../../.specs/AUTOCODE_POST_MVP_ROADMAP.md) (items 1-8, 10-43 of the improvement review). Item 9 (cross-spec learning loop) and the full per-task-commit redesign (item 2's complete fix) are deferred to their own specs; see the Deferred note at the end of this entry.

### Breaking changes

- **`agents/references/` moved to `plugins/autocode/references/`**: the six reference docs (`analysis-parsing.md`, `artifact-triggers.md`, `conventional-commits.md`, `failure-categories.md`, `refactoring-guidelines.md`, `test-frameworks.md`) were being auto-registered as spawnable agents with all tools and no description, since Claude Code scans `agents/` recursively. Anyone with a hardcoded `agents/references/...` path (in a fork, a custom rule, or their own notes) needs to update it to `references/...`. Every citing path in agents, skills, and docs was updated in this release.
- **Task-runner rollback is no longer a destructive `git checkout -- .`**: a failed fix/refactor cycle now snapshots with `git diff HEAD > $SNAPSHOT` before the cycle and restores via `git checkout HEAD -- . && git apply "$SNAPSHOT"` on failure. Prior task work in the same session is no longer wiped out by a failed retry cycle. Known residual: untracked files created by a failed cycle are not cleaned up by the restore (only tracked-file content is reverted).
- **`review.sh` and `generate-report.sh` merged**: `generate-report.sh` is deleted; `review.sh` now writes `SUMMARY.md` directly (changes summary, artifact counts, high-risk scan, deferred issues, review hints) and prints only a short pointer line, with no ANSI color codes.
- **`update-task-status.sh` validates `TASK_ID`**: rejects anything not matching `^T[0-9]+$` before it reaches the grep/sed patterns, instead of silently mismatching or corrupting TODO.md on IDs containing `/`, `.`, `*`, `&`, or `\`.

### Added

- **`scripts/lib.sh`**: shared `validate_identifier`, `require_identifier`, `spec_dir_for`, `json_escape`, `log_hook_error`, and `extract_spec_dir` helpers, sourced by four hooks and six-plus skill scripts to eliminate the copy-pasted identifier-validation and spec-dir-construction logic
- **`scripts/read-config.sh`**: centralized, indentation-anchored YAML config reads (`read_config_value`) with a `yq`-when-present, `awk`-fallback strategy, replacing the fragile `grep -A2` config-window parsing in `check-edit.sh` and `on-agent-complete.sh`
- **GitHub Actions CI** (`.github/workflows/autocode-ci.yml`): shellcheck on every `.sh` file, `jq empty` on `hooks.json` and `plugin.json`, `node --check` on `judge-artifacts.mjs`, and the bats suite, wired through a new `plugins/autocode/Makefile` `make test` target so local runs and CI stay in sync
- **Bats test suite** (`tests/`)
- **`artifact_judge.model` and `code_review.model`** optional keys in `templates/autocode.yml`: the judge now defaults to a pinned, cheap model instead of running unpinned; `code_review.model` lets security-sensitive projects opt the reviewer into a stronger model without changing the plugin-wide default
- **`--plugin-root` override flag for `init.sh`**, alongside self-resolution and a `[ -d "$PLUGIN_DIR/templates" ]` abort guard so a wrong resolution fails loudly instead of silently installing a broken config
- **Pre-2.0 `.claude/specs/` migration detection in init**: prints a migration hint when the old spec location is found, and fixes the `.gitignore` existence check to recognize `.specs`/`/.specs/` variants instead of appending duplicate entries

### Changed

- **Task-runner categorizes red-phase failures early**: a `setup`-category red failure (broken env, missing deps) now fails fast instead of burning up to 3 opus coder retries before being classified
- **Refactorer receives `CHANGED_FILES` directly** from the task-runner (parsed from the coder's `### Changes Made` output) instead of re-deriving them from git or inferring them from the full PLAN.md
- **Session-summarizer archives the previous summary before writing the new one** (Step 6 was reordered; archiving after writing was archiving the summary that had just replaced it)
- **`check-context.sh` factors in transcript size** passed from the hook, instead of estimating purely from spec files, artifacts, and CLAUDE.md (a combination that made the WARNING/CRITICAL thresholds effectively unreachable)
- **Plan-builder runs one bounded analyzer-feedback revision cycle**: it now applies unambiguous, file:line-anchored analyzer findings itself and surfaces only the rest as open questions, instead of only relaying every finding to the user
- **`reviewer`, `plan-researcher`, `plan-builder`, and `session-summarizer` gained `permissionMode: acceptEdits`**, matching the other file-writing agents that already had it, so a permission prompt inside an unattended background subagent can no longer stall the pipeline
- **`spec-archive` copies `REVIEW.md` into the archive while keeping the working-tree copy** (previously the human sign-off record survived in neither git, since `.specs/` is gitignored, nor the archive, since it was the one file explicitly excluded from the move)
- **`sync-pr` fetches and diffs against `origin/<default-branch>`** instead of the local branch, so a PR description no longer includes commits that are already merged when local `main` lags origin
- **`commit` skill screens for risky untracked files** (`.env`/`.env.*`, `*.pem`/`*.key`, anything containing `credentials`, unexpectedly large files) before an unconditional `git add -A`
- **Standardized `$AUTOCODE_PLUGIN_ROOT` for all skill/agent references-file citations**; `hooks.json` alone continues to use the harness-native `${CLAUDE_PLUGIN_ROOT}`, documented as deliberate since hooks fire before any plugin-bootstrapped env var is guaranteed loaded
- **`plugin.json`'s `agents` array is documentation, not the source of truth**: agent registration is directory-scan-based (the `agents/references/` incident above is the proof), so the explicit array is now understood as a curated allow-list/doc rather than a registration mechanism (closes roadmap item 3.2)
- **Model choices documented, not changed**: `task-runner.md` and `reviewer.md` each gained a scoping comment explaining their `opus`/`sonnet` pins (task-runner is the biggest cost lever as the most frequently spawned agent; reviewer's default stays sonnet with `code_review.model` as the opt-in override for security-sensitive repos) instead of leaving the choice unexplained

### Fixed

- **init.sh's `PLUGIN_DIR` resolution** ("bricks the whole plugin" bug): fixed the post skills-migration path so `templates/autocode.yml`, the justifications-template lookup, and the `AUTOCODE_PLUGIN_ROOT` written to settings all resolve correctly instead of silently pointing at `skills/init`
- **Bracketed task IDs breaking the artifact-audit glob**: `on-agent-complete.sh` strips `[`/`]` from the fallback `TASK_ID` before it hits the `find -name "${TASK_ID}_*"` glob, fixing false "missing artifact" warnings and a leaking `task="[T1]"` in the audit tag
- **review.sh missing untracked/uncommitted changes on feature branches**: it now always emits committed, uncommitted, and untracked sections instead of only showing uncommitted diffs when the branch diff was empty
- **coder.md's Bash-contradicting LARGE-task instruction**: reworded so LARGE tasks no longer instruct the coder to test between sub-steps despite having no Bash access
- **judge-artifacts.mjs's silent-degrade, greedy-JSON-extraction, and unpinned-model issues**: every degrade-to-pass path (missing SDK, missing credentials, timeout, unparseable verdict) is now logged to `hook-errors.jsonl`, JSON extraction takes the last balanced object instead of a greedy brace match, and the model is pinned and configurable via `artifact_judge.model`
- **Spec-attribution mtime-race in `on-agent-complete.sh`**: attribution now prefers `extract_spec_dir` against the transcript's matching Task invocation (correlated by `subagent_type`), falling back to the "most recently modified TODO.md" mtime heuristic only when extraction fails, fixing misattributed completions/failures/audits with two active specs or parallel task-runners
- **check-edit.sh's unquoted command execution and fragile config-window parsing**: the configured check command now runs via `bash -c "$CHECK_CMD \"\$1\"" _ "$FILE_PATH"` instead of word-splitting/glob-expanding it directly, and the `static_analysis`/`on_edit` gates read through `read-config.sh` instead of a `grep -A2` window that broke on an intervening comment line or an unrelated `enabled:` key
- **JSONL escaping gaps**: all fields in log-failure.sh/log-usage.sh (and hook printf fallbacks) now route through the shared `json_escape`, instead of escaping only one field and risking invalid JSONL from a stray `"` in a project path or spec ID
- **build-task-queue.sh's unanchored `[T<n>]` extraction and phase-header mismatch**: task-ID extraction is anchored to the start of the checkbox line instead of matching a mid-line bracket, and the phase-header pattern is now shared with `validate-autocode.sh` so a `## Phase 1: Name`-style TODO.md no longer fails validation while the queue builder accepts it
- **update-task-status.sh's injection-unsafe `TASK_ID` handling and lack of locking**: added the `^T[0-9]+$` validation described above, plus an optimistic-concurrency read-check-modify-verify retry loop (no `flock` dependency, since it isn't reliably available on macOS) so two task-runners racing to update the same TODO.md no longer silently clobber each other's checkbox
- The remaining smaller items: shared phase-header pattern (item 19), reordered validation-before-scaffolding in create-plan/create-tasks (item 21), frontmatter-only high-risk matching in review.sh (item 31), narrowed `Bash` grants and an added `git merge-base` allowance for code-review (item 25), identifier validation on code-review's `SPEC_DIR` construction (item 26), analyzer's deleted phantom "Return Values" section (item 36), and the remaining polish items (39-43): placeholder consistency across SKILL.md command blocks (`{identifier}`-style, fixing the `<SPEC_DIR>`/`<identifier>` mismatch), doc/behavior reconciliation (spec-archive "move" wording, help table's init row, `yq`-optional wording in `templates/autocode.yml`, handoff template `Z`-suffixed timestamps), and the smaller hook/script cleanups (read-handoff.sh errors to stderr, hoisted stat detection in find-active-spec.sh, and similar)

### Deferred

Per the roadmap's own recommendation that Phase 5's two large design efforts go through the plugin's normal spec workflow rather than being implemented ad hoc: item 9 (making the cross-spec learning loop real) got its own spec at `.specs/learning-loop-and-usage-stats/`, and the full per-task-commit redesign (item 2's complete fix, beyond this release's patch-file-based rollback mitigation) got its own spec at `.specs/per-task-commit-model/`.

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

Initial public release of autopilot

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

[Unreleased]: https://github.com/stevenjcumming/autorama
[1.0.0-rc.2]: https://github.com/stevenjcumming/autorama
[1.0.0-rc.1]: https://github.com/stevenjcumming/autorama
[0.15.0]: https://github.com/stevenjcumming/autorama
[0.14.3]: https://github.com/stevenjcumming/autorama
[0.14.2]: https://github.com/stevenjcumming/autorama
[0.14.1]: https://github.com/stevenjcumming/autorama
[0.14.0]: https://github.com/stevenjcumming/autorama
[0.13.0]: https://github.com/stevenjcumming/autorama
[0.12.1]: https://github.com/stevenjcumming/autorama
[0.12.0]: https://github.com/stevenjcumming/autorama
[0.11.0]: https://github.com/stevenjcumming/autorama
[0.10.0]: https://github.com/stevenjcumming/autorama
