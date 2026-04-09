---
allowed-tools: Bash, Read
description: Use once per project to set up autoskill. Resolves the plugin install path and writes AUTOSKILL_PLUGIN_ROOT to .claude/settings.local.json so the build command can locate its templates and references.
---

# Autoskill Init

Initialize autoskill for your project. This resolves the plugin's install path and persists it as the `AUTOSKILL_PLUGIN_ROOT` environment variable in `.claude/settings.local.json`. You only need to run this once per project.

## Step 1: Resolve Plugin Path

Since `AUTOSKILL_PLUGIN_ROOT` may not be set yet (this is the command that sets it), detect the plugin path first:

```bash
if [ -n "$AUTOSKILL_PLUGIN_ROOT" ]; then
  echo "$AUTOSKILL_PLUGIN_ROOT"
elif command -v jq &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  jq -r '.[] | select(.package_name == "autoskill") | .install_directory' ~/.claude/plugins/installed_plugins.json 2>/dev/null || echo ""
elif command -v python3 &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  python3 -c "
import json, sys
with open('$HOME/.claude/plugins/installed_plugins.json') as f:
    plugins = json.load(f)
for p in plugins:
    if p.get('package_name') == 'autoskill':
        print(p['install_directory'])
        sys.exit(0)
" 2>/dev/null || echo ""
fi
```

Capture the output as `PLUGIN_PATH`. If empty, tell the user the plugin path could not be detected and ask them to provide it manually.

## Step 2: Run Initialization

```bash
bash {PLUGIN_PATH}/scripts/init.sh
```

The init script will:
- Resolve its own directory to determine the plugin root
- Write `AUTOSKILL_PLUGIN_ROOT` into `.claude/settings.local.json` using jq if available, python3 as fallback, or manual instructions as a last resort

## Step 3: Inform User

After the script completes, inform the user of the results. Note that `AUTOSKILL_PLUGIN_ROOT` will be available as an environment variable in **new** Claude Code sessions (requires a session restart to take effect).

Confirm that the user can now use `/autoskill:build` to generate skills from their codebase patterns.
