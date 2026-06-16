# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc.1] - 2026-06-12

Release candidate for the first stable release. Promote to 1.0.0 after the rc survives real-world use of build and update against at least one project.

### Breaking changes

- **Commands removed in favor of skills**: The `commands/` directory is gone. `init`, `build`, and `update` now live at `skills/<name>/SKILL.md` with `name` and trigger-condition `description` frontmatter (`allowed-tools` and `argument-hint` are preserved). Invocation is unchanged (`/autoskill:init`, `/autoskill:build`, `/autoskill:update`), and the skills also trigger on natural-language requests. Anything that referenced the `commands/*.md` paths must point at the new skill directories.
- **Discovery output format**: The discovery agent's response now begins with a required `<status>` tag carrying a `result` of `found`, `empty`, or `search-failed` plus the list of search patterns attempted. Consumers of discovery output must parse this tag; the build and update skills branch on it (valid `empty` proceeds to the ask-the-user path, `search-failed` retries once with different patterns instead of being treated as empty, and a missing tag is treated as `search-failed`).

### Added

- **Restart instruction**: The init skill now ends by explicitly telling the user to restart Claude Code for hooks and settings to take effect, and the README installation steps carry the same note.
- **`settings.example.json` documentation**: The usage guide now shows exactly what init writes to `.claude/settings.local.json` and explains why `AUTOSKILL_PLUGIN_ROOT` must be an absolute path, for users who configure manually or whose init fails.
- **Frontmatter hard limits** documented in the skill-output-guide (description capped at 1024 characters; name lowercase-hyphenated matching the directory) and enforced by quality-check Check 1.
- **`Related Files` section** added to the canonical SKILL.md structure in the guide and to `SKILL.template.md`.
- **Companion file `shape` field** carried through to `metadata.json` so update-time diffs can compare edit shapes.

### Changed

- **Docs reworded for skills**: README and `docs/autoskill/` pages now describe skill invocation; agent and reference files refer to the orchestrating build and update skills instead of commands.
- **`plugin.json`** moved to `.claude-plugin/plugin.json` per the current plugin spec; added the `repository` field and dropped the redundant `commands`/`agents` arrays (both are auto-discovered).
- **Permissions**: build and update no longer request unscoped `Bash`; init scopes its Bash usage to the specific tools it runs.

### Fixed

- **`<test-files>` handoff**: The build and update skills now request and parse the discovery agent's `<test-files>` block, and the synthesizer declares it as input. Previously the block was dropped at the orchestrator boundary, so the test-template feature could never trigger.
- **`init.sh` failure reporting**: The settings-write failure branch was unreachable under `set -e`. The script now uses `if merge_env_setting; then`, runs under `set -euo pipefail`, guards against running from a subdirectory, validates existing settings JSON before merging, and writes via a temp file.
- **`/autoskill:init` plugin detection**: The registry query now matches the actual `installed_plugins.json` schema (`plugins` object keyed by `name@marketplace` with `installPath`), with a glob-based cache fallback and a clear message when auto-detection fails.
- **Update re-seeding**: `metadata.json` now records the developer's original `pattern_description`, and the update skill re-seeds discovery from it instead of the synthesized trigger description.
- **`generated_by` attribution**: The synthesizer now records the invoking skill (`autoskill:build` or `autoskill:update`) instead of always claiming build.
- **Quality checklist alignment**: The quality-check agent now runs all 17 checks from the guide (the user-provided-docs check was missing), numbered in the guide's order, and verifies source file paths with Glob.

## [0.1.0] - 2026-04-12

### Added

- **`/autoskill:build` command**: 7-phase workflow (detect, discover, handle empty results, clarify, synthesize, register, summarize) for generating reusable skill files from codebase patterns. Resolves name conflicts via numeric suffix. Accepts optional user-provided documentation (URLs or absolute paths) as authoritative context for naming and framing.
- **`/autoskill:update` command**: Dedicated command for maintaining existing skills. Replaces the in-place rerun flow from the build command with a diff-and-confirm workflow that never overwrites without explicit approval.
- **`/autoskill:init` command**: Plugin bootstrapping via `init.sh` script.
- **`discovery` agent (sonnet)**: Pattern search and example selection. Surfaces test files alongside source files so the synthesizer can find them without re-searching. Includes a mandatory companion-file sweep (Step 4.5) to surface registration manifests and middleware config files that must be edited for every new pattern instance.
- **`synthesizer` agent (opus)**: `SKILL.md` and `metadata.json` generation. Emits a "Register the new instance" step for companion files. Treats user-provided docs as the team's intent layer while grounding observations in the code.
- **`quality-check` agent (sonnet)**: Output validation with stricter rules that block when listed companion files are missing from `SKILL.md`.
- **`SKILL.template.md`**: Language-agnostic skill output template.
- **`metadata.template.json`**: Metadata template including companion file registration fields.
- **`skill-output-guide.md` reference**: Language-agnostic conventions for skill authoring, used by the synthesizer and quality-check agents.
- **Marketplace registration**: Plugin registered in `.claude-plugin/marketplace.json`.
- **User-facing docs** (`docs/autoskill/`) covering overview, usage guide, how it works, agent architecture, and generated output format.
