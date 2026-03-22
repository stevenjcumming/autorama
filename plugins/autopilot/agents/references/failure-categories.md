# Test Failure Categories

Categorize test failures by inspecting output. Use the first matching category (priority order).

| Priority | Category | Pattern Indicators |
|----------|----------|--------------------|
| 1 | `setup` | `beforeEach`, `setUp`, `ENOENT`, `before all`, fixture errors |
| 2 | `syntax` | `SyntaxError`, `parse error`, `unexpected token` |
| 3 | `timeout` | `timeout`, `exceeded`, `ETIMEDOUT` |
| 4 | `runtime` | `TypeError`, `ReferenceError`, `NilClass`, `AttributeError` |
| 5 | `missing` | `Cannot find module`, `ModuleNotFoundError`, `unresolved import` |
| 6 | `assertion` | `Expected`, `AssertionError`, `to equal`, `toBe`, `assert` |
| 7 | `unknown` | Default if no pattern matches |

## Retryability

- `setup` → **NOT retryable** — environment issue, output failure and exit
- `syntax` → Retryable — coder can fix syntax errors
- `timeout` → Retryable — may indicate infinite loop or missing mock
- `runtime` → Retryable — implementation error
- `missing` → Retryable — missing file/module
- `assertion` → Retryable — logic error in implementation
- `unknown` → Retryable — attempt fix, may fail

## Refactoring Evaluation Criteria

| Issue | Pattern | Priority |
|-------|---------|----------|
| Duplication | Similar code blocks (3+ lines) repeated | High |
| Long functions | Functions > 50 lines | Medium |
| Deep nesting | > 3 levels of indentation | Medium |
| Magic values | Hardcoded strings/numbers without constants | Low |
| Dead code | Unused variables, unreachable code | High |
| Naming | Unclear or inconsistent naming | Low |
| Comments | Outdated or misleading comments | Medium |

## Safe Refactorings

| Refactoring | When to Apply |
|-------------|---------------|
| Extract variable | Complex expression used multiple times |
| Extract function | Repeated logic or overly long function |
| Rename | Unclear or misleading names |
| Remove dead code | Provably unused code |
| Simplify conditional | Nested if/else that can be flattened |
| Extract constant | Magic values used in multiple places |

## Refactoring Guardrails

**Never:**
- Change public interfaces
- Restructure across files
- Premature optimization
- Style-only changes (leave to linter)
- Add features or capabilities
