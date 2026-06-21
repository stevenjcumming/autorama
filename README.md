# Autorama

Autorama is a Claude Code plugin marketplace for safe, structured, semi-autonomous software development. 

Claude Code is powerful but project-ignorant. It does not know your coding patterns, your team conventions, or your domain context. Generic tools produce generic results. Autorama closes that gap with project-specific skills, structured development loops, and the context layer Claude needs to work reliably in your codebase. Autorama makes sure Claude knows your project.

| Plugin | Purpose |
|--------|---------|
| `autocode` | Development framework from spec to pull request |
| `autoskill` | Generate skills from project-specific coding patterns |
| `autocontext` (in-progress) | Generates token-efficient, project-specific context for agents |

## Install

```bash
# Add the marketplace
/plugin marketplace add stevenjcumming/autorama

# Install the plugins
/plugin install autocode@stevenjcumming
/plugin install autoskill@stevenjcumming
```

After installing, restart Claude Code so the plugins' hooks and settings take effect. The same applies after running each plugin's init skill (`/autoskill:init`, `/autocode:init`): both write settings that are only loaded when a session starts.

---

## autocode

A structured TDD workflow with specialized agents for autonomous execution and human-gated submission.

- [Usage Guide](docs/autocode/usage-guide.md) - Quick start, safety principles, configuration
- [Workflow Overview](docs/autocode/workflow-overview.md) - Stage-by-stage breakdown with skill reference
- [Workflow Stages](docs/autocode/workflow-stages/) - Deep-dive per stage
- [Agent Architecture](docs/autocode/agent-architecture.md) - Agent harness and task runner design
- [Agent Handoff](docs/autocode/agent-handoff.md) - Context preservation between tasks
- [Artifact System](docs/autocode/artifacts.md) - Decisions, risks, justifications, review hints
- [Hook System](docs/autocode/hook-system.md) - Pre/post tool hooks
- [Configuration](docs/autocode/configuration.md) - Full config reference
- [GitHub Integration](docs/autocode/github-integration.md) - GitHub app setup and CI review alignment
- [Migrating to v2](docs/autocode/migrating-to-v2.md) - Breaking changes and upgrade steps
- [Justification Categories](docs/autocode/justifications.md) - When and why justifications are required
- [Human Review](docs/autocode/human_review.md) - Review stage and approval flow
- [Rules](docs/autocode/rules.md) - Cross-session learning via `.claude/rules/`
- [Evaluation Pipeline](docs/autocode/evaluation_pipeline.md) - Testing the plugin itself
- [End-to-End Flowchart](docs/autocode/e2e_flowchart.md)

---

## autoskill

A skill generation engine that discovers codebase patterns and generates Claude Code skills so future sessions follow your team's conventions automatically.

- [Overview](docs/autoskill/overview.md) - What autoskill does and skill summary
- [Usage Guide](docs/autoskill/usage-guide.md) - Step-by-step init, build, and update instructions
- [How It Works](docs/autoskill/how-it-works.md) - Build and update workflows under the hood
- [Agent Architecture](docs/autoskill/agent-architecture.md) - Discovery, synthesizer, and quality-check agents
- [Generated Output](docs/autoskill/generated-output.md) - Skill folder structure and metadata

---

## License

MIT
