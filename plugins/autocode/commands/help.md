---
description: Use when the user asks about available autocode commands, workflow order, or how to use the plugin. Displays the command table and typical workflow.
---

# Autocode Help

Display the available Autocode commands in the order they should be used.

## Workflow Commands (in order)

| # | Command | Purpose |
|---|---------|---------|
| 1 | `/autocode:init` | Initialize Autocode configuration and install optional dependencies |
| 2 | `/autocode:new-spec <id>` | Create a new spec folder and SPEC.md file |
| 3 | `/autocode:create-plan <id>` | Generate an implementation plan from a spec |
| 4 | `/autocode:create-tasks <id>` | Convert the plan into a phased TODO checklist |
| 5 | `/autocode:execute <path>` | Execute TDD loop (Write Tests / Red / Code / Green / Analysis / Refactor) |
| 6 | `/autocode:review <id>` | Generate a review summary of changes and artifacts |
| 7 | `/autocode:code-review [id]` | Structured code review against a configurable checklist |
| 8 | `/autocode:commit` | Create a commit with a conventional commit message |
| 9 | `/autocode:sync-pr` | Create or update a PR for the current branch |

## Utility Commands

| Command | Purpose |
|---------|---------|
| `/autocode:spec-archive <id>` | Archive spec files to `~/.autocode/specs/` |

## Typical Workflow

1. **Init** — Run once per project to set up configuration
2. **Spec** — Define requirements for a feature or change
3. **Plan** — Generate a detailed implementation plan from the spec
4. **Tasks** — Break the plan into actionable tasks with a TODO checklist
5. **Execute** — Run the autonomous TDD loop to implement each task
6. **Review** — Inspect the changes and generated artifacts
7. **Code Review** — Run a structured code review against a checklist (optional)
8. **Submit** — Commit and open/update a PR

Print the table and workflow summary above to the user.
