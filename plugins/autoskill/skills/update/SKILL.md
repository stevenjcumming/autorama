---
name: update
description: Use when the user wants to update an existing autoskill with current codebase patterns. Triggers on "update skill", "refresh skill", "re-sync skill", or similar requests to bring an existing skill up to date with how the codebase has evolved.
allowed-tools: Read, Edit, Write, Glob, Grep, Task, WebFetch, Bash(date:*)
argument-hint: <skill-name>
---

# Autoskill Update

Update an existing autoskill by re-running discovery against the current codebase, generating updated skill content, and presenting a diff for confirmation before overwriting.

Before starting, read `${CLAUDE_PLUGIN_ROOT}/references/orchestration.md`. It holds the stack-detection procedure and the exact discovery, synthesizer, and quality-check Task invocations referenced by phase below, shared verbatim with the `autoskill:build` skill.

## Arguments

- `$ARGUMENTS` contains the name of the existing skill to update (e.g., `api-endpoint`, `background-job`). May be empty.

## Phase 1: Validate Target Skill and Setup

### 1.0 Handle a Missing Argument

If `$ARGUMENTS` is empty, list the skills available to update: read `.claude/skills/autoskill-manifest.json` if it exists (its `name` entries), or, if the manifest is missing, scan `.claude/skills/*/metadata.json` for entries whose `generated_by` field starts with `autoskill:`. Present the list and ask the developer which one they want to update. Once they answer, treat their choice as `$ARGUMENTS` and continue at 1.1.

### 1.1 Locate Existing Skill

Check whether `.claude/skills/<skill-name>/` exists.

- If it does not exist, list available skills the same way as 1.0 and ask: "No skill named `<skill-name>` found. Did you mean one of these?"
- If it exists, proceed.

### 1.2 Read Existing Skill

Read the existing skill files:

- `.claude/skills/<skill-name>/SKILL.md` (required)
- `.claude/skills/<skill-name>/metadata.json` (required)
- Any additional files in the skill directory (templates, references, scripts)

Read `pattern_description` from `metadata.json` and record it as `EXISTING_PATTERN_DESCRIPTION`. This is the original natural-language description the developer gave at build time, which is what discovery should be re-seeded with; the synthesized trigger description in `SKILL.md` frontmatter is a derived artifact and drifts further from the developer's intent on every update. If `metadata.json` has no `pattern_description` field (the skill predates it), fall back to extracting the pattern description from the `SKILL.md` frontmatter and content. Record the full set of existing files as `EXISTING_SKILL_FILES`.

### 1.3 Detect Project Stack

Follow the "Stack Detection" procedure in `references/orchestration.md`. Record the result as `DETECTED_STACK`.

### 1.4 Capture the Current Timestamp

Run the "Capture CURRENT_TIMESTAMP" procedure from `references/orchestration.md` once, here. Reuse the resulting `CURRENT_TIMESTAMP` value for every timestamp field this run writes (`fetched_at` on any refreshed or added documentation in 1.5, the `CURRENT_TIMESTAMP` input to the synthesizer in Phase 4, and `last_updated` in the manifest in Phase 6). Do not call `date` again later in the same run.

### 1.5 Refresh Supporting Documentation

Read `user_provided_docs` from the existing skill's `metadata.json` (if present). These are the documentation sources supplied when the skill was originally built (or last updated).

Show the developer the list:

> "This skill was built with the following documentation sources:
> 1. https://... (type: url, fetched 2026-03-01)
> 2. /Users/you/notes/pattern.md (type: path, fetched 2026-03-01)
>
> Options:
> - 'refresh' to re-fetch all existing sources with their current content
> - 'add' to add new sources in addition to the existing ones
> - 'replace' to discard the existing list and provide a new one
> - 'skip' to proceed without touching documentation sources
>
> What would you like to do?"

Handle each option:

