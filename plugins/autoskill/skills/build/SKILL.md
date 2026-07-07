---
name: build
description: Use when the user wants to build a skill from codebase patterns. Triggers on "build a skill for", "capture how we", "make a skill from", "create a skill for", "codify how we do", or similar requests to turn a project pattern into a reusable skill.
allowed-tools: Read, Edit, Write, Glob, Grep, Task, WebFetch, Bash(date:*)
argument-hint: <pattern description>
---

# Autoskill Build

Generate a reusable, project-specific skill from codebase patterns. This skill orchestrates a 7-phase workflow: understand the request, discover examples, handle missing examples, ask clarifying questions, generate and write skill files, update the manifest, and confirm.

Before starting, read `${CLAUDE_PLUGIN_ROOT}/references/orchestration.md`. It holds the stack-detection procedure and the exact discovery, synthesizer, and quality-check Task invocations referenced by phase below, shared verbatim with the `autoskill:update` skill.

## Arguments

- `$ARGUMENTS` contains the natural-language pattern description (e.g., "how we build API endpoints", "our background job pattern", "the way we write data access layers"), and may optionally contain inline documentation references (URLs or absolute file paths) the developer supplied up front (e.g. "build a skill for our service clients using docs: https://wiki.internal/service-clients").

## Phase 1: Understand the Request

### 1.0 Capture the Current Timestamp

Run the "Capture CURRENT_TIMESTAMP" procedure from `references/orchestration.md` once, before anything else in this workflow. Reuse the resulting `CURRENT_TIMESTAMP` value for every timestamp field this run writes (`fetched_at` in 1.4, the `CURRENT_TIMESTAMP` input to the synthesizer in Phase 5, and `last_updated` in the manifest in Phase 6). Do not call `date` again later in the same run.

### 1.1 Extract Pattern Name

Derive a kebab-case skill name from the pattern description. For example:

- "how we build API endpoints" -> `api-endpoint`
- "our background job pattern" -> `background-job`
- "the way we write data access layers" -> `data-access-layer`

If the description is too ambiguous to derive a clear name, ask the user for a short label before proceeding.

### 1.2 Detect Project Stack

Follow the "Stack Detection" procedure in `references/orchestration.md`. Record the result as `DETECTED_STACK`.

### 1.3 Parse Inline Documentation References

Before asking anything, scan `$ARGUMENTS` for documentation references the developer already supplied inline: absolute file paths and URLs. If found, treat these as pre-supplied sources for Phase 1.5 (skip asking about them there). If `$ARGUMENTS` contains none, Phase 1.5 asks normally.

### 1.4 Resolve Name Conflicts

Check whether `.claude/skills/<skill-name>/` already exists.

- If it does not exist, use the name as-is. No conflict; proceed straight to 1.5 without asking anything there either, unless 1.5 still needs to ask about documentation.
- If it exists, a conflict needs the developer's input. A silent auto-suffix (`<skill-name>-2`) is almost always wrong: two skills with overlapping trigger descriptions compete for activation forever, and the collision is usually a signal the developer wanted `autoskill:update`, not a sibling. Fold this into the single combined question in 1.5 instead of asking about it separately.

### 1.5 Ask the One Combined Question (Naming + Documentation)

Ask at most one question here, before discovery runs, combining whatever of the following two topics still needs an answer after 1.3 and 1.4:

- **Naming**, only if 1.4 found a conflict: "A skill named `<skill-name>` already exists. Would you like to update it instead (hand off to `autoskill:update`), replace it, or pick a new name for this one?" Wait for and honor their choice: "update" hands off to the update skill and this workflow stops here; "replace" continues build under the same name and Phase 5.3/6 overwrite the existing skill; a new name restarts from 1.1 with the developer's chosen name.
- **Documentation**, only if 1.3 found no inline references: "Do you have any documentation I should reference while building this skill? You can paste: URLs (architecture docs, ADRs, RFCs, framework guides, Notion exports, internal wiki pages) or absolute file paths to docs on your machine. Paste one per line, or reply 'none'."

If neither topic needs asking (no conflict, and docs were already supplied inline), skip this step entirely and proceed straight to Phase 2. Discovery uses whatever documentation ends up available, so resolving this before Phase 2 (rather than deferring to Phase 4) keeps discovery's Step 1 and Step 6 seeded correctly.

