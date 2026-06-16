# Agent Architecture

Autoskill delegates work through three specialized agents. The build and update skills act as orchestrators, dispatching to agents via `Task()` and parsing their structured output.

## Agent Tree

```
/autoskill:build (skill, Opus)
    ├── autoskill-discovery (Sonnet)
    ├── autoskill-synthesizer (Opus)
    └── autoskill-quality-check (Sonnet)

/autoskill:update (skill, Opus)
    ├── autoskill-discovery (Sonnet)
    ├── autoskill-synthesizer (Opus)
    └── autoskill-quality-check (Sonnet)
```

Both skills use the same three agents. The update skill seeds discovery with the existing skill's pattern description instead of a new user description.

## Model Tiers

| Tier | Model | Agents | Role |
|------|-------|--------|------|
| **Heavy** | Opus | synthesizer | Complex synthesis, pattern distillation, writing voice |
| **Medium** | Sonnet | discovery, quality-check | Codebase search, structured validation |

The orchestrating skills (build, update) also run on Opus since they manage the multi-phase workflow and make judgment calls about quality check results.

## Agent Reference

### `autoskill-discovery`

Finds concrete examples of a pattern in the codebase.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Glob, Grep |
| Input | Pattern description, detected stack, user-provided docs |
| Output | `<status>` (required), `<examples>`, `<dependency-map>`, `<test-files>`, `<companion-files>`, `<observations>`, `<internal-docs>` |

**Key behaviors:**
- Searches using four strategies: directory/naming conventions, structural patterns, content patterns, internal documentation
- Selects 2-5 representative examples (not edge cases or legacy code)
- Maps dependencies per example, including test files
- Runs companion file detection using four heuristics (config initializers, middleware registries, reverse-reference, parallel structure confirmation)
- Always reports a result status (`found`, `empty`, or `search-failed`) with every search pattern attempted, so the orchestrating skill can tell "the codebase lacks this pattern" apart from "the search never ran properly"
- Read-only; does not write or modify any files

### `autoskill-synthesizer`

Generates complete skill folder content from discovery output and clarifying answers.

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read |
| Input | Skill name, pattern description, stack, discovery output, clarifying answers, user-provided docs, template and guide paths |
| Output | `<skill-files>`, `<file-summary>`, `<quality-notes>` |

**Key behaviors:**
- Reads the SKILL.md template, metadata.json template, and skill-output-guide before generating
- Reads all example files and key dependencies to understand the pattern
- Synthesizes the pattern across examples rather than reproducing a single one
- Generates trigger descriptions with synonym coverage and undertrigger correction
- Determines whether additional files (templates, references, scripts) are needed
- Handles variant splitting when discovery reports parallel flavors of the same pattern
- Returns all content in memory; does not write files

### `autoskill-quality-check`

Validates generated skill content against a 16-point quality checklist.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read |
| Input | Skill files output, skill name, detected stack, guide path |
| Output | `<quality-result>` with status (pass, pass-with-warnings, fail) |

**Checklist categories:**
- Frontmatter validity and trigger description quality
- Steps describe intent (not commands)
- No hardcoded example paths
- Edge cases present and actionable
- Testing section describes test shape
- Companion files surfaced in Steps when present
- Length budget (target 300 lines, hard ceiling 500)
- No dangling file references
- Quick Checklist consistency with Steps

Issues are categorized as **blocking** (must fix before writing) or **warnings** (noted for the developer).

## Tool Access Principles

- **Discovery** gets `Read`, `Glob`, `Grep` for searching. No write access.
- **Synthesizer** gets `Read` only for loading templates and examples. No write access.
- **Quality-check** gets `Read` only for loading the guide. No write access.
- All file writes happen in the orchestrating skill, not in agents.

## Related Documentation

- [How It Works](how-it-works.md) - Full build and update workflows
- [Generated Output](generated-output.md) - What the agents produce
