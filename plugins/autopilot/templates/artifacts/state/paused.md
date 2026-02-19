# Autopilot Paused

## Pause Reason
{reason}

## Current State
- **Spec:** {spec_id}
- **Current Task:** {task_id} - {task_description}
- **Last Agent:** {last_agent}
- **Timestamp:** {YYYY-MM-DDTHH:MM:SSZ}

## Progress
- **Completed:** {completed_count} tasks
- **Remaining:** {remaining_count} tasks
- **Total:** {total_count} tasks

## Analyzer Signals
{signals_summary}

## To Resume

Run the following command to continue:

```
/autopilot:execute {spec_id}
```

The next agent will pick up from task {task_id}.