Parse whatever documentation sources result (inline from 1.3, or from this question) into a list. For each:

- **Absolute file path**: verify the path exists and is readable, then use Read to load its full content
- **URL**: use WebFetch to retrieve the content; treat HTTP errors as a soft failure, warn the developer, and continue without that source
- **Relative path or ambiguous input**: ask the developer to disambiguate or skip the item

Record the successfully-loaded sources as `USER_PROVIDED_DOCS`, a structured list where each entry contains:

- `source`: the original URL or absolute path (exact string the user supplied)
- `type`: "url" or "path"
- `content`: the full text the tool retrieved
- `fetched_at`: `CURRENT_TIMESTAMP` from 1.0 (so update re-runs can compare)

If no documentation is available (inline, or the developer replies "none"), set `USER_PROVIDED_DOCS` to an empty list. Do NOT halt the workflow on empty; this is an optional affordance.

The list is passed to Phase 2 (discovery) and Phase 5 (synthesis). Discovery uses it to seed Step 1 (Understand the Pattern) and Step 6 (Internal Documentation). Synthesis uses it as authoritative context alongside observations.

## Phase 2: Discovery

Run the "Discovery Invocation" procedure from `references/orchestration.md`, with `{pattern_description}` set to the pattern description from Phase 1, `{detected_stack}` set to `DETECTED_STACK`, and `{user_provided_docs}` set to `USER_PROVIDED_DOCS`.

### 2.1 Branch on Discovery Status

Follow the "Discovery Status Branching" rules in `references/orchestration.md`:

- **`found`**: Skip Phase 3 and go directly to Phase 4.
- **`empty`**: Proceed to Phase 3.
- **`search-failed`**: Handled per the shared retry rule; if the retry also fails, surface to the developer and wait for guidance rather than falling through to Phase 3.

## Phase 3: Handle No Examples Found

If discovery returned status `empty`, present a graceful message to the developer that includes the `<no-examples-reason>` discovery returned (what was searched and why nothing matched), then the options:

> I could not find existing examples of this pattern in your codebase. {no-examples-reason}
>
> Here are some options:
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

Run the "Synthesizer Invocation" procedure from `references/orchestration.md`, with `{skill_name}`, `{pattern_description}`, `{detected_stack}`, `{discovery_output}`, `{clarifying_answers}` (= `CLARIFYING_ANSWERS`), and `{user_provided_docs}` (= `USER_PROVIDED_DOCS`) filled in from the phases above, `{current_timestamp}` set to the `CURRENT_TIMESTAMP` captured in 1.0, and `{invoked_by}` set to `autoskill:build`.

Parse the `<skill-files>`, `<file-summary>`, and `<quality-notes>` tags from the response.

### 5.2 Quality Check

Run the "Quality Check Invocation" procedure from `references/orchestration.md`, with `{skill_files_output}`, `{skill_name}`, and `{detected_stack}` filled in.

Parse the `<quality-result>` tag and follow the pass / pass-with-warnings / fail handling described there.

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

Derive `pattern_type` yourself from the pattern description and discovery observations: a short free-form category label such as `service-integration`, `background-processing`, `data-access`, or `ui-component`. It is not produced by any agent; pick the label a teammate scanning the manifest would find most recognizable.

Each entry has the following fields:

```json
{
  "skills": [
    {
      "name": "<skill-name>",
      "path": ".claude/skills/<skill-name>/",
      "description": "<one-line description from SKILL.md frontmatter>",
      "pattern_type": "<free-form label describing the pattern category>",
      "last_updated": "<CURRENT_TIMESTAMP from 1.0>"
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

- This skill acts as an orchestrator. The heavy lifting (discovery, synthesis, quality checking) is delegated to specialized agents via Task().
- All phases are intent-driven. No phase prescribes specific tool calls, grep patterns, or language-specific commands. Claude adapts its approach based on the detected stack.
- `references/orchestration.md` and `references/skill-output-guide.md`, both under `${CLAUDE_PLUGIN_ROOT}`, serve as self-reference for orchestration mechanics and quality standards throughout the workflow.
- Generated skills use only the files they need. A simple pattern may produce just SKILL.md and metadata.json. A complex pattern may also include templates, references, or scripts.
