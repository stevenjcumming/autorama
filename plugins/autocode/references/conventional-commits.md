# Conventional Commits Reference

Based on the [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) specification.

## Structure

```
<type>(<scope>): <description>

<body>

[optional footer(s)]
```

## Rules

1. The **header** (`<type>(<scope>): <description>`) is a single line, max ~72 characters
2. A **body** is required — it provides contextual information about the code changes. It MUST begin one blank line after the description
3. The body explains **what changed and why**, not just what. Use bullet points for multiple changes
4. **Footers** are optional. Each footer uses `Token: value` or `Token #value` format

## Types

| Type | SemVer | When to use |
|------|--------|-------------|
| `feat` | MINOR | New feature or capability added |
| `fix` | PATCH | Bug fix |
| `docs` | — | Documentation only |
| `style` | — | Formatting, whitespace, missing semicolons (no code change) |
| `refactor` | — | Code change that neither fixes a bug nor adds a feature |
| `perf` | — | Performance improvement |
| `test` | — | Adding or correcting tests |
| `build` | — | Build system or external dependencies |
| `ci` | — | CI configuration |
| `chore` | — | Maintenance tasks |

## Scope

- A noun in parentheses describing the section of the codebase: `feat(auth):`, `fix(parser):`
- During autocode execution, use the **spec identifier** as scope: `feat(auth-refactor):`

## Breaking Changes

- Append `!` after the type/scope: `feat(api)!: remove deprecated endpoint`
- Or add a `BREAKING CHANGE:` footer
- Both correlate with MAJOR in SemVer

## Body Guidelines

The body should provide long-term context for anyone reading `git log`:

- **What** was done (high-level summary of changes)
- **Why** it was done (motivation, problem being solved, requirement)
- **How** if non-obvious (approach taken, trade-offs made)
- Reference task IDs when available: `Task: [T3]`

## Examples

### Feature with task context (autocode)

```
feat(auth-refactor): add JWT token refresh endpoint

Implement automatic token refresh to improve session handling:
- Add /api/auth/refresh endpoint with rotation
- Store refresh tokens in secure HTTP-only cookies
- Set access token expiry to 15 minutes

Task: [T3]
```

### Bug fix

```
fix(api): handle null user in profile lookup

The profile endpoint returned a 500 when called with a non-existent
user ID. Added null check and proper 404 response.

- Add null guard before accessing user properties
- Return 404 with structured error body
- Add regression test for missing user case
```

### Refactor

```
refactor(billing): extract invoice calculation into service object

Invoice total calculation was duplicated across three controllers.
Consolidated into InvoiceCalculator service to reduce drift risk.

- Extract shared logic to app/services/invoice_calculator.rb
- Update controllers to delegate to new service
- No behavior change; existing tests pass unchanged
```
