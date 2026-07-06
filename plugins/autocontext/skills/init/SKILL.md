---
name: init
description: Use once per project to set up autocontext. Triggers on "set up autocontext", "initialize autocontext", "autocontext init", or when create/update report that AUTOCONTEXT_PLUGIN_ROOT is not set. Resolves the plugin install path, writes AUTOCONTEXT_PLUGIN_ROOT to .claude/settings.local.json, and injects the CONTEXT.md execution contract into .claude/CLAUDE.md.
allowed-tools: Bash(jq:*), Bash(python3:*), Bash(bash:*), Bash(ls:*), Read, Edit, Write
---

<!-- Bash is scoped to the four commands this skill actually runs: jq and python3 for the registry lookup fallbacks, ls for the plugin cache glob, and bash to invoke init.sh. Edit and Write are needed for the execution contract injection into .claude/CLAUDE.md. -->

# Autocontext Init

Initialize autocontext for your project. This resolves the plugin's install path, persists it as the `AUTOCONTEXT_PLUGIN_ROOT` environment variable in `.claude/settings.local.json`, and injects the CONTEXT.md execution contract into `.claude/CLAUDE.md` so agents know how to consume `CONTEXT.md` files. You only need to run this once per project. Re-running is safe: the env var is refreshed and the contract is never duplicated.

## Step 1: Resolve Plugin Path

Since `AUTOCONTEXT_PLUGIN_ROOT` may not be set yet (this is the skill that sets it), detect the plugin path. Try the following sources in order and capture the first non-empty result as `PLUGIN_PATH`:

1. If `$AUTOCONTEXT_PLUGIN_ROOT` is already set in the current environment, use its value directly (re-running init simply refreshes the settings file).

2. Query the plugin registry with jq. The registry at `~/.claude/plugins/installed_plugins.json` keys plugins as `<name>@<marketplace>` under a top-level `plugins` object, and each value is an array of install records with an `installPath` field:

```bash
jq -r '.plugins | to_entries[] | select(.key | startswith("autocontext@")) | .value[].installPath' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null | head -n 1
```

3. If jq is not available, use python3. Pass the registry path as an argument rather than interpolating it into the program text:

```bash
python3 -c '
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for key, installs in data.get("plugins", {}).items():
    if key.split("@")[0] == "autocontext":
        for entry in installs:
            if entry.get("installPath"):
                print(entry["installPath"])
                raise SystemExit
' "$HOME/.claude/plugins/installed_plugins.json" 2>/dev/null
```

4. If neither jq nor python3 is available, or the registry queries returned nothing (for example, the registry schema changed again), glob the plugin cache directly:

```bash
ls -d "$HOME"/.claude/plugins/cache/*/autocontext/* 2>/dev/null | head -n 1
```

If every source comes up empty, tell the user: "Could not auto-detect the autocontext install path. Please provide the absolute path to the installed plugin directory (it contains scripts/init.sh)." Then use their answer as `PLUGIN_PATH`.

## Step 2: Run Initialization

```bash
bash "{PLUGIN_PATH}/scripts/init.sh"
```

The init script will:
- Resolve its own directory to determine the plugin root
- Create `.claude/` if it does not exist
- Write `AUTOCONTEXT_PLUGIN_ROOT` into `.claude/settings.local.json` using jq if available, python3 as fallback, or manual instructions as a last resort

## Step 3: Inject Execution Contract

Read `.claude/CLAUDE.md`. If the file already contains the heading `## CONTEXT.md Execution Contract`, skip this step (the contract is already installed). Otherwise, append the contract below to the end of the file. If `.claude/CLAUDE.md` does not exist, create it with only the contract.

The contract to inject, verbatim:

```markdown
## CONTEXT.md Execution Contract

All paths in CONTEXT.md files are root-relative.

Before acting in any directory:

1. Read the CONTEXT.md in the working directory.
2. Load any files listed in Key References, including other CONTEXT.md files if referenced.
3. If opening or modifying a specific file, check the Docs table for a matching pattern and load those references alongside the Key References.
4. Match the task to a bundle in the Tasks table and load that bundle.
5. Apply all Never Do Here constraints before writing any code. These hold regardless of the active task.

If no bundle matches the task, still apply Key References and Never Do Here from the current CONTEXT.md, notify the user with "No Task Match", and proceed.
If a referenced file does not exist, note it and proceed without it. Do not invent its contents.
```

## Step 4: Inform User

After the script and contract injection complete, inform the user of the results (env var written, contract injected or already present), ending with this explicit instruction:

> Restart Claude Code now for settings to take effect. `AUTOCONTEXT_PLUGIN_ROOT` is only loaded into the environment when a session starts, so the current session cannot see it.

Confirm that, after restarting, the user can run `/autocontext:create <path>` to generate the first `CONTEXT.md`.

## Notes

- Init is idempotent. Running it again refreshes the env var without duplicating the contract.
- Init does not generate any `CONTEXT.md` files. That is what `/autocontext:create` is for.
- Autocontext has no YAML config file and no yq dependency.
