# Code Review Checklist

A generic checklist for structured code review. Each item should be evaluated
against the diff under review. Report only actionable violations -- skip items
that do not apply or where the code already meets the standard.

## Security

- [ ] No secrets, API keys, tokens, or credentials are hardcoded or committed
- [ ] User input is validated and sanitized before use in queries, commands, or output
- [ ] Authentication and authorization checks are present where required
- [ ] Sensitive data is not logged, exposed in error messages, or leaked to clients
- [ ] Dependencies do not introduce known vulnerabilities (check advisories)

## Testing

- [ ] New functionality has corresponding unit tests covering expected behavior
- [ ] Edge cases and boundary conditions are tested (empty input, nulls, limits)
- [ ] Error paths and failure scenarios have explicit test coverage
- [ ] Tests are deterministic and do not depend on external state or ordering
- [ ] Test assertions verify behavior, not implementation details

## Error Handling

- [ ] Errors are caught at appropriate levels and not silently swallowed
- [ ] Error messages are descriptive and include context for debugging
- [ ] External calls (network, file I/O, subprocesses) have failure handling
- [ ] Resource cleanup occurs in error paths (connections, file handles, locks)
- [ ] Unexpected exceptions do not crash the application or leak internal details

## Code Quality

- [ ] Functions and variables have clear, descriptive names that convey intent
- [ ] Code avoids unnecessary duplication; shared logic is extracted appropriately
- [ ] Public interfaces have docstrings or comments explaining purpose and usage
- [ ] Complex logic is broken into small, focused functions with single responsibilities
- [ ] No dead code, commented-out blocks, or leftover debugging statements remain

## Performance

- [ ] Database queries avoid N+1 patterns and use appropriate indexing
- [ ] Large collections are not loaded entirely into memory when pagination or streaming is possible
- [ ] Expensive operations are not performed inside tight loops unnecessarily
- [ ] Caching is used where appropriate for repeated expensive computations
- [ ] File and network I/O operations use buffering and avoid unnecessary round trips
