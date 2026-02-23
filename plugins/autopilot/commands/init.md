---
allowed-tools: Bash, Read
description: Initialize Autopilot configuration and install optional dependencies
---

# Autopilot Init

Initialize Autopilot for your project. This will:

1. Create `.claude/autopilot.yml` configuration file
2. Check for `yq` and offer to install it (enables config customization)
3. Add `.claude/specs/` to `.gitignore`
4. Bootstrap `AUTOPILOT_PLUGIN_ROOT` env var into `.claude/settings.local.json`

## Step 1: Resolve Plugin Path

Since `AUTOPILOT_PLUGIN_ROOT` may not be set yet (this is the command that sets it), detect the plugin path first:

```bash
if [ -n "$AUTOPILOT_PLUGIN_ROOT" ]; then
  echo "$AUTOPILOT_PLUGIN_ROOT"
elif command -v jq &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  jq -r '.[] | select(.package_name == "claude-code-autopilot") | .install_directory' ~/.claude/plugins/installed_plugins.json 2>/dev/null || echo ""
elif command -v python3 &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  python3 -c "
import json, sys
with open('$HOME/.claude/plugins/installed_plugins.json') as f:
    plugins = json.load(f)
for p in plugins:
    if p.get('package_name') == 'claude-code-autopilot':
        print(p['install_directory'])
        sys.exit(0)
" 2>/dev/null || echo ""
fi
```

Capture the output as `PLUGIN_PATH`. If empty, tell the user the plugin path could not be detected and ask them to provide it.

## Step 2: Run Initialization

```bash
bash {PLUGIN_PATH}/scripts/init.sh
```

The init script will:
- Create `.claude/autopilot.yml` from template
- Check for `yq` dependency
- Add `.claude/specs/` to `.gitignore`
- Write `AUTOPILOT_PLUGIN_ROOT` to `.claude/settings.local.json`

## Step 3: Inform User

After the script completes, inform the user of the results. Note that `AUTOPILOT_PLUGIN_ROOT` will be available as an env var in **new** Claude Code sessions (requires restart).
