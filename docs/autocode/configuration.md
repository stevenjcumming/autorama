# Configuration

The autocode plugin is configured via `.claude/autocode.yml` in the project root. All keys are optional -- the system uses sensible defaults when configuration is absent.

## Setup

Run `/autocode:init` or copy the template manually:

```
cp plugins/autocode/templates/autocode.yml .claude/autocode.yml
```

## Reference

### Static Analysis

Run static analysis tools after tests pass and automatically fix blocking issues.

```yaml
static_analysis:
  enabled: true                   # Master switch (default: true)
  commands:
    - rubocop                     # Simple string form
    - npm run lint
    - command: eslint --format json src/
      format: json                # auto, json, text (default: auto)
  fail_on_warnings: false         # Block on warnings (default: false)
  max_fix_attempts: 2             # Max fix attempts per rule (default: 2)
  on_edit:
    enabled: true                 # Per-edit hook toggle (default: true)
    command: ""                   # Per-file command; edited file path is appended
```

**Per-edit quality gate (`on_edit`):** a PostToolUse hook runs a per-file check against each file Claude writes or edits and feeds failures back immediately. `command` is the per-file command (for example `npx eslint` or `rubocop`); when empty, the first simple string under `commands:` is used. Set `enabled: false` if your linter is too slow to run per edit. See [Hook System](hook-system.md).

Commands can be specified as a simple string or as an object with an explicit `format` field:

| Format | Behavior |
|--------|----------|
| `auto` | Auto-detect JSON or text output (default) |
| `json` | Parse as structured JSON |
| `text` | Parse as plain text |

**Blocking behavior:**
- Errors always block (must be fixed before task completes)
- Warnings block only if `fail_on_warnings: true`
- Info-level issues are logged but don't block

**Fix attempts:** Each blocking issue is tracked by `{tool}:{rule}` key. Issues exceeding `max_fix_attempts` generate a debt artifact instead of retrying.

**Missing commands:** If a configured command is not installed, autocode logs a warning and continues. Remove the `static_analysis` section entirely to disable.

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

### Artifact Judge

Optional, default off. After a task-runner completes a task, a read-only Agent SDK call judges whether the task's artifacts are substantive or template stubs and emits a structured warning for stubs. Costs tokens and requires `node` with `@anthropic-ai/claude-agent-sdk`.

```yaml
artifact_judge:
  enabled: false
```

Feature sections are active when present. To disable a feature, remove the section entirely.

Requires `yq` for full functionality. Falls back to built-in defaults without it.

## Keeping the Config in Context (CLAUDE.md import)

`/autocode:init` offers to append this to the project `CLAUDE.md`:

```markdown
## Autocode

@.claude/autocode.yml
```

The `@` import loads `.claude/autocode.yml` into context at session start, so every session and every spawned agent sees the test command and analysis config without a Read round-trip. Add it manually if init was skipped or ran non-interactively.

## Settings Bootstrap (settings.local.json)

`/autocode:init` writes the plugin's install path into `.claude/settings.local.json` so scripts and skills can resolve `$AUTOCODE_PLUGIN_ROOT`:

```json
{
  "env": {
    "AUTOCODE_PLUGIN_ROOT": "/Users/you/.claude/plugins/cache/stevenjcumming/autorama/plugins/autocode"
  }
}
```

If you configure this manually (or init fails), follow the same pattern with these rules:

- The path MUST be absolute. Hook and script commands resolved from relative paths can be intercepted by whatever directory the session happens to start in; absolute paths remove that ambiguity.
- Use `settings.local.json` (personal, gitignored), not the shared `settings.json`. The install path is machine-specific.
- Restart Claude Code after editing; `env` values are read at session start.

A portable `settings.example.json` for teams that want to document the shape without committing machine paths:

```json
{
  "env": {
    "AUTOCODE_PLUGIN_ROOT": "<ABSOLUTE_PATH_TO>/plugins/autocode"
  }
}
```

## Full Example

```yaml
static_analysis:
  enabled: true
  commands:
    - rubocop
    - command: eslint --format json src/
      format: json
  fail_on_warnings: false
  max_fix_attempts: 2

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
| `.claude/autocode.yml` | Active configuration (user-created) |
| `plugins/autocode/templates/autocode.yml` | Template with defaults and examples |

## Related Documentation

- [Hook System](hook-system.md)
- [Agent Architecture](agent-architecture.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Rules](rules.md)
