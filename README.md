# Autopilot

Autopilot is a Claude Code plugin for semi-autonomous software development. It provides a structured framework with workflows, slash commands, and specialized agents for running safe development loops with human oversight. Autonomous execution. Human-gated submission. 

## Workflow

```
Requirements → Spec → Plan → Tasks → Write Tests → Red → Code → Green → Analysis → Refactor → Review → Submit
```

The plugin guides you through a structured development workflow:

1. **Spec** - Define requirements and acceptance criteria
2. **Plan** - Research codebase and create implementation plan
3. **Tasks** - Break plan into actionable checklist
4. **Execute** - Execute a TDD loop autonomously via an agent harness
5. **Review** - Human checkpoint for changes and artifacts
6. **Submit** - Commit and create pull request

See [docs/workflow-overview.md](docs/workflow-overview.md) for detailed stage descriptions.

## Quick Start

```bash
# 1. Install the plugin
/plugin marketplace add stevenjcumming/autopilot
/plugin install autocode

# 2. See available commands and workflow
/autocode:help

# 3. Initialize (creates config, installs yq, updates gitignore)
/autocode:init

# 4. Start a new feature
/autocode:new-spec my-feature

# 5. Fill in REQUIREMENT.md 
# Copy and paste your GitHub or JIRA ticket 

# 6. Fill in SPEC.md
# Write or generate a SPEC.md based on REQUIREMENT.md 

# 7. Generate the tasks
/autocode:create-plan my-feature
/autocode:create-tasks my-feature

# 8. Start development
/autocode:execute my-feature T1

# 9. Review and create/update PR
/autocode:review my-feature
/autocode:commit
/autocode:sync-pr
```

## Safety Principles

- **Human checkpoints** - Review stage requires approval before submission
- **Automatic pause** - Stops on repeated violations and human review flags
- **Incremental changes** - Small, reviewable tasks with clean handoffs between each completion
- **Artifact trail** - Decisions, assumptions, risks, and justifications documented per spec
- **Context preservation** - Handoff artifacts ensure continuity between task agents
- **Continuous improvement** - Rules in `.claude/rules/` inform future sessions

## Configuration

Configure via `.claude/autocode.yml`. Run `/autocode:init` to create from template. Key settings:

| Setting | Default | Description |
|---------|---------|-------------|
| `justification.categories` | (see config) | Require justification for flagged file categories |
| `static_analysis.commands` | `[]` | Static analysis commands to run during autocode |

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

## Plugin Naming

**Autopilot** is the umbrella brand and marketplace name (`stevenjcumming/autopilot`). Under it, individual plugins handle specific areas of the development workflow:

| Plugin | Purpose |
|--------|---------|
| `autocode` | Development workflow: TDD loop, specs, plans, PRs |
| `autoskill` | Skill generation for teams and projects |
| `autocontext` | Context management (future) |

When you install from the marketplace, you install specific plugins: `/plugin install autocode`. The marketplace stays under the `autopilot` name on GitHub.

## License

MIT
