---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git push:*), Bash(git remote show:*), Bash(gh repo view:*), Bash(gh pr view:*), Bash(gh pr create:*), Bash(gh pr edit:*), Read
description: Use when the user wants to create a new GitHub PR or update an existing PR's description for the current branch. Pushes the branch and generates a description from commits and diff.
---

## Arguments

$ARGUMENTS

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status`
- Default branch: !`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`

## Template

Use the PR description template from `.claude/templates/pr_description.md` if it exists. If not, use this default format:

```
## Summary
<Brief description of what this PR does>

## Related issue(s)
<Link to related issues, e.g., Fixes #123, Closes #456>

## Testing
<How to test these changes>

## Acceptance criteria
<Checklist of requirements that must be met>
```

## Task

Sync the pull request for the current branch (create if it doesn't exist, update if it does):

1. Check if `.claude/templates/pr_description.md` exists and read it for the template format
2. Use the default branch from the Context section above as the base branch for all comparisons
3. If on the default branch, create a new feature branch first based on the changes
4. Check if a PR already exists for this branch using `gh pr view`

### If no PR exists (create flow):

5. Push the current branch to origin with `git push -u origin HEAD`
6. Get commits (`git log <default-branch>..HEAD --oneline`) and diff stats (`git diff <default-branch>...HEAD --stat`) for the PR description
7. Analyze the commits and changes to generate a PR description following the template
8. Create the PR using `gh pr create --base <default-branch>`

### If PR exists (update flow):

The goal is to **preserve the existing PR description** and only incorporate information from new unpushed commits. Do NOT rewrite or regenerate the entire description.

5. Get the existing PR description using `gh pr view --json body -q .body`
6. Determine which commits are not yet on the remote: `git log origin/<branch>..HEAD --oneline`
7. If there are no unpushed commits, just report that the PR is up to date — do not edit the description
8. If there are unpushed commits:
   a. Push the current branch with `git push -u origin HEAD`
   b. Get the diff stats for the new commits: `git diff origin/<branch>..HEAD --stat` (run this before pushing)
   c. Generate a short summary of only the new changes based on the new commits and their diffs
   d. Append the new summary to the **end of the existing `## Summary` section** (before the next `##` heading). If there is no `## Summary` section, append it to the end of the existing body
   e. Update the PR using `gh pr edit --body "..."` with the merged description

**Important**: Never remove or rewrite content that was already in the PR description (e.g., issue links, manual notes, custom sections).

### General

Use a HEREDOC to pass the body to gh pr create/edit.

You have the capability to call multiple tools in a single response. You MUST do all of the above in a single message. Do not use any other tools or do anything else. Do not send any other text or messages besides these tool calls.
