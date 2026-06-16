---
name: new-spec
allowed-tools: Bash(bash $AUTOCODE_PLUGIN_ROOT/skills/new-spec/scripts/new-spec.sh:*), Read
description: Use when the user wants to start a new feature or change by creating a spec folder with REQUIREMENT.md and SPEC.md under .specs/. This is the first step in the autocode workflow.
argument-hint: <identifier>
---

# New Spec

Create a new spec folder containing REQUIREMENT.md and SPEC.md templates.

## Step 1: Run New Spec Script

```bash
bash $AUTOCODE_PLUGIN_ROOT/skills/new-spec/scripts/new-spec.sh $ARGUMENTS
```

If the script exits with an error because the spec already exists, relay the error message to the user and suggest choosing a different identifier; then stop.

After creating the spec, read the SPEC.md file and inform the user it's ready for their requirements (REQUIREMENT.md is where raw source material gets pasted; SPEC.md references it).
