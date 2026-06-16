# Code Review Checklist

A generic checklist for structured code review. Each item has a stable ID
(SEC-1, TEST-2, etc.) so findings can cite the item they violate. Evaluate
each item against the diff under review. Report only actionable violations;
skip items that do not apply or where the code already meets the standard.

## Severity Calibration Examples

Severity is assigned by comparison to these concrete examples, not by
adjective. When unsure, find the closest example below and match its level.

**CRITICAL** (production incident, security breach, or data loss): SQL built
by string interpolation from user input (SEC-2):

```python
cursor.execute(f"SELECT * FROM users WHERE name = '{request.args['name']}'")
# Injectable. Must be: cursor.execute("SELECT * FROM users WHERE name = %s", (name,))
```

**HIGH** (incorrect behavior or resource leak under real conditions): a file
handle leaked on the error path (ERR-4):

```javascript
const fh = await fs.open(path);
const data = await parse(fh);  // throws on malformed input: fh never closes
await fh.close();
// Must be try/finally (or `await using`) so close runs on the error path too.
```

**MEDIUM** (quality issue that invites future bugs): an external call with no
failure handling, swallowing the error context (ERR-1, ERR-3):

```ruby
def sync_profile(user)
  resp = HTTP.get("#{API}/profile/#{user.id}") rescue nil
  update(user, resp)   # resp is nil on any network failure; update misbehaves silently
end
```

**LOW** (style or hygiene, no behavior change): leftover debugging output
(QUAL-5):

```go
fmt.Println("DEBUG: got here", payload) // remove before merge
```

## Security

- SEC-1: No secrets, API keys, tokens, or credentials are hardcoded or committed
- SEC-2: User input is validated and sanitized before use in queries, commands, or output
- SEC-3: Every new or modified endpoint, handler, or entry point that touches protected data performs authentication and authorization checks
- SEC-4: Sensitive data is not logged, exposed in error messages, or leaked to clients
- SEC-5: Newly added or upgraded dependencies are flagged for an advisory check

## Testing

- TEST-1: New functionality has corresponding unit tests covering expected behavior
- TEST-2: Edge cases and boundary conditions are tested (empty input, nulls, limits)
- TEST-3: Error paths and failure scenarios have explicit test coverage
- TEST-4: Tests are deterministic and do not depend on external state or ordering
- TEST-5: Test assertions verify behavior, not implementation details

## Error Handling

- ERR-1: Errors are handled or propagated; no empty catch/rescue blocks silently swallow them
- ERR-2: Error messages are descriptive and include context for debugging
- ERR-3: External calls (network, file I/O, subprocesses) have failure handling
- ERR-4: Resource cleanup occurs in error paths (connections, file handles, locks)
- ERR-5: Unexpected exceptions do not crash the application or leak internal details

## Code Quality

- QUAL-1: Functions and variables have clear, descriptive names that convey intent
- QUAL-2: Logic duplicated in three or more places is extracted into a shared function or module
- QUAL-3: Public interfaces have docstrings or comments explaining purpose and usage
- QUAL-4: Functions stay focused; anything longer than roughly 40 lines or nested more than three levels deep is split into smaller functions
- QUAL-5: No dead code, commented-out blocks, or leftover debugging statements remain

## Performance

- PERF-1: Database access avoids N+1 patterns (no queries issued inside loops over records)
- PERF-2: Collections that can grow without bound are paginated or streamed rather than loaded entirely into memory
- PERF-3: Expensive operations whose result does not change per iteration are hoisted out of loops
- PERF-4: Expensive computations repeated with identical inputs in the same request or loop reuse a cached or memoized result
- PERF-5: File and network I/O operations use buffering and avoid unnecessary round trips
