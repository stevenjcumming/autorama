---
name: init
allowed-tools: Bash(jq:*), Bash(python3:*), Bash(bash */skills/init/scripts/init.sh:*), Bash(printf "\n## Autocode\n\n@.claude/autocode.yml\n" >> CLAUDE.md), Read
description: Use once per project to set up Autocode. Creates autocode.yml config, checks for yq dependency, adds .specs/ to .gitignore, and bootstraps the AUTOCODE_PLUGIN_ROOT env var.
argument-hint: [--justifications <template>]
---

<!--
Tool-scoping rationale:
- `Bash(bash */skills/init/scripts/init.sh:*)` is narrowed to the one script
  this skill actually runs (Step 3): a single, non-compound command, so a
  glob-prefix rule reliably matches regardless of the detected absolute
  plugin path.
- `Bash(jq:*)` and `Bash(python3:*)` are left broad rather than scoped to the
  specific invocations in Step 1. Step 1 runs a single multi-line compound
  script (if/fi control flow plus command substitution) as one Bash call;
  Claude Code's permission matcher only documents parsing simple linear
  separators (&&, ||, ;, |, newlines), not control-flow constructs, so a
  narrow per-invocation rule for the jq/python3 calls inside that script is
  not reliably guaranteed to match. Init runs once per project, so accepting
  a permission prompt here is an acceptable, low-frequency cost.
- `Bash(printf "\n## Autocode\n\n@.claude/autocode.yml\n" >> CLAUDE.md)` is an
  exact-match rule (no trailing wildcard) for the one fixed CLAUDE.md-append
  command in Step 4, which has no variable parts.
-->

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
  PLUGIN_PATH="$(jq -r '
    if (.plugins? | type) == "object" then
      (.plugins | to_entries[] | select(.key | startswith("autocode@")) | .value[].installPath)
    elif type == "array" then
      (.[] | select(.package_name == "autocode") | .install_directory)
    else empty end
  ' ~/.claude/plugins/installed_plugins.json 2>/dev/null | head -n 1)"
fi
if [ -z "$PLUGIN_PATH" ] && command -v python3 &> /dev/null && [ -f ~/.claude/plugins/installed_plugins.json ]; then
  PLUGIN_PATH="$(python3 -c "
import json, os, sys
path = os.path.expanduser('~/.claude/plugins/installed_plugins.json')
with open(path) as f:
    data = json.load(f)
# installed_plugins.json has two known shapes:
#  1. current: {\"plugins\": {\"<name>@<marketplace>\": [{\"installPath\": ...}]}}
#  2. legacy:  [{\"package_name\": ..., \"install_directory\": ...}]
if isinstance(data, dict) and isinstance(data.get('plugins'), dict):
    for key, installs in data['plugins'].items():
        if key.split('@')[0] == 'autocode':
            for entry in installs:
                if entry.get('installPath'):
                    print(entry['installPath'])
                    sys.exit(0)
elif isinstance(data, list):
    for p in data:
        if p.get('package_name') == 'autocode':
            print(p.get('install_directory', ''))
            sys.exit(0)
" 2>/dev/null)"
fi
echo "$PLUGIN_PATH"
```

Each fallback only runs if the previous one produced no path, so an installed `jq` that finds nothing still falls through to the python3 branch. Both the `jq` and `python3` paths handle either known shape of `installed_plugins.json`: the current registry format (a top-level `plugins` object keyed by `<name>@<marketplace>`, each value an array of install records with `installPath`) and the legacy format (a top-level array of records with `package_name` / `install_directory`).

Capture the output as `PLUGIN_PATH`. If empty, tell the user the plugin path could not be detected and ask them to provide it.

## Step 2: Parse Arguments

Check `$ARGUMENTS` for a `--justifications <template>` flag. If present, extract the template name (e.g., `python`, `rails`, `django`, `ruby`, `typescript`, `react`, `go`).

## Step 3: Run Initialization

```bash
bash {PLUGIN_PATH}/skills/init/scripts/init.sh --plugin-root {PLUGIN_PATH} {JUSTIFICATION_ARGS}
```

Always pass `--plugin-root {PLUGIN_PATH}` using the exact path captured in Step 1. init.sh self-resolves its own plugin root from its script path as a fallback, but the explicit `--plugin-root` override is defense in depth: it lets the already-known-good path from Step 1 win even if self-resolution is ever wrong. `{JUSTIFICATION_ARGS}` is `--justifications <template>` if a template was requested in Step 2, otherwise empty.

The init script will:
- Create `.claude/autocode.yml` from template
- Check for `yq` dependency
- Detect a pre-2.0 `.claude/specs/` directory and print a migration hint (does not move anything automatically)
- Add `.specs/` to `.gitignore`
- Write `AUTOCODE_PLUGIN_ROOT` to `.claude/settings.local.json`
- Create `.claude/justifications.yml` from the specified template (if provided)

Note: when stdin is not a tty (which is the case when this command runs the script), init.sh skips the interactive `yq` install prompt and instead prints the install command. If the script reports that `yq` is missing, relay the printed install command to the user so they can install it themselves.

## Step 4: Inform User

After the script completes, inform the user of the results.

If the script printed the CLAUDE.md import recommendation (it does not modify CLAUDE.md in non-interactive runs), ask the user whether to add the autocode section to the project `CLAUDE.md`. If they agree, append it:

```bash
printf "\n## Autocode\n\n@.claude/autocode.yml\n" >> CLAUDE.md
```

The `@.claude/autocode.yml` import keeps the test and analysis config in context for every session and every spawned agent, without a Read round-trip.

If no justification template was specified, mention the available templates and how to use them.

## Step 5: Require a Restart

End by telling the user explicitly: **restart Claude Code for hooks and settings to take effect.** The `AUTOCODE_PLUGIN_ROOT` env var written to `.claude/settings.local.json` is only read at session start, and the plugin's hooks are only registered when the session loads the plugin. Nothing initialized in this session will work until the restart.
