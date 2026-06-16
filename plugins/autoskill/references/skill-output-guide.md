# Skill Output Guide

Reference for what good generated skills look like. Consumed by the
`autoskill:build` and `autoskill:update` skills as self-reference during
orchestration, by the synthesizer agent when generating skill output, and by
the quality-check agent as the authoritative source of the Quality Checklist.

---

## Progressive Disclosure

A skill is loaded in three layers. Each layer has a different cost and different
rules for what belongs in it.

1. **Metadata (always in context).** The frontmatter `name` and `description`
   sit in Claude's context permanently. Claude reads them to decide whether to
   load the skill. Write the description as a standalone trigger: it must
   contain enough signal to fire without reading the body.
2. **Body (loaded on trigger).** The SKILL.md body, from the first heading
   through References, is loaded once Claude decides the skill is relevant.
   Target under 300 lines. A hard ceiling of 500 lines applies; above that,
   move Edge Cases or Inline Context into `references/`.
3. **Bundled resources (loaded on demand).** Files under `templates/`,
   `references/`, and `scripts/` are only read when a SKILL.md step explicitly
   points to them. Put detail that a first-time reader does not need here.

The three-layer model is what makes skills cheap to keep around: metadata cost
is tiny, body cost is paid only when the skill triggers, and bundled resources
are paid only when the work actually needs them.

---

## Folder Layout

### Minimal Skill (most patterns)

```
.claude/skills/<skill-name>/
  SKILL.md          # Core instructions
  metadata.json     # Discovery metadata and conventions
```

### Full Skill (complex patterns with templates or references)

```
.claude/skills/<skill-name>/
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

## Quick Checklist

<One-line-per-step checkbox list mirroring the Steps below. Concrete enough to
verify against a PR diff. Omit if Steps has fewer than four items.>

- [ ] <item 1>
- [ ] <item 2>
- [ ] <item 3>
- [ ] <item 4>

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

## Examples

<Two or three before/after pairs showing the pattern's triggering context.
Use an Input/Output format: "Input: <what the developer said or the shape of
the request>" followed by "Output: <the concrete artifact that should result>".
Draw the examples from real moments observed in the source files, not from
imagined scenarios.>

## References

- `templates/component.md` - structural template for the main artifact
- `references/edge-cases.md` - detailed edge case documentation

## Related Files

- `config/services_config.yml` - add a new entry under `services:` keyed by the service name
```

The `Examples` section grounds the skill in its actual triggering context. For
code-pattern skills, a pair of "when the user says X, produce Y" moments anchors
the reader faster than any amount of prose description.

The `Related Files` section lists files in the user's project that must be
edited for every new instance of the pattern (the companion files discovery
surfaced), each with a one-line description of the required edit. It is
distinct from `References`, which points to skill-internal files. Omit the
section when discovery found no companion files.

The `Quick Checklist` section is a scannable reference for experienced
implementers and a paste target for PR descriptions. It mirrors the Steps as
a one-line-per-step checkbox list where each item is concrete enough to verify
against a PR diff. The synthesizer omits this section when Steps has fewer
than four items, since a three-item checklist duplicates Steps without adding
value.

---

## metadata.json Structure

```json
{
  "skill_name": "<skill-name>",
  "description": "One-line description matching SKILL.md frontmatter",
  "pattern_description": "The developer's original pattern description, verbatim, so update re-runs can re-seed discovery from it",
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
  "companion_files": [
    {
      "path": "config/betamocks/services_config.yml",
      "reason": "Central registry. Each service using the :betamocks middleware must add an entry here.",
      "shape": "add a new entry under services: keyed by the service name, with base_uris and endpoints subkeys"
    }
  ],
  "user_provided_docs": [
    {
      "source": "https://example.com/docs/service-client-pattern",
      "type": "url",
      "fetched_at": "2026-04-09T12:00:00Z"
    },
    {
      "source": "/Users/you/notes/betamocks-explainer.md",
      "type": "path",
      "fetched_at": "2026-04-09T12:00:00Z"
    }
  ],
  "conventions": {
    "naming": "kebab-case files, PascalCase exports",
    "structure": "feature-based directory layout under src/features/",
    "testing": "co-located test files with .test suffix"
  },
  "compatibility": [
    "sidekiq",
    "internal-lib/service-base"
  ],
  "last_updated": "2026-04-09T12:00:00Z",
  "generated_by": "autoskill:build"
}
```

