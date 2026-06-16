---
name: init
allowed-tools: Bash(jq:*), Bash(python3:*), Bash(bash:*), Read
description: Use once per project to set up Autocode. Creates autocode.yml config, checks for yq dependency, adds .specs/ to .gitignore, and bootstraps the AUTOCODE_PLUGIN_ROOT env var.
argument-hint: [--justifications <template>]
---

<!-- Bash is scoped to jq/python3 (plugin path detection before AUTOCODE_PLUGIN_ROOT exists) and bash (running init.sh by detected path). -->

# Autocode Init

Initialize Autocode for your project. This will:

1. Create `.claude/autocode.yml` configuration file
2. Check for `yq` and offer to install it (enables config customization)
3. Add `.specs/` to `.gitignore`
4. Bootstrap `AUTOCODE_PLUGIN_ROOT` env var into `.claude/settings.local.json`

## Step 1: Resolve Plugin Path

Since `AUTOCODE_PLUGIN_ROOT` may not be set yet (this is the command that sets it), detect the plugin path first:

```bash
PLUGIN_PATH="$AUTOCODE_PLUGIN_ROOT"
if [ -z "$PLUGIN_PATH" ] && command -v jq &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  PLUGIN_PATH="$(jq -r '.[] | select(.package_name == "autocode") | .install_directory' ~/.claude/plugins/installed_plugins.json 2>/dev/null)"
fi
if [ -z "$PLUGIN_PATH" ] && command -v python3 &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  PLUGIN_PATH="$(python3 -c "
import json, sys
with open('$HOME/.claude/plugins/installed_plugins.json') as f:
    plugins = json.load(f)
for p in plugins:
    if p.get('package_name') == 'autocode':
        print(p['install_directory'])
        sys.exit(0)
" 2>/dev/null)"
fi
echo "$PLUGIN_PATH"
```

Each fallback only runs if the previous one produced no path, so an installed `jq` that finds nothing still falls through to the python3 branch.

Capture the output as `PLUGIN_PATH`. If empty, tell the user the plugin path could not be detected and ask them to provide it.

## Step 2: Parse Arguments

Check `$ARGUMENTS` for a `--justifications <template>` flag. If present, extract the template name (e.g., `python`, `rails`, `django`, `ruby`, `typescript`, `react`, `go`).

## Step 3: Run Initialization

```bash
bash {PLUGIN_PATH}/skills/init/scripts/init.sh {JUSTIFICATION_TEMPLATE}
```

Pass the justification template name as the first argument to the init script (empty if not specified).

The init script will:
- Create `.claude/autocode.yml` from template
- Check for `yq` dependency
- Add `.specs/` to `.gitignore`
- Write `AUTOCODE_PLUGIN_ROOT` to `.claude/settings.local.json`
- Create `.claude/justifications.yml` from the specified template (if provided)

Note: when stdin is not a tty (which is the case when this command runs the script), init.sh skips the interactive `yq` install prompt and instead prints the install command. If the script reports that `yq` is missing, relay the printed install command to the user so they can install it themselves.

## Step 4: Inform User

After the script completes, inform the user of the results.

If the script printed the CLAUDE.md import recommendation (it does not modify CLAUDE.md in non-interactive runs), ask the user whether to add the autocode section to the project `CLAUDE.md`. If they agree, append it:

```bash
bash -c 'printf "\n## Autocode\n\n@.claude/autocode.yml\n" >> CLAUDE.md'
```

The `@.claude/autocode.yml` import keeps the test and analysis config in context for every session and every spawned agent, without a Read round-trip.

If no justification template was specified, mention the available templates and how to use them.

## Step 5: Require a Restart

End by telling the user explicitly: **restart Claude Code for hooks and settings to take effect.** The `AUTOCODE_PLUGIN_ROOT` env var written to `.claude/settings.local.json` is only read at session start, and the plugin's hooks are only registered when the session loads the plugin. Nothing initialized in this session will work until the restart.
