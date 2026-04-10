---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Read
description: Use when the user wants to commit staged or unstaged changes with a conventional commit message (feat/fix/docs/refactor/etc). Stages all changes if nothing is staged.
---

## Context

- Git status: !`git status`
- Changes to commit: !`git diff HEAD`
- Recent commits: !`git log --oneline -5`

## Task

Create a commit for the above changes.

### Step 1: Read the conventional commits reference

Read the reference at `$AUTOCODE_PLUGIN_ROOT/agents/references/conventional-commits.md` for commit message format rules.

### Step 2: Stage changes

Check if anything is already staged: `git diff --cached --quiet`
- If the command **fails** (exit code 1): something is already staged — skip `git add` and commit only what's staged
- If the command **succeeds** (exit code 0): nothing is staged — run `git add -A` to stage all changes

### Step 3: Create the commit

Write a conventional commit message following the reference. The body is required — it provides long-term context.

Use a heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<body explaining what changed and why>
EOF
)"
```

Do not ask for approval. Execute the commit immediately.

You have the capability to call multiple tools in a single response. You MUST do all of the above in a single message. Do not use any other tools or do anything else. Do not send any other text or messages besides these tool calls.
