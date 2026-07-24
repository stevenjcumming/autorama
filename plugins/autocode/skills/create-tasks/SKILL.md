---
name: create-tasks
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/create-tasks/scripts/create-tasks.sh:*), Read, Edit
description: Use when the user has a completed PLAN.md and wants to break it into actionable tasks. Generates a phased TODO.md checklist with task IDs ([T1], [T2]) for execution. Does NOT start implementation.
argument-hint: <identifier>
model: sonnet # mechanical PLAN.md -> TODO.md conversion with a human reviewing the output; see docs/MODEL_SELECTION.md
---

# Create Tasks

Convert an implementation plan into an actionable TODO checklist.

**This command marks the end of the planning phase. Do NOT start implementation.**

## Step 1: Create TODO.md Template

Run the create-tasks script:

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/create-tasks/scripts/create-tasks.sh $ARGUMENTS
```

The script validates upstream content (does PLAN.md exist and have real content, not just unfilled template boilerplate?) *before* scaffolding TODO.md, so a failed check never leaves a stale, empty TODO.md behind. If the script exits with an error because TODO.md already exists, stop and ask the user whether to keep the existing TODO.md or regenerate it. Only if they choose to regenerate, delete the existing TODO.md, re-run the script, and continue. If the script exits with an error because PLAN.md is missing or is empty/unfilled template content, surface the error message and tell the user to complete the plan first, then stop. For any other script error, surface the error message and stop.

## Step 2: Read the Plan

Read `PLAN.md` from the spec directory and extract:
- All phases with their names and goals
- Each change within each phase (files to create/modify)
- Success criteria (automated and manual)
- Testing requirements

```
Read(".specs/$ARGUMENTS/PLAN.md")
```

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

First read the generated template (Edit requires a prior Read):

```
Read(".specs/$ARGUMENTS/TODO.md")
```

Then replace the template content in `TODO.md` with **numbered tasks**:

- **Phases**: Use `## P1:`, `## P2:`, etc.
- **Tasks**: Prefix each task with `[T1]`, `[T2]`, etc. (global numbering across all phases)
- **Ratings**: After the task ID, carry over each task's difficulty rating from PLAN.md as a parenthesized annotation: `- [ ] [T1] (easy) First task`. Valid ratings are `easy`, `standard`, and `hard`. A missing annotation is valid and means `standard`; if PLAN.md has no rating for a task, omit the annotation rather than guessing. The rating selects the coder's model tier during execution (see the plugin's `docs/MODEL_SELECTION.md`).

This enables targeted execution: `/autocode:execute <identifier> T3` runs only task T3.

```markdown
# TODO

<!-- Task checklist generated from PLAN.md -->
<!-- Run specific task: /autocode:execute <identifier> T3 -->
<!-- Run specific phase: /autocode:execute <identifier> P1 -->
<!-- (easy|standard|hard) after a task ID rates its difficulty; edit freely before /autocode:execute -->

## P1: [Actual Phase Name from PLAN.md]

- [ ] [T1] (easy) First task
- [ ] [T2] Second task
- [ ] [T3] (standard) Write tests for [component]
- [ ] [T4] (hard) Run [verification command]

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

Task ratings: each task carries an (easy|standard|hard) difficulty rating
that picks the coder's model tier during execution (missing = standard).
This is your checkpoint to adjust them - edit the annotations in TODO.md
before running /autocode:execute if any rating looks wrong.

Run options:
- All tasks: /autocode:execute <identifier>
- Single task: /autocode:execute <identifier> T1
- Single phase: /autocode:execute <identifier> P1

First task:
- [ ] [T1] <First task description>
```

## Step 6: STOP

**Do NOT begin implementation.** The user must review and approve the task list first.
