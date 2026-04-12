# Generated Output

## Progressive Disclosure

Skills load in three layers, each with a different cost:

1. **Metadata (always in context)** - The frontmatter `name` and `description` sit in Claude's context permanently. Claude reads them to decide whether to load the skill.
2. **Body (loaded on trigger)** - The SKILL.md body loads once Claude decides the skill is relevant. Target: under 300 lines.
3. **Bundled resources (loaded on demand)** - Files under `templates/`, `references/`, and `scripts/` are only read when a SKILL.md step explicitly points to them.

This model keeps skills cheap to maintain. Metadata cost is tiny, body cost is paid only when the skill triggers, and resource cost is paid only when the work needs them.

---

## Folder Layout

### Minimal Skill

Most patterns produce two files:

```
.claude/skills/<skill-name>/
  SKILL.md          # Core instructions
  metadata.json     # Discovery metadata and conventions
```

### Full Skill

Complex patterns may include additional files:

```
.claude/skills/<skill-name>/
  SKILL.md
  metadata.json
  templates/        # Structural templates Claude fills in
  references/       # Supporting docs for edge cases or variants
  scripts/          # Helper scripts for scaffolding
```

| Directory | Included When |
|-----------|---------------|
| `templates/` | Pattern produces files with a consistent structure that benefits from a skeleton |
| `references/` | Edge cases or historical decisions too detailed for SKILL.md |
| `scripts/` | Pattern involves scaffolding or repetitive file creation |

---

## SKILL.md Sections

| Section | Purpose |
|---------|---------|
| **Frontmatter** | `name` and `description` (trigger). Always in Claude's context. |
| **When to Use** | Positive and negative signals for activating the skill |
| **Quick Checklist** | One-line-per-step checkbox list mirroring Steps. Omitted if fewer than 4 steps. |
| **Steps** | Ordered instructions described as intent, not commands |
| **Inline Context** | Project-specific conventions and constraints that prevent mistakes |
| **Edge Cases** | Situations requiring special handling, with actionable guidance |
| **Testing** | Shape of a good test: what to assert, what to mock, coverage expectations |
| **Examples** | Input/Output pairs drawn from real codebase examples |
| **References** | Paths to skill-internal files (templates, references, scripts). Omitted for minimal skills. |
| **Related Files** | Companion files in the project that must be edited for every new instance. Omitted when none exist. |

---

## metadata.json Fields

| Field | Description |
|-------|-------------|
| `skill_name` | Kebab-case skill identifier |
| `description` | One-line description matching SKILL.md frontmatter |
| `source_files` | Example file paths used during discovery |
| `dependency_map` | Per-example dependency mapping |
| `internal_docs_read` | Documentation files found during discovery |
| `companion_files` | Files that must be edited for every new pattern instance (empty array if none) |
| `user_provided_docs` | Documentation sources supplied by the developer (source, type, fetched_at) |
| `conventions` | Project's naming, structure, and testing conventions in plain language |
| `compatibility` | Hard dependencies the pattern relies on (optional, used by update for drift detection) |
| `last_updated` | ISO 8601 timestamp |
| `generated_by` | `autoskill:build` or `autoskill:update` |

---

## Manifest

The `/autoskill:build` and `/autoskill:update` commands maintain `.claude/skills/autoskill-manifest.json` as a human-readable index of all generated skills.

```json
{
  "skills": [
    {
      "name": "api-endpoint",
      "path": ".claude/skills/api-endpoint/",
      "description": "One-line description",
      "pattern_type": "Free-form pattern category label",
      "last_updated": "2026-04-12T12:00:00Z"
    }
  ]
}
```

The manifest is informational. It does not affect how Claude discovers or loads skills.

---

## Related Documentation

- [Usage Guide](usage-guide.md) - How to build and update skills
- [How It Works](how-it-works.md) - Build and update workflow phases
- [Agent Architecture](agent-architecture.md) - Agents that produce these outputs
