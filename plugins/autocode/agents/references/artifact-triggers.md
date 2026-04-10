# Artifact Triggers & Generation Reference

## Trigger Conditions

| Artifact | Trigger |
|----------|---------|
| Justification | Changed file matches `justification.categories` glob in config |
| Decision | Choice made between multiple valid approaches |
| Risk | Changes touch security, auth, payment, or migration paths |
| Debt | Shortcut taken or retry_count > 0 |
| Review Hint | Test files modified, >3 files changed, or subtle implications |
| Assumption | Task required inferring unstated requirements |

## Path Pattern

`{SPEC_DIR}/artifacts/{type}/{task_id}_{name}_{timestamp}.md`

## File Categories

Determine category based on file path:

| Category | Path Pattern | Notes |
|----------|-------------|-------|
| `spec_modification` | `*_spec.rb`, `*.test.ts`, etc. | **REQUIRES JUSTIFICATION** |
| `migration` | `db/migrate/*`, `migrations/*` | **CREATE NEW, don't edit deployed** |
| `dependency` | `package.json`, `Gemfile`, etc. | Why needed? Lighter alternatives? |
| `configuration` | `config/**/*.yml`, `*.env*` | Production impact? Secrets? |
| `api_change` | `*_controller.rb`, `api/**` | Breaking change? Consumers? |
| `security` | Files with auth/security/permission in path | Weakens access controls? |
| `general` | All other files | Purpose? Affects other code? |

## Justification Category Questions

| Category | Key Questions |
|----------|---------------|
| `spec_modification` | Adding new specs? Changing assertions to pass? |
| `migration` | New migration? Editing deployed migration? |
| `dependency` | Why needed? Security status? Lighter alternatives? |
| `configuration` | Production impact? Secrets involved? |
| `api_change` | Breaking change? Consumers to coordinate? |
| `security` | Weakens access controls? Needs security review? |
| `general` | Purpose? Affects other code? |

## Inline Artifacts (generated manually by coder)

| Condition | Artifact |
|-----------|----------|
| Chose between approaches | Decision |
| Inferred unstated requirement | Assumption |
| Identified risk not caught by hook | Risk (manual) |
| Shortcut taken | Debt |

## Artifact Templates

Templates are located at `$AUTOPILOT_PLUGIN_ROOT/templates/artifacts/`:
- `justification.md`, `decision.md`, `assumption.md`, `risk.md`, `debt.md`, `review_hint.md`, `dependency.md`

The PostToolUse hook creates template artifact files on disk when Edit/Write occurs. The task-runner fills these with real content after agent work completes.
