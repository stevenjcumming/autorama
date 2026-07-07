---
name: help
description: Use when the user asks what autoskill can do or how it works. Triggers on "autoskill help", "what can autoskill do", "list autoskill commands", "how does autoskill work", or similar requests for an overview of the plugin.
allowed-tools: Read, Glob
---

# Autoskill Help

Autoskill generates reusable, project-specific skills from codebase patterns, then keeps them in sync as the codebase evolves.

## Commands

| Command | Purpose |
|---|---|
| `autoskill:build <pattern description>` | Create a new skill from codebase patterns |
| `autoskill:update <skill-name>` | Refresh an existing generated skill against current code |
| `autoskill:list` | Show all generated skills and flag drift |
| `autoskill:remove <skill-name>` | Delete a generated skill |
| `autoskill:help` | Show this help |

## Typical Order

1. Run `autoskill:build` to generate a skill. Under the hood this runs discovery, synthesis, and a quality check, and gives you a chance to confirm the output before it's written.
2. As the codebase evolves, run `autoskill:update <skill-name>` to re-sync a skill's content with current patterns.
3. Run `autoskill:list` any time to see what's installed and whether anything looks stale.
4. Run `autoskill:remove <skill-name>` if a generated skill is no longer needed.

## No Setup Required

There is no init or bootstrap step. Autoskill works immediately after the plugin is installed, using `${CLAUDE_PLUGIN_ROOT}` to locate its own templates and references. No restart is needed before `autoskill:build` or any other command will work.
