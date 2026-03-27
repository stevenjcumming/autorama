# Workflow: Code Review

## Purpose

Perform a structured code review of recent changes against a configurable checklist. The command delegates to a reviewer agent that analyzes the diff, explores the codebase for context, and produces a severity-bucketed report. Unlike the Review stage (which summarizes artifacts for human oversight), Code Review focuses on finding specific checklist violations in the code itself.

## Command

```
/autopilot:code-review [identifier] [--ref <ref>]
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `[identifier]` | No | Spec identifier to scope the review (e.g., `auth-refactor`) |
| `--ref <ref>` | No | Git ref to diff against (default: HEAD~1 or spec branch point) |

## Examples

```bash
# Review uncommitted changes using the default checklist
/autopilot:code-review

# Review changes for a specific spec
/autopilot:code-review auth-refactor

# Review against a specific git ref
/autopilot:code-review --ref main

# Both spec-scoped and ref-based
/autopilot:code-review auth-refactor --ref origin/main
```

## Prerequisites

- Git repository with changes to review
- A checklist file (uses built-in default if none configured)

## What It Does

1. **Gathers diff**: Runs `git diff` and `git diff --stat` for the changes to review
2. **Loads checklist**: Resolves the checklist from config, project file, or built-in default
3. **Resolves reviewer agent**: Reads `agents.reviewer` from `.claude/autopilot.yml`, falling back to the built-in `autopilot:autopilot-reviewer`
4. **Spawns reviewer**: Passes the diff, diff stat, checklist, and output path to the agent
5. **Presents results**: Reads the generated report and displays findings to the user

## Review Process

```
/autopilot:code-review [identifier]
├── Gather diff (git diff + git diff --stat)
├── Load checklist (config → project → default)
├── Resolve reviewer agent (config → autopilot:autopilot-reviewer)
├── Spawn reviewer agent
│   ├── Understand changes from diff
│   ├── Explore codebase context (Read, Grep, Glob)
│   ├── Evaluate each checklist item against diff
│   ├── Assess severity of findings
│   └── Write report to OUTPUT_PATH
└── Present results summary
```

## Severity Levels

| Severity | Definition | Examples |
|----------|------------|---------|
| **CRITICAL** | Will cause production incidents if deployed | Security vulnerabilities, data loss, auth bypasses, injection flaws |
| **HIGH** | Likely to cause problems | Bugs, regressions, race conditions, resource leaks |
| **MEDIUM** | Code quality concerns | Missing error handling, poor naming, insufficient validation, duplication |
| **LOW** | Nice-to-have improvements | Style issues, minor optimizations, documentation gaps |

## Output

The reviewer agent writes a structured report to:

- **Spec mode**: `.claude/specs/<identifier>/artifacts/CODE_REVIEW.md`
- **Standalone mode**: `.claude/CODE_REVIEW.md`

Report format:

```markdown
# Code Review

**Date:** 2026-03-27
**Ref:** HEAD
**Files Changed:** 5

## Summary

- CRITICAL: 0
- HIGH: 1
- MEDIUM: 2
- LOW: 1

## HIGH

### Missing error handling on external API call
**File:** `app/services/payment_service.rb:45`
**Description:** HTTP call to payment gateway has no rescue block
**Impact:** Unhandled timeout will crash the request and return 500
**Fix:** Wrap in begin/rescue with appropriate error response
**Checklist:** Error Handling — External calls have failure handling

## MEDIUM
...

## Checklist Coverage

Items checked with no findings:
- No secrets or credentials hardcoded
- Tests are deterministic
- ...
```

## Checklist Configuration

The checklist is resolved in priority order:

| Priority | Source | Path |
|----------|--------|------|
| 1 | Config | Path specified in `code_review.checklist` in `.claude/autopilot.yml` |
| 2 | Project | `.claude/code-review-checklist.md` |
| 3 | Default | `$AUTOPILOT_PLUGIN_ROOT/templates/code-review-checklist.md` |

The default checklist covers five areas: Security, Testing, Error Handling, Code Quality, and Performance (5 items each, 25 total).

To customize, copy the default and modify:

```bash
cp plugins/autopilot/templates/code-review-checklist.md .claude/code-review-checklist.md
```

Or point to a custom path in config:

```yaml
# .claude/autopilot.yml
code_review:
  checklist: .claude/my-team-checklist.md
