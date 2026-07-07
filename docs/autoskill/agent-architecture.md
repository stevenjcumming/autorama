# Agent Architecture

Autoskill delegates work through three specialized agents. The build and update skills act as orchestrators, dispatching to agents via `Task()` and parsing their structured output.

## Agent Tree

```
/autoskill:build (skill)
    ├── discovery (Sonnet)
    ├── synthesizer (Opus)
    └── quality-check (Sonnet)

/autoskill:update (skill)
    ├── discovery (Sonnet)
    ├── synthesizer (Opus)
    └── quality-check (Sonnet)
```

Both skills use the same three agents (invoked as `autoskill:discovery`, `autoskill:synthesizer`, `autoskill:quality-check` — the harness adds the `autoskill:` prefix at invocation time, so each agent's own `name:` field is bare). The update skill seeds discovery with the existing skill's pattern description instead of a new user description. Both skills' shared orchestration logic (stack detection, the exact Task invocations for each agent, discovery status branching) lives in one place, `references/orchestration.md`, so the two skills can't drift out of sync with each other.

## Model Tiers

| Tier | Model | Agents | Role |
|------|-------|--------|------|
| **Heavy** | Opus | synthesizer | Complex synthesis, pattern distillation, writing voice |
| **Medium** | Sonnet | discovery, quality-check | Codebase search, structured validation |

The orchestrating skills (build, update) inherit the session's default model rather than pinning one: their work (parsing tags, branching on status, asking questions) is mostly mechanical, and pinning would also freeze them below newer model families as they ship. The synthesizer keeps its explicit Opus pin, since that is where the actual generation quality lives.

## Agent Reference

### `discovery`

Finds concrete examples of a pattern in the codebase.

| Field | Value |
|-------|-------|
| Model | Sonnet |
| Tools | Read, Glob, Grep |
| Input | Pattern description, detected stack, user-provided docs |
| Output | `<status>` (required), `<examples>`, `<no-examples-reason>` (when examples is "none"), `<dependency-map>`, `<test-files>`, `<companion-files>`, `<observations>`, `<internal-docs>` |

**Key behaviors:**
- Searches using four strategies: directory/naming conventions, structural patterns, content patterns, internal documentation
- Selects 2-5 representative examples (not edge cases or legacy code); since Glob results are ordered by modification time, recency preference means favoring earlier-sorting candidates when otherwise equal, not inspecting timestamps directly
- Maps dependencies per example, including test files
- Runs companion file detection using four heuristics (config initializers, middleware registries, reverse-reference, parallel structure confirmation)
- Always reports a result status (`found`, `empty`, or `search-failed`) with every search pattern attempted, so the orchestrating skill can tell "the codebase lacks this pattern" apart from "the search never ran properly"; on `empty`, `<no-examples-reason>` explains what was searched and why nothing matched
- Read-only; does not write or modify any files

### `synthesizer`

Generates complete skill folder content from discovery output and clarifying answers.

| Field | Value |
|-------|-------|
| Model | Opus |
| Tools | Read |
| Input | Skill name, pattern description, stack, discovery output, clarifying answers, user-provided docs, a shared `CURRENT_TIMESTAMP` (captured once by the orchestrating skill, since this agent has no Bash access), invoking skill, template and guide paths |
| Output | `<skill-files>`, `<file-summary>`, `<quality-notes>` |

**Key behaviors:**
- Reads the SKILL.md template, metadata.json template, and skill-output-guide before generating
- Reads all example files and key dependencies to understand the pattern
- Synthesizes the pattern across examples rather than reproducing a single one
- Generates trigger descriptions with synonym coverage and undertrigger correction
- Determines whether additional files (templates, references, scripts) are needed
- Handles variant splitting when discovery reports parallel flavors of the same pattern
- Self-verifies its own output against the skill-output-guide's Quality Checklist directly (rather than a separately maintained paraphrase), so its self-check and the quality-check agent's pass can't drift out of sync
- Returns all content in memory; does not write files

### `quality-check`

Validates generated skill content against an 18-check quality checklist, each check identified by a stable slug (e.g. `frontmatter-valid`, `no-dangling-references`, `no-leaked-placeholders`) defined once in the skill-output-guide, rather than by position, so the count can grow without renumbering everything downstream.

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
- No leaked `{{...}}` template placeholders from `SKILL.template.md` or `metadata.template.json` in generated output

Issues are categorized as **blocking** (must fix before writing) or **warnings** (noted for the developer).

## Tool Access Principles

- **Discovery** gets `Read`, `Glob`, `Grep` for searching. No write access.
- **Synthesizer** gets `Read` only for loading templates and examples. No write access.
- **Quality-check** gets `Read` only for loading the guide. No write access.
- All file writes happen in the orchestrating skill, not in agents.
- The orchestrating skills get a narrow `Bash(date:*)` grant, used once per run to capture a single shared timestamp for every field that needs one — no agent has Bash access of its own.

## Related Documentation

- [How It Works](how-it-works.md) - Full build and update workflows
- [Generated Output](generated-output.md) - What the agents produce
