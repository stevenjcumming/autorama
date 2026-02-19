# Workflow: Autopilot

## Purpose

Execute the Test -> Code -> Analysis -> Refactor loop autonomously for a spec, generating artifacts until all tasks are complete.

## Architecture

Autopilot uses an **Agent Harness** architecture where background agents complete individual tasks with clean handoffs between them:

```
/autopilot:execute
    └── Loop Controller (hook-based)
            │
            ├── PreToolUse Hook: Load context
            │   ├── Read TODO.md for next task
            │   └── Read handoff/handoff.md
            │
            ├── Task Agent (background, one task)
            │   ├── autopilot-tester
            │   ├── autopilot-coder
            │   ├── autopilot-analyzer
            │   └── autopilot-refactorer
            │
            └── PostToolUse Hook: Save state
                ├── Update TODO.md
                ├── Write handoff/handoff.md
                ├── Generate session summary
                └── Git commit

            ... new agent spawns for next task ...
```

**Key benefits:**
- **Fresh context per task** - Each task agent starts with clean context
- **Clean handoffs** - Handoff artifacts preserve decisions
- **Automatic commits** - Git history tracks each task completion
- **Pause signals** - Analyzer can trigger pause for human review
- **Background execution** - Task agents run in background for monitoring

## Command

```
/autopilot:execute <identifier> [T<n>|P<n>]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `identifier` | Yes | Spec identifier (e.g., `auth-refactor`) |
| `filter` | No | Task ID (e.g., `T3`) or phase ID (e.g., `P1`) to limit scope |

## Examples

```bash
# Run all tasks
/autopilot:execute auth-refactor

# Run only task T3
/autopilot:execute auth-refactor T3

# Run all tasks in phase P1
/autopilot:execute auth-refactor P1
```

## Configuration

Autopilot can be customized via `.claude/autopilot.yml`:

```yaml
# Single-task mode: exit after each task for fresh context (default: true)
single_task_mode: true   # Exit after each task for clean handoffs

# Override default agents
agents:
  tester: autopilot-tester       # Or your custom tester
  coder: autopilot-coder         # Or your custom coder
  refactorer: autopilot-refactorer

# Skills for dynamic selection (see workflows/05_skills.md)
coding_skills:
  - service-object-skill         # .claude/skills/service-object-skill/SKILL.md
  - controller-skill
  - react-component-skill

testing_skills: []
refactoring_skills: []

# Auto-commit configuration
auto_commit:
  enabled: true                    # Commit after each task (default: true)
  message_template: "feat({spec_id}): complete {task_id} - {task_summary}"

# Pause signal configuration
pause_signals:
  enabled: true                    # Pause on analyzer signals (default: true)
  triggers:
    - signal: "repeated_violation"
      threshold: 3                 # Same rule violated 3+ times
    - signal: "high_severity"
      types: ["security", "breaking_change"]
    - signal: "human_review_needed"

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

When `static_analysis.enabled: true` (default), autopilot runs configured static analysis tools after tests pass:

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

If a configured command is not installed, autopilot logs a warning and continues. This allows the same config to work across different environments.

### Single-Task Mode

When `single_task_mode: true`, autopilot:
1. Completes **one task** from TODO.md
2. Updates TODO.md with completion status
3. Exits with a continuation prompt

This clears the context window between tasks, which is useful for:
- Large task lists that would exhaust context
- Complex tasks that generate substantial artifacts
- Maintaining fresh context for each implementation

Re-run `/autopilot:execute <identifier>` to continue with the next task. TODO.md state persists, so autopilot resumes from where it left off.

The coder agent dynamically selects skills based on task context. See [Skills documentation](./05_skills.md) for details.

### Handoff Artifacts

Autopilot generates handoff artifacts after each task:

1. **Session summary** - Compressed context of what was done
2. **Files modified** - List of changes made
3. **Key decisions** - Important choices documented
4. **Next task context** - Setup for the next agent

Handoff artifacts are stored at `.claude/specs/<identifier>/artifacts/handoff/handoff.md` and provide continuity between task agents.

