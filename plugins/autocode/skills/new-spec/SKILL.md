---
name: new-spec
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/new-spec/scripts/new-spec.sh:*), Read
description: Use when the user wants to start a new feature or change by creating a spec folder with REQUIREMENT.md and SPEC.md under .specs/. This is the first step in the autocode workflow.
argument-hint: <identifier>
model: sonnet # template scaffolding via script with a human filling in the content; see docs/MODEL_SELECTION.md
---

# New Spec

Create a new spec folder containing REQUIREMENT.md and SPEC.md templates.

## Step 1: Run New Spec Script

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/new-spec/scripts/new-spec.sh $ARGUMENTS
```

If the script exits with an error because the spec already exists, relay the error message to the user and suggest choosing a different identifier; then stop.

The script's own stdout already confirms what was created (`Created spec at ...` / `Created requirements at ...`) - no need to read the files back just to show the user what was written. Inform the user the spec is ready for their requirements (REQUIREMENT.md is where raw source material gets pasted; SPEC.md references it).
