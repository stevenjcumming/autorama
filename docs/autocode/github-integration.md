# GitHub Integration

Autocode ends its workflow at `/autocode:sync-pr`, which creates or updates the pull request. Teams that also run Claude in CI can connect the two surfaces so local review and CI review apply the same criteria instead of producing duplicate findings.

## Setting Up the GitHub App

For teams, run inside Claude Code:

```
/install-github-app
```

This sets up two GitHub Actions workflows:

1. An `@claude` mention action: comment `@claude` on an issue or PR and Claude responds with changes or analysis.
2. An automatic PR review action: Claude reviews each opened pull request.

Both workflows need `ANTHROPIC_API_KEY` set as a repository secret (the installer walks through this).

## Aligning CI Review with the Autocode Checklist

The automatic PR review action overlaps with `/autocode:code-review`. If you use both with default settings, you get two review surfaces with different criteria. Align them by embedding the autocode checklist in the workflow's custom instructions.

The checklist ships at `plugins/autocode/skills/code-review/code-review-checklist.md` (project override: `.claude/code-review-checklist.md`). In the generated workflow file (`.github/workflows/claude-code-review.yml` or similar), point the review prompt at the same criteria:

```yaml
      - uses: anthropics/claude-code-action@v1
        with:
          anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
          direct_prompt: |
            Review this pull request against the checklist in
            .claude/code-review-checklist.md. Report only actionable
            violations, bucketed by severity (CRITICAL/HIGH/MEDIUM/LOW),
            citing checklist item IDs (SEC-1, ERR-3, ...).
```

For this to work, commit the checklist into the repo (copy it to `.claude/code-review-checklist.md`); CI cannot read your local plugin install.

## The allowed_tools Warning

The workflow's `allowed_tools` input must list every permitted tool **explicitly**. This matters in two ways:

- Tools not listed are unavailable to the action; a review workflow that needs to run tests must list the exact Bash commands (for example `Bash(npm test:*)`), not `Bash`.
- Each tool from each MCP server must be individually listed. There is no wildcard for "all tools from this server"; an unlisted MCP tool silently does not exist in CI.

Keep the CI tool list as tight as the autocode agents keep theirs: a reviewer needs read access and little else.

## Avoiding Duplicate Reviews

When a PR was produced by the autocode workflow, the checklist review already ran locally (`/autocode:code-review` writes `CODE_REVIEW.md` to the spec's artifacts). `/autocode:sync-pr` notes this in the PR description when a review report exists, so the CI reviewer (or a human) can skip re-running the same checklist and focus on anything new since the report.

Options, from lightest to strictest:

1. Keep both surfaces, with the PR description note telling the CI reviewer what already ran (default behavior).
2. Configure the CI review to skip PRs whose description contains the autocode review marker.
3. Disable the automatic PR review workflow and rely on `/autocode:code-review` plus human review via `/autocode:review`.

## Related Documentation

- [Workflow Stages: Submit](workflow-stages/07_submit.md)
- [Workflow Stages: Code Review](workflow-stages/06_code_review.md)
- [Configuration](configuration.md)
