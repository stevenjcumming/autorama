# CONTEXT.md Format Guide

This is the single definition of the `CONTEXT.md` format for the autocontext plugin. The analyzer, generator, and validator agents all load this file. The generator follows it when composing content; the validator checks files against it.

## What CONTEXT.md Is

A `CONTEXT.md` provides scoped, directory-level context that agents read before acting: purpose, key references, documentation mappings, task bundles, and constraints. It answers up to five questions. Sections are included only when the agent would make wrong assumptions without them.

Codebases carry implicit knowledge. A `payments/` directory is not like a `docs/` directory, but nothing in the file tree tells the agent that. Stuffing everything into a single root-level instructions file creates a monolithic blob loaded on every task regardless of relevance; it does not scale, does not route, and does not distinguish "never do this anywhere" from "never do this here specifically". `CONTEXT.md` solves this by scoping context to the directory where the agent is working.

## Design Principles

- **One file type.** `CONTEXT.md` is the only file autocontext introduces.
- **Scoped, not global.** Each `CONTEXT.md` governs its own directory. No implicit inheritance. If a subdirectory needs parent context, it declares the dependency in Key References.
- **Declarative routing.** Tasks map to tool bundles. The agent does not decide what applies; the `CONTEXT.md` declares it.
- **Bundles are complete.** A task bundle is the full specification for that task. If a constraint matters, it belongs in the bundle.
- **Constraints are axioms.** Never Do Here holds regardless of the active task. If a task bundle and a Never Do Here constraint conflict, the constraint wins.
- **Co-located with code.** `CONTEXT.md` files live in the repo and version with the code.
- **Only what the agent cannot derive.** Conventional directories that need no special guidance get no `CONTEXT.md`.
- **External docs via full URLs.** Documentation in private GitHub repositories is referenced by full URL (e.g., `https://github.com/org/repo/blob/main/path.md`). The agent uses `gh api` to fetch content when needed.

## Canonical Structure

```markdown
# Context: [Directory Name]

## Purpose
[Non-obvious domain context, ownership boundaries, or constraints specific to this directory]

## Key References
- [name] -- [why it matters here]

## Docs

| When this file is opened | Load these references |
|---------|------------|
| [glob or substring] | [pointers] |

## Tasks

| When doing this | Use these tools |
|------|-------|
| [project-specific task] | /instructions/[file].md, /rules/[file].md, /skills/[skill-name] |
| [framework-specific task] | /instructions/[file].md, /skills/[skill-name] |

## Never Do Here
- [Hard constraint]
```

Formatting rules:

- The H1 is always `# Context: [Directory Name]`.
- Section headers are H2 and use exactly these names: Purpose, Key References, Docs, Tasks, Never Do Here.
- Key References entries are bullets using a two-hyphen separator: `- [name] -- [why it matters here]`.
- Docs and Tasks are two-column tables with exactly the column headers shown above.
- Never Do Here entries are plain bullets.

## Path Rules

- All local paths are root-relative (from the project root), never relative to the directory holding the `CONTEXT.md`.
- External documentation uses full URLs.
- Inheritance is opt-in and explicit. A subdirectory that needs parent or sibling context lists that `CONTEXT.md` in its own Key References. Nothing is inherited implicitly.

## Section Details

### Purpose

- Non-obvious domain context, ownership boundaries, or constraints the agent could not infer from filenames alone.
- Not a README. README is for humans onboarding; Purpose is for agent orientation.
- **Skip** for conventional directories where the name says it all (e.g., `app/controllers`, `db/seeds`, `tests/unit`).
- **Include** when the directory has non-obvious ownership, boundaries, or domain context (e.g., a `payments/` directory that does not own the user billing record).

### Key References

- Files the agent should load before acting here. All paths are root-relative.
- Can include other `CONTEXT.md` files when this directory needs parent or sibling context.
- Can include full URLs to files in external repositories.
- Each entry explains **why it matters here**, not just what it is.
- Keep the list short. Include only references relevant to tasks in this directory.

### Docs

- A table mapping file globs or substrings to references the agent should load when opening or modifying a matching file.
- **Only generated if the directory is flat and contains files from multiple unrelated domains in one folder.**
- When a file matches a pattern, its references are loaded alongside directory-level Key References (cumulative).
- If no pattern matches, only directory-level Key References apply.
- References can be local (root-relative) or external (full URLs).

### Tasks

- The routing function. Maps atomic development actions to the tools that fulfill them.
- Two types: project-specific tasks (e.g., `add-feature-flag`, `endpoint-serialization`) and language/framework-specific tasks (e.g., `write-rails-migration`, `write-react-hook`).
- Each task maps to a bundle of instructions, rules, and skills. Bundle paths use root-relative paths.
- **The bundle is the complete specification.** If a rule matters for a task, it belongs in the bundle. If it is missing, the agent executes without that constraint. Fix incomplete bundles rather than supplementing at runtime.
- **Only generated if the directory has repeatable development actions requiring specific guidance.**

