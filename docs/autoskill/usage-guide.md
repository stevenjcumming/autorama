# Usage Guide

## Prerequisites

- Claude Code installed
- Autoskill plugin installed (`claude plugin add autoskill`)

## Initialize

Run once per project to set up autoskill.

```
/autoskill:init
```

This resolves the plugin's install path and writes `AUTOSKILL_PLUGIN_ROOT` to `.claude/settings.local.json`. Restart Claude Code after running this; hooks and settings (including this environment variable) are only loaded when a session starts.

### What Init Writes

Init produces a `settings.local.json` shaped like this `settings.example.json`:

```json
{
  "env": {
    "AUTOSKILL_PLUGIN_ROOT": "/Users/you/.claude/plugins/cache/stevenjcumming/autoskill/1.0.0-rc.1"
  }
}
```

The value on your machine is the absolute path where the plugin is installed. If init fails or you configure manually, follow the same shape and keep the path absolute. The build and update skills resolve templates and references through `$AUTOSKILL_PLUGIN_ROOT` from whatever directory a session happens to run in; a relative path would resolve against the current working directory, silently pointing at the wrong location (or at an attacker-controllable one). Absolute paths are the secure, portable pattern for settings-driven script and hook references.

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

**1. Supporting documentation (optional)**

Autoskill asks if you have any documentation it should reference. You can paste:
- URLs (architecture docs, ADRs, RFCs, wiki pages)
- Absolute file paths to local docs

Reply `none` to skip. This is optional but improves quality when docs exist.

**2. Discovery runs automatically**

Autoskill searches your codebase for 2-5 representative examples of the pattern. It maps dependencies, finds companion files, and records observations about conventions.

Companion files are files in your project that must be edited every time a new instance of the pattern is created. For example, if every new component requires a corresponding internationalization file, autoskill detects that relationship so the generated skill includes it as an explicit step.

If no examples are found, you will be offered options: point to an example file, describe the pattern, share docs, or draft from conventions alone.

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

Use this when your codebase has evolved and an existing skill needs to reflect current patterns.

### What You Will Be Asked

**1. Documentation refresh**

If the skill was built with documentation sources, autoskill shows the list and asks what to do:
- `refresh` - Re-fetch all existing sources
- `add` - Keep existing sources and add new ones
- `replace` - Discard existing sources and provide new ones
- `skip` - Proceed without touching documentation

**2. Re-discovery runs automatically**

Autoskill searches the codebase again using the existing pattern description. It also runs a compatibility check: if the skill's `metadata.json` records hard dependencies (gems, packages, CLIs), it verifies they still exist in the project and warns about any drift.

**3. Scope and convention questions**

Autoskill summarizes what changed since the last build and asks:
- Has the scope of this pattern changed?
- Are the differences intentional changes that should be reflected?

**4. Diff and confirm**

Unlike build, update never writes without explicit approval. Autoskill shows a readable diff of proposed changes to `SKILL.md`, `metadata.json`, and any additional files. Changes are only written after you explicitly confirm. If you decline, no files are modified.

---

## Related Documentation

- [How It Works](how-it-works.md) - Detailed workflow phases
- [Generated Output](generated-output.md) - What the skill folder contains