### Auto-Commit

When `auto_commit.enabled: true` (default), autopilot commits changes after each task completion:

1. Stages all modified files
2. Creates commit with conventional message format
3. Includes task ID and summary in commit message

**Configuration:**

```yaml
auto_commit:
  enabled: true
  message_template: "feat({spec_id}): complete {task_id} - {task_summary}"
```

Example commit message:
```
feat(auth-refactor): complete T3 - Add password validation

Co-Authored-By: Claude <noreply@anthropic.com>
```

To disable auto-commits and commit manually: `auto_commit.enabled: false`

### Pause Signals

When `pause_signals.enabled: true` (default), autopilot pauses automatically on certain analyzer signals:

| Signal | Trigger | Action |
|--------|---------|--------|
| `repeated_violation` | Same rule violated 3+ times | Pause for human review |
| `high_severity` | Security or breaking change | Pause immediately |
| `human_review_needed` | Explicit review flag | Pause for approval |

**Configuration:**

```yaml
pause_signals:
  enabled: true
  triggers:
    - signal: "repeated_violation"
      threshold: 3
    - signal: "high_severity"
      types: ["security", "breaking_change"]
    - signal: "human_review_needed"
```

When paused, autopilot saves state to `artifacts/state/paused.md` with:
- Current task and attempt count
- Recent analyzer signals
- Resume instructions

To resume: re-run `/autopilot:execute <identifier>` - it picks up from the paused task.

### Manual Pause

You can manually pause autopilot at any time using:

```
/autopilot:pause-autopilot <identifier>
```

This immediately:
1. Saves current state to `artifacts/state/paused.md`
2. Records the current task and attempt count
3. Outputs resume instructions

Use manual pause when you want to:
- Review progress before continuing
- Make manual changes to the spec or tasks
- Intervene in the automation loop

### Justification Configuration

Customize when and how justifications are required for file modifications:

```yaml
justification:
  enabled: true  # Set to false to disable all justifications

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
    enabled: true  # false = skip unmatched files
    title: "File Modification"
    questions:
      - "What is the purpose of this change?"
```

**Pattern Syntax:**
- Simple patterns (no `/`) match basename only: `*.test.ts` matches `foo.test.ts` anywhere
- Path patterns match full paths: `*/api/*` matches `src/api/users.ts`

**Optional dependency:** Install `yq` for config customization. Without `yq`, built-in defaults are used.

## Prerequisites

- Spec folder must exist at `.claude/specs/<identifier>/`
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
   - **Write Tests**: Write failing tests from acceptance criteria via `autopilot-tester`
   - **Red**: Run tests via Bash, expect failure (tests define expected behavior)
   - **Code**: Implement changes with artifact generation via `autopilot-coder`
   - **Green**: Run tests via Bash, expect pass (implementation satisfies tests)
   - **Analysis**: Run static analysis tools, fix blocking issues
   - **Refactor**: Clean up code if needed
4. Updates TODO.md as tasks complete
5. Continues until all tasks done or exit condition met

## Agent Pipeline

```
/autopilot:execute <identifier>
├── Validates prerequisites (TODO.md, PLAN.md, SPEC.md)
├── loop-controller (orchestrator)
│   ├── Reads TODO.md for next task
│   ├── Checks for pause signals
│   └── Spawns autopilot-task-runner in background
│       ├── autopilot-tester - Writes tests from acceptance criteria (TDD red phase)
│       ├── autopilot-coder - Implements changes with artifacts
│       ├── autopilot-analyzer - Runs static analysis, reports issues
│       └── autopilot-refactorer - Cleans up code
├── PostToolUse hooks on task completion:
│   ├── handoff-writer - Generates handoff.md
│   ├── session-summarizer - Compresses context
│   └── Auto-commit changes
└── Repeats until all tasks done or pause triggered
```

### Agents

