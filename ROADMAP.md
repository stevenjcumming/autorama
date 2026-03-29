# Roadmap

## Planned

### `/autopilot:new-spec` — GitHub Issue Auto-Population

When a GitHub issue URL is provided alongside the spec identifier, automatically fetch the issue via `gh issue view` and pre-populate `REQUIREMENT.md` with the title, body, and labels. Draft `SPEC.md` from that content rather than leaving it blank.

**Example usage:**
```
/autopilot:new-spec https://github.com/owner/repo/issues/123
```

## Unplanned

### `/autopilot:oneshot` — Full Pipeline from GitHub Issue

A single command that ingests a GitHub issue URL and runs the entire autopilot workflow end-to-end: spec → plan → tasks → execute → review → commit (up to but not including PR submit).

**Example usage:**
```
/autopilot:oneshot https://github.com/owner/repo/issues/123
```

### `[no-test]` TODO Flag — Skip Test Generation

A flag on individual TODO tasks that instructs the task-runner to skip the tester agent for that task. Useful for tasks where writing a test is not applicable (e.g. config changes, docs, scaffolding).

**Example usage:**
```
- [ ] [T3] [no-test] Add default config file
```
