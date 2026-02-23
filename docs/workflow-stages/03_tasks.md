# Workflow: Create Tasks

## Purpose

Convert an implementation plan into a phased TODO checklist. This marks the end of planning—do not start implementation until the task list is reviewed.

## Command

```
/autopilot:create-tasks <identifier>
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `identifier` | Yes | Name of existing spec folder |

## Prerequisites

- Spec folder must exist at `.claude/specs/<identifier>/`
- `PLAN.md` must be present and filled out

## What It Does

1. Validates spec folder and `PLAN.md` exist
2. Creates `TODO.md` from template
3. Spawns `task-builder` agent to populate tasks

## Agent Pipeline

```
task-builder
├── Reads PLAN.md
├── Extracts phases and changes
├── Converts each change to atomic task
├── Orders by dependency
└── Writes TODO.md
```

### Agents

| Agent | Purpose | Output |
|-------|---------|--------|
| `task-builder` | Converts plan to actionable tasks | TODO.md |

## Directory Structure

```
.claude/
└── specs/
    └── <identifier>/
        ├── REQUIREMENT.md
        ├── SPEC.md
        ├── RESEARCH.md
        ├── PLAN.md
        └── TODO.md       <-- Created by task-builder
```

## Task Conversion Rules

### Granularity

| Rule | Example |
|------|---------|
| One task per file | `Create UserService at src/services/user.ts` |
| Separate test tasks | `Write unit tests for UserService` |
| Include verification | `Run test suite and fix failures` |

### Ordering (within each phase)

1. Data structures / Types
2. Core logic / Business rules
3. External interfaces (APIs, CLI, UI)
4. Background processes
5. Tests
6. Verification

### Task Descriptions

- Start with a verb (Create, Add, Update, Implement, Write, Run)
- Include file path when known
- Reference patterns to follow
- Keep under 80 characters

## TODO.md Format

```markdown
# TODO

## Phase 1: [Name]

- [ ] First task
- [ ] Second task
- [ ] Write tests for [component]
- [ ] Run [verification command]

---

## Phase 2: [Name]

- [ ] First task
- [ ] Second task
```

## Output

The command returns:
- Location of TODO.md
- Task count per phase
- Total task count
- First task to start with

## Next Steps

After the command completes:

1. Review TODO.md for completeness
2. Verify task ordering makes sense
3. Engage autopilot
