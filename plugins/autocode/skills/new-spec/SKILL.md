---
allowed-tools: Bash, Read
description: Use when the user wants to start a new feature or change by creating a spec folder with REQUIREMENT.md and SPEC.md under .specs/. This is the first step in the autocode workflow.
argument-hint: <identifier>
---

# New Spec

Create a new spec folder and SPEC.md file.

## Step 1: Run New Spec Script

```bash
bash $AUTOCODE_PLUGIN_ROOT/scripts/new-spec.sh $ARGUMENTS
```

After creating the spec, read the SPEC.md file and inform the user it's ready for their requirements.
