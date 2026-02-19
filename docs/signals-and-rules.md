# Signals and Rules

The autopilot plugin implements a feedback loop where agent interaction patterns are captured as signals, and persistent patterns are promoted to rules that apply automatically in all sessions.

## Overview

```
Agent interaction patterns during autopilot
        ↓
    Signals accumulated over session
        ↓
    /autopilot:reflect analyzes patterns
        ↓
    Rule proposals presented to engineer
        ↓
    Selected rules written to .claude/rules/
        ↓
    Auto-loaded in future sessions
```

## 1. Signals

Signals are lightweight markers that record notable patterns during execution. They feed into the reflect stage for rule proposal generation.

### Types

| Signal Type | Confidence | Meaning |
|-------------|------------|---------|
| Correction | High | Agent changed approach mid-task |
| Rejection | High | Tests caught incorrect changes, agent reverted |
| Repetition | High | Same issue occurred 3+ times |
| Approval | Medium | Approach validated by passing tests |
| Clarification | Medium | Information gap discovered during execution |
| Praise | Low | Positive feedback pattern |

### Generation

| Agent | Signals Produced |
|-------|-----------------|
| autopilot-tester | Approval, repetition, clarification |
| autopilot-coder | Correction, approval |
| autopilot-analyzer | Approval, correction |
| autopilot-refactorer | Signals based on refactoring patterns |

Signals are written to `{SPEC_DIR}/artifacts/signals/` with metadata including type, confidence, date, context, and source agent.

### Pause Triggers

The `evaluate-signals.sh` script checks signals between tasks and pauses the autopilot when:

- A rule is violated 3+ times (repeated_violation)
- A high-severity or security signal appears (high_severity)
- A signal is flagged for human review (human_review_needed)

Thresholds are configurable in `.claude/autopilot.yml` under `pause_signals`.

## 2. Rules

Rules are the persistent output of the feedback loop. They live in `.claude/rules/` and are automatically loaded by Claude Code in all future sessions.

### Creation via `/autopilot:reflect`

The reflect stage analyzes all signals and artifacts from a completed spec, then proposes rules:

1. **Gather** -- Counts and classifies signals by type and confidence
2. **Analyze** -- Reviews decisions and assumptions for recurring patterns
3. **Propose** -- Generates rule candidates with confidence ratings
4. **Select** -- Engineer chooses which rules to create
5. **Write** -- `rules-builder` agent creates rule files

### Proposal Confidence

| Confidence | Action |
|------------|--------|
| High | Recommend creation (based on high-confidence signals like corrections and rejections) |
| Medium | Require engineer confirmation |
| Low | Report for monitoring only, no rule created |

### Rule Format

**Global rule** (applies everywhere):

```markdown
# API Error Format

Always return JSON error responses with `error`, `message`, and `code` fields.
```

**Path-specific rule** (applies to matching files):

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Controller Conventions

- All endpoints must validate input before processing
- Use the shared error formatter for all error responses
```

### Storage

Rules are written to `.claude/rules/` and version-controlled. Claude Code loads them automatically based on the working context -- path-specific rules only apply when working on matching files.

## Lifecycle Summary

```
Phase 1: GENERATION (during Autopilot)
  All agents write signal artifacts during execution

Phase 2: ANALYSIS (/autopilot:reflect)
  Reads all signals + artifacts
  Identifies patterns across full session

Phase 3: SELECTION (human)
  Engineer reviews proposed rules
  Selects which to create

Phase 4: PERSISTENCE
  rules-builder writes .claude/rules/
  Auto-loaded in all future sessions
```

## Configuration

| Key | Default | Effect |
|-----|---------|--------|
| `pause_signals.triggers` | (see config doc) | Pause trigger conditions |
| `static_analysis.max_fix_attempts` | `2` | Fix attempts before logging and continuing |

## Related Documentation

- [Evaluation Pipeline](evaluation_pipeline.md)
- [Agent Handoff](agent-handoff.md)
- [Configuration](configuration.md)
- [Artifacts](artifacts.md)
- [Reflect Workflow](workflow-stages/07_reflect.md)
