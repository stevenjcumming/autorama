# Autoskill

A skill generation engine that transforms codebase patterns into reusable, project-specific Claude Code skills. Autoskill discovers how your team implements recurring patterns (API endpoints, background jobs, data access layers, etc.), then generates skills that teach Claude to follow those same conventions in future sessions.

## Skills

The plugin ships three skills. Invoke them as slash commands or describe what you want in natural language; the skill descriptions act as triggers.

| Skill | Purpose | Input | Output |
|-------|---------|-------|--------|
| `/autoskill:init` | One-time project setup | (none) | `AUTOSKILL_PLUGIN_ROOT` in `.claude/settings.local.json` |
| `/autoskill:build <pattern>` | Generate a new skill from codebase patterns | Natural-language pattern description | Skill folder in `.claude/skills/<name>/` |
| `/autoskill:update <name>` | Update an existing skill with current codebase state | Skill name | Updated skill folder with diff confirmation |

## How Skills Are Used

Generated skills live in `.claude/skills/` where Claude's skill loader automatically discovers them. Once a skill exists, Claude activates it whenever a developer's request matches the skill's trigger description. No manual loading or configuration is needed.

## Documentation

- [Usage Guide](usage-guide.md) - Step-by-step instructions for init, build, and update
- [How It Works](how-it-works.md) - Build and update workflows under the hood
- [Agent Architecture](agent-architecture.md) - Discovery, synthesizer, and quality-check agents
- [Generated Output](generated-output.md) - Skill folder structure, SKILL.md sections, metadata.json fields
