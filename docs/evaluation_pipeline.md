# Evaluation Pipeline

The autopilot plugin implements a multi-layered evaluation pipeline that gives engineers structured visibility into agent work at every stage.

## Overview

```
Autopilot Execution → Artifacts Generated → Review Checkpoint → Submit
```

## 1. Artifact Generation During Execution

Each sub-agent generates typed artifacts as it works:

| Agent | Produces |
|-------|----------|
| **Tester** | Test files |
| **Coder** | Implementation code (and analysis fixes when directed) |
| **Analyzer** | Analysis report with fix instructions |
| **Refactorer** | Refactoring changes |
| **Task Runner** | Justifications, decisions, assumptions, risks, debt, review hints (Step 6: artifact generation) |

Artifacts accumulate at `.claude/specs/<SPEC_ID>/artifacts/`.

### Artifact Types

| Artifact | When Generated | Purpose |
|----------|----------------|---------|
| **Justification** | File modified in a flagged category | Category-specific checklist explaining why |
| **Decision** | Multiple valid approaches exist | Options, trade-offs, rationale |
| **Assumption** | Requirement inferred | What was assumed, basis, validation questions |
| **Risk** | Potential problem identified | Likelihood, impact, mitigation |
| **Debt** | Shortcut taken | Ideal vs shortcut, repayment plan |
| **Review Hint** | Human judgment needed | Files, line ranges, specific questions |

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
- [ ] Approved to continue to Submit stage
- [ ] Needs changes (return to implementation)
- [ ] Fundamental issues (return to Spec)

### Outcomes

| Decision | Effect |
|----------|--------|
| **Approve** | Continue to Submit stage |
| **Request Changes** | Return to autopilot with specific fixes |
| **Reject** | Return to Spec stage for fundamental issues |

## 3. Submit Stage (`/autopilot:commit`, `/autopilot:sync-pr`)

The final quality gate feeds into standard code review workflows.

- `/autopilot:commit` generates conventional commits with structured messages
- `/autopilot:sync-pr` creates or updates a GitHub PR with summary, changes, testing details, and acceptance criteria

## Key Properties

- **Artifact-driven audit trail**: Every agent decision is recorded with rationale, alternatives considered, and risk assessment
- **Proactive review hints**: Agents flag what needs human judgment with specific questions and file locations
- **Justification system**: Certain file categories (specs, migrations, dependencies, security, API changes) automatically require written justification
- **Context preservation**: handoff.md artifacts and hooks ensure continuity between tasks so the evaluation trail is coherent across the full session
- **Configurable thresholds**: Static analysis rules and justification categories are customizable in `.claude/autopilot.yml`

## Related Documentation

- [Execute Workflow](workflow-stages/04_execute.md)
- [Review Workflow](workflow-stages/06_review.md)
- [Submit Workflow](workflow-stages/07_submit.md)
- [Artifacts](artifacts.md)
- [Justifications](justifications.md)
