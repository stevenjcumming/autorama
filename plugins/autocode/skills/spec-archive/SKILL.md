---
name: spec-archive
description: Use when the user is done with a spec and wants to archive all of its files (REQUIREMENT.md, SPEC.md, PLAN.md, TODO.md, SUMMARY.md, artifacts, REVIEW.md) to ~/.autocode/specs/ for long-term storage. REVIEW.md is copied into the archive as well as being preserved in the working directory, so the durable human sign-off record survives in both places.
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/spec-archive/scripts/spec-archive.sh:*), Read
argument-hint: <identifier>
---

# Spec Archive

Move all spec files except REVIEW.md to `~/.autocode/specs/<project>/<id>/` for long-term storage, and additionally copy REVIEW.md there too (it also stays in the working directory).

## Arguments

- `$ARGUMENTS` contains: `<identifier>`
- Parse the arguments to extract:
  - `IDENTIFIER`: The spec identifier (e.g., `auth-refactor`)
- Construct `SPEC_DIR` as `.specs/$IDENTIFIER`

## Step 1: Ensure REVIEW.md Exists

Check if `$SPEC_DIR/REVIEW.md` exists. If it does not, tell the user to run `/autocode:review {IDENTIFIER}` first to complete the review checkpoint, then **STOP**. Do not run the archive script without REVIEW.md (the script requires it and will exit with an error).

## Step 2: Run Archive Script

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/spec-archive/scripts/spec-archive.sh $ARGUMENTS
```

The script validates the spec directory itself. It will:
1. Determine the project name from the git remote or directory name
2. Create `~/.autocode/specs/<project>/<id>/`
3. Move all spec files except REVIEW.md (REQUIREMENT.md, SPEC.md, PLAN.md, TODO.md, SUMMARY.md, artifacts/) to the archive
4. Copy REVIEW.md into the archive too, *without* removing it from the working directory

**Why REVIEW.md gets both treatments:** REVIEW.md is the durable human sign-off record and the single most audit-relevant file in a spec. Because `init.sh` gitignores `.specs/`, a file that only ever lived in the working directory would survive in neither git nor the archive - the least durable of the three places it could live. Keeping the working-tree copy preserves git-diff/PR visibility for projects where `.specs/` isn't fully gitignored; copying it into the archive too means an archived spec is self-contained (a full historical record) even if the working-tree copy is later deleted.

If the script exits with an error, relay its message to the user and stop.

## Step 3: Inform User

After the script completes, inform the user:
- Where the files were archived
- That REVIEW.md is preserved in the spec directory *and* copied into the archive
- How to find the archived files later
