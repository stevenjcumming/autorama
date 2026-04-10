---
description: Use when the user is done with a spec and wants to archive its files (SPEC.md, PLAN.md, TODO.md, artifacts) to ~/.autocode/specs/ for long-term storage. Preserves REVIEW.md in the working directory.
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/scripts/spec-archive.sh:*), Read, Write
argument-hint: <identifier>
---

# Spec Archive

Move all spec files except REVIEW.md to `~/.autocode/specs/<project>/<id>/` for long-term storage.

## Arguments

- `$ARGUMENTS` contains: `<identifier>`
- Parse the arguments to extract:
  - `IDENTIFIER`: The spec identifier (e.g., `auth-refactor`)
- Construct `SPEC_DIR` as `.claude/specs/$IDENTIFIER`

## Step 1: Validate Prerequisites

Verify the spec directory exists and contains content:

```bash
ls $SPEC_DIR/SPEC.md $SPEC_DIR/PLAN.md $SPEC_DIR/TODO.md 2>/dev/null
```

If the spec directory doesn't exist or is empty, inform the user and exit.

## Step 2: Ensure REVIEW.md Exists

Check if `$SPEC_DIR/REVIEW.md` exists. If not, inform the user that a review should be generated first and invoke:

```
/autopilot:review $IDENTIFIER
```

Wait for the review to complete before proceeding.

## Step 3: Run Archive Script

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/spec-archive.sh $ARGUMENTS
```

The script will:
1. Determine the project name from the git remote or directory name
2. Create `~/.autocode/specs/<project>/<id>/`
3. Copy all spec files (SPEC.md, PLAN.md, TODO.md, artifacts/) to the archive
4. Remove all spec files except REVIEW.md from the working directory

## Step 4: Inform User

After the script completes, inform the user:
- Where the files were archived
- That REVIEW.md was preserved in the spec directory
- How to find the archived files later
