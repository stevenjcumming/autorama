---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*)
description: Use when the user wants to commit staged or unstaged changes with a conventional commit message (feat/fix/docs/refactor/etc). Stages all changes if nothing is staged.
---

## Context

- Git status: !`git status`
- Changes to commit: !`git diff HEAD`
- Recent commits: !`git log --oneline -5`

## Task

Create a commit for the above changes:

1. Check if anything is already staged: `git diff --cached --quiet`
   - If the command **fails** (exit code 1): something is already staged — skip `git add` and commit only what's staged
   - If the command **succeeds** (exit code 0): nothing is staged — run `git add -A` to stage all changes
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