| Agent | Purpose | Output |
|-------|---------|--------|
| `loop-controller` | Orchestrates the agent loop | Spawns task runners, monitors completion |
| `autopilot-task-runner` | Executes single task with full loop | Task completion status |
| `autopilot-tester` | Write tests from acceptance criteria (TDD red phase) | Test files |
| `autopilot-coder` | Implement task with justifications | Code changes, artifacts |
| `autopilot-analyzer` | Run static analysis tools | Issue reports, fix instructions |
| `autopilot-refactorer` | Clean up after implementation | Refactored code |
| `handoff-writer` | Generate handoff artifacts | handoff.md with context |
| `session-summarizer` | Compress session context | Summary for next agent |

## Main Loop Logic

```
tasks = filter_tasks(TODO.md, FILTER)  # Apply T<n> or P<n> filter if provided

while uncompleted_tasks exist in tasks:
    task = get_next_task(tasks)
    analysis_attempts_by_rule = {}  # Per-rule tracking
    refactor_history = []
    MAX_REFACTOR_CYCLES = 3

    # Error category retry limits
    ERROR_RETRY_LIMITS = {
        "setup": 0, "timeout": 1, "runtime": 2,
        "assertion": 3, "syntax": 3, "missing": 1, "unknown": 2
    }

    loop:
        attempt_count++

        # Test Phase
        test_result = run_tests()

        # Code Phase
        if task.not_implemented:
            assess_complexity()  # SMALL/MEDIUM/LARGE
            implement_task(task)
            generate_justifications()
            generate_artifacts_as_needed()

        # Check test results with category-driven retries
        if NOT tests_pass:
            category = test_result.primary_category
            max_for_category = ERROR_RETRY_LIMITS.get(category, 2)
            if attempt_count >= max_for_category:
                output_failure("max_retries_for_{category}")
                exit
            continue  # Retry

        # Analysis Phase (after tests pass) — per-rule tracking
        if static_analysis.enabled:
            analysis_result = run_static_analysis()
            if analysis_result.has_blocking_issues:
                for issue in blocking_issues:
                    key = "{tool}:{rule}"
                    analysis_attempts_by_rule[key] += 1
                    if over_limit: generate_debt_artifact(issue)

                if actionable_issues:
                    fix_with_context(actionable_issues, analysis_attempts_by_rule)
                    continue  # Return to Test

        # Refactor Phase with stuck detection
        refactor_result = refactor_code()
        if refactor_made_changes:
            refactor_history.append(changes_summary)
            if len(refactor_history) >= MAX_REFACTOR_CYCLES:
                if is_oscillating(refactor_history) or is_diminishing(refactor_history):
                    break  # Accept current state
            continue  # Return to Test

        # Exit Condition
        mark_task_complete()
        break

    update_todo_md()
```

## Exit Conditions

| Condition | Action |
|-----------|--------|
| All filtered tasks completed | Exit with success summary |
| Category retry limit exceeded | Output failure, exit task |
| Setup error | Pause immediately (no retries) |
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

### Signal Generation

When stuck is detected, a signal artifact is generated:
- Type: `repetition_refactor_stuck`
- Confidence: high
- Details: files affected, cycle count, pattern type (oscillating/diminishing)

## Error-Driven Retries (v0.11.0)

Test failures are classified by category, and each category has its own retry limit:

| Category | Max Retries | Description |
|----------|-------------|-------------|
| `setup` | 0 | Environment issue — pause immediately |
| `timeout` | 1 | Increase timeout or refactor — 1 retry |
| `runtime` | 2 | May be environmental — 2 retries |
| `assertion` | 3 | Code change likely needed — 3 retries |
| `syntax` | 3 | Immediate fix, high priority — 3 retries |
| `missing` | 1 | Dependency issue — 1 retry |
| `unknown` | 2 | Default fallback |

**Severity hierarchy** (most severe first): `setup` > `syntax` > `timeout` > `runtime` > `assertion` > `missing`

