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

Read the reference at `$AUTOCODE_PLUGIN_ROOT/references/conventional-commits.md` for commit message format rules.

The Context section shows only the diff stat. If the stat alone is not enough to write an accurate message, run `git diff HEAD -- <path>` for the specific files you need to inspect.

### Step 2: Stage and commit

First, decide how to stage. If something is already staged, commit only what's staged — skip straight to the commit command below with no `git add`.

If nothing is staged, before running `git add -A`, review the git status output already shown in the Context section for risky files that look unrelated to the change being committed:
- `.env`, `.env.*`
- `*.pem`, `*.key`
- anything containing `credentials`
- unexpectedly large files
- any other file that clearly doesn't belong with the rest of the diff

- If none of the status output matches these patterns, stage everything: `git add -A`
- If any matches are found, do NOT run `git add -A`. Instead stage only the specific safe files/paths individually (e.g. `git add path/to/file1 path/to/file2`), and explicitly tell the user which file(s) you excluded and why before or alongside the commit report.

Then commit in a single command using a heredoc for the message:

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <description>

<body explaining what changed and why>
EOF
)"
```

Write a conventional commit message following the reference. The body is required; it provides long-term context. Use the heredoc to preserve formatting.

Do not ask for approval to commit. Execute the commit immediately once staging is decided — the only checkpoint is the exclusion-and-explanation step above for risky untracked files, not a full approval prompt.

You have the capability to call multiple tools in a single response. Batch the Read and the staging/commit commands together where the staging decision is unambiguous (no risky files found). Do not use any other tools beyond targeted `git diff` reads, and do not send any other text besides these tool calls — except when files were excluded from staging, in which case briefly name the excluded files and why, or when there is nothing to commit, in which case report that instead.
