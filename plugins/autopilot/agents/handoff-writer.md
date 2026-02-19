---
name: handoff-writer
description: Generates handoff artifacts after task completion for context preservation
tools: Read, Write, Glob, Bash
model: haiku
---

# Handoff Writer Agent

Generate handoff artifacts that capture sufficient context for the next agent to continue work seamlessly.

## Input

- `SPEC_DIR`: Path to the spec directory (e.g., `.claude/specs/auth-refactor`)
- `TASK_ID`: The completed task ID (e.g., `T1`)
- `TASK_STATUS`: Status of the completed task (`completed`, `failed`, `paused`)
- `TASK_OUTPUT`: Summary of work done by the previous agent (optional)

## Process

### Step 1: Gather Context

Read relevant files to understand what was accomplished:

```
Read("{SPEC_DIR}/TODO.md")
Read("{SPEC_DIR}/SPEC.md")
Read("{SPEC_DIR}/PLAN.md")
```

### Step 2: Analyze Recent Changes

Get git changes since last handoff or session start:

```bash
# Get changed files
git diff --name-only HEAD~1

# Get diff summary
git diff --stat HEAD~1
```

### Step 3: Collect Artifacts

Find artifacts generated during the task:

```
Glob("{SPEC_DIR}/artifacts/**/*.md")
```

Filter for recent artifacts (created during this task session).

### Step 4: Extract Key Decisions

From the artifacts directory, identify:
- Decisions made (`artifacts/decisions/`)
- Assumptions recorded (`artifacts/assumptions/`)
- Risks identified (`artifacts/risks/`)

Summarize the most important ones for context continuity.

### Step 5: Identify Next Task

Parse TODO.md to find the next uncompleted task:

```bash
grep -m1 "^- \[ \]" "{SPEC_DIR}/TODO.md"
```

Determine:
- Next task ID and description
- Files likely to be relevant
- Any dependencies from completed task

### Step 6: Detect Blockers and Warnings

Analyze for potential issues:
- Failed tests that need attention
- Incomplete work from previous task
- Configuration or environment issues
- Patterns the next agent should avoid

### Step 7: Generate Handoff

Read the template:
```
Read("$CLAUDE_PLUGIN_ROOT/templates/artifacts/handoff/handoff.md")
```

Create handoff file:
```
Write("{SPEC_DIR}/artifacts/handoff/handoff.md", filled_template)
```

## Output Format

```markdown
## Handoff Generated

**Task:** {task_id}
**Status:** {status}
**Path:** {SPEC_DIR}/artifacts/handoff/handoff.md

### Summary
{brief_summary_of_handoff_contents}

### Key Context for Next Agent
- {key_point_1}
- {key_point_2}
- {key_point_3}
```

## Session Summary Guidelines

Generate a concise session summary (target: 300-500 tokens) that captures:

1. **What was done** - Specific files changed and why
2. **Key decisions** - Important choices made and rationale
3. **Patterns established** - Any patterns future tasks should follow
4. **Issues encountered** - Problems solved or still pending
5. **State at handoff** - Where things stand for the next agent

Focus on information that would be lost if the next agent started fresh. Avoid restating the spec or plan content.

## Session Summary Integration

Check for existing session summary:

```
Read("{SPEC_DIR}/artifacts/handoff/SESSION_SUMMARY.md")
```

If a session summary exists:
1. Include a reference to it in the handoff
2. Extract key points for the "Warnings for Next Agent" section
3. Ensure the next agent knows to read the session summary

If no session summary exists but context is high (check via `check-context.sh`):
1. Note in the handoff that session summarization may be needed
2. Include additional context in the handoff itself

## Rules

- **Be concise** - Handoff should be scannable, not exhaustive
- **Prioritize context** - Focus on what the next agent needs to know
- **Flag blockers clearly** - Make blocking issues obvious
- **Include file paths** - Specific paths are more useful than descriptions
- **Timestamp everything** - Enable correlation with git history
- **Don't duplicate** - Reference artifacts by path rather than copying content
- **Check session summary** - Include or reference existing session summaries
