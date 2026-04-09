# Skill Output Guide

Reference for what good generated skills look like. The `autoskill:build` command
uses this document as self-reference when generating skill output.

---

## Folder Layout

### Minimal Skill (most patterns)

```
.claude/skills/autoskills/<skill-name>/
  SKILL.md          # Core instructions
  metadata.json     # Discovery metadata and conventions
```

### Full Skill (complex patterns with templates or references)

```
.claude/skills/autoskills/<skill-name>/
  SKILL.md
  metadata.json
  templates/        # Structural templates Claude fills in during generation
    component.md    # e.g., "shape of a typical component for this pattern"
  references/       # Supporting docs Claude reads for context
    edge-cases.md
  scripts/          # Helper scripts if the pattern involves codegen or scaffolding
    scaffold.sh
```

Only include `templates/`, `references/`, or `scripts/` when the pattern genuinely
needs them. Most skills only need `SKILL.md` + `metadata.json`.

---

## SKILL.md Structure

A well-formed SKILL.md has YAML frontmatter followed by structured sections.

```markdown
---
name: <skill-name>
description: >
  <One-line trigger description. Claude uses this to decide when to activate the skill.>
---

# <Skill Name>

## When to Use

<Clear conditions under which this skill applies. Include both positive signals
("when you see X") and negative signals ("do not use this for Y").>

## Steps

1. <First step, described as intent, not commands>
2. <Second step>
3. ...

Each step describes what to accomplish, not which tool to call. Claude determines
the right approach based on the project's stack and structure.

## Inline Context

<Key facts Claude needs while executing the pattern. This is not a tutorial;
it is contextual knowledge that prevents common mistakes.>

- <Convention or constraint>
- <Convention or constraint>

## Edge Cases

- <Situation that requires special handling>
- <Another edge case>

## Testing

<What a complete test looks like for this pattern. Describe the shape of a good
test without naming specific frameworks unless the project's stack makes the
choice unambiguous.>

## References

- `templates/component.md` - structural template for the main artifact
- `references/edge-cases.md` - detailed edge case documentation
```

---

## metadata.json Structure

```json
{
  "skill_name": "<skill-name>",
  "description": "One-line description matching SKILL.md frontmatter",
  "source_files": [
    "src/features/billing/charge-customer.ts",
    "src/features/onboarding/create-account.ts"
  ],
  "dependency_map": {
    "src/features/billing/charge-customer.ts": [
      "src/lib/payments.ts",
      "src/types/billing.ts"
    ]
  },
  "internal_docs_read": [
    "docs/architecture.md",
    "CONTRIBUTING.md"
  ],
  "conventions": {
    "naming": "kebab-case files, PascalCase exports",
    "structure": "feature-based directory layout under src/features/",
    "testing": "co-located test files with .test suffix"
  },
  "last_updated": "2026-04-09T12:00:00Z",
  "generated_by": "autoskill:build"
}
```

Key points about `conventions`:
- Use the project's actual naming, not a generic label like `rails_conventions`
- Describe conventions in plain language
- Include naming, structure, and testing conventions at minimum

---

## Writing Good Trigger Descriptions

The `description` field in SKILL.md frontmatter is what Claude uses to decide
whether to activate the skill. A good trigger description is specific enough to
fire when relevant and narrow enough to avoid false positives.

### Good Triggers

| Trigger | Why It Works |
|---------|-------------|
| "When creating a new API endpoint that follows the project's controller pattern" | Scoped to a specific action (new endpoint) and references the project pattern |
| "When adding a background job that processes items from a queue" | Describes the shape of the work, not a framework |
| "When implementing a new data migration that transforms existing records" | Clear action with enough specificity to avoid matching unrelated migrations |

### Weak Triggers

| Trigger | Problem |
|---------|---------|
| "When writing code" | Too broad; matches everything |
| "When using Rails service objects" | Stack-specific; breaks if project uses a different framework |
| "When making changes" | Vague; does not describe what kind of changes |
| "For backend development" | Category, not a trigger condition |

### Guidelines

- Start with "When" followed by a specific action verb
- Reference the pattern shape, not a framework name (unless the project only uses one)
- Include enough context that Claude can distinguish this pattern from similar ones
- A trigger should match 2-10 times across a typical month of development, not 0 or 100

---

## Minimal vs. Full Skills

### When a Minimal Skill Is Enough

- The pattern is a single file type (e.g., "how we write data access objects")
- No structural templates are needed; the SKILL.md instructions are sufficient
- The pattern has few edge cases that fit in the main document

### When to Include Extra Files

| Directory | Include When |
|-----------|-------------|
| `templates/` | The pattern produces files with a consistent structure that benefits from a skeleton |
| `references/` | There are edge cases, historical decisions, or context too long for the main SKILL.md |
| `scripts/` | The pattern involves scaffolding, codegen, or repetitive file creation that a script accelerates |

---

## Quality Checklist

Before presenting generated skill output, verify:

- [ ] SKILL.md has valid YAML frontmatter with `name` and `description`
- [ ] Trigger description is specific and action-oriented (see guidelines above)
- [ ] Steps describe intent, not tool calls or language-specific commands
- [ ] No hardcoded file paths that only apply to the source examples
- [ ] Conventions in metadata.json use the project's actual patterns, not generic labels
- [ ] Edge cases section is present and non-empty
- [ ] Testing section describes the shape of a good test without assuming a framework
- [ ] Only files that add value are included (no empty templates or placeholder scripts)
- [ ] If templates exist, they use the project's actual language and conventions
- [ ] Source files in metadata.json are real paths that exist in the project
