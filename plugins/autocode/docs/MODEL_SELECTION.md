# Model Selection

This document is the canonical reference for how autocode chooses a model tier for every agent and skill it runs. The decision tables below are the single source of truth: they are restated inline in the skills that apply them (skills are prompts and must carry their own instructions), but any change starts here and propagates outward.

## The Two Mechanisms

Autocode splits model selection into two mechanisms:

1. **Fixed roles**: the `model` field in the agent's or skill's frontmatter is the whole story. No caller ever passes a `model` parameter to these agents or skills. Their tier follows the role, because the difficulty of their work does not vary much per work item.
2. **Dynamic roles** (plan-builder, coder, reviewer): frontmatter holds the *safe* tier (opus). The orchestrating skill computes the actual tier from a decision table at spawn time and passes it on the Task call. If any call site omits the parameter, the agent runs at its safe default.

This split exists because of a structural property worth preserving: **omitted parameters fail up, not down**. A forgotten `model` parameter, a new call site, or a partial rollout can only ever run a dynamic agent at opus, never silently at a weaker tier. Silent-failure roles (planning, review, testing) can only be downgraded on positive evidence of triviality, never by prediction or by a global knob's side effect.

Platform constraints that make the split work:

- Skill frontmatter `model` cannot be overridden by any caller: the Skill tool accepts only `skill` and `args`. Skill pins are fixed by construction, so all dynamic roles must be agents, and they are.
- Agent model precedence is: the `CLAUDE_CODE_SUBAGENT_MODEL` env var, then the Task call's `model` parameter, then frontmatter, then the session model. The per-invocation parameter persists across resumes of that agent.

> **Footgun: `CLAUDE_CODE_SUBAGENT_MODEL`.** This environment variable silently outranks every mechanism in this design, including the decision tables and the safe defaults. Setting it collapses all agent tiers to one model: the tester, the plan-builder, the coder, everything. Do not set it in a project that uses autocode unless you intend exactly that.

## Decision Tables (canonical)

First match wins in every table.

### Planning (P table)

Applied by the `create-plan` skill before spawning the plan-builder.

| # | Condition | Model |
|---|---|---|
| P1 | Spec is docs/chore/config-only, single module, no open questions | sonnet |
| P2 | Spec touches auth, schema, concurrency, or migrations, OR has unresolved open questions, OR spans 3+ modules | ceiling |
| P3 | Everything else | opus |

P1 requires positive evidence on all three conditions. Ambiguity resolves to P3 (opus), never down to sonnet.

### Coding (C table)

Applied by the `task-runner` per sub-agent spawn.

| # | Condition | Model |
|---|---|---|
| C1 | Generation, task rated `easy` | sonnet |
| C2 | Generation, task rated `standard` (or rating missing) | opus |
| C3 | Generation, task rated `hard` | ceiling |
| C4 | Repair against a named error, structure intact | sonnet |
| C5 | Two failed repairs, or repair needs structural change (new file, signature change, crossing the design contract) | return to generation tier |

C5 is monotonic within a task: once a repair escalates back to the generation tier, it does not drop back down for that task, and the respawn carries the full failure history.

### Code review (R table)

Applied by the `code-review` skill before spawning the reviewer(s).

| # | Condition | Model |
|---|---|---|
| R1 | Any task escalated via C5 or failed during execution | opus |
| R2 | Diff touches security-sensitive paths (auth, input handling, SQL, crypto, secrets) | opus |
| R3 | Diff over ~300 lines or spanning 3+ modules | opus |
| R4 | Small diff, no sensitive paths, clean execution record | sonnet |

An unavailable execution record is treated as not-clean, so R4 only fires on positive evidence.

## Modifiers (applied after a rule fires)

| # | Modifier | Effect |
|---|---|---|
| M1 | Task rating in TODO.md (written by plan-builder, human-editable at the create-tasks checkpoint) | Selects among C1/C2/C3 |
| M2 | `models.ceiling` in `.claude/autocode.yml` (default `opus`; `fable` allowed) | Caps dynamic resolutions only; fixed frontmatter pins ignore it |
| M3 | Repair return trigger (C5) | Monotonic within a task; carries full failure history back up |
| M4 | Explicit user override (`/autocode:execute <id> [model]`, `/autocode:ticket <url> [model-override]`, `code_review.model` in autocode.yml) | Wins over the tables; still capped by M2 |

