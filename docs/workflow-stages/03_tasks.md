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

Tasks are globally numbered with `[T1]`, `[T2]`, etc. across all phases, and phases use `P1:`, `P2:` prefixes. This enables targeted execution of individual tasks or phases.

```markdown
# TODO

<!-- Task checklist generated from PLAN.md -->
<!-- Run specific task: /autopilot:execute <SPEC_DIR> T3 -->
<!-- Run specific phase: /autopilot:execute <SPEC_DIR> P1 -->

## P1: [Actual Phase Name from PLAN.md]

- [ ] [T1] First task
- [ ] [T2] Second task
- [ ] [T3] Write tests for [component]
- [ ] [T4] Run [verification command]

---

## P2: [Actual Phase Name from PLAN.md]

- [ ] [T5] First task
- [ ] [T6] Second task
- [ ] [T7] Write tests for [component]
```

## Output

The command returns:
- Location of TODO.md
- Task count per phase (with task ID ranges, e.g., T1-T4)
- Total task count
- Run options for executing all tasks, a single task, or a single phase
- First task to start with

## Next Steps

After the command completes:

1. Review TODO.md for completeness
2. Verify task ordering makes sense
3. Run all tasks: `/autopilot:execute <SPEC_DIR>`
4. Or run a specific task: `/autopilot:execute <SPEC_DIR> T1`
5. Or run a specific phase: `/autopilot:execute <SPEC_DIR> P1`
