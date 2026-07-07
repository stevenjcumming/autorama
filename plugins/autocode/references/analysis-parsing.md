# Static Analysis Parsing Reference

## Configuration Format

Each entry under `commands:` takes one of two forms: a plain string command, or an object with `command:` and an optional `format:` key (the object form is what the format-detection rules below key off). The block-level `enabled:` switch turns analysis on or off.

```yaml
static_analysis:
  enabled: true                   # Master switch (default: true)
  commands:                       # Commands to run
    - rubocop                     # Plain string form
    - npm run lint
    - command: eslint --format json src/   # Object form
      format: json                # auto, json, text (default: auto)
    - command: reek -c .reek.yml --format json
      format: json
    - npm run typecheck
  fail_on_warnings: false         # Block on warnings (default: false)
  max_fix_attempts: 2             # Max fix attempts per issue (default: 2)
```

Skip analysis entirely when `enabled: false` or `commands` is empty.

## Output Format Detection

1. If `format: json` specified → parse as JSON
2. If `format: text` specified → parse as text
3. If `format: auto` or unspecified → try JSON first, fall back to text

## JSON Output Structures

```json
// ESLint format
[{"filePath": "...", "messages": [{"ruleId": "...", "severity": 1|2, "message": "...", "line": N}]}]

// RuboCop format
{"files": [{"path": "...", "offenses": [{"cop_name": "...", "severity": "...", "message": "...", "location": {"line": N}}]}]}
```

## Text Output Patterns

```
# File:line:col: message
src/foo.ts:10:5: error: Something wrong

# File:line: [severity] message
src/bar.rb:20: [W] Unused variable
```

## Severity Mapping

| Raw Value | Normalized |
|-----------|-----------|
| `error`, `fatal`, `E`, `2` | `error` |
| `warning`, `warn`, `W`, `1` | `warning` |
| `info`, `convention`, `C`, `0` | `info` |

Note: ESLint severity `0` means "off"; rules set to 0 produce no messages, so `0` never appears in ESLint output. The `0` mapping exists for other tools that emit it.

## Blocking Status

An issue is **blocking** if:
- Severity is `error`, OR
- Severity is `warning` AND `fail_on_warnings: true`

## Common Fix Suggestions

| Rule | Suggested Fix |
|------|---------------|
| `no-unused-vars` | Remove unused variable or use it |
| `prefer-const` | Change let to const |
| `Metrics/MethodLength` | Extract code into smaller methods |
| (Generic) | Fix the {rule} violation |

## Issue ID Format

Composite key: `{tool}:{rule}` (e.g., `eslint:no-unused-vars`). Used by the task-runner for per-rule attempt tracking.
