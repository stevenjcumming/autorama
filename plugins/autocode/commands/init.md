---
allowed-tools: Bash, Read
description: Use once per project to set up Autocode. Creates autocode.yml config, checks for yq dependency, adds .claude/specs/ to .gitignore, and bootstraps the AUTOCODE_PLUGIN_ROOT env var.
---

# Autocode Init

Initialize Autocode for your project. This will:

1. Create `.claude/autocode.yml` configuration file
2. Check for `yq` and offer to install it (enables config customization)
3. Add `.claude/specs/` to `.gitignore`
4. Bootstrap `AUTOCODE_PLUGIN_ROOT` env var into `.claude/settings.local.json`

## Step 1: Resolve Plugin Path

Since `AUTOCODE_PLUGIN_ROOT` may not be set yet (this is the command that sets it), detect the plugin path first:

```bash
if [ -n "$AUTOCODE_PLUGIN_ROOT" ]; then
  echo "$AUTOCODE_PLUGIN_ROOT"
elif command -v jq &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  jq -r '.[] | select(.package_name == "autocode") | .install_directory' ~/.claude/plugins/installed_plugins.json 2>/dev/null || echo ""
elif command -v python3 &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  python3 -c "
import json, sys
with open('$HOME/.claude/plugins/installed_plugins.json') as f:
    plugins = json.load(f)
for p in plugins:
    if p.get('package_name') == 'autocode':
        print(p['install_directory'])
        sys.exit(0)
" 2>/dev/null || echo ""
fi
```

Capture the output as `PLUGIN_PATH`. If empty, tell the user the plugin path could not be detected and ask them to provide it.

## Step 2: Parse Arguments

Check `$ARGUMENTS` for a `--justifications <template>` flag. If present, extract the template name (e.g., `python`, `rails`, `django`, `ruby`, `typescript`, `react`, `go`).

## Step 3: Run Initialization

```bash
bash {PLUGIN_PATH}/scripts/init.sh {JUSTIFICATION_TEMPLATE}
```

Pass the justification template name as the first argument to the init script (empty if not specified).

The init script will:
- Create `.claude/autocode.yml` from template
- Check for `yq` dependency
- Add `.claude/specs/` to `.gitignore`
- Write `AUTOCODE_PLUGIN_ROOT` to `.claude/settings.local.json`
- Create `.claude/justifications.yml` from the specified template (if provided)

## Step 4: Inform User

After the script completes, inform the user of the results. Note that `AUTOCODE_PLUGIN_ROOT` will be available as an env var in **new** Claude Code sessions (requires restart).

If no justification template was specified, mention the available templates and how to use them.
