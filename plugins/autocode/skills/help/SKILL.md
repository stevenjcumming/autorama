---
name: help
description: Use when the user asks about available autocode skills, workflow order, or how to use the plugin. Displays the skill table and typical workflow.
model: haiku # purely display-only - prints a static/templated table and workflow summary with no judgment calls, tool use, or file reads; see docs/MODEL_SELECTION.md
---

# Autocode Help

Display the available Autocode skills in the order they should be used. Each skill is invoked as a slash command (`/autocode:<name>`); Claude can also trigger them automatically when a request matches a skill's description.

## Workflow Skills (in order)

| # | Skill | Purpose |
|---|-------|---------|
| 1 | `/autocode:init` | Initialize Autocode configuration and install optional dependencies |
| 2 | `/autocode:new-spec <id>` | Create a new spec folder and SPEC.md file |
| 3 | `/autocode:create-plan <id>` | Generate an implementation plan from a spec |
| 4 | `/autocode:create-tasks <id>` | Convert the plan into a phased TODO checklist |
| 5 | `/autocode:execute <id>` | Execute TDD loop (Write Tests / Red / Code / Green / Analysis / Refactor) |
| 6 | `/autocode:review <id>` | Generate a review summary of changes and artifacts |
| 7 | `/autocode:code-review [id]` | Structured code review against a configurable checklist |
| 8 | `/autocode:commit` | Create a commit with a conventional commit message |
| 9 | `/autocode:sync-pr` | Create or update a PR for the current branch |

## Utility Skills

| Skill | Purpose |
|-------|---------|
| `/autocode:spec-archive <id>` | Archive spec files to `~/.autocode/specs/` |
| `/autocode:ticket <issue-url> [model]` | Run spec/plan/tasks/execute unattended from a GitHub issue, ending at the review checkpoint (commit/PR are separate, manual) |

## Model Selection

Model tiers are chosen automatically: fixed roles are pinned in frontmatter, while planning, coding, and code review resolve per work item from decision tables (task ratings in TODO.md, `models.ceiling` in autocode.yml, and `[model]` arguments as overrides). See the plugin's `docs/MODEL_SELECTION.md` for the tables and best practices.

## Context Hygiene

| When | Do | Why |
|------|----|-----|
| Switching to a new spec | `/clear` | A new spec shares nothing with the previous one |
| Between planning and `/autocode:execute` | `/compact` | Execute re-reads SPEC.md, PLAN.md, and TODO.md from disk; the planning conversation is not needed |

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