The optional `compatibility` field lists hard dependencies the pattern cannot
work without (gems, npm packages, CLIs, internal libraries). The update
skill uses it to warn the developer when a recorded dependency has
disappeared from the project. Omit the field when no hard dependencies were
identified. The `generated_by` field records the invoking skill:
`autoskill:build` on first generation, `autoskill:update` after an update.

Key points about `conventions`:
- Use the project's actual naming, not a generic label like `rails_conventions`
- Describe conventions in plain language
- Include naming, structure, and testing conventions at minimum

---

## Writing Voice

Prose in SKILL.md and its bundled references should read like a senior engineer
briefing a capable colleague, not a style guide.

- **Prefer imperative voice.** "Create the handler" beats "You should create a
  handler". Skip filler like "In order to". Get to the verb.
- **Ground non-obvious steps in a one-sentence because.** For any step whose
  reasoning is not self-evident, append a short justification drawn from
  discovery observations or user-provided docs. Example: "Register the new
  service in `services_config.yml`, because the middleware reads that file at
  boot and any service missing from it silently returns nil."
- **Avoid ALWAYS/NEVER in all caps.** Shouting makes SKILL.md feel like a wiki
  dump and does not actually raise compliance. If a constraint is truly hard,
  state the failure mode instead: "Skipping this registration causes
  `services_config.yml` validation to fail at boot."
- **Keep the tone calm and specific.** The reader already decided to use the
  skill. Do not spend paragraphs justifying the skill's existence.

## Template Conventions

Every file under `templates/` is something Claude is expected to copy, adapt,
and fill in. The template file itself must make its expectations legible.

- **Placeholder banner.** Every template file begins with a comment block, in
  the file's native comment syntax, listing the tokens a reader must replace.
  The banner names each token and describes what to put there. Example for
  YAML: `# Replace: <service_name>, <base_uri>, <auth_strategy>`. For Ruby:
  `# Replace: <ClassName>, <table_name>`. The synthesizer derives this list
  from the placeholders actually used in the template body.
- **Inline "why" comments on structural choices.** If the template contains a
  structural choice that looks wrong at first glance, counter-intuitive
  ordering, unusual error-handling placement, an unfamiliar middleware order,
  annotate the choice with a one-line comment explaining the failure mode that
  the choice prevents. The reader should not have to guess which lines are
  load-bearing.
- **Use real tokens, not metavariables.** Placeholders should look like
  `<service_name>` or `{{ServiceName}}`, not `FOO` or `XYZ`. Token style
  should match what the project already uses in its own templates if any
  exist.

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

### Hard Limits

The skill loader enforces two frontmatter constraints. Violating either one
does not degrade the skill; it prevents it from loading at all.

- `name` must be lowercase and hyphenated, and must match the skill's
  directory name exactly.
- `description` is capped at 1024 characters. The phrase-coverage advice
  below operates inside this cap: enumerate synonyms and trigger phrasings
  until the description approaches the limit, then stop. A description that
  overruns the cap in pursuit of coverage breaks activation entirely.

### Undertrigger Correction

Claude systematically undertriggers skills; it tends not to activate a skill
even when the skill clearly applies. Compensate by writing descriptions a
little pushy.

- Include an explicit directive: "Make sure to use this skill whenever the
  user mentions X, Y, or Z, even if they do not explicitly ask for
  '<internal-pattern-name>'."
- Name the trigger situation in the user's words, not in the internal
  vocabulary. A developer asking "wrap the Stripe API" should trigger a
  service-client skill even if they never say "service client".

### Cover the Phrase Space

Developers describe the same job many ways. The description should enumerate
the phrases the synthesizer has seen (or can reasonably expect).

- Enumerate three to five synonyms for the artifact itself. For a service
  client pattern: "client", "service", "connector", "API wrapper", "gateway".
- Enumerate three to five natural trigger phrasings a developer would use:
  "integrate with Stripe", "wrap the Stripe API", "add a new upstream",
  "build a client for their API", "connect to the billing provider".
- Describe the *job* the pattern does, not the internal base-class name. The
  reader does not know the internal vocabulary and will not search for it.