### Never Do Here

- Hard constraints that apply regardless of the active task. These are axioms, not rules files.
- If a task bundle and a Never Do Here constraint conflict, the constraint wins.
- Use only for: non-obvious, frequently violated, or catastrophic-if-missed constraints specific to this directory.
- Do not duplicate constraints already enforced by rules that every task bundle in the directory includes.
- Do not use as a rule backlog. If the list grows large, split constraints into rule files and reference them from task bundles.
- Generated files may propose candidates, but this section always requires human review. Directory-specific hard constraints live in the heads of the developers; they cannot be fully inferred from code.

## Anti-patterns

The generator avoids these; the validator checks for them.

1. **The everything CONTEXT.md.** A root-level context that declares every task bundle for every directory. This defeats routing. Task bundles belong in the CONTEXT.md closest to where work happens. Detection: a root or near-root file whose Tasks table routes work for many unrelated subdirectories.
2. **Speculative loading.** Loading rules or skills not declared in any task bundle because they "seem relevant". The bundle is the complete specification. Fix incomplete bundles; do not supplement at runtime. Detection: bundle entries with no plausible connection to the task, or prose telling the agent to "also consider" undeclared references.
3. **CONTEXT.md as README.** README is for humans onboarding; CONTEXT.md is for agent orientation. Different audiences, different purposes. Do not merge them. Detection: long narrative prose, setup instructions, badges, or history in place of actionable sections.
4. **Execution logic in CONTEXT.md.** CONTEXT.md tells agents what context to load, not how to execute tasks. Execution logic belongs in rules or skills. Detection: numbered how-to steps, code snippets to copy, or command sequences inside any section.
5. **Implicit context chaining.** Assuming a subdirectory inherits from a parent because the parent has a CONTEXT.md. Inheritance is opt-in. If a child needs parent context, it must explicitly reference it in Key References. Detection: content that only makes sense with the parent's context, with no explicit Key References entry pointing at the parent's CONTEXT.md.
6. **Never Do Here as a rule backlog.** Accumulating every constraint, including ones already enforced by task bundles. Use only for axioms: non-obvious, catastrophic-if-missed constraints that hold regardless of task. Detection: a long list, or entries that restate rules the bundles already load.

The validator additionally flags: relative paths where root-relative paths are required, and sections that are present but empty (except a deliberately empty Never Do Here carrying a `<!-- TODO: Review -->` marker awaiting human input).

## Confidence Ratings

The analyzer rates each section high, medium, or low. The generator marks low-confidence sections with `<!-- TODO: Review -->` comments.

- **High:** supported by multiple confirmed files or consistent patterns across the directory; references verified to exist.
- **Medium:** supported by a clear signal (a consistent naming convention, a single authoritative config) but not cross-confirmed.
- **Low:** inferred from a single file, from naming alone, from absence of evidence, or from convention in other projects rather than this one.

Fabricating a reference is never acceptable at any confidence level. A missing reference is a TODO, not an invented path.

## Examples

Representative examples of well-formed sections. Paths are illustrative.

### Purpose (non-obvious ownership boundary)

```markdown
## Purpose
Handles payment processing and refund orchestration. This directory does not
own the user billing record; that lives in app/models/billing and is modified
only through BillingAccount service calls. Charge state transitions are
event-sourced; direct state column writes corrupt the projection.
```

### Key References (admin routes)

```markdown
## Key References
- config/routes/admin.rb -- admin routes are constrained by AdminConstraint; new admin endpoints must be added here, not in the main routes file
- app/policies/admin_policy.rb -- every admin controller action authorizes through this policy; understand its role matrix before adding actions
- docs/architecture/admin-authn.md -- explains why admin sessions are separate from user sessions
```

### Docs (flat directory, mixed domains)

```markdown
## Docs

| When this file is opened | Load these references |
|---------|------------|
| *_serializer.rb | docs/api/serialization.md |
| *_form.rb | docs/architecture/form-objects.md |
| *_job.rb | https://github.com/org/docs-internal/blob/main/background-jobs.md |
```

### Tasks (project-specific and framework-specific)

```markdown
## Tasks

| When doing this | Use these tools |
|------|-------|
| add-feature-flag | /instructions/feature-flags.md, /rules/flag-naming.md, /skills/flipper-setup |
| endpoint-serialization | /instructions/serializers.md, /rules/api-versioning.md |
| write-rails-migration | /instructions/migrations.md, /rules/zero-downtime.md, /skills/strong-migrations |
| write-form-object | /instructions/form-objects.md, /rules/validation-placement.md |
```

### Never Do Here (axioms)

```markdown
## Never Do Here
- Never write to the charges table directly; all charge state changes go through the event store
- Never call external payment providers from a request thread; provider calls run in jobs only
```
