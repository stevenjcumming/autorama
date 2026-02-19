# Agent Handoff

The autopilot plugin uses a handoff system to preserve context between sequential task executions. Each agent starts fresh with no memory of previous work, so the handoff pipeline ensures continuity by writing structured artifacts that the next agent loads at initialization.

## Overview

```
Task N completes
    ↓
save-state.sh (PostToolUse) → Writes current.json with task status
    ↓
on-agent-complete.sh (SubagentStop) → Auto-commits, generates handoff.md
    ↓
Loop controller checks context limits
    ↓  (if critical)
session-summarizer → Writes SESSION_SUMMARY.md
    ↓
Task N+1 spawned
    ↓
load-context.sh (PreToolUse) → Loads handoff.md via read-handoff.sh
    ↓
Task runner initializes with previous context
```

## 1. Handoff Artifact

The central artifact is `handoff.md`, written to `{SPEC_DIR}/artifacts/handoff/handoff.md` after each task completes. It contains everything the next agent needs to continue work without re-reading the full codebase.

### Sections

| Section | Content |
|---------|---------|
| **Completed Task** | Task ID, description, status, timestamp |
| **Session Summary** | 300-500 token summary of what was accomplished |
| **Files Modified** | Table of changed files with change types |
| **Key Decisions** | Decisions made with rationale and alternatives considered |
| **Next Task Context** | Next task ID, relevant files, dependencies from completed work |
| **Blockers** | Issues preventing progress, with severity levels |
| **Warnings** | Important context the next agent should know |
| **Artifacts Generated** | List of artifacts created, by type and path |

The template lives at `plugins/autopilot/templates/artifacts/handoff/handoff.md`.

### Generation

Two paths can produce `handoff.md`:

1. **Hook-generated** -- `on-agent-complete.sh` creates a lightweight handoff inline using git diff and TODO.md parsing. This is the default path during the autopilot loop.
2. **Agent-generated** -- The `handoff-writer` agent produces a richer handoff by analyzing artifacts and decisions. This is used when deeper context preservation is needed.

Both paths write to the same location, so the most recent handoff is always available at the canonical path.

## 2. Hook Pipeline

Three hooks coordinate the handoff lifecycle. They are defined in `plugins/autopilot/hooks/hooks.json` and execute automatically during the autopilot loop.

### `load-context.sh` (PreToolUse)

Fires before each `autopilot-*` Task agent is spawned. Loads context from the previous task into the new agent's prompt.

**What it loads:**

| Context Block | Source | Purpose |
|---------------|--------|---------|
| `<handoff-context>` | `handoff.md` | Previous task summary, decisions, warnings |
| `<current-task>` | `TODO.md` | Next uncompleted task with subtasks and notes |
| `<progress-summary>` | `TODO.md` | Completed/remaining task counts |

The hook delegates to `read-handoff.sh` when available, falling back to manual file reads if the script is missing.

### `save-state.sh` (PostToolUse)

Fires after each `autopilot-*` Task agent completes. Writes lightweight state tracking to `{SPEC_DIR}/artifacts/state/current.json`.

**State tracked:**

```json
{
  "last_agent": "autopilot-task-runner",
  "last_task": "T1",
  "task_completed": true,
  "timestamp": "2025-01-15T10:30:00Z",
  "spec_dir": ".claude/specs/my-feature"
}
```

This file is a quick-reference for the loop controller and other hooks to determine what just happened without parsing agent output.

### `on-agent-complete.sh` (SubagentStop)

Fires when an autopilot agent finishes. Handles the heavier post-task work:

1. **Auto-commit** (if `auto_commit` section present in config) -- stages all changes, creates a commit with the task summary as the message
2. **Generate handoff.md** -- builds the handoff artifact from git diff and TODO.md
3. **Check context limits** -- calls `check-context.sh` and emits `<context-warning>` or `<context-critical>` tags

**Output tags:**

| Tag | Meaning |
|-----|---------|
| `<auto-commit>` | Commit was created |
| `<handoff-generated>` | handoff.md was written |
| `<context-warning>` | Context usage is high |
| `<context-critical>` | Context usage is critical, summarization needed |
| `<agent-completed>` | Agent finished (always emitted) |

## 3. Session Summarization

When context usage hits critical levels, the `session-summarizer` agent compresses the full session into a compact summary.

### Trigger

The loop controller spawns the session summarizer when:
- `on-agent-complete.sh` emits `<context-critical>`
- `check-context.sh` reports context above the configured threshold
- Manual invocation at session end

### Output

The summarizer writes `{SPEC_DIR}/artifacts/handoff/SESSION_SUMMARY.md`, targeting 500-1000 tokens (2000-4000 characters). It extracts:

- Completed work and current progress
- Key decisions and their rationale
- Patterns established in the codebase
- Issues encountered and resolutions
- Current state for the next session

Existing summaries are archived with timestamps before being overwritten.

### Compression Priorities

| Priority | Content |
|----------|---------|
| High | Actionable context, blockers, warnings |
| Medium | Decisions made, patterns established |
| Low | Routine completions, standard approaches |
| Omit | Redundant information, verbose descriptions |

## 4. Pause State

When the autopilot pauses (signal evaluation, context limits, or manual pause), a `paused.md` artifact preserves the exact state for resumption.

**Written to:** `{SPEC_DIR}/artifacts/state/paused.md`

### Contents

| Section | Purpose |
|---------|---------|
| **Pause Reason** | Why execution stopped (signal threshold, context limit, manual) |
| **Current State** | Spec, task, attempt count, phase, timestamp |
| **Progress** | Completed and remaining task lists |
| **Analyzer Signals** | Recent signals from static analysis |
| **Recent Errors** | Errors encountered during execution |
| **Files Modified** | Uncommitted changes at pause time |
| **Context for Resume** | What was being attempted, what went wrong, suggested next steps |
| **Manual Intervention Notes** | Space for human reviewer notes before resuming |

Resuming with `/autopilot:execute <spec_id>` loads the pause state and continues from where execution stopped.

## 5. `read-handoff.sh` Utility

A standalone script that assembles handoff context for any consumer. Used by `load-context.sh` but can be called directly.

**Usage:** `read-handoff.sh <spec_dir>`

**Behavior:**
1. Reads `handoff.md` from the spec's artifact directory
2. Parses `TODO.md` for the first uncompleted task with its subtasks
3. Outputs all context in XML-tagged blocks for agent consumption

## Configuration

The handoff system is configured via `.claude/autopilot.yml`:

| Key | Default | Effect |
|-----|---------|--------|
| `auto_commit.message_template` | conventional | Commit message format |

Feature sections are active when present. To disable a feature, remove the section entirely.

## Related Documentation

- [Orchestration Flow](orchestration_flow.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Autopilot Workflow](workflows/04_autopilot.md)
