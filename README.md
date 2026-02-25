# Autopilot

A Claude Code plugin for AI-autonomous software development with structured workflows and safety guardrails.

## Workflow

```
Requirements → Spec → Plan → Tasks → Test → Code → Analysis → Refactor → Review → Submit
```

The plugin guides you through a structured development workflow:

1. **Spec** - Define requirements and acceptance criteria
2. **Plan** - Research codebase and create implementation plan
3. **Tasks** - Break plan into actionable checklist
4. **Execute** - Execute Test/Code/Analysis/Refactor loop autonomously via Agent Harness
5. **Review** - Human checkpoint for changes and artifacts (approve, request changes, or reject)
6. **Submit** - Commit and create pull request

See [docs/workflow-overview.md](docs/workflow-overview.md) for detailed stage descriptions.

## Quick Start

```bash
# 1. Install the plugin
/plugin marketplace add stevenjcumming/claude-code-autopilot
/plugin install autopilot

# 2. See available commands and workflow
/autopilot:help

# 3. Initialize (creates config, installs yq, updates gitignore)
/autopilot:init

# 4. Start a new feature
/autopilot:new-spec my-feature

# 5. Fill in REQUIREMENT.md 
# Copy and paste your GitHub or JIRA ticket 

# 6. Fill in SPEC.md
# Write or generate a SPEC.md based on REQUIREMENT.md 

# 7. Generate the tasks
/autopilot:create-plan my-feature
/autopilot:create-tasks my-feature

# 8. Start development
/autopilot:execute my-feature T1

# 9. Review and create/update PR
/autopilot:review my-feature
/autopilot:commit
/autopilot:sync-pr
```

## Safety Principles

- **Human checkpoints** - Review stage requires approval before submission
- **Automatic pause** - Stops on repeated violations and human review flags
- **Incremental changes** - Small, reviewable tasks with auto-commits after each completion
- **Artifact trail** - Decisions, assumptions, risks, and justifications documented per spec
- **Context preservation** - Handoff artifacts ensure continuity between task agents
- **Continuous improvement** - Rules in `.claude/rules/` inform future sessions

## Configuration

Configure via `.claude/autopilot.yml`. Run `/autopilot:init` to create from template. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `auto_commit.message_template` | conventional | Commit message format after each task |
| `justification.categories` | (see config) | Require justification for flagged file categories |
| `static_analysis.commands` | `[]` | Static analysis commands to run during autopilot |

Feature sections are active when present. To disable a feature, remove the section entirely.

See [docs/configuration.md](docs/configuration.md) for full reference.

## Documentation

- [Workflow Overview](docs/workflow-overview.md)
- [Workflow Stages](docs/workflow-stages/)
- [End-to-End Flowchart](docs/e2e_flowchart.md)
- [Agent Architecture](docs/agent-architecture.md)
- [Agent Handoff](docs/agent-handoff.md)
- [Hook System](docs/hook-system.md)
- [Artifact System](docs/artifacts.md)
- [Evaluation Pipeline](docs/evaluation_pipeline.md)
- [Rules](docs/rules.md)
- [Configuration](docs/configuration.md)
- [Justification Categories](docs/justifications.md)
- [Human Review](docs/human_review.md)

## License

MIT
