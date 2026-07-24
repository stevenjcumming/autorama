---
name: sync-pr
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git branch:*), Bash(git checkout:*), Bash(git switch:*), Bash(git push:*), Bash(git fetch:*), Bash(git remote show:*), Bash(gh repo view:*), Bash(gh pr view:*), Bash(gh pr create:*), Bash(gh pr edit:*), Read
description: Use when the user wants to create a new GitHub PR or update an existing PR's description for the current branch. Pushes the branch and generates a description from commits and diff.
model: sonnet # light generation (a PR description) with a human reading the output; see docs/MODEL_SELECTION.md
---

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status`
- Default branch: !`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`

## Template

Resolve the PR description template in this order:

1. Check `.claude/autocode.yml` for `pr_template_path` (optional config; most projects will not have this key set). If present, use that path (relative to the project root) as the template
2. `.claude/templates/pr_description.md` in the project, if it exists
3. The shipped default: `$AUTOCODE_PLUGIN_ROOT/templates/pr_description.md`

Read the first one that exists and use it as the description format.

## Task

Sync the pull request for the current branch (create if it doesn't exist, update if it does):

1. Resolve and read the PR description template per the Template section above
2. Use the default branch from the Context section above as the base branch for all comparisons
3. Fetch the default branch from origin so `origin/<default-branch>` is up to date before computing any commit ranges: `git fetch origin <default-branch>`
4. If on the default branch, create a new feature branch first based on the changes
5. Check if a PR already exists for this branch using `gh pr view`

### If no PR exists (create flow):

6. Push the current branch to origin with `git push -u origin HEAD`
7. Get commits (`git log origin/<default-branch>..HEAD --oneline`) and diff stats (`git diff origin/<default-branch>...HEAD --stat`) for the PR description — always compare against `origin/<default-branch>`, never the bare local branch name, since local main can lag origin
8. Analyze the commits and changes to generate a PR description following the template. If a checklist review report exists (`.specs/*/artifacts/CODE_REVIEW.md` or `.claude/CODE_REVIEW.md`), append a one-line note to the description: `> Checklist code review already ran via /autocode:code-review (see {path}); CI/human reviewers can focus on changes since that report.`
9. Create the PR using `gh pr create --base <default-branch>`

### If PR exists (update flow):

The goal is to **preserve the existing PR description** and only incorporate information from new unpushed commits. Do NOT rewrite or regenerate the entire description.

5. Get the existing PR description using `gh pr view --json body -q .body`
6. Determine which commits are not yet on the remote: `git log origin/<branch>..HEAD --oneline`
7. If there are no unpushed commits, just report that the PR is up to date — do not edit the description
8. If there are unpushed commits:
   a. Get the diff stats for the new commits: `git diff origin/<branch>..HEAD --stat` (run this before pushing, while origin/<branch> still lags HEAD)
   b. Push the current branch with `git push -u origin HEAD`
   c. Generate a short summary of only the new changes based on the new commits and their diffs
   d. Append the new summary to the **end of the existing `## Summary` section** (before the next `##` heading). If there is no `## Summary` section, append it to the end of the existing body
   e. Update the PR using `gh pr edit --body "..."` with the merged description

**Important**: Never remove or rewrite content that was already in the PR description (e.g., issue links, manual notes, custom sections).

### General

Use a HEREDOC to pass the body to gh pr create/edit.

You have the capability to call multiple tools in a single response; batch independent calls together where possible. The flow is conditional, so use as many messages as the branching requires, but stay focused: no tools beyond those listed above, and no commentary other than the final report of what was created or updated.
