---
allowed-tools: Bash, Read
description: Initialize Autopilot configuration and install optional dependencies
---

# Autopilot Init

Initialize Autopilot for your project. This will:

1. Create `.claude/autopilot.yml` configuration file
2. Check for `yq` and offer to install it (enables config customization)
3. Add `.claude/specs/` to `.gitignore`

## Step 1: Run Initialization

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/init.sh
```

After the script completes, inform the user of the results and next steps.
