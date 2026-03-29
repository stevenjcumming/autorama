# Configuration

The autopilot plugin is configured via `.claude/autopilot.yml` in the project root. All keys are optional -- the system uses sensible defaults when configuration is absent.

## Setup

Run `/autopilot:init` or copy the template manually:

```
cp plugins/autopilot/templates/autopilot.yml .claude/autopilot.yml
```

## Reference

### Justification

Require written justifications when modifying certain file categories.

```yaml
justification:
  categories:
    spec_modification:
      title: "Test/Spec Modification"
      patterns:
        - "*_spec.rb"
        - "*_test.rb"
      questions:
        - "Is this adding new specs for extracted code?"
        - "Is this refactoring spec structure (no assertion changes)?"
        - "Is this updating test doubles for extracted collaborators?"
        - "Is this removing specs for deleted code?"
        - "Is this fixing specs that tested implementation details?"
        - "Are you changing assertions to make a failing test pass? **(STOP IF YES)**"
    migration:
      title: "Database Migration"
      patterns:
        - "*/db/migrate/*"
        - "*/migrations/*"
      questions:
        - "Is this a new migration?"
        - "Is this editing an unmigrated migration?"
        - "Is this editing a deployed migration? **(CREATE NEW MIGRATION INSTEAD)**"
    dependency:
      title: "Dependency Change"
      patterns:
        - "Gemfile"
        - "Gemfile.lock"
      questions:
        - "Why is this dependency needed?"
        - "What is the security/maintenance status?"
        - "Are there lighter alternatives?"
        - "Does this require approval (e.g., enterprise requirements)?"
    configuration:
      title: "Configuration Change"
      patterns:
        - "*/config/*.yml"
        - "*/config/*.yaml"
      questions:
        - "What behavior does this change?"
        - "Does this affect production?"
        - "Are secrets or credentials involved?"
        - "Is this environment-specific?"
    security:
      title: "Security-Sensitive File"
      patterns:
        - "*auth*"
        - "*security*"
        - "*permission*"
        - "*policy*"
        - "*credential*"
      questions:
        - "What security implications does this change have?"
        - "Have you verified this doesn't weaken access controls?"
        - "Does this need security review?"
  default:
    title: "File Modification"
    questions:
      - "What is the purpose of this change?"
      - "Does this change affect other parts of the codebase?"
      - "Is this change reversible?"
```

Each category has:
- `title` -- Display name for the justification prompt
- `patterns` -- Glob patterns matching file paths
- `questions` -- Prompting questions the coder must answer

Questions can include `**(STOP IF YES)**` or similar directives to block work when a condition is met.

The `default` section applies to files not matching any category. Remove it to only require justifications for explicitly listed categories.

Feature sections are active when present. To disable a feature, remove the section entirely.

Requires `yq` for full functionality. Falls back to built-in defaults without it.

## Full Example

```yaml
justification:
  categories:
    spec_modification:
      title: "Test/Spec Modification"
      patterns:
        - "*_spec.rb"
        - "*_test.rb"
      questions:
        - "Is this adding new specs for extracted code?"
        - "Are you changing assertions to make a failing test pass? **(STOP IF YES)**"
    security:
      title: "Security-Sensitive File"
      patterns: ["*auth*", "*credential*"]
      questions: ["What security implications does this change have?"]
  default:
    title: "File Modification"
    questions:
      - "What is the purpose of this change?"
```

## File Locations

| File | Purpose |
|------|---------|
| `.claude/autopilot.yml` | Active configuration (user-created) |
| `plugins/autopilot/templates/autopilot.yml` | Template with defaults and examples |

## Related Documentation

- [Hook System](hook-system.md)
- [Agent Architecture](agent-architecture.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Rules](rules.md)
