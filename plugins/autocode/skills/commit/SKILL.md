---
name: commit
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git add:*), Bash(git commit:*), Read
description: Use when the user wants to commit staged or unstaged changes with a conventional commit message (feat/fix/docs/refactor/etc). Stages all changes if nothing is staged.
---

## Context

- Git status: !`git status`
- Changes summary: !`git diff HEAD --stat`
- Recent commits: !`git log --oneline -5`

## Task

Create a commit for the above changes.

If the git status shows a clean working tree with nothing staged (nothing to commit), tell the user there is nothing to commit and stop. Do not run any other commands.

### Step 1: Read the conventional commits reference

Read the reference at `${CLAUDE_PLUGIN_ROOT}/agents/references/conventional-commits.md` for commit message format rules.

The Context section shows only the diff stat. If the stat alone is not enough to write an accurate message, run `git diff HEAD -- <path>` for the specific files you need to inspect.

### Step 2: Stage and commit

Stage and commit in one compound command. The first part stages everything only when nothing is already staged (if something is staged, commit only what's staged):

```bash
git diff --cached --quiet && git add -A; git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<body explaining what changed and why>
EOF
)"
```

Write a conventional commit message following the reference. The body is required; it provides long-term context. Use the heredoc to preserve formatting.

Do not ask for approval. Execute the commit immediately.

You have the capability to call multiple tools in a single response. Do the Read and the compound stage-and-commit command in a single message. Do not use any other tools beyond targeted `git diff` reads, and do not send any other text besides these tool calls (unless there is nothing to commit, in which case report that instead).