- **refresh**: iterate over the existing list and re-load each via Read (paths) or WebFetch (URLs), setting `fetched_at` to `CURRENT_TIMESTAMP` for each. Report any that are now unreachable and drop them from the refreshed list
- **add**: keep the existing list (refreshed or as-is per developer preference), then prompt for additional sources the same way Phase 1.5 of the build skill does, setting `fetched_at` to `CURRENT_TIMESTAMP` for the new entries
- **replace**: prompt from scratch with the same question the build skill asks
- **skip**: there is no stored document *content* to carry forward (the synthesizer's metadata.json output intentionally omits `content`, keeping only `source`, `type`, and `fetched_at` so the source string is enough to re-fetch later). "Skip" therefore means proceeding to synthesis without any documentation content this run, not reusing prior content. Say so plainly: "Proceeding without documentation content this run; the sources stay recorded in metadata, but synthesis won't have their content to draw from, which may reduce accuracy for anything the docs previously anchored." Carry the source list forward unchanged (so re-fetching later remains possible), but with an empty `content` for each until a future `refresh` or `add`.

Record the final list as `USER_PROVIDED_DOCS` for Phase 2 and Phase 4. If the existing skill has no `user_provided_docs` field (e.g., it was built before this feature shipped), treat the starting list as empty and offer the build-style "paste or reply 'none'" prompt.

## Phase 2: Re-Discovery

Run the "Discovery Invocation" procedure from `references/orchestration.md`, with `{pattern_description}` set to `EXISTING_PATTERN_DESCRIPTION`, `{detected_stack}` set to `DETECTED_STACK`, and `{user_provided_docs}` set to `USER_PROVIDED_DOCS`.

Follow the "Discovery Status Branching" rules in `references/orchestration.md`, with one update-specific addition to the `empty` branch:

- **`found`**: Proceed to the compatibility check (2.1).
- **`empty`**: In addition to the shared rule, this specifically means the pattern may have been removed or significantly changed since the skill was built. Inform the user, including the `<no-examples-reason>` discovery returned: "I could not find examples of this pattern in the current codebase. {no-examples-reason} The pattern may have been removed or significantly changed. Would you like to point me to an example, or keep the skill as-is?" Wait for the user's response before proceeding. If they choose to keep as-is, skip directly to Phase 7 and close out without writing anything; there are no changes to diff or apply.
- **`search-failed`**: Handled per the shared retry rule.

### 2.1 Compatibility Check

Read the `compatibility` field from the existing skill's `metadata.json` (if present). For each entry, verify that the dependency still exists in the current project environment:

- For language-ecosystem packages (gems, npm packages, Python packages, Go modules, etc.): check the project's lockfile or manifest for the package name. If missing, record it as a drift.
- For CLIs (e.g., `yq`, `jq`, `gh`): grep the repository and the user's scripts for the command, excluding common noise paths (`node_modules/`, `vendor/`, `.git/`, `log/`, `tmp/`, and equivalents for the detected stack), and require a word-boundary match so a short CLI name (like `gh`) does not match arbitrary substrings inside longer words. If no callers remain, record it as a drift.
- For internal libraries or modules (e.g., `internal-lib/service-base`): Glob for the path. If the path has disappeared, record it as a drift.

Warn the user about every drift before proceeding:

> "This skill's metadata records a dependency on `<name>`, which I could not find in the current project. The pattern may no longer work the same way. Do you want to proceed with the update, drop this dependency from `compatibility`, or halt and investigate?"

Respect the user's choice. Drops should be reflected when writing the new metadata.json in Phase 6.

If the existing skill has no `compatibility` field (e.g., it predates this feature), skip this sub-step.

## Phase 3: Ask About Changes

Present a brief summary of what discovery found compared to the existing skill, then ask:

1. **Scope changes**: "Has the scope of this pattern changed? Should the skill cover more or less than it currently does?"
2. **New conventions**: "I found these differences from the current skill: {summarize key differences}. Are these intentional changes that should be reflected?"

Wait for the developer to answer. Record their responses as `UPDATE_GUIDANCE` for use in Phase 4.

## Phase 4: Generate Updated Skill Content

### 4.1 Generate Skill Content

Run the "Synthesizer Invocation" procedure from `references/orchestration.md`, with `{skill_name}`, `{pattern_description}` (= `EXISTING_PATTERN_DESCRIPTION`), `{detected_stack}`, `{discovery_output}`, `{clarifying_answers}` (= `UPDATE_GUIDANCE`), and `{user_provided_docs}` (= `USER_PROVIDED_DOCS`) filled in from the phases above, `{current_timestamp}` set to the `CURRENT_TIMESTAMP` captured in 1.4, and `{invoked_by}` set to `autoskill:update`.

Parse the `<skill-files>`, `<file-summary>`, and `<quality-notes>` tags from the response.

### 4.2 Quality Check

Run the "Quality Check Invocation" procedure from `references/orchestration.md`, with `{skill_files_output}`, `{skill_name}`, and `{detected_stack}` filled in.

Parse the `<quality-result>` tag and follow the pass / pass-with-warnings / fail handling described there.

## Phase 5: Diff and Confirm

1. Compare the new skill files against the existing files in `.claude/skills/<skill-name>/`
2. Present a readable summary showing:
   - Sections added to `SKILL.md`
   - Sections removed or changed in `SKILL.md`
   - Changes to `metadata.json`
   - Template or script files added, removed, or modified
   - Companion files newly detected or no longer present since the last run
   - Documentation sources added, removed, or refreshed (with timestamps)
3. Ask: "Here are the proposed changes. Should I apply this update?"
4. Only write files after receiving explicit confirmation. If the developer declines, do not write and skip to Phase 7.

## Phase 6: Write Files

Overwrite the existing files in `.claude/skills/<skill-name>/`:

- Write `SKILL.md`
- Write `metadata.json`
- Write any additional files (templates, references, scripts) returned by the synthesizer
- Remove any files that existed in the old skill but are not present in the new output (after confirming with the user)

Update `.claude/skills/autoskill-manifest.json`:

- If the manifest file does not exist, create it with this skill as its first entry (mirroring the build skill's Phase 6).
- If the manifest exists but has no entry for this skill (e.g. the skill was built before the manifest feature shipped, or the manifest was hand-edited), add a new entry for it.
- Otherwise, update the existing entry:
  - Update the `description` field if it changed
  - Update the `pattern_type` field if it changed
  - Set `last_updated` to `CURRENT_TIMESTAMP` from 1.4
  - Do not modify other skill entries

## Phase 7: Confirm and Close

Summarize what was updated:

1. List all files changed (with paths relative to the project root)
2. Briefly describe what changed and why
3. Note any quality warnings if applicable

## Notes

- This skill always requires an existing generated skill. To create a new skill, use the `autoskill:build` skill.
- The diff-and-confirm step (Phase 5) is mandatory. Unlike build, update never writes without explicit approval.
- Discovery is re-run from scratch against the current codebase. This catches patterns that have evolved since the skill was first created.
- The existing skill's pattern description seeds discovery, so results stay focused on the original intent unless the user redirects scope in Phase 3.
