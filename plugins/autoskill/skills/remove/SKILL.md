---
name: remove
description: Use when the user wants to delete a generated skill. Triggers on "remove autoskill skill", "delete generated skill", "uninstall skill <name>", or similar requests to remove a previously-built skill.
allowed-tools: Read, Edit, Glob, Bash(rm -rf .claude/skills/*)
argument-hint: <skill-name>
---

# Autoskill Remove

Delete a generated skill's directory and its manifest entry together, so the two never drift out of sync (a leftover directory with no manifest entry, or a manifest entry pointing at a deleted directory, is exactly the bug this skill exists to avoid).

## Arguments

- `$ARGUMENTS` contains the name of the skill to remove (e.g., `api-endpoint`)

## Phase 1: Locate the Skill

Look up the name in `.claude/skills/autoskill-manifest.json`, if it exists.

- If the manifest has an entry for this name, use its `path` to confirm `.claude/skills/<name>/` exists.
- If the manifest does not exist, or has no entry for this name, check directly whether `.claude/skills/<name>/` exists.

If the skill cannot be found by either method, list the available skills (Glob `.claude/skills/*/metadata.json`, cross-checked against the manifest, the same reconciliation `autoskill:list` performs) and ask the developer which one they meant. Do not proceed until a valid target is identified.

## Phase 2: Confirm Before Deleting

Before deleting anything, show the developer:

- The skill's path: `.claude/skills/<name>/`
- Its description (from the manifest entry, or from `SKILL.md` frontmatter if the manifest entry is missing)

Ask explicitly: "Delete the `<name>` skill at `.claude/skills/<name>/`? This removes the skill directory and its manifest entry."

Do not delete anything until the developer confirms.

## Phase 3: Delete Directory and Manifest Entry Together

On confirmation, perform both of the following as a single unit of work:

1. Delete the `.claude/skills/<name>/` directory and everything in it.
2. Remove this skill's entry from `.claude/skills/autoskill-manifest.json`, leaving every other entry untouched. If the manifest has no entry for this skill (e.g., it was already orphaned), skip this step.

Do not touch any usage or telemetry log, even if one exists elsewhere in the project. Removal only affects the skill's own directory and its manifest entry, not any historical event log.

If the manifest becomes an empty `skills` array after removal, leave it as a valid empty manifest rather than deleting the manifest file itself.

## Phase 4: Confirm and Close

Report what was deleted:

1. The directory removed
2. Whether a manifest entry was also removed (or noted as already absent)

## Notes

- This skill is destructive. Phase 2's confirmation step is mandatory and must never be skipped.
- To see what's available before removing something, use `autoskill:list`.
