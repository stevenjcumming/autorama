# Orchestration Reference

Shared procedure blocks for the `autoskill:build` and `autoskill:update` skills. Both skills load this file in their first phase and refer back to its sections by name instead of restating them. Edit here once; both skills stay in sync.

Agent names referenced below (`autoskill:discovery`, `autoskill:synthesizer`, `autoskill:quality-check`) are the bare agent names as declared in each agent's frontmatter `name` field. Do not prefix them a second time (there is no `autoskill:autoskill-discovery`).

All plugin-relative paths below use `${CLAUDE_PLUGIN_ROOT}`, the harness-native variable that resolves to this installed plugin's absolute root. It is substituted inline wherever it appears in skill content, agent content, and Task prompts, so it can be used directly without any bootstrapping step.

---

## Capture CURRENT_TIMESTAMP

Both build and update need a single, real ISO 8601 UTC timestamp shared across every field that claims one (`fetched_at` on user-provided docs, `last_updated` in metadata.json, `last_updated` in the manifest). Capture it once, early, before any other timestamped work happens in the phase sequence:

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
```

Record the result as `CURRENT_TIMESTAMP`. Reuse this same value for every timestamp field written during the run; do not re-invoke `date` per field; a single run should never contain two different timestamps that both claim to be "now". Neither the discovery nor the synthesizer nor the quality-check agent has its own Bash access, so the orchestrating skill (build or update) is the only place this can be captured, and it must pass `CURRENT_TIMESTAMP` down explicitly to any agent that needs to emit a timestamp.

---

## Stack Detection

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

---

## Discovery Invocation

Delegate example discovery to the `autoskill:discovery` agent.

```
Task(
  subagent_type="autoskill:discovery",
  prompt="Discover examples of the following pattern in this codebase.

  PATTERN_DESCRIPTION: {pattern_description}
  DETECTED_STACK: {detected_stack}
  USER_PROVIDED_DOCS: {user_provided_docs}

  Search the codebase using the strategies in your process steps. Return structured output with <status>, <examples>, <dependency-map>, <test-files>, <companion-files>, <observations>, and <internal-docs> tags."
)
```

`{pattern_description}` is the current pattern description (the developer's fresh input for build, or the existing skill's recorded `pattern_description` for update).

Parse the agent's response to extract:

- `<status>` tag content (required: `result` of `found`, `empty`, or `search-failed`, plus the `patterns-attempted` list)
- `<examples>` tag content (list of example files, or "none")
- `<no-examples-reason>` tag content, when `<examples>` is "none" (what was searched and why nothing matched, or what failed)
- `<dependency-map>` tag content
- `<test-files>` tag content (example-to-test-file pairings, used by the synthesizer to decide whether a test template is warranted)
- `<companion-files>` tag content (list of companion files, or "none")
- `<observations>` tag content
- `<internal-docs>` tag content

### Discovery Status Branching

Branch on the `result` field of `<status>`:

- **`found`**: Examples exist. Proceed to the calling skill's next phase.
- **`empty`**: The searches ran successfully but the codebase genuinely lacks the pattern (build) or no longer contains it (update). This is a valid result; do NOT retry discovery. Re-running queries that completed and matched nothing will always return nothing. Surface `<no-examples-reason>` to the developer alongside whatever empty-result message the calling skill's phase specifies, so they see what was searched and why nothing matched instead of a generic menu.
- **`search-failed`**: The search itself could not complete (tool errors, unreadable paths, or every strategy aborted before producing results). Do NOT treat this as empty. Read the `patterns-attempted` list and re-run the discovery Task once with different patterns: broaden or rephrase the structural signals, try alternate naming conventions, or relax directory assumptions that the attempted patterns show were too narrow. If the retry also returns `search-failed`, surface the failure to the developer, listing the patterns attempted in both runs, and ask how to proceed (e.g., point to an example file or a directory to search). Do not silently fall through to the empty-result path.

If the `<status>` tag is missing from the response (a non-conforming agent reply), treat it as `search-failed` and follow that branch.

---

## Synthesizer Invocation

Delegate skill generation to the `autoskill:synthesizer` agent.

```
Task(
  subagent_type="autoskill:synthesizer",
  prompt="Generate the complete skill folder content for the following pattern.

  SKILL_NAME: {skill_name}
  PATTERN_DESCRIPTION: {pattern_description}
  DETECTED_STACK: {detected_stack}
  DISCOVERY_OUTPUT: {discovery_output}
  CLARIFYING_ANSWERS: {clarifying_answers}
  USER_PROVIDED_DOCS: {user_provided_docs}
  CURRENT_TIMESTAMP: {current_timestamp}
  INVOKED_BY: {invoked_by}
  TEMPLATE_DIR: ${CLAUDE_PLUGIN_ROOT}/templates/
  GUIDE_PATH: ${CLAUDE_PLUGIN_ROOT}/references/skill-output-guide.md

  Return all file content in <skill-files> tags. Do not write any files."
)
```

- `{clarifying_answers}` is the build skill's Phase 4 answers, or the update skill's Phase 3 `UPDATE_GUIDANCE`.
- `{current_timestamp}` is the `CURRENT_TIMESTAMP` captured above; the synthesizer has no Bash access and cannot produce its own.
- `{invoked_by}` is `autoskill:build` or `autoskill:update`, whichever skill is running.

Parse the `<skill-files>`, `<file-summary>`, and `<quality-notes>` tags from the response.

---

## Quality Check Invocation

Delegate quality validation to the `autoskill:quality-check` agent.

```
Task(
  subagent_type="autoskill:quality-check",
  prompt="Validate the following generated skill content.

  SKILL_FILES: {skill_files_output}
  SKILL_NAME: {skill_name}
  DETECTED_STACK: {detected_stack}
  GUIDE_PATH: ${CLAUDE_PLUGIN_ROOT}/references/skill-output-guide.md

  Return a <quality-result> tag with status and any issues found."
)
```

Parse the `<quality-result>` tag:

- **status="pass"**: Proceed to writing.
- **status="pass-with-warnings"**: Proceed to writing. Note warnings for the developer in the calling skill's confirmation phase.
- **status="fail"**: Read the `<blocking-issues>` and `<fix-suggestions>`. Apply the suggested fixes to the generated content in memory (edit the parsed file content directly). If fixes require re-generation, re-prompt the synthesizer with the specific issues to address. Then re-run the quality check. If it fails a second time, proceed anyway and note the unresolved issues for the developer.

Check identifiers in `<blocking-issues>` and `<warnings>` are the stable slugs defined in the skill-output-guide's Quality Checklist (e.g. `no-dangling-references`), not bare numbers; the guide is the single source for what each check means and how many there are.
