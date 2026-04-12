# Usage Guide

## Prerequisites

- Claude Code installed
- Autocode plugin installed (`/plugin install autocode`)

## Initialize

Run once per project to create the config file, install `yq`, and update `.gitignore`.

```
/autocode:init
```

## Quick Start

```bash
# 1. Start a new feature
/autocode:new-spec my-feature

# 2. Fill in REQUIREMENT.md
# Copy and paste your GitHub or JIRA ticket

# 3. Fill in SPEC.md
# Write or generate a SPEC.md based on REQUIREMENT.md

# 4. Generate the plan and tasks
/autocode:create-plan my-feature
/autocode:create-tasks my-feature

# 5. Run the autonomous TDD loop
/autocode:execute my-feature T1

# 6. Review and submit
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

Configure via `.claude/autocode.yml`. Run `/autocode:init` to create from template.

| Setting | Default | Description |
|---------|---------|-------------|
| `justification.categories` | (see config) | Require justification for flagged file categories |
| `static_analysis.commands` | `[]` | Static analysis commands to run during autocode |

See [configuration.md](configuration.md) for full reference.
