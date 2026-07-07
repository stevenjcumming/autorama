# Workflow: Autorama

## Purpose

Execute the Write Tests -> Red -> Code -> Green -> Analysis -> Refactor loop autonomously for a spec, generating artifacts until all tasks are complete.

## Architecture

Autorama uses an **Agent Harness** inspired architecture where background agents complete individual tasks with clean handoffs between them:

```
/autocode:execute (skill, lightweight loop owner)
    │
    ├── Step 3: setup-artifacts.sh + build-task-queue.sh
    │
    ├── Step 4: Task Loop (for each task in queue)
    │   │
    │   ├── Spawn fresh Task(task-runner) per task
    │   │   │
    │   │   ├── PreToolUse Hook: load-context.sh
    │   │   │   └── Loads handoff context and current task
    │   │   ├── PreToolUse Hook: log-skill-usage.sh
    │   │   │   └── Logs agent spawn to usage.jsonl
    │   │   │
    │   │   ├── task-runner (clean context)
    │   │   │   ├── 1. tester (writes tests)
    │   │   │   ├── 2. Bash: run tests → expect RED (fail)
    │   │   │   ├── 3. coder (implements to satisfy tests)
    │   │   │   ├── 4. Bash: run tests → expect GREEN (pass)
    │   │   │   ├── 5. analyzer (static analysis)
    │   │   │   └── 6. refactorer (cleanup)
    │   │   │
    │   │   ├── PostToolUse Hook: check-edit.sh (Write|Edit|MultiEdit)
    │   │   │   └── Per-file static analysis; exits 2 to feed errors back
    │   │   └── SubagentStop Hook: on-agent-complete.sh
    │   │       └── Parses <task-completed> tag, audits artifacts, checks context
    │   │
    │   └── Parse the single <task-completed> tag (status=completed|failed)
    │
    └── Step 5: Present final summary (Completed / Failed / Skipped)
```

**Key benefits:**
- **Fresh context per task** - Each task agent starts with clean context
- **Clean handoffs** - Handoff artifacts preserve decisions
- **Manual commits** - Use `/autocode:commit` after tasks complete
- **Background execution** - Task agents run in background via Task tool

## Skill

```
/autocode:execute <identifier> [T<n>|P<n>]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `identifier` | Yes | Spec identifier (e.g., `auth-refactor`) |
| `filter` | No | Task ID (e.g., `T3`) or phase ID (e.g., `P1`) to limit scope |

## Examples

```bash
# Run all tasks
/autocode:execute auth-refactor

# Run only task T3
/autocode:execute auth-refactor T3

# Run all tasks in phase P1
/autocode:execute auth-refactor P1
```

## Configuration

Autorama can be customized via `.claude/autocode.yml`:

```yaml
# Static analysis configuration
static_analysis:
  enabled: true                   # Master switch (default: true)
  commands:                       # Commands to run
    - rubocop                     # Simple string form
    - npm run lint
    - command: eslint --format json src/
      format: json                # auto, json, text (default: auto)
    - command: reek -c .reek.yml --format json
      format: json
    - npm run typecheck
  fail_on_warnings: false         # Block on warnings (default: false)
  max_fix_attempts: 2             # Max fix attempts per issue (default: 2)
```

### Static Analysis

When `static_analysis.enabled: true` (default), autocode runs configured static analysis tools after tests pass:

1. **Commands are checked** - Verifies each command exists before running
2. **Output is parsed** - Auto-detects JSON or text format
3. **Issues are categorized** - Errors, warnings, and info levels
4. **Blocking issues trigger fixes** - Coder agent receives fix instructions

**Command formats:**

```yaml
# Simple string - command runs as-is
commands:
  - rubocop
  - npm run lint

# Object form - specify output format
commands:
  - command: eslint --format json src/
    format: json    # Explicit JSON parsing
  - command: pylint src/
    format: text    # Explicit text parsing
  - command: mypy src/
    format: auto    # Auto-detect (default)
