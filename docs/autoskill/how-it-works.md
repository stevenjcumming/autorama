# How It Works

## Build Workflow

The `/autoskill:build` skill orchestrates a 7-phase workflow. The build skill acts as an orchestrator; the heavy lifting is delegated to specialized agents via `Task()`.

```
  Pattern Description
        ↓
  1. Understand Request ─── capture timestamp, detect stack, resolve name, collect docs
        ↓
  2. Discovery ─────────── discovery agent (Sonnet)
        ↓
  3. No Examples? ──────── fallback options (skip if examples found)
        ↓
  4. Clarifying Questions ─ scope, edge cases, alternatives
        ↓
  5. Generate & Validate
        ├── Synthesize ──── synthesizer agent (Opus)
        ├── Quality Check ── quality-check agent (Sonnet)
        └── Write Files ─── .claude/skills/<name>/
        ↓
  6. Update Manifest ───── autoskill-manifest.json
        ↓
  7. Confirm & Close
```

### Phase 1: Understand the Request

- Captures a single timestamp (via a narrowly-scoped `Bash(date:*)` grant) reused for every timestamped field this run writes, since none of the delegated agents have Bash access of their own
- Derives a kebab-case skill name from the pattern description
- Scans for lockfiles and manifests to detect the project stack (language, frameworks, tooling)
- Parses `$ARGUMENTS` for inline documentation references, so a request like "build a skill for X using docs: https://..." doesn't need a follow-up question
- If `.claude/skills/<name>/` already exists, or documentation wasn't supplied inline, asks a single combined question covering whichever of the two still needs an answer (update existing / replace / new name; and/or which docs to use) — asked once, before discovery runs, since discovery uses whatever documentation is available to seed its own search

### Phase 2: Discovery

Delegates to the `discovery` agent. The agent searches the codebase using four strategies in order of reliability:

1. **Directory and naming conventions** - Directories or files whose names match the pattern role
2. **Structural patterns** - Inheritance, decorators, annotations, registration patterns
3. **Content patterns** - Shared method signatures, lifecycle hooks, consistent imports
4. **Internal documentation** - ADRs, CONTRIBUTING guides, README files in relevant directories

The agent selects 2-5 representative examples, maps their dependencies, detects companion files (registration manifests that must be edited for every new instance), and records observations about conventions.

Companion file detection uses four heuristics:
- Follow configuration initializers to their data files
- Search middleware and package registries for config manifests
- Reverse-reference each example's identifying symbol across the repo
- Confirm candidates via parallel structure (multiple entries, one per existing instance)

Every discovery response carries a required status (`found`, `empty`, or `search-failed`) along with the search patterns attempted. The build skill branches on it: `found` proceeds to clarifying questions, `empty` goes to Phase 3, and `search-failed` triggers one retry with different patterns (a failed search says nothing about whether the pattern exists). If the retry also fails, the attempted patterns are shown to the developer.

### Phase 3: Handle No Examples

If discovery returned status `empty` (the searches ran, the codebase genuinely lacks the pattern), autoskill first states what discovery searched and why nothing matched (`<no-examples-reason>`), then the developer chooses from:
1. Point to a specific example file
2. Describe the pattern verbally
3. Share internal architecture docs
4. Draft from conventions alone

This phase is skipped when examples are found.

### Phase 4: Clarifying Questions

All questions are asked at once (not iteratively). Always asked: scope, edge cases, alternatives. Conditionally asked: inconsistency resolution (if examples disagree), test conventions (if unclear from the dependency map).

### Phase 5: Generate and Validate

Three sub-steps:

1. **Synthesize** - The `synthesizer` agent reads the templates, guide, examples, and clarifying answers, then generates all skill file content in memory, using the shared timestamp captured in Phase 1 for every timestamp field it writes
2. **Quality check** - The `quality-check` agent validates against an 18-check checklist, each identified by a stable slug. Issues are categorized as blocking (must fix) or warnings (noted for the developer). See the [agent architecture](agent-architecture.md#quality-check) for the full checklist
3. **Write files** - Skill files are written to `.claude/skills/<skill-name>/`

If the quality check fails, the synthesizer is re-prompted with specific issues. If it fails a second time, files are written anyway with unresolved issues noted.

### Phase 6: Update Manifest

Creates or updates `.claude/skills/autoskill-manifest.json` with the skill's name, path, description, pattern type, and timestamp. The manifest is a human-readable index; it does not affect how Claude discovers skills.

### Phase 7: Confirm and Close

Summarizes all files written, describes what the skill enables, and notes any quality warnings. For complex skills, offers to test on a new example.

---

## Update Workflow

The `/autoskill:update` skill re-runs discovery against the current codebase, generates updated content, and presents a diff for confirmation before overwriting. Unlike build, update never writes without explicit approval.

```
  Skill Name (or none — autoskill lists candidates and asks)
       ↓
  1. Validate & Setup ──── locate skill, read existing files, detect stack, capture timestamp
       ↓
  2. Re-Discovery ──────── discovery agent (Sonnet)
       ├── Compatibility ── verify recorded dependencies still exist
       ↓
  3. Ask About Changes ─── scope changes, new conventions
       ↓
  4. Generate Updated ──── synthesizer + quality check (same as build)
       ↓
  5. Diff & Confirm ────── show changes, wait for approval
       ↓
  6. Write Files ──────── overwrite skill folder, update manifest (created if missing)
       ↓
  7. Confirm & Close
```

### How Update Differs from Build

| Aspect | Build | Update |
|--------|-------|--------|
| Starting point | Pattern description | Existing skill name |
| Discovery seed | User's description | Existing skill's pattern description |
| Documentation handling | Ask for new sources | Show existing sources with refresh/add/replace/skip options |
| Compatibility check | Not applicable | Verifies recorded hard dependencies still exist |
| Clarifying questions | Scope, edge cases, alternatives | Scope changes, convention differences |
| Write confirmation | Writes immediately after quality check | Shows diff first, requires explicit approval |
| File cleanup | Creates new directory | Can remove files no longer in the output (after confirming) |

### Compatibility Check

During re-discovery, the update skill reads the `compatibility` field from `metadata.json`. For each entry (gems, npm packages, CLIs, internal libraries), it verifies the dependency still exists in the project — CLI checks exclude common noise paths (`node_modules/`, `vendor/`, `.git/`, `log/`, `tmp/`, and stack equivalents) and require a word-boundary match, so a short command name doesn't false-match inside an unrelated longer word. Missing dependencies are flagged as drift, and the developer chooses to proceed, drop the dependency, or investigate.

---

## Related Documentation

- [Agent Architecture](agent-architecture.md) - Agent details, model tiers, tool access
- [Generated Output](generated-output.md) - What the skill folder contains