```

## Custom Reviewer Agent

The built-in `autopilot:autopilot-reviewer` agent provides a generic, checklist-driven review. For projects with domain-specific standards, you can replace it with a custom agent.

### Why Use a Custom Agent?

A custom reviewer agent is valuable when your project needs:

- **Domain-specific risk models** — e.g., "adding a non-null column in one step is CRITICAL because of blue/green deployments" vs the generic "validate database changes"
- **Conditional review sections** — e.g., Sidekiq rules only when Sidekiq files change, migration rules only when migrations exist
- **Escalation routing** — e.g., "flag for Identity team" or "requires Platform team review"
- **Merge recommendations** — aggregating findings into APPROVE/REQUEST_CHANGES/BLOCK
- **Institutional knowledge** — deployment models, compliance requirements, team conventions

A custom checklist alone can't do codebase exploration, conditional logic, or escalation routing. Those require agent-level control.

### Configuration

Override the reviewer in `.claude/autopilot.yml`:

```yaml
agents:
  reviewer: my-custom-reviewer
```

The agent can be:
- A project-local agent in `.claude/agents/my-custom-reviewer.md`
- A plugin agent using `namespace:agent-name` format

### Agent Contract

Your custom agent receives these inputs:

| Input | Description |
|-------|-------------|
| `DIFF` | Full git diff of the changes to review |
| `DIFF_STAT` | Diff stat summary (files changed, insertions, deletions) |
| `CHECKLIST` | The resolved checklist content |
| `SPEC_DIR` | Path to spec directory (empty if standalone mode) |
| `OUTPUT_PATH` | Where to write the review report |

Your agent **must**:
- Write a review report to `OUTPUT_PATH`
- Include a summary with finding counts per severity

Your agent **may**:
- Use its own severity model and risk framework
- Explore the codebase with Read, Grep, Glob
- Add sections beyond the standard format (e.g., merge recommendation, specialist routing)
- Reference its own checklist instead of (or in addition to) the provided one

### Example Custom Agent Structure

```yaml
---
name: my-custom-reviewer
description: Domain-specific code reviewer for my-project
tools: Read, Glob, Grep, Bash
model: sonnet
---
```

```markdown
# My Custom Reviewer

<input>
- DIFF, DIFF_STAT, CHECKLIST, SPEC_DIR, OUTPUT_PATH
</input>

<process>
### Step 1: Classify changed files
Map file paths to review sections (migrations, jobs, auth, etc.)

### Step 2: Apply domain rules
Check for domain-specific violations beyond the generic checklist

### Step 3: Explore context
Read related files to assess impact

### Step 4: Write report
Include findings, merge recommendation, and escalation routing
</process>
```

## Comparison: Code Review vs Review

| Aspect | `/autopilot:code-review` | `/autopilot:review` |
|--------|--------------------------|---------------------|
| **Focus** | Finding checklist violations in code | Summarizing artifacts for human oversight |
| **Input** | Git diff | Artifacts, git changes, review hints |
| **Output** | Severity-bucketed findings report | Interactive summary with approval workflow |
| **Agent** | Configurable reviewer agent | Runs inline (no agent) |
| **Decision** | Informational — no approval flow | Approve / Request Changes / Reject |
| **When to use** | Automated quality gate | Human checkpoint before submission |

Both can be used together: run `/autopilot:code-review` first for automated checks, then `/autopilot:review` for the human decision.

## Key Characteristics

- **Agent-delegated**: The command orchestrates; the reviewer agent does the analysis
- **Customizable**: Both the checklist and the agent can be swapped out
- **Codebase-aware**: The agent can explore beyond the diff for context
- **Non-blocking**: Produces a report but does not approve or reject — that's the human's job

## Next Steps

After code review:

1. **Fix findings**: Address CRITICAL and HIGH issues before proceeding
2. **Run `/autopilot:review`**: Human checkpoint for artifact review and approval
3. **Submit**: `/autopilot:commit` and `/autopilot:sync-pr`
