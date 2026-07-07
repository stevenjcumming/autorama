# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0-rc.2] - 2026-07-07

Implements Phases 1-4 and 6 of [`.specs/AUTOSKILL_POST_MVP_ROADMAP.md`](../../.specs/AUTOSKILL_POST_MVP_ROADMAP.md) (items 1-8, 11-26 of the improvement review). Item 9 (evaluation loop for generated skills) and item 10 (usage/outcome telemetry) are deferred to their own specs, per the roadmap's own recommendation ("The two design efforts. Each deserves its own spec"); see `.specs/skill-quality-evaluation-loop/` and `.specs/skill-usage-telemetry/`.

**GA promotion note**: this rc bundles what the roadmap originally staged as rc.2 (Phase 1), rc.3 (Phases 2-3), and 1.1.0 (Phase 4 and the Phase 6 items that ride along) into a single release, since all of it landed together in one pass. It does **not** by itself satisfy the item 1.6 GA checklist below (real end-to-end use against at least one project, ideally two different stacks) — that validation still needs to happen against a real project before cutting 1.0.0.

### Breaking changes

- **`${CLAUDE_PLUGIN_ROOT}` replaces `$AUTOSKILL_PLUGIN_ROOT`; the `/autoskill:init` skill and `scripts/init.sh` are removed.** A spike confirmed that Claude Code's harness-native `${CLAUDE_PLUGIN_ROOT}` variable is substituted inline in skill content, agent content, and Task prompts for a marketplace-installed plugin, with no bootstrap step and no restart needed — the plugin's only setup step and biggest onboarding failure mode is gone. Anyone with `AUTOSKILL_PLUGIN_ROOT` still set in a project's `.claude/settings.local.json` can delete that key; nothing reads it anymore.
- **Agents renamed, dropping the redundant `autoskill-` prefix.** `autoskill-discovery` -> `discovery`, `autoskill-synthesizer` -> `synthesizer`, `autoskill-quality-check` -> `quality-check`. Invocation changes from `autoskill:autoskill-discovery` to `autoskill:discovery` (and similarly for the other two). Anything that referenced the old doubled names directly needs updating.
- **Quality checklist checks are now identified by stable slug, not position.** `frontmatter-valid`, `no-dangling-references`, `no-leaked-placeholders` (new), etc., defined once in `references/skill-output-guide.md`'s Quality Checklist (now 18 checks, up from 17), consumed by both the synthesizer's self-check and the quality-check agent. Anything that parsed `quality-check`'s output by check number instead of by the tag content needs updating.
- **Update's "skip" documentation option no longer implies stored content exists.** The synthesizer's metadata.json output never stored fetched document content (only `source`/`type`/`fetched_at`, so sources can be re-fetched later); "skip" now says plainly that it proceeds without documentation content this run, rather than claiming to carry forward content that was never actually stored.

### Added

- **`references/orchestration.md`**: single-sourced stack-detection procedure and the exact discovery/synthesizer/quality-check Task invocations, loaded by both `build` and `update` so an agent-contract change is one edit instead of two.
- **`autoskill:help`**: command table and typical workflow order.
- **`autoskill:list`**: reads the manifest, reconciles it against what's actually on disk (flags orphaned directories and dangling manifest entries), and flags likely-stale entries (old `last_updated`, or `source_files` that no longer resolve).
- **`autoskill:remove <skill-name>`**: deletes a generated skill's directory and its manifest entry together, after explicit confirmation, so neither is left orphaned by a manual deletion.
- **GitHub Actions CI** (`.github/workflows/autoskill-ci.yml`) and `plugins/autoskill/Makefile`: shellcheck (graceful no-op if the plugin ships zero shell scripts, which it does as of this release), `jq empty` on `plugin.json`, and a new stdlib-only `scripts/check-consistency.py` that validates skill/agent frontmatter, skill-name-matches-directory, description length under the 1024-char loader cap, `subagent_type` strings matching a real agent's `name`, and `plugin.json`/`marketplace.json` version agreement.
- **`<no-examples-reason>` is now consumed**, not just emitted: both `build` and `update` surface discovery's explanation of what was searched and why nothing matched in their empty-result messages, instead of a generic four-option menu with no context.
- **`CURRENT_TIMESTAMP`** captured once per run (via a new narrow `Bash(date:*)` grant on `build`/`update`) and passed explicitly to the synthesizer, replacing four places that previously asked a Bash-less agent to invent an ISO 8601 timestamp.
- **`.claude-plugin/plugin.json`** gained `keywords` (mirroring the marketplace tags) and `license: MIT`.