The task-runner classifies each test failure with a `Primary Category` using the most severe category when multiple apply.

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
| Justifications | Flagged file modified | `.claude/specs/<identifier>/artifacts/justifications/` |
| Decisions | Multiple approaches possible | `.claude/specs/<identifier>/artifacts/decisions/` |
| Assumptions | Inferring unstated requirements | `.claude/specs/<identifier>/artifacts/assumptions/` |
| Dependencies | Code interconnections | `.claude/specs/<identifier>/artifacts/dependencies/` |
| Risks | Potential problems identified | `.claude/specs/<identifier>/artifacts/risks/` |
| Review Hints | Human judgment needed | `.claude/specs/<identifier>/artifacts/review_hints/` |
| Technical Debt | Shortcuts taken | `.claude/specs/<identifier>/artifacts/debt/` |

### During Analysis Phase

| Artifact | When | Location |
|----------|------|----------|
| Signals | Clean analysis or repeated violations | `.claude/specs/<identifier>/artifacts/signals/` |

### File Categories Requiring Justification

| Category | Pattern | Prompt |
|----------|---------|--------|
| Spec | `*_spec.rb`, `*_test.*` | Changing assertions? Why? |
| Migration | `db/migrate/*` | New or editing existing? |
| Dependency | `Gemfile`, `package.json` | Why needed? |
| Config | `config/**/*` | Production impact? |
| API | `*_controller.rb`, `api/**` | Breaking change? |
| Security | `*auth*`, `*permission*` | Access implications? |

## Directory Structure

```
.claude/
├── autopilot.yml             # Configuration (optional)
├── commands/
│   ├── autopilot.md           # Command definition
│   └── pause-autopilot.md     # Manual pause command
├── scripts/
│   ├── validate-autopilot.sh  # Prerequisite validation
│   ├── evaluate-signals.sh    # Pause signal evaluation
│   ├── check-context.sh       # Context limit detection
│   └── read-handoff.sh        # Handoff reader utility
├── hooks/
│   ├── hooks.json             # Hook definitions
│   ├── load-context.sh        # PreToolUse context loader
│   ├── save-state.sh          # PostToolUse state saver
│   └── on-agent-complete.sh   # SubagentStop handler
├── agents/
│   ├── autopilot.md           # Main orchestrator
│   ├── loop-controller.md     # Agent loop orchestrator
│   ├── autopilot-task-runner.md # Single-task executor
│   ├── autopilot-tester.md    # Test writing (TDD red phase)
│   ├── autopilot-coder.md     # Implementation + artifacts
│   ├── autopilot-analyzer.md  # Static analysis + fix instructions
│   ├── autopilot-refactorer.md # Code cleanup
│   ├── handoff-writer.md      # Generates handoff artifacts
│   └── session-summarizer.md  # Context compression
├── templates/
│   └── artifacts/
│       ├── handoff/
│       │   └── handoff.md     # Handoff template
│       └── state/
│           └── paused.md      # Pause state template
├── skills/                    # Custom coding patterns (optional)
│   └── <skill-name>/
│       └── SKILL.md
├── artifacts/                  # Curated/promoted artifacts (user-managed)
│   └── ...                    # Artifacts promoted from specs
└── specs/
    └── <identifier>/
        ├── REQUIREMENT.md
        ├── SPEC.md
        ├── RESEARCH.md
        ├── PLAN.md
        ├── TODO.md             # Updated by autopilot
        └── artifacts/          # Generated during loop (gitignored)
            ├── justifications/
            ├── decisions/
            ├── assumptions/
            ├── dependencies/
            ├── risks/
            ├── review_hints/
            ├── debt/
            ├── signals/
            ├── handoff/        # Handoff artifacts
            │   └── handoff.md
            └── state/          # Pause state
                └── paused.md
```

## Output

The command provides:
- Progress updates as tasks complete
- Summary of artifacts generated
- Final status with completed task count
- Any issues requiring human attention

## Next Steps

After autopilot completes:

1. Review generated artifacts in `.claude/specs/<identifier>/artifacts/`
2. Check for any flagged review hints
3. Validate assumptions documented
4. Proceed to Review stage (human checkpoint)
5. Optionally promote valuable artifacts to `.claude/artifacts/` for long-term reference
