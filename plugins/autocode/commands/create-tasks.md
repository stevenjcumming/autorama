---
allowed-tools: Bash, Read, Edit
description: Use when the user has a completed PLAN.md and wants to break it into actionable tasks. Generates a phased TODO.md checklist with task IDs ([T1], [T2]) for execution. Does NOT start implementation.
argument-hint: <identifier>
---

# Create Tasks

Convert an implementation plan into an actionable TODO checklist.

**This command marks the end of the planning phase. Do NOT start implementation.**

## Step 1: Create TODO.md Template

Run the create-tasks script:

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/create-tasks.sh $ARGUMENTS
```

## Step 2: Read the Plan

Read `PLAN.md` from the spec directory and extract:
- All phases with their names and goals
- Each change within each phase (files to create/modify)
- Success criteria (automated and manual)
- Testing requirements

```
Read(".specs/$ARGUMENTS/PLAN.md")
```

If PLAN.md is empty or has only template content, tell the user to complete the plan first and stop.

## Step 3: Convert to Tasks

For each phase, create tasks following these rules:

### Task Granularity
- **One task per file modification** - Each file changed = one task
- **Separate test tasks** - Tests for each component get their own task
- **Include verification tasks** - Add tasks for running automated checks

### Task Ordering
Within each phase, order by dependencies:
1. Data structures / Types
2. Core logic / Business rules
3. External interfaces (APIs, CLI, UI)
4. Background processes
5. Tests
6. Verification

### Task Descriptions
Write concise, actionable descriptions:
- Start with a verb (Create, Add, Update, Implement, Write, Run)
- Include the file path when known
- Reference patterns to follow when helpful
- Keep under 80 characters

**Good examples:**
- `Create UserService at src/services/user.ts`
- `Add validation to OrderController.create()`
- `Write unit tests for PaymentService`
- `Run test suite and fix failures`

**Bad examples:**
- `Work on the user stuff` (vague)
- `Create the user service file and add all the methods for CRUD` (too long)
- `Tests` (not actionable)

## Step 4: Write TODO.md

Replace the template content in `TODO.md` with **numbered tasks**:

- **Phases**: Use `## P1:`, `## P2:`, etc.
- **Tasks**: Prefix each task with `[T1]`, `[T2]`, etc. (global numbering across all phases)

This enables targeted execution: `/autocode:execute <SPEC_DIR> T3` runs only task T3.

```markdown
# TODO

<!-- Task checklist generated from PLAN.md -->
<!-- Run specific task: /autocode:execute <SPEC_DIR> T3 -->
<!-- Run specific phase: /autocode:execute <SPEC_DIR> P1 -->

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

### Rules
- **Extract from PLAN.md only** - Don't invent tasks not in the plan
- **Keep tasks atomic** - Each should be completable in one session. The task-runner gets a fresh context per task; large tasks risk hitting context limits.
- **Match phase names exactly** - Use the phase names from PLAN.md
- **Include all verification** - Success criteria become verification tasks
- **Don't skip trivial tasks** - If it's in the plan, it needs a task
- **Preserve order** - Respect the dependency order in the plan

## Step 5: Present Results

After writing TODO.md, present:

```
Planning complete. Generated TODO.md with N tasks across M phases.

Files:
- .specs/<identifier>/PLAN.md - Implementation plan
- .specs/<identifier>/TODO.md - Task checklist

Run options:
- All tasks: /autocode:execute <identifier>
- Single task: /autocode:execute <identifier> T1
- Single phase: /autocode:execute <identifier> P1

First task:
- [ ] [T1] <First task description>
```

## Step 6: STOP

**Do NOT begin implementation.** The user must review and approve the task list first.
