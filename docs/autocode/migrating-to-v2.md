# Migrating to autocode 2.0.0

Most users need to do very little: slash command invocation is unchanged, and the config file format is backward compatible. This guide covers the four breaking areas.

## Commands Are Now Skills

Every former command file moved from `plugins/autocode/commands/<name>.md` to `plugins/autocode/skills/<name>/SKILL.md`. Names are unchanged and invocation is the same:

| You type (unchanged) | v1 file (removed) | v2 file |
|----------------------|-------------------|---------|
| `/autocode:help` | `commands/help.md` | `skills/help/SKILL.md` |
| `/autocode:init` | `commands/init.md` | `skills/init/SKILL.md` |
| `/autocode:new-spec` | `commands/new-spec.md` | `skills/new-spec/SKILL.md` |
| `/autocode:create-plan` | `commands/create-plan.md` | `skills/create-plan/SKILL.md` |
| `/autocode:create-tasks` | `commands/create-tasks.md` | `skills/create-tasks/SKILL.md` |
| `/autocode:execute` | `commands/execute.md` | `skills/execute/SKILL.md` |
| `/autocode:review` | `commands/review.md` | `skills/review/SKILL.md` |
| `/autocode:code-review` | `commands/code-review.md` | `skills/code-review/SKILL.md` |
| `/autocode:commit` | `commands/commit.md` | `skills/commit/SKILL.md` |
| `/autocode:sync-pr` | `commands/sync-pr.md` | `skills/sync-pr/SKILL.md` |
| `/autocode:spec-archive` | `commands/spec-archive.md` | `skills/spec-archive/SKILL.md` |

**Action needed only if** you reference the old paths (forks, scripts, docs, custom checklist copies). Note the checklist moved with its skill: `templates/code-review-checklist.md` is now `skills/code-review/code-review-checklist.md`. A project-level override at `.claude/code-review-checklist.md` keeps working unchanged.

Skills also mean Claude can now trigger these automatically when your request matches a skill description ("review my changes against the checklist" invokes code-review). Nothing is required to enable that.

## If Your Automation Parsed the Old Failure Tag

The v1 failure tag was:

```
<task-completed task="T3" status="failed" reason="..." />
```

The v2 tag adds two required attributes and a required body:

```
<task-completed task="T3" status="failed" category="assertion" retryable="true" reason="..." />
```

- `category` is one of `setup|syntax|timeout|runtime|missing|assertion|unknown`
- `retryable` is `true|false`
- The text above the tag now always contains partial results (steps completed, test files written, files changed) and suggested alternatives

To migrate a parser: match the tag by attribute name, not position (`category="..."` and `retryable="..."` appear between `status` and `reason`). Treat a missing or unparseable tag as `status=failed category=unknown`; that is what the execute skill itself now does. The success tag is unchanged. The full contract lives in `plugins/autocode/agents/references/failure-categories.md`.

## If Your Automation Relied on "Stop on First Failure"

The v1 execute loop exited on any task failure. In v2:

- `category=setup` still stops the whole loop (environment problems hit every task)
- Any other failure skips only same-phase tasks after the failed one plus tasks that depend on it, and **continues running independent tasks**
- The final summary has explicit `Completed`, `Failed`, and `Skipped` sections; parse those rather than assuming "loop ended" means "everything before the end succeeded"

## New autocode.yml Toggles

Both are optional; defaults preserve sensible behavior:

```yaml
static_analysis:
  on_edit:
    enabled: true     # per-edit lint hook (PostToolUse); set false for slow linters
    command: ""       # per-file command; falls back to first entry in commands:

artifact_judge:
  enabled: false      # read-only SDK judge of artifact substance; costs tokens
```

`/autocode:init` on an existing project does not overwrite your config; add these keys manually if you want non-default values.

## After Upgrading

Restart Claude Code (or run `/reload-plugins`). The new hooks (per-edit analysis, artifact audit) and the skills surface are only registered at session load.
