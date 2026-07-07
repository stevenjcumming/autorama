---
task_id: {task_id}
status: {completed|failed}
timestamp: {YYYY-MM-DDTHH:MM:SSZ}
spec_id: {spec_id}
agent: {agent_name}
---

# Task Handoff

## Facts (never summarize, never paraphrase; copy exactly)

<!-- Identifiers survive summarization only if held verbatim in this block.
     Fill from real values; write "unknown" rather than guessing. -->

- Spec ID: {spec_id}
- Current task ID: {task_id}
- Next task ID: {next_task_id}
- Test command: `{test_command}`
- Test file paths: {test_file_paths}
- Files changed: {files_changed}
- Failure categories so far: {failure_categories_or_none}

## Completed Task

- **ID:** {task_id}
- **Description:** {task_description}
- **Status:** {status}
- **Timestamp:** {timestamp}

## Session Summary

<!-- Concise summary of what was accomplished in this session -->

{session_summary}

## Files Modified

| File | Change Type | Description |
|------|-------------|-------------|
| {file_path} | {added\|modified\|deleted} | {brief_description} |

## Key Decisions Made

<!-- Major decisions and their rationale -->

| Decision | Rationale | Alternatives Considered |
|----------|-----------|------------------------|
| {decision} | {why} | {alternatives} |

## Next Task Context

- **Next Task ID:** {next_task_id}
- **Next Task Description:** {next_task_description}
- **Relevant Files:** {relevant_files}
- **Dependencies:** {any_dependencies_from_completed_task}

## Blockers

<!-- Any issues preventing progress -->

| Blocker | Severity | Details |
|---------|----------|---------|
| {blocker} | {low\|medium\|high} | {details} |

## Warnings for Next Agent

<!-- Important context the next agent needs to know -->

- {warning_1}
- {warning_2}

## Artifacts Generated

<!-- List of artifacts created during this task -->

| Type | Path | Summary |
|------|------|---------|
| {justification\|decision\|risk\|etc} | {path} | {brief_summary} |