### Changed

- **Build's naming and documentation prompts are combined into one question**, asked once before discovery runs (not two separate stops): name-conflict resolution (only if `.claude/skills/<name>/` already exists) and the supporting-documentation ask (only if `$ARGUMENTS` didn't already carry inline doc references). If neither applies, nothing is asked and discovery starts immediately.
- **Name conflicts ask instead of auto-suffixing.** Build no longer silently creates `<skill-name>-2` on a collision; it asks whether to update the existing skill instead, replace it, or pick a new name, since a collision is usually a signal the developer wanted `autoskill:update`.
- **Update handles a missing skill-name argument**: `/autoskill:update` with no argument now lists generated skills (from the manifest, or by scanning `metadata.json` files if the manifest is missing) and asks which one to update, instead of leaving the behavior undefined.
- **Update creates the manifest if it's missing**, mirroring build's existing behavior, instead of assuming an entry (or the manifest itself) already exists.
- **Update's compatibility check excludes noise paths and requires word-boundary matching** for CLI dependency checks, matching discovery's existing exclusion list, instead of an unbounded repo-wide grep.
- **Discovery's recency hint is now actionable**: reworded from "prefer files with recent modifications if visible" (the agent has no way to see mtimes directly) to noting that Glob results are mtime-ordered, so earlier-sorting candidates should be preferred when otherwise equal.
- **Build/update orchestrators no longer pin `model: opus`**; they inherit the session's default model, since their work (parsing tags, branching, asking questions) is mechanical. The synthesizer keeps its explicit `opus` pin, since that's where generation quality actually lives.
- **The guide's "Good Triggers" table** now includes one full modern-form example (synonyms, enumerated phrasings, pushy directive) alongside the existing short rows, which are now labeled "minimum bar, not target."

### Fixed

- **Stray trailing `</output>` tag** removed from the end of `agents/discovery.md`, `agents/synthesizer.md`, and `agents/quality-check.md` — a leftover after the real `<output>` section closes, which made the tag structure ambiguous.
- **init's cache-glob fallback** (moot as of this release — the entire init skill is removed; see Breaking Changes above).

### Deferred

- **Item 9 (evaluation loop for generated skills)** and **item 10 (usage/outcome telemetry)**, the roadmap's Phase 5 "strategic" bucket, are out of scope for this release. Each has its own REQUIREMENT.md + SPEC.md under `.specs/skill-quality-evaluation-loop/` and `.specs/skill-usage-telemetry/`, ready for a future `/autocode:create-plan` pass.

### GA Promotion Checklist (item 27)

Before promoting a future rc to `1.0.0`, confirm all of the following against real projects, ideally spanning two different stacks (a single-stack validation risks overfitting, since discovery's heuristics are stack-sensitive):

- [ ] `autoskill:build` succeeds end-to-end on a real repo, producing a skill a developer would actually want to keep.
- [ ] `autoskill:update` round-trips: running it again on the same skill produces a sensible diff, not spurious churn.
- [ ] Both the `empty` and `search-failed` discovery paths are exercised at least once and behave as documented (graceful ask vs. one retry with different patterns).
- [ ] A generated skill actually triggers in a fresh Claude Code session on a phrasing the developer would naturally use, not just the exact pattern description it was built from.
- [ ] `autoskill:list` and `autoskill:remove` are exercised at least once against a project with more than one generated skill.

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
