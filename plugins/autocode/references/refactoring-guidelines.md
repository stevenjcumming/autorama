# Refactoring Guidelines

Used by the refactorer agent to evaluate and apply safe cleanup refactoring.

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
