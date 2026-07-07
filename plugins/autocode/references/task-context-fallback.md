# Task-Context Fallback

This file is the single definition of the deprecated `<task-context>` fallback used by agents spawned from the task-runner (coder, tester). Do not restate it inline in an agent's instructions; cite this file.

## Deprecated Fallback

If `<task-context>` is not present in the prompt (legacy invocation without the task-runner), fall back to reading `SPEC.md`, `PLAN.md`, and `TODO.md`. This path wastes tokens by loading full files — prefer inline context from the task-runner.