```

**Blocking behavior:**

- Errors always block (must be fixed)
- Warnings block only if `fail_on_warnings: true`
- Info-level issues are logged but don't block

**Missing commands:**

If a configured command is not installed, autocode logs a warning and continues. This allows the same config to work across different environments.


### Handoff Artifacts

Autorama generates handoff artifacts after each task. The `task-runner` writes `handoff.md` directly as its final step (Step 8). Each handoff includes:

1. **Session summary** - Compressed context of what was accomplished
2. **Files modified** - List of changes with types and descriptions
3. **Key decisions** - Important choices and their rationale
4. **Next task context** - Next task ID, relevant files, and dependencies
5. **Blockers** - Any issues preventing progress
6. **Warnings for next agent** - Important context the next agent needs

Handoff artifacts are stored at `.specs/<identifier>/artifacts/handoff/handoff.md` and provide continuity between task agents.

### Justification Configuration

Customize when and how justifications are required for file modifications:

```yaml
justification:
  categories:
    # Override built-in category or add custom ones
    spec_modification:
      title: "Test/Spec Modification"
      patterns:
        - "*_spec.rb"
        - "*.test.ts"
      questions:
        - "Is this adding new specs?"
        - "Are you changing assertions to pass? **(STOP)**"

    # Custom category example
    infrastructure:
      title: "Infrastructure Change"
      patterns:
        - "terraform/**"
        - "*.tf"
      questions:
        - "Has platform team reviewed?"

  default:
    title: "File Modification"
    questions:
      - "What is the purpose of this change?"