### Standalone Rule

The description is the only part of the skill in Claude's context before the
skill triggers. It must be interpretable without the body.

- Do not write "see below", "as described in Steps", or "refer to the
  Inline Context". The reader has not read those yet.
- A reader holding only the description should be able to tell (a) what the
  pattern is, (b) what phrases would trigger it, and (c) what kind of work
  results from applying it.

### Two "When to Use" Surfaces

A skill has two places that look like they answer "when should this skill run",
and they serve different readers.

- **Frontmatter `description`** is the pre-load trigger. It is always in
  context. Claude reads it to decide whether to load the body at all. Write it
  for a reader who has not seen the skill yet and who needs enough signal to
  commit to loading it.
- **`## When to Use` section** is the post-load runtime context. Claude reads
  it once the skill has already been loaded, to decide whether to proceed
  with the pattern versus stop. Write it for a reader who is already holding
  the full skill and needs positive and negative signals to choose.

These two surfaces should not be verbatim copies of each other. The description
is a trigger; the section is a decision aid. If the synthesizer writes the
same sentence in both, it is under-using one of the two surfaces.

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
| `templates/<pattern>_spec.<ext>` | The Testing section describes a multi-part test shape and discovery surfaced at least one real corresponding test file to model on |
| `templates/<companion-data>.<ext>` | A companion registration entry references a conventional fixture/data file that every new instance must create |
| `references/` | There are edge cases, historical decisions, or context too long for the main SKILL.md |
| `references/<variant>.md` | The pattern has two or more coherent variants (see Variant Splitting below) |
| `scripts/` | The pattern involves scaffolding, codegen, or repetitive file creation that a script accelerates |

### Variant Splitting

Sometimes a single pattern legitimately has parallel flavors, for example a
Postgres and a Mongo variant of the same data access layer, or a REST and a
GraphQL variant of the same service client. These are not inconsistencies or
drift; they are distinct canonical shapes that share a workflow.

The right structure is one SKILL.md plus one `references/<variant>.md` per
variant.

- The SKILL.md carries the shared workflow, the Steps common to every
  variant, and the **selection heuristic**: the rule that tells an
  implementer which variant to pick based on the shape of the work.
- Each `references/<variant>.md` carries only the variant-specific detail.
  Because references load on demand, readers only pay for the variant they
  actually need, and the main SKILL.md stays small.
- The SKILL.md References section lists each variant file with a one-line
  description of when to read it.

Variant splitting is distinct from handling inconsistencies. If discovery
finds two examples that disagree on, say, error handling, that is a Phase 4
clarifying question for the developer ("which is canonical?"), not a split.
Only split when the examples are all canonical and parallel.

---

## Quality Checklist

Before presenting generated skill output, verify:

- [ ] SKILL.md has valid YAML frontmatter with `name` and `description`, within the hard limits (`name` lowercase-hyphenated and matching the skill directory; `description` under 1024 characters)
- [ ] Trigger description is specific and action-oriented (see guidelines above)
- [ ] Steps describe intent, not tool calls or language-specific commands
- [ ] No hardcoded file paths that only apply to the source examples
- [ ] Conventions in metadata.json use the project's actual patterns, not generic labels
- [ ] Edge cases section is present and non-empty
- [ ] Testing section describes the shape of a good test without assuming a framework
- [ ] Only files that add value are included (no empty templates or placeholder scripts)
- [ ] If templates exist, they use the project's actual language and conventions
- [ ] Source files in metadata.json are real paths that exist in the project
- [ ] When the project has central registration manifests or middleware configuration files relevant to the pattern, SKILL.md contains an explicit "Register the new instance" step
- [ ] metadata.json contains a `companion_files` field (empty array acceptable)
- [ ] If the developer supplied documentation sources, SKILL.md reflects their terminology and framing, and metadata.json `user_provided_docs` lists each source with type and fetched_at
- [ ] SKILL.md is within the length budget: target under 300 lines, hard ceiling 500
- [ ] Every file path mentioned in SKILL.md resolves to a known destination (companion file, skill-internal path, or Related Files entry); no dangling references
- [ ] Every edge case says *how* to handle the situation, not just *that* it exists
- [ ] If a Quick Checklist section is present, its items mirror Steps 1:1 or are a strict subset
