# Human Review

## Task Filtering

When running `/autocode:execute`, the engineer controls which tasks are executed via an optional filter argument:

| Invocation | Scope |
|---|---|
| `/autocode:execute auth-refactor` | All uncompleted tasks in order |
| `/autocode:execute auth-refactor T3` | Only task T3 |
| `/autocode:execute auth-refactor P1` | All uncompleted tasks in phase P1 |

There is no range syntax (e.g., `T2-T5`). The options are: one task, one phase, or everything.

## Initiating Review

Review can happen at two levels:

### Informal Review (Between Tasks)

Between tasks, the engineer can inspect changes at any time:

- Inspect the code changes and artifacts in `.specs/<id>/artifacts/`
- Read the handoff at `.specs/<id>/artifacts/handoff/handoff.md`
- Run tests or check git diffs manually

### Formal Review (`/autocode:review`)

The `/autocode:review <id>` command triggers a structured review process. It is designed to run after implementation is complete (all tasks or a meaningful batch). The review command:

1. **Gathers summary data** — runs a review script that collects changes, artifacts, and flagged items
2. **Presents an enhanced summary** covering:
   - Code changes and files needing attention
   - Artifact counts and notable entries
   - High-risk items with full details and mitigation strategies
   - Review hints flagged for human judgment
3. **Provides a review checklist** — a structured checklist covering artifacts, code quality, high-risk items, and readiness to proceed
4. **Awaits a human decision** with three options:
   - **Approve** — proceed to the Submit stage
   - **Request changes** — return to implementation with specifics on what needs fixing
   - **Reject** — return to the Spec stage for fundamental issues

## After Review

The engineer's decision determines the next step:

| Decision | Next Action |
|---|---|
| **Approve** | Run `/autocode:commit` and `/autocode:sync-pr` to submit |
| **Request changes** | Run `/autocode:execute <id>` again (optionally filtering to specific tasks) to address the feedback |
| **Reject** | Run `/autocode:new-spec <id>` to rework the specification from scratch |

The full post-review pipeline for an approved review is:

```
/autocode:review → /autocode:commit → /autocode:sync-pr
```

- `/autocode:commit` creates a conventional commit
- `/autocode:sync-pr` creates or updates a GitHub pull request
