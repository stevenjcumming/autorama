---
name: help
description: Use when the user asks about available autocontext skills, the CONTEXT.md format, or how to use the plugin. Displays the skill table and typical workflow.
allowed-tools: Read
---

# Autocontext Help

Display the available Autocontext skills and workflow. Each skill is invoked as a slash command (`/autocontext:<name>`); Claude can also trigger them automatically when a request matches a skill's description.

## Skills

| # | Skill | Purpose |
|---|-------|---------|
| 1 | `/autocontext:init` | One-time project setup: writes `AUTOCONTEXT_PLUGIN_ROOT` to settings and injects the CONTEXT.md execution contract into `.claude/CLAUDE.md` |
| 2 | `/autocontext:create [path]` | Analyze a directory and generate a `CONTEXT.md` (draft is confirmed before writing) |
| 3 | `/autocontext:update [path]` | Validate an existing `CONTEXT.md` and apply approved fixes for broken references, stale tasks, and structural anti-patterns |

## Typical Workflow

1. **Init**: run once per project, then restart the session so the env var loads
2. **Create**: generate a `CONTEXT.md` for each directory with non-obvious context (payments, admin, integrations); skip conventional directories
3. **Review**: fill in `Never Do Here` and verify `Tasks` by hand; these sections always require human review
4. **Update**: run periodically or after refactors to catch broken references and drift

## What CONTEXT.md Is

A directory-scoped guidance file that agents read before acting. Up to five sections, each included only when the agent would make wrong assumptions without it:

| Section | Answers |
|---------|---------|
| Purpose | What non-obvious domain context or ownership boundaries apply here? |
| Key References | Which files should be loaded before acting here, and why? |
| Docs | Which references load when a specific file pattern is opened? |
| Tasks | Which instruction/rule/skill bundle fulfills each repeatable task? |
| Never Do Here | Which hard constraints hold regardless of the active task? |

The full format specification lives at `$AUTOCONTEXT_PLUGIN_ROOT/references/context-format-guide.md`.

Print the tables and workflow summary above to the user.
