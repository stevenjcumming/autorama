# Workflow: Reflect

## Purpose

Analyze session signals and artifacts to propose rules for `.claude/rules/`. The Reflect stage enables continuous improvement by capturing patterns from implementation and codifying them as modular rules.

## Command

```
/autopilot:reflect [identifier]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `identifier` | No | Spec identifier for context (e.g., `auth-refactor`) |

## Examples

```bash
# Reflect on the current session
/autopilot:reflect

# Reflect with spec context
/autopilot:reflect auth-refactor
```

## What Are Rules?

Rules are modular instruction files in `.claude/rules/` that Claude automatically loads. They provide project-specific guidance without cluttering `CLAUDE.md`.

### Rule Structure

**Global rule** (applies to all files):
```markdown
# API Error Format

Always return JSON error objects, never plain strings:

- Error format: `{"error": {"code": "ERROR_CODE", "message": "..."}}`
- Use SCREAMING_SNAKE_CASE for error codes
```

**Path-specific rule** (applies only to matching files):
```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Controller Conventions

- All endpoints must include input validation
- Use the standard error response format
- Include OpenAPI documentation comments
```

### Rule Directory Structure

```
.claude/rules/
├── api-errors.md           # Global rule
├── testing.md              # Global rule
├── frontend/
│   ├── react.md            # Path-specific for React files
│   └── styles.md           # Path-specific for CSS/SCSS
└── backend/
    └── database.md         # Path-specific for DB code
```

## Signals vs Artifacts

### Signals: Real-Time Observations

**Signals** are captured **during** autopilot execution. Each signal records a notable event:

| Signal Type | Trigger | Confidence |
|-------------|---------|------------|
| Correction | Agent changed approach mid-task | High |
| Rejection | Refactoring broke tests, was reverted | High |
| Repetition | Same test failed multiple times | High |
| Approval | Tests pass, assumption validated | Medium |
| Clarification | Missing information discovered | Medium |
| Praise | Positive feedback received | Low |

**Location**: `.claude/specs/<identifier>/artifacts/signals/`

### Artifacts: Structured Records

**Artifacts** are created throughout implementation to document decisions and assumptions.

**Location**: `.claude/specs/<identifier>/artifacts/{type}/`

## Prerequisites

- Autopilot should have been run (to generate signals and artifacts)
- Even without signals, existing artifacts provide useful input

## What It Does

```
/autopilot:reflect
├── Run reflect.sh (count signals, artifacts, existing rules)
├── Analyze signals
│   ├── Read each signal file
│   ├── Extract type, confidence, context
│   └── Identify potential rules
├── Analyze artifacts
│   ├── Review decisions, assumptions
│   └── Find recurring patterns
├── Generate rule proposals
│   ├── High confidence → Propose as rules
│   ├── Medium confidence → Propose with caveats
│   └── Low confidence → Report for monitoring only
├── Present proposals table to user
├── User selects which rules to create
├── Spawn rules-builder agent
│   └── Creates selected rules in .claude/rules/
└── Summary of created rules
```

## Confidence Levels

### High Confidence (Corrections, Rejections, Repetitions)

These indicate clear patterns that should become rules:

| Source | Example |
|--------|---------|
| Direct correction | Agent had to change approach after feedback |
| Rejected refactoring | Tests caught behavior change |
| Repeated failure | Same pattern caused issues multiple times |

**Action**: Propose as rule, recommend creation.

### Medium Confidence (Approvals, Clarifications)

These have supporting evidence but benefit from review:

| Source | Example |
|--------|---------|
| Validated assumption | Assumption proved correct |
| Successful pattern | Approach worked well |
| Clarification | Gap in knowledge was filled |

**Action**: Propose as rule, require user confirmation.

### Low Confidence (Praise, Single Instances)

Not enough data to create a rule:

| Source | Example |
|--------|---------|
| Single instance | One-time observation |
| Positive feedback | Praise without specific context |

**Action**: Report for monitoring, don't propose as rule.

## Example Session

```
$ /autopilot:reflect

==========================================
         REFLECT STAGE
==========================================

## Signals Available

Found 3 signal(s) in .claude/specs/<identifier>/artifacts/signals

| Signal Type | Count |
|-------------|-------|
| correction | 2 |
| approval | 1 |

## Artifacts Available

| Artifact Type | Count |
|---------------|-------|
| decisions | 1 |

## Existing Rules

No existing rules in .claude/rules

## Summary

- Signals to analyze: 3
- Artifacts to review: 3
- Existing rules: 0

==========================================

## Proposed Rules

Based on 3 signals and 3 artifacts analyzed:

| # | Rule | Paths | Confidence | Source |
|---|------|-------|------------|--------|
| 1 | api-error-format.md | src/api/**/*.ts | High | Correction: API errors |
| 2 | jwt-auth.md | **/auth/**/* | High | Correction: Auth approach |
| 3 | test-naming.md | (global) | Medium | Approval: Test patterns |

### Rule Details

#### 1. api-error-format.md

**Paths**: `src/api/**/*.ts`
**Confidence**: High
**Source**: Correction - returned plain string error, changed to JSON

**Proposed content**:
```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Error Format

Always return JSON error objects, never plain strings:

- Format: `{"error": {"code": "ERROR_CODE", "message": "Human readable"}}`
- Use SCREAMING_SNAKE_CASE for error codes
- Include appropriate HTTP status codes
```

---

#### 2. jwt-auth.md
...

==========================================

Which rules would you like to create?
> All rules

Creating rules...

✓ Created .claude/rules/api-error-format.md
✓ Created .claude/rules/jwt-auth.md
✓ Created .claude/rules/test-naming.md

## Reflect Complete

### Rules Created
- .claude/rules/api-error-format.md
- .claude/rules/jwt-auth.md
- .claude/rules/test-naming.md

### Next Steps
- Review created rules in `.claude/rules/`
- Adjust rule content or paths as needed
- Rules will automatically apply in future sessions
```

## Directory Structure

```
.claude/
├── commands/
│   └── reflect.md              # Command definition
├── scripts/
│   └── reflect.sh              # Data gathering script
├── agents/
│   └── rules-builder.md        # Creates rule files
├── artifacts/                  # Curated/promoted artifacts (user-managed)
│   └── ...
├── specs/
│   └── <identifier>/
│       └── artifacts/          # Input for reflect (per-spec, gitignored)
│           ├── signals/        # Session signals
│           ├── decisions/      # Decisions made
│           └── assumptions/    # Assumptions made
└── rules/                      # Output: created rules
    ├── api-errors.md
    └── testing.md
```

## Output

The command provides:
- Summary of signals and artifacts analyzed
- Table of proposed rules with confidence levels
- Detailed view of each proposed rule
- Interactive selection of which rules to create
- Summary of created rules

## Best Practices

1. **Run after significant work**: Reflect after completing a feature or fixing complex bugs
2. **Review proposed rules**: Even high-confidence proposals benefit from human review
3. **Adjust paths carefully**: Too broad catches unrelated files, too narrow misses cases
4. **Keep rules focused**: One concept per rule file
5. **Use subdirectories**: Group related rules (e.g., `frontend/`, `backend/`)

## Next Steps

After reflecting:

1. Review created rules in `.claude/rules/`
2. Adjust rule content or path patterns as needed
3. Test that rules apply correctly in new sessions
4. Proceed to Submit stage when ready
