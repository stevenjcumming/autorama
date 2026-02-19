---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
description: Create a commit with a detailed conventional commit message
---

## Context

- Git status: !`git status`
- Changes to commit: !`git diff HEAD`
- Recent commits: !`git log --oneline -5`

## Task

Create a commit for the above changes:

1. Stage all changes with `git add -A`
2. Create a commit with a detailed message following this format:

```
<type>(<scope>): <subject>

<detailed body explaining what changed and why>
- Use bullet points for multiple changes
- Explain the reasoning, not just the what
```

Types: feat, fix, docs, style, refactor, perf, test, chore

Do not ask for approval. Execute the commit immediately.

You have the capability to call multiple tools in a single response. You MUST do all of the above in a single message. Do not use any other tools or do anything else. Do not send any other text or messages besides these tool calls.
