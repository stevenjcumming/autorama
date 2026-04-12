---
description: Use when the user wants to build a skill from codebase patterns. Triggers on "build a skill for", "capture how we", "make a skill from", "create a skill for", "codify how we do", or similar requests to turn a project pattern into a reusable skill.
allowed-tools: Bash, Read, Edit, Write, Glob, Grep, Task, WebFetch
argument-hint: <pattern description>
model: opus
---

# Autoskill Build

Generate a reusable, project-specific skill from codebase patterns. This command orchestrates a 7-phase workflow: understand the request, discover examples, handle missing examples, ask clarifying questions, generate and write skill files, update the manifest, and confirm.

## Arguments

- `$ARGUMENTS` contains the natural-language pattern description (e.g., "how we build API endpoints", "our background job pattern", "the way we write data access layers")

## Phase 1: Understand the Request

### 1.1 Extract Pattern Name

Derive a kebab-case skill name from the pattern description. For example:

- "how we build API endpoints" -> `api-endpoint`
- "our background job pattern" -> `background-job`
- "the way we write data access layers" -> `data-access-layer`

If the description is too ambiguous to derive a clear name, ask the user for a short label before proceeding.

### 1.2 Detect Project Stack

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

### 1.3 Resolve Name Conflicts

Check whether `.claude/skills/<skill-name>/` already exists.

- If it does not exist, use the name as-is.
- If it exists, append an incrementing numeric suffix: `<skill-name>-2`, `<skill-name>-3`, etc. Find the first unused suffix.
- Inform the user of the final name if a suffix was added: "A skill named `<skill-name>` already exists. Creating `<skill-name>-2` instead. Use `/update <skill-name>` to modify an existing skill."

### 1.4 Collect Supporting Documentation

Before discovery runs, give the developer a chance to point to authoritative documentation that describes this pattern. Ask once:

> "Do you have any documentation I should reference while building this skill? You can paste:
> - URLs (e.g., architecture docs, ADRs, RFCs, framework guides, Notion exports, internal wiki pages)
> - Absolute file paths to docs on your machine (e.g., /Users/you/notes/pattern.md)
>
> Paste one per line, or reply 'none'."

Parse the response into a list of sources. For each:

- **Absolute file path**: verify the path exists and is readable, then use Read to load its full content
- **URL**: use WebFetch to retrieve the content; treat HTTP errors as a soft failure, warn the developer, and continue without that source
- **Relative path or ambiguous input**: ask the developer to disambiguate or skip the item

Record the successfully-loaded sources as `USER_PROVIDED_DOCS`, a structured list where each entry contains:

- `source`: the original URL or absolute path (exact string the user supplied)
- `type`: "url" or "path"
- `content`: the full text the tool retrieved
- `fetched_at`: current ISO 8601 timestamp (so update re-runs can compare)

If the developer replies "none" or provides nothing, set `USER_PROVIDED_DOCS` to an empty list. Do NOT halt the workflow on empty; this is an optional affordance.

The list is passed to Phase 2 (discovery) and Phase 5 (synthesis). Discovery uses it to seed Step 1 (Understand the Pattern) and Step 6 (Internal Documentation). Synthesis uses it as authoritative context alongside observations.

## Phase 2: Discovery

Delegate example discovery to the `autoskill-discovery` agent.

```
Task(
  subagent_type="autoskill:autoskill-discovery",
  prompt="Discover examples of the following pattern in this codebase.

  PATTERN_DESCRIPTION: {pattern_description}
  DETECTED_STACK: {detected_stack}
  USER_PROVIDED_DOCS: {user_provided_docs}

  Search the codebase using the strategies in your process steps. Return structured output with <examples>, <dependency-map>, <companion-files>, <observations>, and <internal-docs> tags."
)
```

Parse the agent's response to extract:

- `<examples>` tag content (list of example files, or "none")
- `<dependency-map>` tag content
- `<companion-files>` tag content (list of companion files, or "none")
- `<observations>` tag content
- `<internal-docs>` tag content

If `<examples>` contains "none", proceed to Phase 3. Otherwise, skip Phase 3 and go directly to Phase 4.

## Phase 3: Handle No Examples Found

If the discovery agent found no examples, present a graceful message to the developer:

> I could not find existing examples of this pattern in your codebase. Here are some options:
>
> 1. **Point me to an example file** - If you know a file that implements this pattern, share its path and I will use it as a starting point.
> 2. **Describe the pattern** - Tell me how this pattern works in your project and I will draft a skill from your description.
> 3. **Share internal docs** - If there are architecture docs, ADRs, or CONTRIBUTING guides that describe this pattern, point me to them.
> 4. **Draft from conventions alone** - I can create a skill based on the project's general conventions and structure, without specific examples.

