# Configuration

The autopilot plugin is configured via `.claude/autopilot.yml` in the project root. All keys are optional -- the system uses sensible defaults when configuration is absent.

## Setup

Run `/autopilot:init` or copy the template manually:

```
cp plugins/autopilot/templates/autopilot.yml .claude/autopilot.yml
```

## Reference

### Agent Overrides

Override the default agent used for each role in the autopilot loop.

```yaml
agents:
  tester: autopilot:autopilot-tester
  coder: autopilot:autopilot-coder
  refactorer: autopilot:autopilot-refactorer
  reviewer: autopilot:autopilot-reviewer
```

All fields are optional. When omitted, the built-in agent is used. Values use the `namespace:agent-name` format. Use this to swap in project-specific agents that follow different conventions.

The `reviewer` agent is used by `/autopilot:code-review`. It receives the diff, diff stat, checklist, and output path. Override it to use a custom agent with domain-specific risk models, escalation routing, or project standards.

### Skills

Load skill files into agent context for domain-specific knowledge.

```yaml
coding_skills: []
testing_skills: []
refactoring_skills: []
```

Skills are loaded from `.claude/skills/{skill-name}/SKILL.md`. The coder agent dynamically selects appropriate skills per task based on file types and patterns.

Example:
```yaml
coding_skills:
  - service-object-skill
  - react-component-skill
testing_skills:
  - jest-skill
refactoring_skills:
  - dry-refactor-skill
```

### Auto-Commit

Auto-commits use [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) format with a body for long-term context. The format is `<type>(<spec_id>): <task_summary>` with task ID and file count in the body. The commit type (feat, fix, refactor, test, etc.) is chosen by the task-runner based on the nature of the changes. Auto-commit always runs when there are uncommitted changes after a task completes.

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
agents:
  tester: autopilot:autopilot-tester
  coder: autopilot:autopilot-coder
  refactorer: autopilot:autopilot-refactorer
  reviewer: autopilot:autopilot-reviewer

coding_skills:
  - service-object-skill
  - react-component-skill
testing_skills:
  - jest-skill
refactoring_skills:
  - dry-refactor-skill

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