`fable` is never a default and is never chosen by a table on its own. It is reachable only when `models.ceiling: fable` is set and a ceiling rule (P2, C3) resolves to it, or when an explicit override (M4) names it.

## Fixed Frontmatter Assignments

| Component | `model` | Rationale |
|---|---|---|
| tester | opus | Defines the oracle everything downstream trusts; weak tests fail silently |
| task-runner | sonnet | Judgment moved into the deterministic C-table rules it applies |
| refactorer | sonnet | Behavior-preserving work on green, opus-designed code |
| analyzer, plan-researcher, plan-analyzer | sonnet | Output feeds a more capable consumer |
| session-summarizer | sonnet | Bounded compression, but a lossy handoff silently degrades every later task; haiku is false economy |
| execute, code-review, create-plan (skills) | sonnet | Orchestration: parse, decide by table, spawn |
| commit, sync-pr, new-spec, create-tasks, review, init (skills) | sonnet | Light generation or template filling with a human reading the output |
| help, spec-archive (skills) | haiku | Display and script wrappers |
| plan-builder, coder, reviewer | opus | Safe default for dynamic roles; orchestrators pass the computed tier |

## Configuration

One knob, in `.claude/autocode.yml`:

```yaml
models:
  ceiling: opus        # opus (default) or fable
```

- `ceiling` caps dynamic resolutions (the P, C, and R tables plus M4 overrides). It does not affect fixed frontmatter pins, so lowering it for cost control cannot starve the tester or any other fixed role.
- When the key or file is absent, the ceiling is `opus`. A garbage value is treated as `opus` with a warning.
- `code_review.model` (existing key) remains supported as an M4 override for the reviewer specifically: when set, it replaces the R-table result.

## Decision Logging

Every dynamic decision (P, C, and R applications, including C5 returns and M4 overrides) is logged through the existing usage logger:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/log-usage.sh model-selection <role> ok '{"rule":"C1","tier":"sonnet","spec":"<id>","task":"T3"}'
```

Events land in `$CLAUDE_PLUGIN_DATA/usage.jsonl` with `type: model-selection`. `read-history.sh --model-stats` summarizes them (count per rule, C5 return rate) so the tables can be tuned on real data. The code-review skill also reads these events to apply R1 (a C5 escalation during execution forces an opus review).

## Best Practices for Users

**On the default path, do nothing.** The common case (a small spec, easy-to-standard tasks, a clean run) completes almost entirely on sonnet, and capability is bought only on evidence. You should not need to think about models at all.

**Review the ratings at the create-tasks checkpoint.** The plan-builder rates each task `easy`, `standard`, or `hard` in TODO.md (for example `- [ ] [T3] (easy) Update README install steps`). This is the one human checkpoint (M1) before execution: if you know a task is trickier than it looks, edit its rating to `standard` or `hard` before running `/autocode:execute`. A missing or unrecognized rating safely means `standard`.

**Use explicit overrides for known-hard work, not as a habit.** `/autocode:execute <id> [model]` and `/autocode:ticket <url> [model-override]` accept a model that replaces the table result for generation work (repairs still run the cheap C4/C5 path, so an opus override does not make every retry expensive). Reserve `fable` for work you already know is unusually hard; it is the most expensive tier and the tables never pick it on their own.

**Raise the ceiling only when you need it.** `models.ceiling: fable` lets the hardest planning specs (P2) and `hard`-rated tasks (C3) reach fable automatically. Leave it at `opus` otherwise; the ceiling exists so that one line of config bounds the worst-case spend of an entire run.

**Do not rate everything `hard`.** Rating inflation is visible in `read-history.sh --model-stats` (rule counts), and `hard` tasks cost ceiling-tier tokens. Conversely, `easy` is only safe when the design contract in PLAN.md fully specifies the change; when in doubt the plan-builder writes `standard`, and so should you.

**Watch the one-line announcements.** Every dynamic decision is announced in one line as it happens (for example "Planning on sonnet via P1: docs-only spec, single module") and logged with the rule that fired. If a run picked a tier you disagree with, the rule ID tells you exactly which condition to argue with.

**Do not set `CLAUDE_CODE_SUBAGENT_MODEL`.** See the footgun note above; it flattens every tier in the plugin.
