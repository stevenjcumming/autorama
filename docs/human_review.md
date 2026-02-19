# Human Review

## Task Filtering

When running `/autopilot:execute`, the engineer controls which tasks are executed via an optional filter argument:

| Invocation | Scope |
|---|---|
| `/autopilot:execute auth-refactor` | All uncompleted tasks in order |
| `/autopilot:execute auth-refactor T3` | Only task T3 |
| `/autopilot:execute auth-refactor P1` | All uncompleted tasks in phase P1 |

There is no range syntax (e.g., `T2-T5`). The options are: one task, one phase, or everything.

## Single Task Mode

The `single_task_mode` setting in `.claude/autopilot.yml` controls how many tasks the loop controller completes before returning control to the engineer:

```yaml
single_task_mode: true   # default
```

- **`true` (default)** — The loop controller exits after completing one task. The engineer sees a summary with remaining tasks listed and must run `/autopilot:execute` again to continue.
- **`false`** — The loop controller runs through all filtered tasks (or all tasks if no filter) before returning. The engineer only regains control when the entire batch is done or a pause signal fires.

With the default setting, the engineer gets a natural checkpoint after every task. With it disabled, checkpoints only occur when the full run finishes or a pause condition triggers (e.g., 3+ repeated violations, security issues, or explicit human review requests).

## Initiating Review

Review can happen at two levels:

### Informal Review (Between Tasks)

When `single_task_mode` is enabled, the engineer regains control after each task. At this point they can:

- Inspect the code changes and artifacts in `.claude/specs/<id>/artifacts/`
- Read the handoff at `.claude/specs/<id>/artifacts/handoff/handoff.md`
- Run tests or check git diffs manually
- Decide whether to continue with `/autopilot:execute <id>` or stop

This is an informal checkpoint — no structured review process runs.

### Formal Review (`/autopilot:review`)

The `/autopilot:review <id>` command triggers a structured review process. It is designed to run after implementation is complete (all tasks or a meaningful batch). The review command:

1. **Gathers summary data** — runs a review script that collects changes, artifacts, and flagged items
2. **Presents an enhanced summary** covering:
   - Code changes and files needing attention
   - Artifact counts and notable entries
   - High-risk items with full details and mitigation strategies
   - Review hints flagged for human judgment
3. **Provides a review checklist** — a structured checklist covering artifacts, code quality, high-risk items, and readiness to proceed
4. **Awaits a human decision** with three options:
   - **Approve** — proceed to the Reflect stage
   - **Request changes** — return to implementation with specifics on what needs fixing
   - **Reject** — return to the Spec stage for fundamental issues

## After Review

The engineer's decision determines the next step:

| Decision | Next Action |
|---|---|
| **Approve** | Run `/autopilot:reflect <id>` to analyze session signals and propose rules, then `/autopilot:commit` and `/autopilot:sync-pr` to submit |
| **Request changes** | Run `/autopilot:execute <id>` again (optionally filtering to specific tasks) to address the feedback |
| **Reject** | Run `/autopilot:new-spec <id>` to rework the specification from scratch |

The full post-review pipeline for an approved review is:

```
/autopilot:review → /autopilot:reflect → /autopilot:commit → /autopilot:sync-pr
```

- `/autopilot:reflect` analyzes signals from the implementation session and proposes rule changes
- `/autopilot:commit` creates a conventional commit
- `/autopilot:sync-pr` creates or updates a GitHub pull request
