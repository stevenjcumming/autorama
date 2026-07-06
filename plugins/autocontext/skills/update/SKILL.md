---
name: update
description: Use when the user wants to validate and fix an existing CONTEXT.md. Triggers on "update context", "check context", "validate CONTEXT.md", "fix context", or similar requests to repair stale or broken directory context.
allowed-tools: Bash(gh:*), Bash(ls:*), Read, Edit, Glob, Grep, Task
argument-hint: [path]
model: opus
---

<!-- Bash is scoped to gh (external URL validation via gh api) and ls (target directory checks). Validation is delegated to the validator agent; this skill only orchestrates, reports findings, and applies user-approved fixes with Edit. No Write: update never creates or rewrites whole files. -->

# Autocontext Update

Validate and fix an existing `CONTEXT.md` for a specified directory. Validation is delegated to the validator agent; fixes are applied only after the user approves them.

If `$AUTOCONTEXT_PLUGIN_ROOT` is not set, stop and tell the user to run `/autocontext:init` first (then restart the session).

## Arguments

`$ARGUMENTS` contains the target directory path. Defaults to the current working directory if omitted.

## Phase 1: Validate Target

1. Confirm the target directory exists. If not, exit with an error.
2. Check for an existing `CONTEXT.md` in the directory. If none exists, exit with an error and suggest using `/autocontext:create` instead.
3. Read the existing `CONTEXT.md` so its content can be passed to the validator.

## Phase 2: Validate CONTEXT.md

Delegate validation to the validator agent.

```
Task(
  subagent_type="autocontext:autocontext-validator",
  prompt="Validate the CONTEXT.md in the following directory against the current state of the codebase.

  TARGET_DIR: {target_directory}
  CONTEXT_MD: {existing_context_md_content}
  FORMAT_GUIDE: $AUTOCONTEXT_PLUGIN_ROOT/references/context-format-guide.md

  Check for:
  1. BROKEN REFERENCES: Verify all local paths in Key References, Docs, and Tasks point to files that exist. For full URLs (GitHub links), use gh api to check accessibility.
  2. STALE TASKS: Check if task bundles reference skills, rules, or instructions that have been moved or deleted.
  3. MISSING COVERAGE: Check if new files in the directory would benefit from Docs table entries (only if a Docs table already exists).
  4. STRUCTURAL ISSUES: Check for the anti-patterns defined in the format guide:
     - The everything CONTEXT.md (root context declaring bundles for all directories)
     - Speculative loading (bundles referencing rules/skills not needed for the task)
     - CONTEXT.md as README (excessive prose, no actionable sections)
     - Execution logic in CONTEXT.md (how-to steps that belong in rules or skills)
     - Implicit context chaining (missing explicit parent references in Key References)
     - Never Do Here as a rule backlog (too many items, duplicating task bundle constraints)
     - Relative paths instead of root-relative paths
     Also flag sections that are present but empty.

  Return structured output with <validation-results> containing:
  - <broken-references> list of broken paths/URLs with suggested fixes
  - <stale-tasks> list of stale task bundles with suggested fixes
  - <missing-coverage> list of files that could use Docs entries
  - <structural-issues> list of anti-patterns found
  - <summary> overall health assessment (healthy/needs-fixes/needs-rewrite)"
)
```

Parse the `<validation-results>` response.

## Phase 3: Report and Fix

1. Present findings to the user, grouped by category. Broken references first (highest priority).
2. For each finding, show the specific fix suggestion.
3. Ask: "Which fixes should I apply?" (Options: all, select specific ones, none)
4. Apply only the approved fixes using Edit. Do not rewrite the entire file.

## Phase 4: Confirm

Summarize what was fixed. If structural issues suggest the file needs a more substantial rewrite, recommend running `/autocontext:create` with the overwrite option instead.

## Notes

- Update is non-destructive by default. It reports and proposes; the user decides.
- Broken references are highest priority. A `CONTEXT.md` pointing to files that do not exist is actively harmful because the agent will note the missing file and proceed without the context the author intended.
- Update does not re-analyze the full directory to rewrite the CONTEXT.md. That is what `/autocontext:create` is for. Update is a targeted validation and repair pass.
- For GitHub URL validation, use `gh api repos/{owner}/{repo}/contents/{path}` to check existence. If `gh` is not authenticated or the request fails, flag the URL as unverifiable rather than broken.
