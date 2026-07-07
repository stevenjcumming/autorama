---
name: list
description: Use when the user wants to see what autoskill has generated. Triggers on "list autoskill skills", "what skills has autoskill generated", "show generated skills", or similar requests to inventory or audit generated skills.
allowed-tools: Read, Glob
---

# Autoskill List

Show every skill autoskill has generated for this project, cross-checked against what's actually on disk, and flag anything that looks stale or out of sync. This skill is read-only: it never writes or modifies anything.

## Phase 1: Read the Manifest

Read `.claude/skills/autoskill-manifest.json`.

- If the file does not exist, report that no skills have been generated yet in this project and suggest running `autoskill:build <pattern description>`. Stop here.
- If it exists, parse the `skills` array. Each entry has `name`, `path`, `description`, `pattern_type`, and `last_updated`.

## Phase 2: Reconcile Against Disk

Glob `.claude/skills/*/metadata.json` to find every generated skill directory actually present.

- **Orphaned directories**: a directory found on disk with no corresponding manifest entry. Flag it as "orphaned — not tracked in the manifest".
- **Dangling manifest entries**: a manifest entry whose `.claude/skills/<name>/` directory no longer exists. Flag it as "manifest entry for a deleted skill — consider removing it".

## Phase 3: Check Staleness Signals

For each manifest entry that still has a matching directory, compute two lightweight staleness signals (this is a cheap subset of the full compatibility check that `autoskill:update` performs, not a replacement for it):

1. **Age**: if `last_updated` is more than ~90 days old, flag "may be stale — consider autoskill:update".
2. **Missing source files**: read the skill's `metadata.json` and, if it has a `source_files` field, Glob-check whether each listed path still exists. If N of M no longer exist, flag "possibly stale — N of M source files no longer found".

A skill can carry both flags at once; show both if both apply.

## Phase 4: Report

Present a table (or list) with one row per manifest entry, showing:

- Name
- Pattern type
- Last updated
- Staleness flags from Phase 3 (or "up to date" if none apply)

Follow with a separate section listing any orphaned directories and any dangling manifest entries found in Phase 2, if there are any.

## Notes

- This skill never modifies `.claude/skills/` or the manifest. To fix drift found here, use `autoskill:update <skill-name>` to refresh a skill, or `autoskill:remove <skill-name>` to clean up an orphaned directory or dangling entry.
