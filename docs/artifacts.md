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
│           tester    │  │       coder         │  │  refactorer         │
└─────────────────────┘  └─────────────────────┘  └─────────────────────┘
              │                    │                    │
              ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        TRIGGER CONDITIONS                               │
├─────────────────────────────────────────────────────────────────────────┤
│  TASK-RUNNER / CODER:                                                   │
│  • File modified     → Justification (based on file category)           │
│  • Choice made       → Decision                                         │
│  • Inferred req      → Assumption                                       │
│  • Potential issue   → Risk                                             │
│  • Shortcut taken    → Debt                                             │
│  • Needs human eye   → Review Hint                                      │
│  • External/internal dep → Dependency                                   │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        ARTIFACT CREATION                                │
├─────────────────────────────────────────────────────────────────────────┤
│  1. Agent identifies trigger condition                                  │
│  2. Agent generates filename: {task_id}_{name}_{timestamp}.md           │
│  3. Agent writes to: .claude/specs/<SPEC_ID>/artifacts/{artifact_type}/ │
│  4. Uses template structure from plugins/autopilot/templates/artifacts/ │
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

### Dependency

**Trigger**: Internal or external dependency identified

**Purpose**: Documents dependency relationships, coupling level, impact of changes, and migration paths if the dependency needs to be replaced.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/dependencies/`

### Review Hint

**Trigger**: Human judgment needed

**Purpose**: Flags specific files and line ranges that require human review, with focused questions for the reviewer.

**Location**: `.claude/specs/<SPEC_ID>/artifacts/review_hints/`

## File Categories Requiring Justification

These categories are the built-in defaults from `agents/references/artifact-triggers.md`. They can be customized in `.claude/autopilot.yml` under `justification.categories`.

| Category | File Patterns | Key Questions |
|----------|---------------|---------------|
| `spec_modification` | `*_spec.rb`, `*.test.ts`, etc. | Adding new specs? Changing assertions to pass? |
| `migration` | `db/migrate/*`, `migrations/*` | New migration? Editing deployed migration? |
| `dependency` | `package.json`, `Gemfile`, etc. | Why needed? Lighter alternatives? |
| `configuration` | `config/**/*.yml`, `*.env*` | Production impact? Secrets? |
| `api_change` | `*_controller.rb`, `api/**` | Breaking change? Consumers? |
| `security` | Files with auth/security/permission in path | Weakens access controls? |
| `general` | All other files | Purpose? Affects other code? |

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
    ├── dependencies/      # Dependency analysis
    ├── risks/             # Potential problems
    ├── debt/              # Shortcuts taken
    ├── review_hints/      # Human review needed
    ├── handoff/           # Context handoff between tasks
    └── state/             # Task runner state tracking
```

### Curated Artifacts (User-Promoted)

```
.claude/
├── artifacts/             # Manually curated artifacts
│   ├── decisions/         # Precedent-setting decisions
│   └── ...                # Other promoted artifacts
```

### Artifact Templates

Templates used for artifact generation are located within the plugin:

```
plugins/autopilot/templates/artifacts/   # Template files for each type
```

## Agent Responsibilities

| Agent | Artifacts Generated |
|-------|---------------------|
| `task-runner` | All artifact types (fills in hook-created templates after sub-agents complete) |
| `coder` | Justification, Decision, Assumption, Risk, Debt, Dependency |
| `refactorer` | Debt (for significant deferred refactoring opportunities) |

## Using Artifacts

### During Development

- **Decisions** provide context if revisiting past choices
- **Assumptions** track what needs validation with stakeholders

### During Review

- **Review Hints** direct attention to areas needing human judgment
- **Risks** surface concerns requiring sign-off
- **Justifications** explain the reasoning behind changes

### For Improvement

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
