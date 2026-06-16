---
name: spec-archive
description: Use when the user is done with a spec and wants to archive all of its files (REQUIREMENT.md, SPEC.md, PLAN.md, TODO.md, SUMMARY.md, artifacts) to ~/.autocode/specs/ for long-term storage. Preserves REVIEW.md in the working directory.
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/spec-archive/scripts/spec-archive.sh:*), Read
argument-hint: <identifier>
---

# Spec Archive

Move all spec files except REVIEW.md to `~/.autocode/specs/<project>/<id>/` for long-term storage.

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
3. Copy all spec files except REVIEW.md (REQUIREMENT.md, SPEC.md, PLAN.md, TODO.md, SUMMARY.md, artifacts/) to the archive
4. Remove the archived files from the working directory, leaving only REVIEW.md

If the script exits with an error, relay its message to the user and stop.

## Step 3: Inform User

After the script completes, inform the user:
- Where the files were archived
- That REVIEW.md was preserved in the spec directory
- How to find the archived files later
