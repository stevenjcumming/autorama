# Evaluation Pipeline

The autopilot plugin implements a multi-layered evaluation pipeline that gives engineers structured visibility into agent work at every stage.

## Overview

```
Autopilot Execution → Artifacts Generated → Review Checkpoint → Reflect Analysis → Rules → Submit
```

## 1. Real-Time Automatic Evaluation

While `/autopilot:execute` runs, the system continuously self-evaluates via `evaluate-signals.sh`:

- **Repeated violations** (same rule broken 3+ times) trigger an automatic pause
- **High severity signals** (security issues, breaking changes) trigger a pause
- **Human review flags** from agents pause execution for engineer input

Each sub-agent generates typed artifacts as it works:

| Agent | Produces |
|-------|----------|
| **Tester** | Signals |
| **Coder** | Justifications, decisions, assumptions, risks, debt, review hints |
| **Analyzer** | Signals |
| **Refactorer** | Signals (if refactoring breaks tests or reveals deeper debt) |

Artifacts accumulate at `.claude/specs/<SPEC_ID>/artifacts/`.

### Signal Types

| Signal Type | Confidence | Meaning |
|-------------|------------|---------|
| Correction | High | Agent changed approach mid-task |
| Rejection | High | Tests caught incorrect changes |
| Repetition | High | Same issue occurred 3+ times |
| Approval | Medium | Approach was validated |
| Clarification | Medium | Information gap discovered |
| Praise | Low | Positive feedback |

### Artifact Types

| Artifact | When Generated | Purpose |
|----------|----------------|---------|
| **Justification** | File modified in a flagged category | Category-specific checklist explaining why |
| **Decision** | Multiple valid approaches exist | Options, trade-offs, rationale |
| **Assumption** | Requirement inferred | What was assumed, basis, validation questions |
| **Risk** | Potential problem identified | Likelihood, impact, mitigation |
| **Debt** | Shortcut taken | Ideal vs shortcut, repayment plan |
| **Review Hint** | Human judgment needed | Files, line ranges, specific questions |
| **Signal** | Notable pattern detected | Type, confidence, trigger, improvement |

## 2. Review Stage (`/autopilot:review <id>`)

The primary human checkpoint. The `review.sh` script gathers and surfaces everything an engineer needs.

### What Gets Surfaced

1. **Changes summary** -- git diff analysis with file counts and flagged files (security, config, API)
2. **Artifact summary** -- table showing counts by type (e.g., 5 justifications, 2 risks, 3 review hints)
3. **High-risk items** -- anything tagged `risk:high` or `priority:critical` is surfaced in full
4. **Review hints** -- specific questions agents flagged for human judgment, with file paths and line ranges

### Review Checklist

The engineer is presented with a structured checklist:

#### Artifacts
- [ ] Justifications reviewed for flagged files
- [ ] Assumptions validated or corrected
- [ ] Decisions approved
- [ ] Technical debt is acceptable

#### Code
- [ ] Code changes match stated intent
- [ ] No security or quality concerns
- [ ] Tests are passing

#### High-Risk Items
- [ ] All high-risk items reviewed and accepted

#### Ready to Proceed
- [ ] Approved to continue to Reflect stage
- [ ] Needs changes (return to implementation)
- [ ] Fundamental issues (return to Spec)

### Outcomes

| Decision | Effect |
|----------|--------|
| **Approve** | Continue to Reflect stage |
| **Request Changes** | Return to autopilot with specific fixes |
| **Reject** | Return to Spec stage for fundamental issues |

## 3. Reflect Stage (`/autopilot:reflect <id>`)

After review approval, the reflect stage analyzes all signals and proposes rules for future sessions.

### Process

1. Count and classify all signals by type and confidence
2. Review artifacts (decisions, assumptions) for patterns
3. Generate rule proposals with confidence ratings
4. Engineer selects which rules to create
5. Rules are stored in `.claude/rules/` and apply automatically in future sessions

### Rule Proposal Confidence

| Confidence | Action |
|------------|--------|
| High | Recommend creation |
| Medium | Require engineer confirmation |
| Low | Report for monitoring only |

### Example Rule Proposal

```
| # | Rule | Paths | Confidence | Source |
|---|------|-------|------------|--------|
| 1 | api-error-format.md | src/api/**/*.ts | High | Correction: API errors |
| 2 | jwt-auth.md | **/auth/**/* | High | Correction: Auth approach |
```

## 4. Submit Stage (`/autopilot:commit`, `/autopilot:sync-pr`)

The final quality gate feeds into standard code review workflows.

- `/autopilot:commit` generates conventional commits with structured messages
- `/autopilot:sync-pr` creates or updates a GitHub PR with summary, changes, testing details, and acceptance criteria

## Key Properties

- **Artifact-driven audit trail**: Every agent decision is recorded with rationale, alternatives considered, and risk assessment
- **Proactive review hints**: Agents flag what needs human judgment with specific questions and file locations
- **Justification system**: Certain file categories (specs, migrations, dependencies, security, API changes) automatically require written justification
- **Context preservation**: handoff.md artifacts and hooks ensure continuity between tasks so the evaluation trail is coherent across the full session
- **Configurable thresholds**: Pause triggers, static analysis rules, and justification categories are customizable in `autopilot.yml`

## Related Documentation

- [Autopilot Workflow](workflows/04_autopilot.md)
- [Review Workflow](workflows/06_review.md)
- [Reflect Workflow](workflows/07_reflect.md)
- [Submit Workflow](workflows/08_submit.md)
- [Artifacts](artifacts.md)
- [Justifications](justifications.md)
