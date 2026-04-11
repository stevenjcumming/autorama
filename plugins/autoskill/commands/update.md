---
description: Use when the user wants to update an existing autoskill with current codebase patterns. Triggers on "update skill", "refresh skill", "re-sync skill", or similar requests to bring an existing skill up to date with how the codebase has evolved.
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Task, WebFetch
argument-hint: <skill-name>
model: opus
---

# Autoskill Update

Update an existing autoskill by re-running discovery against the current codebase, generating updated skill content, and presenting a diff for confirmation before overwriting.

## Arguments

- `$ARGUMENTS` contains the name of the existing skill to update (e.g., `api-endpoint`, `background-job`)

## Phase 1: Validate Target Skill

### 1.1 Locate Existing Skill

Check whether `.claude/skills/<skill-name>/` exists.

- If it does not exist, list available skills from `.claude/skills/autoskill-manifest.json` (if it exists) or by scanning `.claude/skills/` subdirectories. Present the list and ask: "No skill named `<skill-name>` found. Did you mean one of these?"
- If it exists, proceed.

### 1.2 Read Existing Skill

Read the existing skill files:

- `.claude/skills/<skill-name>/SKILL.md` (required)
- `.claude/skills/<skill-name>/metadata.json` (required)
- Any additional files in the skill directory (templates, references, scripts)

Extract the pattern description and scope from the existing `SKILL.md` frontmatter and content. Record these as `EXISTING_PATTERN_DESCRIPTION` and `EXISTING_SKILL_FILES`.

### 1.3 Detect Project Stack

Scan the project root for lockfiles and manifests to determine the project's language(s), frameworks, and tooling:

- Check for `package.json`, `yarn.lock`, `pnpm-lock.yaml`, `bun.lockb` (JavaScript/TypeScript ecosystem)
- Check for `Gemfile`, `Gemfile.lock` (Ruby ecosystem)
- Check for `go.mod`, `go.sum` (Go ecosystem)
- Check for `pyproject.toml`, `requirements.txt`, `Pipfile`, `poetry.lock` (Python ecosystem)
- Check for `Cargo.toml`, `Cargo.lock` (Rust ecosystem)
- Check for `pom.xml`, `build.gradle`, `build.gradle.kts` (Java/Kotlin ecosystem)
- Check for `composer.json` (PHP ecosystem)
- Check for `mix.exs` (Elixir ecosystem)

Also note the top-level directory structure (e.g., `src/`, `app/`, `lib/`, `pkg/`, `internal/`) as it indicates organizational conventions.

Record the detected stack as `DETECTED_STACK` for use in later phases.

### 1.4 Refresh Supporting Documentation

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

- **refresh**: iterate over the existing list and re-load each via Read (paths) or WebFetch (URLs). Report any that are now unreachable and drop them from the refreshed list
- **add**: keep the existing list (refreshed or as-is per developer preference), then prompt for additional sources the same way Phase 1.4 in build.md does
- **replace**: prompt from scratch with the same question build.md asks
- **skip**: carry forward the stored content without re-fetching (stale but cheap)

Record the final list as `USER_PROVIDED_DOCS` for Phase 2 and Phase 4. If the existing skill has no `user_provided_docs` field (e.g., it was built before this feature shipped), treat the starting list as empty and offer the build-style "paste or reply 'none'" prompt.

## Phase 2: Re-Discovery

Delegate example discovery to the `autoskill-discovery` agent, seeded with context from the existing skill.

```
Task(
  subagent_type="autoskill:autoskill-discovery",
  prompt="Discover examples of the following pattern in this codebase.

  PATTERN_DESCRIPTION: {existing_pattern_description}
  DETECTED_STACK: {detected_stack}
  USER_PROVIDED_DOCS: {user_provided_docs}

  Search the codebase using the strategies in your process steps. Return structured output with <examples>, <dependency-map>, <companion-files>, <observations>, and <internal-docs> tags."
)
```

Parse the agent's response to extract:

- `<examples>` tag content
- `<dependency-map>` tag content
- `<companion-files>` tag content (list of companion files, or "none")
- `<observations>` tag content
- `<internal-docs>` tag content

If `<examples>` contains "none", inform the user: "I could not find examples of this pattern in the current codebase. The pattern may have been removed or significantly changed. Would you like to point me to an example, or keep the skill as-is?"

Wait for the user's response before proceeding. If they choose to keep as-is, skip to Phase 5 with no changes.

## Phase 3: Ask About Changes

Present a brief summary of what discovery found compared to the existing skill, then ask:

1. **Scope changes**: "Has the scope of this pattern changed? Should the skill cover more or less than it currently does?"
2. **New conventions**: "I found these differences from the current skill: {summarize key differences}. Are these intentional changes that should be reflected?"

Wait for the developer to answer. Record their responses as `UPDATE_GUIDANCE` for use in Phase 4.

## Phase 4: Generate Updated Skill Content

### 4.1 Generate Skill Content

Delegate skill generation to the `autoskill-synthesizer` agent.

```
Task(
  subagent_type="autoskill:autoskill-synthesizer",
  prompt="Generate the complete skill folder content for the following pattern.

  SKILL_NAME: {skill_name}
  PATTERN_DESCRIPTION: {existing_pattern_description}
  DETECTED_STACK: {detected_stack}
  DISCOVERY_OUTPUT: {discovery_output}
  CLARIFYING_ANSWERS: {update_guidance}
  USER_PROVIDED_DOCS: {user_provided_docs}
  TEMPLATE_DIR: $AUTOSKILL_PLUGIN_ROOT/templates/
  GUIDE_PATH: $AUTOSKILL_PLUGIN_ROOT/references/skill-output-guide.md

  Return all file content in <skill-files> tags. Do not write any files."
)
```

Parse the `<skill-files>`, `<file-summary>`, and `<quality-notes>` tags from the response.

### 4.2 Quality Check

Delegate quality validation to the `autoskill-quality-check` agent.

```
Task(
  subagent_type="autoskill:autoskill-quality-check",
  prompt="Validate the following generated skill content.

  SKILL_FILES: {skill_files_output}
  SKILL_NAME: {skill_name}
  DETECTED_STACK: {detected_stack}
  GUIDE_PATH: $AUTOSKILL_PLUGIN_ROOT/references/skill-output-guide.md

  Return a <quality-result> tag with status and any issues found."
)
```

Parse the `<quality-result>` tag:

- **status="pass"**: Proceed.
- **status="pass-with-warnings"**: Proceed. Note warnings for the developer in Phase 5.
- **status="fail"**: Read the `<blocking-issues>` and `<fix-suggestions>`. Apply the suggested fixes to the generated content in memory. If fixes require re-generation, re-prompt the synthesizer with the specific issues to address. Then re-run the quality check. If it fails a second time, proceed anyway and note the unresolved issues for the developer.

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

Update the skill's entry in `.claude/skills/autoskill-manifest.json`:

- Update the `description` field if it changed
- Update the `pattern_type` field if it changed
- Set `last_updated` to the current ISO 8601 timestamp
- Do not modify other skill entries

## Phase 7: Confirm and Close

Summarize what was updated:

1. List all files changed (with paths relative to the project root)
2. Briefly describe what changed and why
3. Note any quality warnings if applicable

## Notes

- This command always requires an existing skill. To create a new skill, use `/build`.
- The diff-and-confirm step (Phase 5) is mandatory. Unlike build, update never writes without explicit approval.
- Discovery is re-run from scratch against the current codebase. This catches patterns that have evolved since the skill was first created.
- The existing skill's pattern description seeds discovery, so results stay focused on the original intent unless the user redirects scope in Phase 3.