```

**Pattern Syntax:**
- Simple patterns (no `/`) match basename only: `*.test.ts` matches `foo.test.ts` anywhere
- Path patterns match full paths: `*/api/*` matches `src/api/users.ts`

**Optional dependency:** Install `yq` for config customization. Without `yq`, built-in defaults are used.

## Prerequisites

- Spec folder must exist at `.specs/<identifier>/`
- `TODO.md` must exist with uncompleted tasks
- `PLAN.md` must be present
- `SPEC.md` must be present
- If filter provided, task/phase must exist and have uncompleted items

## What It Does

1. Validates spec folder and required files exist
2. Reads TODO.md and filters tasks based on optional filter:
   - No filter: all uncompleted tasks
   - `T<n>`: only the specified task
   - `P<n>`: all uncompleted tasks in the specified phase
3. For each filtered task, executes the Write Tests -> Red -> Code -> Green -> Analysis -> Refactor loop:
   - **Write Tests**: Write failing tests from acceptance criteria via `tester`
   - **Red**: Run tests via Bash, expect failure (tests define expected behavior)
   - **Code**: Implement changes with artifact generation via `coder`
   - **Green**: Run tests via Bash, expect pass (implementation satisfies tests)
   - **Analysis**: Run static analysis tools, fix blocking issues
   - **Refactor**: Clean up code if needed
4. Updates TODO.md as tasks complete
5. Continues until all tasks done or exit condition met

## Agent Pipeline

```
/autocode:execute <identifier>
├── Validates prerequisites (TODO.md, PLAN.md, SPEC.md)
├── Spawns fresh task-runner per task (clean context)
│   ├── tester - Writes tests from acceptance criteria (TDD red phase)
│   ├── coder - Implements changes with artifacts
│   ├── analyzer - Runs static analysis, reports issues
│   └── refactorer - Cleans up code
├── Hooks:
│   ├── load-context.sh (PreToolUse/Task) - Rewrites the Task prompt (via updatedInput) with handoff context and current task
│   ├── log-skill-usage.sh (PreToolUse/Task) - Logs agent spawn to usage.jsonl
│   ├── check-edit.sh (PostToolUse/Write|Edit|MultiEdit) - Per-file static analysis, exits 2 to feed errors back
│   └── on-agent-complete.sh (SubagentStop) - Parses <task-completed> tag, audits artifacts, checks context
└── Repeats until all tasks done; a setup failure stops the loop, other failures skip dependents and continue
```

### Agents

| Agent | Purpose | Output |
|-------|---------|--------|
| `task-runner` | Executes single task with full loop (fresh context per task) | Task completion status |
| `tester` | Write tests from acceptance criteria (TDD red phase) | Test files |
| `coder` | Implement task with justifications | Code changes, artifacts |
| `analyzer` | Run static analysis tools | Issue reports, fix instructions |
| `refactorer` | Clean up after implementation | Refactored code |
| `session-summarizer` | Compress session context | Summary for next agent |

## Main Loop Logic

```
tasks = filter_tasks(TODO.md, FILTER)  # Apply T<n> or P<n> filter if provided

for each task in tasks:
    spawn fresh task-runner(task):
        analysis_attempts_by_rule = {}  # Per-rule tracking
        refactor_history = []
        MAX_CODE_RETRIES = 3
        MAX_REFACTOR_CYCLES = 3

        # Step 2: Write Tests (Red Phase)
        tester = spawn(tester, task)
        test_command, test_files = parse(tester.output)
        run(test_command)  # Expect failure

        # Step 3: Implement (Code → Green, max retries)
        # output_failure() emits a body (partial results + suggested
        # alternatives) followed by one <task-completed status="failed" ...> tag
        for attempt in 1..MAX_CODE_RETRIES:
            coder = spawn(coder, task, test_files)
            test_result = run(test_command)
            if tests_pass: break  # GREEN
            category = categorize_failure(test_result)
            if category == "setup": output_failure(category="setup"); exit  # Not retryable
            if attempt == MAX_CODE_RETRIES: output_failure(category); exit

        # Step 4: Analysis Phase (after tests pass) — per-rule tracking
        if static_analysis.commands configured:
            loop:
                analyzer = spawn(analyzer, config)
                if no blocking_issues: break
                for issue in blocking_issues:
                    key = "{tool}:{rule}"
                    analysis_attempts_by_rule[key] += 1
                    if over_limit: generate_debt_artifact(issue)
                if no actionable_issues: break
                coder = spawn(coder, fixes=actionable_issues)
                if tests_fail: git_checkout; break  # Rollback
                # Re-run analysis

        # Step 5: Refactor Phase with stuck detection
        for cycle in 1..MAX_REFACTOR_CYCLES:
            refactorer = spawn(refactorer, task)
            if no changes: break
            if tests_fail: git_checkout; break  # Rollback
            refactor_history.append(changes)
            if is_oscillating(refactor_history) or is_diminishing(refactor_history):
                break  # Accept current state

        # Step 6: Generate artifacts
        # Step 7: Update TODO.md
        mark_task_complete()
        # Step 8: Write handoff.md directly
        write_handoff(task)
        output <task-completed status="completed">

    # After task-runner completes:
    status, category = parse_task_completed_tag()  # missing/unparseable → failed, unknown
    if status == "failed":
        record_failure(task, category, partial_results, alternatives)
        if category == "setup": break  # setup stops the whole loop
        else: skip_remaining_same_phase_tasks_after(task) and skip_dependents(task)
              # independent tasks in later phases still run
    # else: continue to next task

# Final summary lists Completed, Failed (category + partial results + alternatives), Skipped
```

## Exit Conditions

| Condition | Action |
|-----------|--------|
| All filtered tasks completed | Exit with success summary |
| Category retry limit exceeded (non-setup) | Emit failure tag; skip same-phase tasks after this one plus its dependents; continue independent tasks |
| Setup error | Emit failure tag and stop the whole loop (no retries) |
| Missing/unparseable `<task-completed>` tag | Treat as `status=failed category=unknown`; surface raw tail of runner output |
| Refactor stuck (oscillation) | Accept current state, continue to next task |
| Refactor stuck (diminishing returns) | Accept current state, continue to next task |
| All analysis issues deferred | Log warning, continue |
| Spec gap discovered | Pause, suggest return to Spec |
| Critical error | Pause, surface error |

## Stuck Detection (v0.11.0)

The refactor phase includes stuck detection to prevent infinite loops:

### Oscillation Detection

If `MAX_REFACTOR_CYCLES` (default: 3) refactor iterations occur, the system checks whether the same files are being modified with similar-sized diffs across consecutive cycles. This detects apply/revert patterns where the refactorer keeps toggling changes back and forth.

### Diminishing Returns Detection

If a refactor cycle only produces whitespace, formatting, or comment-only changes, the system treats this as diminishing returns and accepts the current state rather than continuing to loop.

## Error-Driven Retries (v0.11.0)

Test failures are classified by category using pattern matching from `plugins/autocode/references/failure-categories.md`. The task-runner uses these categories to determine retryability:

| Priority | Category | Pattern Indicators | Retryable |
|----------|----------|-------------------|-----------|
| 1 | `setup` | `beforeEach`, `setUp`, `ENOENT`, fixture errors | No — exit immediately |
| 2 | `syntax` | `SyntaxError`, `parse error`, `unexpected token` | Yes |
| 3 | `timeout` | `timeout`, `exceeded`, `ETIMEDOUT` | Yes |
| 4 | `runtime` | `TypeError`, `ReferenceError`, `NilClass` | Yes |
| 5 | `missing` | `Cannot find module`, `ModuleNotFoundError` | Yes |
| 6 | `assertion` | `Expected`, `AssertionError`, `to equal` | Yes |
| 7 | `unknown` | Default if no pattern matches | Yes |

The code phase (Step 3) allows up to 3 retries. Setup errors exit immediately without retrying since they indicate environment issues that code changes cannot fix. All other categories are retried with previous error output passed to the coder for correction.

## Per-Rule Analysis Tracking (v0.11.0)

Analysis fix attempts are tracked per-rule instead of globally. Each blocking issue is identified by a composite key `{tool}:{rule}` (e.g., `eslint:no-unused-vars`).

### How It Works

1. The analyzer outputs blocking issues with Issue IDs in `{tool}:{rule}` format
2. The task runner tracks attempts per Issue ID in `analysis_attempts_by_rule`
3. Issues that exceed `max_fix_attempts` are **deferred** and a debt artifact is generated
4. Remaining **actionable** issues are sent to the coder with fix context

### Fix Context

When the coder is spawned to fix analysis issues, it receives:
- `attempt_history` — per-rule attempt counts
- `previous_approaches` — what was tried before
- `max_attempts` — the limit for this rule

On subsequent attempts, the coder explicitly avoids previous approaches. On the final attempt, it prefers suppression comments with justification over complex refactors.

### Debt Artifacts

Deferred issues generate debt artifacts at `{SPEC_DIR}/artifacts/debt/{tool}_{rule}_{timestamp}.md` documenting the issue, attempts made, and recommended manual action.

## Pre-Implementation Complexity Assessment (v0.11.0)

Before implementing a task, the coder agent evaluates complexity:

| Scope | Criteria | Behavior |
|-------|----------|----------|
| **SMALL** | 1-2 files, single concern | Proceed directly |
| **MEDIUM** | 3-5 files, multiple concerns | Plan approach before coding |
| **LARGE** | 6+ files or architectural change | Generate `decision.md` artifact, break into sub-steps |

For LARGE tasks, the coder writes an approach document to `{SPEC_DIR}/artifacts/decisions/{task_id}_approach.md` and implements sub-steps sequentially, testing between each.

## Artifact Generation

### During Code Phase

| Artifact | When | Location |
|----------|------|----------|
| Justifications | Flagged file modified | `.specs/<identifier>/artifacts/justifications/` |
| Decisions | Multiple approaches possible | `.specs/<identifier>/artifacts/decisions/` |
| Assumptions | Inferring unstated requirements | `.specs/<identifier>/artifacts/assumptions/` |
| Risks | Potential problems identified | `.specs/<identifier>/artifacts/risks/` |
| Review Hints | Human judgment needed | `.specs/<identifier>/artifacts/review_hints/` |
| Technical Debt | Shortcuts taken | `.specs/<identifier>/artifacts/debt/` |

### File Categories Requiring Justification

| Category | Pattern | Prompt |
|----------|---------|--------|
| Spec Modification | `*_spec.rb`, `*.test.ts`, etc. | Changing assertions? Why? |
| Migration | `db/migrate/*`, `migrations/*` | New or editing existing? |
| Dependency | `package.json`, `Gemfile`, etc. | Why needed? |
| Configuration | `config/**/*.yml`, `*.env*` | Production impact? |
| API Change | `*_controller.rb`, `api/**` | Breaking change? |
| Security | `*auth*`, `*security*`, `*permission*` | Access implications? |

## Directory Structure

### Plugin Structure (in `plugins/autocode/`)

```
plugins/autocode/
├── skills/
│   └── execute/
│       └── SKILL.md            # Execute skill definition
├── agents/
│   ├── task-runner.md # Single-task executor (fresh per task)
│   ├── tester.md     # Test writing (TDD red phase)
│   ├── coder.md      # Implementation + artifacts
│   ├── analyzer.md   # Static analysis + fix instructions
│   ├── refactorer.md # Code cleanup
│   └── session-summarizer.md   # Context compression
├── references/                 # Progressive disclosure docs (not under agents/, so they aren't auto-registered as agents)
│   ├── test-frameworks.md
│   ├── artifact-triggers.md
│   ├── analysis-parsing.md
│   └── failure-categories.md
├── skills/execute/scripts/
│   ├── validate-autocode.sh   # Prerequisite validation (execute skill)
│   └── build-task-queue.sh    # Parse TODO.md into task queue (execute skill)
├── scripts/
│   ├── setup-artifacts.sh      # Create artifact directories
│   ├── update-task-status.sh   # Mark tasks complete in TODO.md
│   ├── check-context.sh        # Context limit detection
│   ├── read-handoff.sh         # Handoff reader utility
│   ├── find-active-spec.sh     # Locate active spec directory
│   ├── log-usage.sh            # Log command/agent usage
│   ├── log-failure.sh          # Log failure patterns
│   └── read-history.sh         # Read past usage/failures
├── hooks/
│   ├── hooks.json              # Hook definitions
│   ├── load-context.sh         # PreToolUse context loader (Task, rewrites prompt via updatedInput)
│   ├── log-skill-usage.sh      # PreToolUse agent spawn logger (Task)
│   ├── check-edit.sh           # PostToolUse per-file static analysis (Write|Edit|MultiEdit)
│   ├── on-agent-complete.sh    # SubagentStop handler (tag parse, artifact audit, context check)
│   └── judge-artifacts.mjs     # Optional read-only SDK artifact judge (off by default)
└── templates/
    ├── autocode.yml           # Config template for user projects
    └── artifacts/
        └── handoff/
            └── handoff.md      # Handoff template
```

### User Project Structure

```
.claude/
├── autocode.yml              # Configuration (optional, copy from template)
└── artifacts/                 # Curated/promoted artifacts (user-managed)
    └── ...

.specs/
└── <identifier>/
    ├── REQUIREMENT.md
    ├── SPEC.md
    ├── RESEARCH.md
    ├── PLAN.md
    ├── TODO.md            # Updated by autocode
    └── artifacts/         # Generated during loop
        ├── justifications/
        ├── decisions/
        ├── assumptions/
        ├── risks/
        ├── review_hints/
        ├── debt/
        └── handoff/
            └── handoff.md
```

## Output

The skill provides:
- Progress updates as tasks complete
- Summary of artifacts generated
- Final status with completed task count
- Any issues requiring human attention

## Next Steps

After autocode completes:

1. Review generated artifacts in `.specs/<identifier>/artifacts/`
2. Check for any flagged review hints
3. Validate assumptions documented
4. Proceed to Review stage (human checkpoint)
5. Optionally promote valuable artifacts to `.claude/artifacts/` for long-term reference
