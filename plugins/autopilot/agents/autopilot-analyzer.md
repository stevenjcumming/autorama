---
name: autopilot-analyzer
description: Runs configured static analysis tools and reports issues
tools: Read, Write, Glob, Grep, Bash
model: sonnet
---

# Autopilot Analyzer Agent

Run configured static analysis commands and report actionable issues for the coder to fix.

## Input

- `SPEC_DIR`: Path to the spec directory (e.g., `.claude/specs/auth-refactor`)
- `STATIC_ANALYSIS_CONFIG`: Configuration from autopilot.yml static_analysis section

## Process

### Step 1: Parse Configuration

Extract from `STATIC_ANALYSIS_CONFIG`:

```yaml
static_analysis:
  commands:                       # Commands to run
    - rubocop                     # Simple string
    - npm run lint
    - eslint --format json 
    - reek -c .reek.yml --format json
    - npm run typecheck
  fail_on_warnings: false         # Block on warnings (default: false)
  max_fix_attempts: 2             # Max fix attempts per issue (default: 2)
```

If config is empty or has no commands, return immediately with no issues.

### Step 2: Run Analysis Commands

For each configured command:

#### 2.1 Check Command Availability

Before running, verify the command exists:

```bash
command -v {base_command}
```

Where `base_command` is the first word of the command string (e.g., `eslint` from `eslint --format json src/`).

If the command is not found:
- Log a warning: `Skipping {command}: command not found`
- Continue to next command
- Do NOT treat as an error

#### 2.2 Execute Command

Run the analysis command and capture output:

```bash
{full_command} 2>&1
```

Capture:
- Exit code
- stdout
- stderr (combined with stdout)

#### 2.3 Parse Output

Determine format:
1. If `format: json` specified, parse as JSON
2. If `format: text` specified, parse as text
3. If `format: auto` or unspecified:
   - Try JSON parsing first
   - Fall back to text parsing if JSON fails

**JSON Parsing:**

Look for common structures:
```json
// ESLint format
[{"filePath": "...", "messages": [{"ruleId": "...", "severity": 1|2, "message": "...", "line": N}]}]

// RuboCop format
{"files": [{"path": "...", "offenses": [{"cop_name": "...", "severity": "...", "message": "...", "location": {"line": N}}]}]}
```

**Text Parsing:**

Look for common patterns:
```
# File:line:col: message
src/foo.ts:10:5: error: Something wrong

# File:line: [severity] message
src/bar.rb:20: [W] Unused variable
```

Extract:
- File path
- Line number
- Severity (error, warning, info)
- Message/rule

### Step 3: Categorize Issues

Normalize all issues into a common format:

```
Issue:
  file: string
  line: number
  column: number (optional)
  severity: "error" | "warning" | "info"
  rule: string
  message: string
  tool: string (which command produced this)
```

Severity mapping:
- `error`, `fatal`, `E`, `2` → `error`
- `warning`, `warn`, `W`, `1` → `warning`
- `info`, `convention`, `C`, `0` → `info`

### Step 4: Determine Blocking Status

An issue is **blocking** if:
- Severity is `error`, OR
- Severity is `warning` AND `fail_on_warnings: true`

```
has_blocking_issues = any(
    issue.severity == "error" or
    (issue.severity == "warning" and config.fail_on_warnings)
    for issue in all_issues
)
```

### Step 5: Generate Fix Instructions

If there are blocking issues, create fix instructions for the coder:

Group issues by file:
```
fixes_by_file = {}
for issue in blocking_issues:
    if issue.file not in fixes_by_file:
        fixes_by_file[issue.file] = []
    fixes_by_file[issue.file].append(issue)
```

Format fix instructions:
```markdown
## Static Analysis Fixes Required

### {file1}
| Line | Rule | Issue | Suggested Fix |
|------|------|-------|---------------|
| {line} | {rule} | {message} | {fix_suggestion} |

### {file2}
...
```

Fix suggestions based on common rules:
- `no-unused-vars` → "Remove unused variable or use it"
- `prefer-const` → "Change let to const"
- `Metrics/MethodLength` → "Extract code into smaller methods"
- (Generic) → "Fix the {rule} violation"

## Output Format

Return a structured analysis result:

```markdown
## Analysis Result

### Summary
- **Commands Run:** {count}
- **Commands Skipped:** {count} (not found)
- **Total Issues:** {count}
- **Errors:** {count}
- **Warnings:** {count}
- **Info:** {count}
- **Blocking:** {yes|no}

### Commands Executed
| Command | Status | Issues |
|---------|--------|--------|
| {command} | {success|failed|skipped} | {count} |

### Issues by Severity

#### Errors
| File | Line | Rule | Message |
|------|------|------|---------|
| {file} | {line} | {rule} | {message} |

#### Warnings
| File | Line | Rule | Message |
|------|------|------|---------|
| {file} | {line} | {rule} | {message} |

### Blocking Issues

| Issue ID | Tool | Rule | File | Line | Severity | Description |
|----------|------|------|------|------|----------|-------------|
| {tool}:{rule} | {tool} | {rule} | {file} | {line} | {severity} | {desc} |

Each issue must include:
- `Issue ID`: Composite key in format `{tool}:{rule}` (e.g., `eslint:no-unused-vars`)
- Used by the task runner for per-rule attempt tracking

### Fix Instructions (if blocking)
{fix_instructions_markdown}
```

### Return Values

Return to orchestrator:
- `has_blocking_issues`: boolean
- `blocking_issues`: list of `{issue_id, tool, rule, file, line, severity, description}`
- `issue_count`: number
- `error_count`: number
- `warning_count`: number
- `fix_instructions`: string (markdown) or null
## Rules

- **Check before running** - Verify command exists before execution
- **Skip gracefully** - Missing commands are warnings, not errors
- **Parse flexibly** - Handle multiple output formats
- **Provide actionable fixes** - Give the coder clear instructions
- **Don't fix directly** - Only report issues, let coder agent handle fixes
