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
  tester: autopilot-tester
  coder: autopilot-coder
  refactorer: autopilot-refactorer
  analyzer: autopilot-analyzer
```

All fields are optional. When omitted, the built-in agent is used. Use this to swap in project-specific agents that follow different conventions.

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

### Loop Behavior

Control how the autopilot loop executes.

```yaml
single_task_mode: true
```

| Key | Default | Effect |
|-----|---------|--------|
| `single_task_mode` | `true` | Exit after completing one task instead of continuing the queue |

Setting `single_task_mode: false` makes the loop-controller process all tasks in `TODO.md` sequentially without stopping.

### Auto-Commit

Automatically commit changes after each task completes.

```yaml
auto_commit:
  message_template: "feat({spec_id}): complete {task_id} - {task_summary}"
```

| Key | Default | Effect |
|-----|---------|--------|
| `message_template` | `feat({spec_id}): complete {task_id} - {task_summary}` | Commit message format. Variables: `{spec_id}`, `{task_id}`, `{task_summary}` |

Commits include a `Co-Authored-By: Claude` footer. Handled by the `on-agent-complete.sh` hook.

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
        - "Why does this test need to change?"
    migration:
      title: "Database Migration"
      patterns:
        - "*/db/migrate/*"
        - "*/migrations/*"
      questions:
        - "Is this migration reversible?"
    dependency:
      title: "Dependency Change"
      patterns:
        - "Gemfile"
        - "package.json"
      questions:
        - "Why is this dependency needed?"
    configuration:
      title: "Configuration Change"
      patterns:
        - "*/config/*.yml"
        - "*/config/*.yaml"
      questions:
        - "What does this configuration change affect?"
    security:
      title: "Security-Sensitive File"
      patterns:
        - "*auth*"
        - "*security*"
        - "*permission*"
        - "*credential*"
      questions:
        - "What security implications does this change have?"
  default:
    title: "File Modification"
    questions:
      - "Why is this file being modified?"
```

Each category has:
- `title` -- Display name for the justification prompt
- `patterns` -- Glob patterns matching file paths
- `questions` -- Prompting questions the coder must answer

Questions can include `**(STOP IF YES)**` to block work when a condition is met.

The `default` section applies to files not matching any category. Remove it to only require justifications for explicitly listed categories.

Feature sections are active when present. To disable a feature, remove the section entirely.

Requires `yq` for full functionality. Falls back to built-in defaults without it.

### Pause Signals

Configure when the autopilot loop should pause for human review.

```yaml
pause_signals:
  triggers:
    - signal: "repeated_violation"
      threshold: 3
    - signal: "high_severity"
      types:
        - "security"
        - "breaking_change"
    - signal: "human_review_needed"
```

| Trigger | Condition |
|---------|-----------|
| `repeated_violation` | Same rule violated N+ times (configurable threshold) |
| `high_severity` | Signal severity is "high" or type matches listed types |
| `human_review_needed` | Signal flagged `human_review: required` |

Evaluated by `evaluate-signals.sh` between tasks. Remove the `pause_signals` section to disable all pause triggers.

### Static Analysis

Run static analysis tools and auto-fix issues during the autopilot loop.

```yaml
static_analysis:
  commands:
    - rubocop
    - npm run lint
    - command: "eslint --format json src/"
      format: json
  fail_on_warnings: false
  max_fix_attempts: 2
```

| Key | Default | Effect |
|-----|---------|--------|
| `commands` | `[]` | List of commands to run. String for simple commands, object with `command` and `format` for structured output |
| `fail_on_warnings` | `false` | Treat warnings as blocking issues |
| `max_fix_attempts` | `2` | Maximum times the coder will attempt to fix analysis issues before continuing |

The `format` field accepts `auto`, `json`, or `text`. JSON format enables structured parsing of tool output.

Remove the `static_analysis` section to disable analysis entirely.

## Full Example

```yaml
agents:
  tester: autopilot-tester
  coder: autopilot-coder
  refactorer: autopilot-refactorer
  analyzer: autopilot-analyzer

coding_skills:
  - react-component-skill
testing_skills:
  - jest-skill

single_task_mode: false

auto_commit:
  message_template: "feat({spec_id}): complete {task_id} - {task_summary}"

justification:
  categories:
    security:
      title: "Security-Sensitive File"
      patterns: ["*auth*", "*credential*"]
      questions: ["What security implications does this change have?"]

pause_signals:
  triggers:
    - signal: "repeated_violation"
      threshold: 3
    - signal: "high_severity"
      types: ["security", "breaking_change"]

static_analysis:
  commands:
    - npm run lint
    - command: "eslint --format json src/"
      format: json
  max_fix_attempts: 2
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
- [Signals and Rules](signals-and-rules.md)
