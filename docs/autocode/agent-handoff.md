# Agent Handoff

The autocode plugin uses a handoff system to preserve context between sequential task executions. Each agent starts fresh with no memory of previous work, so the handoff pipeline ensures continuity by writing structured artifacts that the next agent loads at initialization.

## Overview

```
Task N completes
    ↓
task-runner → Writes handoff.md directly (Step 8)
    ↓
on-agent-complete.sh (SubagentStop) → Checks context limits
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

The template lives at `plugins/autocode/templates/artifacts/handoff/handoff.md`.

### Generation

`handoff.md` is written directly by the `task-runner` agent as its final step (Step 8) before completing. The task-runner has full context of the work it just performed, so it writes the handoff inline without requiring a separate agent.

## 2. Hook Pipeline

Two hooks coordinate the handoff lifecycle. They are defined in `plugins/autocode/hooks/hooks.json` and execute automatically during the autocode loop.

### `load-context.sh` (PreToolUse)

Fires before each `autocode-*` Task agent is spawned. Loads context from the previous task into the new agent's prompt.

**What it loads:**

| Context Block | Source | Purpose |
|---------------|--------|---------|
| `<handoff-context>` | `handoff.md` | Previous task summary, decisions, warnings |
| `<current-task>` | `TODO.md` | Next uncompleted task with subtasks and notes |
| `<progress-summary>` | `TODO.md` | Completed/remaining task counts |

The hook delegates to `read-handoff.sh` when available, falling back to manual file reads if the script is missing.

### `on-agent-complete.sh` (SubagentStop)

Fires when a subagent finishes. Checks context limits and signals completion.

1. **Check context limits** -- calls `check-context.sh` and emits `<context-warning>` or `<context-critical>` tags

**Output tags:**

| Tag | Meaning |
|-----|---------|
| `<context-warning>` | Context usage is high |
| `<context-critical>` | Context usage is critical, summarization needed |
| `<agent-completed>` | Agent finished (always emitted) |

Use `/autocode:commit` to commit changes after tasks complete.

## 3. Session Summarization

When context usage hits critical levels, the `session-summarizer` agent compresses the full session into a compact summary.

### Trigger

The session summarizer is triggered when:
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

## 4. `read-handoff.sh` Utility

A standalone script that assembles handoff context for any consumer. Used by `load-context.sh` but can be called directly.

**Usage:** `read-handoff.sh <spec_dir>`

**Behavior:**
1. Reads `handoff.md` from the spec's artifact directory
2. Parses `TODO.md` for the first uncompleted task with its subtasks
3. Outputs all context in XML-tagged blocks for agent consumption

## Configuration

The handoff system is configured via `.claude/autocode.yml`:

Feature sections are active when present. To disable a feature, remove the section entirely.

## Related Documentation

- [Orchestration Flow](orchestration_flow.md)
- [Evaluation Pipeline](evaluation_pipeline.md)
- [Autocode Workflow](workflow-stages/04_autocode.md)
