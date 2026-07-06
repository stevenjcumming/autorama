---
name: create
description: Use when the user wants to generate a CONTEXT.md for a directory. Triggers on "create context for", "add context to", "set up CONTEXT.md", or similar requests to generate directory-scoped agent guidance.
allowed-tools: Bash(gh:*), Bash(ls:*), Read, Edit, Write, Glob, Grep, Task
argument-hint: [path]
model: opus
---

<!-- Bash is scoped to gh (external URL validation via gh api) and ls (target directory checks). Analysis and generation are delegated to agents; this skill only orchestrates, asks the user questions, and writes the final file after confirmation. -->

# Autocontext Create

Generate a `CONTEXT.md` for a specified directory. Analysis is delegated to the analyzer agent, content generation to the generator agent, and nothing is written until the user confirms the draft.

If `$AUTOCONTEXT_PLUGIN_ROOT` is not set, stop and tell the user to run `/autocontext:init` first (then restart the session).

## Arguments

`$ARGUMENTS` contains the target directory path (e.g., `src/api`, `lib/payments`). Defaults to the current working directory if omitted.

## Phase 1: Validate Target

1. Confirm the target directory exists. If not, exit with an error.
2. Check for an existing `CONTEXT.md` in the directory. If one exists, warn the user and ask whether to overwrite or merge. If merging, read the existing file so it can be passed to the generator in Phase 4.
3. If the directory is conventional (e.g., `__pycache__/`, `node_modules/`, `.git/`, `vendor/`, build output), advise the user that a `CONTEXT.md` is likely unnecessary here and ask to confirm before proceeding.

## Phase 2: Analyze Directory

Delegate directory analysis to the analyzer agent.

```
Task(
  subagent_type="autocontext:autocontext-analyzer",
  prompt="Analyze the following directory for CONTEXT.md generation.

  TARGET_DIR: {target_directory}
  FORMAT_GUIDE: $AUTOCONTEXT_PLUGIN_ROOT/references/context-format-guide.md

  Examine the directory's contents: filenames, file types, imports, exports,
  structural patterns, and relationship to neighboring directories. Check for
  existing rules, skills, and project conventions that apply.

  Return structured output with <analysis> containing:
  - <purpose> inferred directory purpose
  - <key-references> files the agent should load (root-relative paths and/or full URLs)
  - <docs-candidates> file patterns and their documentation references (only if directory is flat with mixed domains)
  - <task-candidates> repeatable tasks with their instruction/rule/skill bundles
  - <constraints> things that should never happen in this directory
  - <confidence> per-section confidence rating (high/medium/low)
  - <observations> anything notable about the directory structure"
)
```

Parse the agent's `<analysis>` response.

## Phase 3: Ask About External Documentation

If Key References or Docs candidates were found, ask:

> "Are there any documentation references in external repositories (e.g., private GitHub repos, wikis) that should be linked for this directory? Paste full URLs, one per line, or reply 'none'."

For each URL provided:
- If it looks like a GitHub URL, validate it exists using `gh api` (e.g., `gh api repos/{owner}/{repo}/contents/{path}`). Warn on 404 but do not block. If `gh` is not authenticated or the request fails, note the URL as unverified and continue.
- Add validated URLs to the appropriate section (Key References for general docs, Docs table for file-pattern-specific docs).

## Phase 4: Generate CONTEXT.md

Delegate generation to the generator agent.

```
Task(
  subagent_type="autocontext:autocontext-generator",
  prompt="Generate a CONTEXT.md for the following directory.

  TARGET_DIR: {target_directory}
  ANALYSIS: {analysis_output}
  EXTERNAL_DOCS: {external_docs_from_user}
  EXISTING_CONTEXT_MD: {existing content if the user chose merge, otherwise omit}
  FORMAT_GUIDE: $AUTOCONTEXT_PLUGIN_ROOT/references/context-format-guide.md
  TEMPLATE: $AUTOCONTEXT_PLUGIN_ROOT/templates/context.md

  Rules:
  - Only include sections where the agent would make wrong assumptions without them.
  - All local paths must be root-relative.
  - External documentation must use full URLs.
  - Do not fabricate references. If you cannot find a real file, leave a <!-- TODO: Review --> comment.
  - Only generate Tasks if the directory has repeatable actions requiring specific guidance.
  - Task bundles must be complete specifications. If a rule matters for the task, include it.
  - Only generate a Docs table if the directory is flat with files from multiple domains.
  - Never Do Here is for axioms only: non-obvious, catastrophic-if-missed constraints. Do not duplicate what task bundles already enforce.
  - Do not write execution logic. CONTEXT.md declares what to load, not how to act.
  - Do not write README-style prose. Purpose is for agent orientation, not human onboarding.
  - Mark low-confidence sections with <!-- TODO: Review --> comments.

  Return the full CONTEXT.md content in a <context-md> tag. Do not write any files."
)
```

Parse the `<context-md>` content.

## Phase 5: Confirm and Write

1. Present the draft `CONTEXT.md` to the user.
2. Highlight any `<!-- TODO: Review -->` markers and explain why confidence is low for those sections.
3. Ask: "Should I write this CONTEXT.md, or would you like to adjust anything first?"
4. Only write after explicit confirmation.
5. Write to `{target_directory}/CONTEXT.md`.

## Notes

- The generator must not fabricate references. If it cannot find a real file to reference, it leaves a TODO rather than inventing a path.
- Tasks should only be generated if the directory has repeatable development actions that require specific guidance. Do not generate tasks for directories where the work is obvious.
- Tasks and Never Do Here always require human review before a generated file is considered complete. Never Do Here in particular encodes hard-won, directory-specific constraints that cannot be fully inferred from code.
- If the user wants to merge with an existing `CONTEXT.md`, read the existing file and pass it to the generator agent as additional context.
