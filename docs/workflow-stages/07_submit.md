# Workflow: Submit

## Purpose

Commit code changes and synchronize with GitHub pull requests. The Submit stage finalizes implementation by creating conventional commits and managing PRs for code review.

## Commands

### /autocode:commit

Create a commit with a detailed conventional commit message.

```
/autocode:commit
```

### /autocode:sync-pr

Create or update a GitHub pull request for the current branch.

```
/autocode:sync-pr [pr-number]
```

## Arguments

| Command | Argument | Required | Description |
|---------|----------|----------|-------------|
| `/autocode:commit` | None | - | No arguments required |
| `/autocode:sync-pr` | `pr-number` | No | Existing PR number to update |

## Examples

```bash
# Create a commit for staged changes
/autocode:commit

# Create a new PR for current branch
/autocode:sync-pr

# Update an existing PR
/autocode:sync-pr 123
```

## Prerequisites

- Git repository initialized
- Changes to commit (for `/autocode:commit`)
- GitHub CLI (`gh`) installed and authenticated (for `/autocode:sync-pr`)
- Remote repository configured (for `/autocode:sync-pr`)

## What Each Command Does

### /autocode:commit

1. **Checks staging area**: Runs `git diff --cached --quiet` to detect staged changes
   - If changes are already staged: commits only what is staged (skips `git add`)
   - If nothing is staged: runs `git add -A` to stage all changes
2. **Analyzes changes**: Reviews diff and recent commits for context
3. **Creates commit**: Uses conventional commit format with detailed body
4. **Executes immediately**: No approval required

### /autocode:sync-pr

1. **Checks for template**: Reads `.claude/templates/pr_description.md` if exists
2. **Handles branch**: Creates feature branch if on main/master
3. **Pushes to remote**: Runs `git push -u origin HEAD`
4. **Checks PR status**: Uses `gh pr view` to detect existing PR
5. **Creates or updates**: Uses `gh pr create` or `gh pr edit --body`

## Conventional Commit Format

```
<type>(<scope>): <subject>

<detailed body explaining what changed and why>
- Use bullet points for multiple changes
- Explain the reasoning, not just the what
```

### Commit Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `style` | Formatting, no code change |
| `refactor` | Code change that neither fixes nor adds |
| `perf` | Performance improvement |
| `test` | Adding or updating tests |
| `chore` | Maintenance tasks |

### Example Commits

```
feat(auth): add JWT token refresh endpoint

Implement automatic token refresh to improve user experience:
- Add /api/auth/refresh endpoint
- Store refresh tokens in secure HTTP-only cookies
- Set access token expiry to 15 minutes
- Handle token rotation on each refresh
```

```
fix(api): handle null user in profile lookup

Prevent 500 error when user ID doesn't exist:
- Add null check before accessing user properties
- Return proper 404 response for missing users
- Add test case for non-existent user scenario
```

## PR Description Template

If `.claude/templates/pr_description.md` exists in the user's project, it is used as the template. A default template is provided by the plugin:

```markdown
## Summary
<Brief description of what this PR does>

## Changes
- <List the main changes made>

## Related issue(s)
<Link to related issues, e.g., Fixes #123, Closes #456>

## Testing
<How to test these changes>

- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Acceptance criteria
- [ ] <Requirement 1>
- [ ] <Requirement 2>
```

If no template file exists, the command falls back to a minimal format:

```markdown
## Summary
<Brief description of what this PR does>

## Related issue(s)
<Link to related issues, e.g., Fixes #123, Closes #456>

## Testing
<How to test these changes>

## Acceptance criteria
<Checklist of requirements that must be met>
```

## Workflow Integration

```
/autocode:execute
├── Test → Code → Refactor loop
└── Changes accumulate

/autocode:review
├── Summarize changes and artifacts
└── Human approval

/autocode:commit
├── Stage changes (or use existing staging)
└── Create conventional commit

/autocode:sync-pr
├── Push branch to remote
├── Create or update PR
└── Ready for code review
```

## Directory Structure

```
.claude/
├── commands/
│   ├── commit.md               # Commit command
│   └── sync-pr.md              # PR sync command
└── templates/
    └── pr_description.md       # PR template
```

## Output

### /autocode:commit

- Stages changes (all if nothing staged, or uses existing staging)
- Creates commit with conventional message
- Shows commit hash and summary

### /autocode:sync-pr

- Push confirmation
- PR URL (created or updated)
- PR title and description summary

## Best Practices

1. **Commit frequently**: Small, focused commits are easier to review
2. **Write meaningful messages**: Explain why, not just what
3. **Use correct types**: Choose the commit type that best describes the change
4. **Reference issues**: Link related issues in PR description
5. **Update PR descriptions**: Keep them current as implementation evolves

## Troubleshooting

### "Not a git repository"

Initialize git or navigate to a git repository:
```bash
git init
```

### "gh: command not found"

Install GitHub CLI:
```bash
brew install gh  # macOS
```

### "gh: not authenticated"

Authenticate with GitHub:
```bash
gh auth login
```

### "No upstream branch"

Push with upstream tracking:
```bash
git push -u origin HEAD
```

## Next Steps

After submitting:

1. Monitor PR for review feedback
2. Address review comments
3. Merge when approved
