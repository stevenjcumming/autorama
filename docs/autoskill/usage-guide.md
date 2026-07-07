# Usage Guide

## Prerequisites

- Claude Code installed
- Autoskill plugin installed (`claude plugin add autoskill`), then a session restart so the plugin's skills are registered

There is no further setup step. Build and update resolve the plugin's own templates and references through Claude Code's native `${CLAUDE_PLUGIN_ROOT}` variable, which the harness substitutes automatically; nothing needs to be written to `.claude/settings.local.json` and no second restart is required beyond the one after installation.

---

## Build a Skill

```
/autoskill:build <pattern description>
```

The pattern description is natural language. Examples:

- `/autoskill:build how we build API endpoints`
- `/autoskill:build our background job pattern`
- `/autoskill:build the way we write data access layers`

### What You Will Be Asked

The build workflow is interactive. Here is what to expect at each step:

**1. Naming and documentation (only if needed)**

If you mention documentation inline in your request (e.g. "build a skill for our service clients using docs: https://wiki.internal/..."), autoskill picks it up automatically and does not ask. Otherwise, before discovery runs, it asks a single combined question covering whatever still needs an answer:

- **Naming**, only if `.claude/skills/<name>/` already exists: update the existing skill instead (hands off to `/autoskill:update`), replace it, or pick a new name.
- **Documentation**, only if none was supplied inline: paste URLs (architecture docs, ADRs, RFCs, wiki pages) or absolute file paths to local docs, one per line, or reply `none` to skip.

If neither applies (no name conflict, and docs were already supplied inline), autoskill asks nothing here and goes straight to discovery.

**2. Discovery runs automatically**

Autoskill searches your codebase for 2-5 representative examples of the pattern. It maps dependencies, finds companion files, and records observations about conventions.

Companion files are files in your project that must be edited every time a new instance of the pattern is created. For example, if every new component requires a corresponding internationalization file, autoskill detects that relationship so the generated skill includes it as an explicit step.

If no examples are found, autoskill tells you what it searched and why nothing matched, then offers options: point to an example file, describe the pattern, share docs, or draft from conventions alone.

**3. Clarifying questions**

Autoskill asks about:
- **Scope**: Should the skill cover just the core pattern, or related concerns like error handling and logging?
- **Edge cases**: Unusual scenarios someone implementing this pattern should know about?
- **Alternatives**: When should someone use this pattern versus an alternative approach?

Additional questions appear if inconsistencies were found between examples or if test conventions are unclear.

Answer in whatever format is convenient. Shorthand is fine.

**4. Review output**

Autoskill generates the skill files, runs a quality check, and writes them to `.claude/skills/<skill-name>/`. Build writes files automatically after the quality check passes. It summarizes what was created and what the skill enables.

For complex skills (many files or long SKILL.md), it offers to test the skill on a new example.

### Verifying Your Skill

After build completes:

1. Check the generated files at `.claude/skills/<skill-name>/`
2. Read `SKILL.md` to verify the steps match your team's conventions
3. Review `metadata.json` to confirm source files and dependency mappings
4. Optionally, start a new session and ask Claude to implement the pattern to see the skill in action

---

## Update a Skill

```
/autoskill:update <skill-name>
```

Use this when your codebase has evolved and an existing skill needs to reflect current patterns. Run it with no argument and autoskill lists the skills it has generated and asks which one you mean.

### What You Will Be Asked

**1. Documentation refresh**

If the skill was built with documentation sources, autoskill shows the list and asks what to do:
- `refresh` - Re-fetch all existing sources
- `add` - Keep existing sources and add new ones
- `replace` - Discard existing sources and provide new ones
- `skip` - Proceed without documentation content this run. Autoskill never stores fetched document text between runs (only the source and fetch time, so it can re-fetch later), so `skip` means synthesizing without that content, not silently reusing it; autoskill tells you this plainly when you choose it.

**2. Re-discovery runs automatically**

Autoskill searches the codebase again using the existing pattern description. It also runs a compatibility check: if the skill's `metadata.json` records hard dependencies (gems, packages, CLIs), it verifies they still exist in the project and warns about any drift.

**3. Scope and convention questions**

Autoskill summarizes what changed since the last build and asks:
- Has the scope of this pattern changed?
- Are the differences intentional changes that should be reflected?

**4. Diff and confirm**

Unlike build, update never writes without explicit approval. Autoskill shows a readable diff of proposed changes to `SKILL.md`, `metadata.json`, and any additional files. Changes are only written after you explicitly confirm. If you decline, no files are modified.

---

## Managing Generated Skills

```
/autoskill:list
/autoskill:remove <skill-name>
/autoskill:help
```

`list` reads the manifest, reconciles it against what's actually on disk, and flags entries that look stale (old `last_updated`, or source files that no longer exist). `remove` asks for confirmation, then deletes the skill's directory and its manifest entry together, so neither is left orphaned. `help` shows the full command table and typical order (build once, update as the codebase evolves, remove when no longer needed) if you just want a refresher.

---

## Related Documentation

- [How It Works](how-it-works.md) - Detailed workflow phases
- [Generated Output](generated-output.md) - What the skill folder contains
