# Failure Categories and the Structured Failure Contract

This file is the single definition of the autocode failure contract. The task-runner emits it (Step 9), the execute skill consumes it (failure policy), and `on-agent-complete.sh` parses it (completion signaling). Do not redefine the tag shape anywhere else; cite this file.

## Structured Failure Contract

Every task-runner completion ends with exactly one `<task-completed>` tag.

**Success:**

```
<task-completed task="{task_id}" status="completed" type="{commit_type}" />
```

**Failure:**

```
<task-completed task="{task_id}" status="failed" category="{setup|syntax|timeout|runtime|missing|assertion|unknown}" retryable="{true|false}" reason="{one-line reason}" />
```

`category` comes from the table below; `retryable` follows the Retryability section (do not invent other values). A failure tag MUST be preceded by a body containing:

1. **Partial results** — which steps completed (tests written, red verified, attempts made), test files written, and files changed so far. The coordinator preserves this progress instead of blindly restarting.
2. **Suggested alternatives** — what a human or the coordinator could try next (fix the environment, correct an acceptance criterion, split the task, re-run with a different filter).

**Consumer fallback rule:** a missing or unparseable `<task-completed>` tag (agent died, context exhausted, malformed output) is treated as `status="failed" category="unknown"`, and the consumer surfaces the raw tail of the runner output. Treating a missing tag as success is silent suppression and is never correct.

# Test Failure Categories

Categorize test failures by inspecting output. Use the first matching category (priority order).

| Priority | Category | Pattern Indicators |
|----------|----------|--------------------|
| 1 | `setup` | Hook-failure phrasings on the error line itself: `Error in beforeEach hook`, `failed in "before all" hook`, `setUp (...) failed`, `ERROR at setup of`, fixture setup errors, `ENOENT` while loading fixtures/config |
| 2 | `syntax` | `SyntaxError`, `parse error`, `unexpected token` |
| 3 | `timeout` | `timeout`, `exceeded`, `ETIMEDOUT` |
| 4 | `runtime` | `TypeError`, `ReferenceError`, `NilClass`, `AttributeError` |
| 5 | `missing` | `Cannot find module`, `ModuleNotFoundError`, `unresolved import` |
| 6 | `assertion` | `Expected`, `AssertionError`, `to equal`, `toBe`, `assert` |
| 7 | `unknown` | Default if no pattern matches |

**Matching `setup` precisely:** `setup` is the only non-retryable category, so misclassification aborts the task without retries. Match the hook-failure phrasings against the runner's error line (the line stating where the failure occurred), not as bare substrings anywhere in the output. A stack trace that merely passes through `beforeEach` or `setUp` frames is not a setup failure; classify by the actual error type instead.

## Retryability

- `setup` → **NOT retryable** — environment issue, output failure and exit
- `syntax` → Retryable — coder can fix syntax errors
- `timeout` → Retryable — may indicate infinite loop or missing mock
- `runtime` → Retryable — implementation error
- `missing` → Retryable — missing file/module
- `assertion` → Retryable — logic error in implementation
- `unknown` → Retryable — attempt fix, may fail

**Red phase note:** during the TDD red phase, `missing` (modules/files that do not exist yet) is the expected state, not a failure. Tests are written against code the coder has not created; only treat `missing` as a failure after the implementation step has run.

## Refactoring Guidance

The refactoring evaluation criteria, safe refactorings, and guardrails formerly in this file now live in `refactoring-guidelines.md` (same directory), consumed by the refactorer agent.