Halt and wait for the developer's response. Do not proceed to Phase 4 until the developer provides guidance or an example file. If they provide a file path, re-run discovery with that file as a seed.

## Phase 4: Clarifying Questions

Ask all clarifying questions at once after discovery completes. Do not ask questions iteratively across multiple turns.

### Always Ask

1. **Scope**: "What should this skill cover? Should it include only the core pattern, or also related concerns like error handling, logging, and configuration?"
2. **Edge cases**: "Are there edge cases or unusual scenarios that someone implementing this pattern should know about?"
3. **Alternatives**: "When should someone reach for this pattern versus an alternative approach? What are the signals that this is the right choice?"

### Conditionally Ask

4. **Inconsistencies** (if the discovery agent reported inconsistencies in `<observations>`): "I found some differences between examples: {summarize inconsistencies}. Which approach is the canonical one going forward?"
5. **Test conventions** (if the discovery agent did not find clear test patterns in the dependency map): "What does a complete test look like for this pattern? What should be asserted, what should be mocked or stubbed, and what level of coverage is expected?"

Wait for the developer to answer. Record their responses as `CLARIFYING_ANSWERS` for use in Phase 5.

## Phase 5: Generate and Write Skill Folder

### 5.1 Generate Skill Content

Delegate skill generation to the `autoskill-synthesizer` agent.

```
Task(
  subagent_type="autoskill:autoskill-synthesizer",
  prompt="Generate the complete skill folder content for the following pattern.

  SKILL_NAME: {skill_name}
  PATTERN_DESCRIPTION: {pattern_description}
  DETECTED_STACK: {detected_stack}
  DISCOVERY_OUTPUT: {discovery_output}
  CLARIFYING_ANSWERS: {clarifying_answers}
  USER_PROVIDED_DOCS: {user_provided_docs}
  TEMPLATE_DIR: $AUTOSKILL_PLUGIN_ROOT/templates/
  GUIDE_PATH: $AUTOSKILL_PLUGIN_ROOT/references/skill-output-guide.md

  Return all file content in <skill-files> tags. Do not write any files."
)
```

Parse the `<skill-files>`, `<file-summary>`, and `<quality-notes>` tags from the response.

### 5.2 Quality Check

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

- **status="pass"**: Proceed to writing.
- **status="pass-with-warnings"**: Proceed to writing. Note warnings for the developer in Phase 7.
- **status="fail"**: Read the `<blocking-issues>` and `<fix-suggestions>`. Apply the suggested fixes to the generated content in memory (edit the parsed file content directly). If fixes require re-generation, re-prompt the synthesizer with the specific issues to address. Then re-run the quality check. If it fails a second time, proceed anyway and note the unresolved issues for the developer.

### 5.3 Write Files

Write files directly to `.claude/skills/<skill-name>/`:

- Write `SKILL.md`
- Write `metadata.json`
- Write any additional files (templates, references, scripts) returned by the synthesizer

Create the skill directory first if it does not exist.

## Phase 6: Update Manifest

Create or update `.claude/skills/autoskill-manifest.json` in the user's project.

If the manifest file exists, read it and parse the existing entries. Add or update the entry for this skill without modifying other entries.

If the manifest file does not exist, create it with this skill as the first entry.

Each entry has the following fields:

```json
{
  "skills": [
    {
      "name": "<skill-name>",
      "path": ".claude/skills/<skill-name>/",
      "description": "<one-line description from SKILL.md frontmatter>",
      "pattern_type": "<free-form label describing the pattern category>",
      "last_updated": "<ISO 8601 timestamp>"
    }
  ]
}
```

The manifest is an engineer-readable index. It is not a loader config and does not affect how Claude discovers skills.

## Phase 7: Confirm and Close

Summarize what was created:

1. List all files written (with paths relative to the project root)
2. Describe what the skill enables Claude to do in future sessions
3. Explain that the skill is automatically available because it lives in `.claude/skills/`

If the quality check returned warnings, note them here so the developer is aware.

If the pattern is complex (more than 3 files generated, or the SKILL.md is longer than 100 lines), offer: "This is a substantial skill. Want me to run it now on a new example to verify it works?"

## Notes

- This command acts as an orchestrator. The heavy lifting (discovery, synthesis, quality checking) is delegated to specialized agents via Task().
- All phases are intent-driven. No phase prescribes specific tool calls, grep patterns, or language-specific commands. Claude adapts its approach based on the detected stack.
- The skill-output-guide at `$AUTOSKILL_PLUGIN_ROOT/references/skill-output-guide.md` serves as self-reference for quality standards throughout the workflow.
- Generated skills use only the files they need. A simple pattern may produce just SKILL.md and metadata.json. A complex pattern may also include templates, references, or scripts.
