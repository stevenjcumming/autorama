---
name: init
description: Use once per project to set up autoskill. Triggers on "set up autoskill", "initialize autoskill", "autoskill init", or when build reports that AUTOSKILL_PLUGIN_ROOT is not set. Resolves the plugin install path and writes AUTOSKILL_PLUGIN_ROOT to .claude/settings.local.json so the build skill can locate its templates and references.
allowed-tools: Bash(jq:*), Bash(python3:*), Bash(ls:*), Bash(bash:*), Read
---

# Autoskill Init

Initialize autoskill for your project. This resolves the plugin's install path and persists it as the `AUTOSKILL_PLUGIN_ROOT` environment variable in `.claude/settings.local.json`. You only need to run this once per project.

## Step 1: Resolve Plugin Path

Since `AUTOSKILL_PLUGIN_ROOT` may not be set yet (this is the skill that sets it), detect the plugin path. Try the following sources in order and capture the first non-empty result as `PLUGIN_PATH`:

1. If `$AUTOSKILL_PLUGIN_ROOT` is already set in the current environment, use its value directly (re-running init simply refreshes the settings file).

2. Query the plugin registry with jq. The registry at `~/.claude/plugins/installed_plugins.json` keys plugins as `<name>@<marketplace>` under a top-level `plugins` object, and each value is an array of install records with an `installPath` field:

```bash
jq -r '.plugins | to_entries[] | select(.key | startswith("autoskill@")) | .value[].installPath' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null | head -n 1
```

3. If jq is not available, use python3. Pass the registry path as an argument rather than interpolating it into the program text:

```bash
python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for key, installs in data.get("plugins", {}).items():
    if key.split("@")[0] == "autoskill":
        for entry in installs:
            if entry.get("installPath"):
                print(entry["installPath"])
                raise SystemExit
' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null
```

4. If neither jq nor python3 is available, or the registry queries returned nothing (for example, the registry schema changed again), glob the plugin cache directly:

```bash
ls -d "$HOME"/.claude/plugins/cache/*/autoskill/* 2>/dev/null | head -n 1
```

If every source comes up empty, tell the user: "Could not auto-detect the autoskill install path. Please provide the absolute path to the installed plugin directory (it contains scripts/init.sh)." Then use their answer as `PLUGIN_PATH`.

## Step 2: Run Initialization

```bash
bash "{PLUGIN_PATH}/scripts/init.sh"
```

The init script will:
- Resolve its own directory to determine the plugin root
- Write `AUTOSKILL_PLUGIN_ROOT` into `.claude/settings.local.json` using jq if available, python3 as fallback, or manual instructions as a last resort

## Step 3: Inform User

After the script completes, inform the user of the results, ending with this explicit instruction:

> Restart Claude Code now for hooks and settings to take effect. `AUTOSKILL_PLUGIN_ROOT` is only loaded into the environment when a session starts, so the current session cannot see it.

Confirm that, after restarting, the user can use the `autoskill:build` skill to generate skills from their codebase patterns.
