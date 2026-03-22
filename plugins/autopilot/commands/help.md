---
description: Use when the user asks about available autopilot commands, workflow order, or how to use the plugin. Displays the command table and typical workflow.
---

# Autopilot Help

Display the available Autopilot commands in the order they should be used.

## Workflow Commands (in order)

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/autopilot:init` | Initialize Autopilot configuration and install optional dependencies |
| 2 | `/autopilot:new-spec <id>` | Create a new spec folder and SPEC.md file |
| 3 | `/autopilot:create-plan <id>` | Generate an implementation plan from a spec |
| 4 | `/autopilot:create-tasks <id>` | Convert the plan into a phased TODO checklist |
| 5 | `/autopilot:execute <path>` | Execute TDD loop (Write Tests / Red / Code / Green / Analysis / Refactor) |
| 6 | `/autopilot:review <id>` | Generate a review summary of changes and artifacts |
| 7 | `/autopilot:code-review [id]` | Structured code review against a configurable checklist |
| 8 | `/autopilot:commit` | Create a commit with a conventional commit message |
| 9 | `/autopilot:sync-pr` | Create or update a PR for the current branch |

## Utility Commands

| Command | Purpose |
|---------|---------|
| `/autopilot:spec-archive <id>` | Archive spec files to `~/.autopilot/specs/` |
| `/autopilot:oneshot <blueprint>` | Full-autonomy mode — decompose a blueprint and execute all specs |

## Typical Workflow

1. **Init** — Run once per project to set up configuration
2. **Spec** — Define requirements for a feature or change
3. **Plan** — Generate a detailed implementation plan from the spec
4. **Tasks** — Break the plan into actionable tasks with a TODO checklist
5. **Execute** — Run the autonomous TDD loop to implement each task
6. **Review** — Inspect the changes and generated artifacts
7. **Code Review** — Run a structured code review against a checklist (optional)
8. **Submit** — Commit and open/update a PR

## Oneshot Mode

For fully autonomous execution of a blueprint document:

```
/autopilot:oneshot <blueprint> [--no-questions] [--no-human] [--dry-run] [--resume]
```

This decomposes the blueprint into specs and executes each through the full pipeline.

Print the table and workflow summary above to the user.
