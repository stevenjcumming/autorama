# Uncommitted Work Handling

This file is the single definition of how autocode agents interact with git state during a task-runner session. The execution loop does not commit per task — work from every task in the session stays uncommitted (staged or unstaged) until a human runs the commit skill. Do not redefine this model elsewhere; cite this file.

## Detecting Changed Files

Because nothing is committed mid-session, "what changed" is never a range against a prior commit — it is always relative to `HEAD`, plus untracked files that have no commit to diff against:

```bash
git diff --name-only HEAD 2>/dev/null      # tracked changes, staged or unstaged
git status --porcelain 2>/dev/null          # includes untracked files (prefix "??")
git diff --stat HEAD 2>/dev/null            # summary stats
```

Union the tracked-changes list with the untracked files from `git status --porcelain`. Never use `git diff HEAD~1` or a branch-range diff to find "recent changes" — with no per-task commits, `HEAD~1` spans the wrong tasks (or doesn't exist at all on a fresh branch).

If git is not available, fall back to whatever task/plan context names the files (e.g., TODO.md's task description or the relevant PLAN.md section).

## Rollback Model (task-runner only)

The task-runner is the only agent that reverts changes; refactorer and session-summarizer never roll back — they only read git state to find files, never restore it.

`git checkout -- .` (reverting the whole working tree) is the bug this model replaces: since the tree holds every prior task's uncommitted work too, a whole-tree checkout after one failed cycle discards not just that cycle but every earlier task's work in the same session, while leaving that cycle's new untracked files behind (a half-reverted, inconsistent tree either way).

Instead, the task-runner snapshots before each risky cycle (a coder/tester retry, an analysis-fix attempt, a refactor cycle) and restores only that cycle's delta on failure:

1. **Before the cycle**: `SNAPSHOT=$(mktemp /tmp/autocode-precycle-XXXXXX.patch); git diff HEAD > "$SNAPSHOT"`. This captures the entire tree's delta from the last commit — including every prior task's still-uncommitted work — not just what this cycle is about to touch. An empty patch is fine; it just means the tree was clean going in.
2. **Run the cycle** (spawn the sub-agent, run the test command).
3. **On rollback** (the cycle's result is rejected — tests still fail, regression detected): reset tracked files to the last commit, then re-apply the pre-cycle snapshot to restore exactly the pre-cycle state:
   ```bash
   git checkout HEAD -- .
   git apply "$SNAPSHOT"
   ```
   Net effect: the failed cycle's edits are undone; every prior task's uncommitted work is preserved exactly as it was before the cycle started.
4. **On success**: discard the snapshot (`rm -f "$SNAPSHOT"`); nothing to restore.

**Known limitation — untracked files:** `git checkout HEAD -- .` only touches tracked files. Untracked files a failed cycle created (a new file the coder or refactorer wrote that was never `git add`ed) are not removed by the restore and survive as stray new files. The task-runner does not currently track which untracked files a given cycle created, so this is a documented residual rather than a solved case. Downstream agents (and a human reviewing the tree) should expect the occasional stray untracked file after a rolled-back cycle and treat it as cleanup, not corruption.
