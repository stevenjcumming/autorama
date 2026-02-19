---
allowed-tools: Bash(git status:*), Bash(git diff:*), Bash(git log:*), Bash(git push:*), Bash(gh pr view:*), Bash(gh pr create:*), Bash(gh pr edit:*), Read
description: Create or update PR description based on current changes
---

## Arguments

$ARGUMENTS

## Context

- Current branch: !`git branch --show-current`
- Git status: !`git status`
- Commits on this branch: !`git log main..HEAD --oneline`
- Changes from main: !`git diff main...HEAD --stat`

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
2. If on main/master branch, create a new feature branch first based on the changes
3. Push the current branch to origin with `git push -u origin HEAD`
4. Check if a PR already exists for this branch using `gh pr view`
5. Analyze the commits and changes to generate a PR description following the template
6. If no PR exists: create one using `gh pr create`
7. If PR exists: update it using `gh pr edit --body "..."` (use PR number from arguments if provided)

Use a HEREDOC to pass the body to gh pr create/edit.

You have the capability to call multiple tools in a single response. You MUST do all of the above in a single message. Do not use any other tools or do anything else. Do not send any other text or messages besides these tool calls.
