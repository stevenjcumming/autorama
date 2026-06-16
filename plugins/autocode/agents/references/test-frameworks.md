# Test Framework Reference

## Framework Detection

| File | Framework | Run Command |
|------|-----------|-------------|
| `package.json` with jest | Jest | `npx jest {files}` |
| `package.json` with vitest | Vitest | `npx vitest run {files}` |
| `package.json` with mocha | Mocha | `npx mocha {files}` |
| `Gemfile` with rspec | RSpec | `bundle exec rspec {files}` |
| `Gemfile` with minitest | Minitest | `bundle exec ruby -Itest {files}` |
| `pytest.ini` or `pyproject.toml` | Pytest | `pytest {files}` |
| `go.mod` | Go | `go test -run {TestFunc} ./path/to/pkg` |
| `Cargo.toml` | Rust | `cargo test {test_name}` |
| `Makefile` with test target | Make | `make test` |

If multiple are present, prefer the one specified in `PLAN.md` or `SPEC.md`.

## Test File Glob Patterns

```
**/*.test.ts
**/*.spec.ts
**/*_test.go
**/*_spec.rb
**/test_*.py
```

## Test File Path Conventions

- `__tests__/` directory: `src/__tests__/module.test.ts`
- Co-located tests: `src/module.test.ts`
- Separate `test/` directory: `test/module.test.ts`
- Spec directory: `spec/module_spec.rb`

Follow whatever convention the existing tests use. If no tests exist, use the framework's default convention.

## Syntax Check Commands

| Framework | Syntax Check Command |
|-----------|---------------------|
| TypeScript/Jest/Vitest | `npx tsc --noEmit -p .` (project-wide; per-file `npx tsc --noEmit {file}` ignores tsconfig.json and produces false failures) or `node -c {file}` for JS |
| Ruby/RSpec | `ruby -c {file}` |
| Python/Pytest | `python -m py_compile {file}` |
| Go | `go vet ./path/to/pkg` |
| Rust | `cargo check` |

## Test Command Patterns (for `<test-command>` output)

| Framework | Command Pattern |
|-----------|----------------|
| Jest | `npx jest {file1} {file2}` |
| Vitest | `npx vitest run {file1} {file2}` |
| Mocha | `npx mocha {file1} {file2}` |
| RSpec | `bundle exec rspec {file1} {file2}` |
| Minitest | `bundle exec ruby -Itest {file1}` (one file per invocation; chain with `&&` for multiple) |
| Pytest | `pytest {file1} {file2}` |
| Go | `go test -run {TestFunc} ./path/to/pkg` |
| Cargo | `cargo test {test_name}` |
| Make | `make test` (runs the whole suite; Make cannot target individual files unless the target accepts arguments) |

## Fallback

If none of the detection rows match, or the detected command does not work, inspect the project's CI config (`.github/workflows/*`, `.gitlab-ci.yml`, etc.) or Makefile for how tests are actually run. Use that command and document the choice in the output's Coverage Notes.
