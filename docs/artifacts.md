# Artifacts

## Purpose

Artifacts are structured documentation files generated during the autopilot loop. They create an audit trail of decisions and reasoning that supports human oversight and continuous improvement.

## Artifact Locations

Artifacts follow a two-tier organization:

### Per-Spec Artifacts (Primary)

During autopilot execution, artifacts are generated within the spec directory:

```
.claude/specs/<SPEC_ID>/artifacts/
```

This keeps all work-in-progress artifacts co-located with their spec, making it easy to track what was generated for each feature. Per-spec artifacts are gitignored by default (`.claude/specs/*` is in `.gitignore`).

### Curated Artifacts (Promoted)

Users can promote valuable artifacts to a global location for long-term retention:

```
.claude/artifacts/
```

This location is for curated artifacts that users manually move there. Examples include:
- Decisions that set precedents for future work
- Architectural documentation worth preserving

## Generation Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     /autopilot:execute Command                          │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         Autopilot Orchestrator                          │
│                    (Test → Code → Refactor loop)                        │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
              ┌────────────────────┼────────────────────┐
              ▼                    ▼                    ▼
┌─────────────────────┐  ┌─────────────────────┐  ┌─────────────────────┐
│  autopilot-tester   │  │  autopilot-coder    │  │autopilot-refactorer │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
              │                    │                    │
              ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        TRIGGER CONDITIONS                               │
├─────────────────────────────────────────────────────────────────────────┤
│  TESTER (writes tests, TDD red phase):                                  │
│  • Ambiguous or unclear requirements → Signal (clarification)           │
│                                                                         │
│  CODER:                                                                 │
│  • File modified     → Justification (based on file category)           │
│  • Choice made       → Decision                                         │
│  • Inferred req      → Assumption                                       │
│  • Potential issue   → Risk                                             │
│  • Shortcut taken    → Debt                                             │
│  • Needs human eye   → Review Hint                                      │
│  • Approach changed  → Signal (correction)                              │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        ARTIFACT CREATION                                │
├─────────────────────────────────────────────────────────────────────────┤
│  1. Agent identifies trigger condition                                  │
│  2. Agent generates filename: {timestamp}_{type}_{description}.md       │
│  3. Agent writes to: .claude/specs/<SPEC_ID>/artifacts/{artifact_type}/ │
│  4. Uses template structure from .claude/templates/artifacts/           │
└─────────────────────────────────────────────────────────────────────────┘
```

## Artifact Types

### Justification

**Trigger**: File modification in a flagged category (test, migration, config, API, security, dependency)

**Purpose**: Documents why a change was made, alternatives considered, and risk assessment. Includes category-specific checklists to ensure important considerations aren't missed.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/justifications/`

### Decision

**Trigger**: Choice between multiple valid approaches

**Purpose**: Records options considered, trade-offs evaluated, and rationale for the chosen approach. Creates a record for future reference if the decision needs revisiting.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/decisions/`

### Assumption

**Trigger**: Inferring unstated requirements

**Purpose**: Documents what was assumed, the basis for the assumption, validation questions, and what would need to change if the assumption is wrong.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/assumptions/`

### Risk

**Trigger**: Potential negative impact identified

**Purpose**: Captures likelihood, impact, mitigation strategies, and rollback plans. Surfaces concerns that need human attention.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/risks/`

### Debt

**Trigger**: Shortcut or compromise taken

**Purpose**: Documents what the ideal implementation would be, why the shortcut was taken, and a plan for paying it back later.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/debt/`

### Review Hint

**Trigger**: Human judgment needed

**Purpose**: Flags specific files and line ranges that require human review, with focused questions for the reviewer.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/review_hints/`

### Signal

**Trigger**: Interaction patterns worth capturing (approach changes, repeated failures, validated assumptions)

**Purpose**: Raw material for the `/autopilot:reflect` stage. Signals are analyzed to propose rules for `.claude/rules/`.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/signals/`

## File Categories Requiring Justification

| Category | File Patterns | Key Questions |
|----------|---------------|---------------|
| `spec_modification` | `*_spec.rb`, `*.test.ts`, `*.test.js` | Changing assertions? Adding or removing tests? |
| `migration` | `db/migrate/*`, `migrations/*` | New migration or editing existing? |
| `dependency` | `package.json`, `Gemfile`, `*.lock` | Why needed? Security status? |
| `configuration` | `config/**/*`, `*.env*` | Production impact? Secrets involved? |
| `api_change` | `*_controller.rb`, `api/**` | Breaking change? Consumer coordination? |
| `security` | `*auth*`, `*permission*`, `*security*` | Access control implications? |

## Directory Structure

### Per-Spec Artifacts (Generated)

```
.claude/specs/<SPEC_ID>/
├── REQUIREMENT.md
├── SPEC.md
├── RESEARCH.md
├── PLAN.md
├── TODO.md
└── artifacts/             # Generated during autopilot
    ├── justifications/    # Why changes were made
    ├── decisions/         # Approach choices
    ├── assumptions/       # Inferred requirements
    ├── risks/             # Potential problems
    ├── debt/              # Shortcuts taken
    ├── review_hints/      # Human review needed
    └── signals/           # Patterns for /autopilot:reflect
```

### Curated Artifacts (User-Promoted)

```
.claude/
├── artifacts/             # Manually curated artifacts
│   ├── decisions/         # Precedent-setting decisions
│   └── ...                # Other promoted artifacts
└── templates/
    └── artifacts/         # Template files for each type
```

## Agent Responsibilities

| Agent | Artifacts Generated |
|-------|---------------------|
| `autopilot-tester` | Test files, Signal (clarification, repetition) |
| `autopilot-coder` | Justification, Decision, Assumption, Risk, Debt, Review Hint, Signal (correction, approval) |
| `autopilot-refactorer` | Signal (if patterns observed) |

## Using Artifacts

### During Development

- **Decisions** provide context if revisiting past choices
- **Assumptions** track what needs validation with stakeholders

### During Review

- **Review Hints** direct attention to areas needing human judgment
- **Risks** surface concerns requiring sign-off
- **Justifications** explain the reasoning behind changes

### For Improvement

- **Signals** feed into `/autopilot:reflect` to generate rules
- **Debt** tracks cleanup work for future sprints

## Promoting Artifacts

After completing a spec, review the generated artifacts and promote valuable ones:

```bash
# Example: Promote a precedent-setting decision
cp .claude/specs/api-v2/artifacts/decisions/2024-01-16-pagination-strategy.md \
   .claude/artifacts/decisions/
```

Promoted artifacts should be:
- Broadly applicable beyond the original spec
- Worth preserving for long-term reference
- Edited to remove spec-specific details if needed

Per-spec artifacts that are not promoted will be cleaned up when the spec directory is deleted (since `.claude/specs/*` is gitignored).
