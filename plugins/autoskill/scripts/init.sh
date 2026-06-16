#!/usr/bin/env bash

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE=".claude/settings.local.json"

echo "=== Autoskill Initialization ==="
echo ""

# Guard the cwd assumption: SETTINGS_FILE is written relative to the current
# directory, so running from a subdirectory would silently create a stray
# .claude/ folder there.
# Compare physical paths (pwd -P): git returns symlink-resolved paths, so a
# logical pwd would false-positive under e.g. macOS /var -> /private/var.
GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [ -n "$GIT_ROOT" ] && [ "$GIT_ROOT" != "$(pwd -P)" ]; then
  echo "ERROR: Run this script from the project root: $GIT_ROOT"
  echo "  $SETTINGS_FILE is written relative to the current directory."
  exit 1
fi
if [ -z "$GIT_ROOT" ] && [ ! -d ".claude" ]; then
  echo "NOTE: No git repository or .claude directory found here."
  echo "  Settings will be created at $(pwd)/$SETTINGS_FILE"
fi

# Create .claude directory if it doesn't exist
if [ ! -d ".claude" ]; then
  mkdir -p ".claude"
  echo "Created .claude directory"
fi

# Merge AUTOSKILL_PLUGIN_ROOT into settings.local.json
echo "=== Bootstrapping Plugin Root ==="

merge_env_setting() {
  local file="$1"
  local plugin_dir="$2"
  local tmp

  if command -v jq &> /dev/null; then
    if [ -f "$file" ]; then
      if ! jq empty "$file" 2>/dev/null; then
        echo "ERROR: $file exists but is not valid JSON."
        echo "  Fix or remove the file, then re-run this script."
        return 1
      fi
      tmp="$(mktemp)"
      jq --arg dir "$plugin_dir" '.env["AUTOSKILL_PLUGIN_ROOT"] = $dir' "$file" > "$tmp"
      mv "$tmp" "$file"
    else
      tmp="$(mktemp)"
      jq -n --arg dir "$plugin_dir" '{"env": {"AUTOSKILL_PLUGIN_ROOT": $dir}}' > "$tmp"
      mv "$tmp" "$file"
    fi
  elif command -v python3 &> /dev/null; then
    python3 -c "
import json, os, sys
file_path = sys.argv[1]
plugin_dir = sys.argv[2]
data = {}
if os.path.exists(file_path):
    try:
        with open(file_path) as f:
            data = json.load(f)
    except ValueError:
        print('ERROR: %s exists but is not valid JSON.' % file_path)
        print('  Fix or remove the file, then re-run this script.')
        sys.exit(1)
data.setdefault('env', {})['AUTOSKILL_PLUGIN_ROOT'] = plugin_dir
tmp_path = file_path + '.tmp'
with open(tmp_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(tmp_path, file_path)
" "$file" "$plugin_dir"
  else
    echo "WARNING: Neither jq nor python3 found. Cannot write settings."
    echo "  Manually add to $file:"
    echo "  {\"env\": {\"AUTOSKILL_PLUGIN_ROOT\": \"$plugin_dir\"}}"
    return 1
  fi
}

if merge_env_setting "$SETTINGS_FILE" "$PLUGIN_DIR"; then
  echo "Set AUTOSKILL_PLUGIN_ROOT=$PLUGIN_DIR"
  echo "  in $SETTINGS_FILE"
else
  echo "Failed to write settings. See above for manual instructions."
fi

echo ""
echo "=== Initialization Complete ==="
echo ""
echo "Next steps:"
echo "  1. Restart your Claude Code session for the new environment variable to take effect"
echo "  2. Run /autoskill:build to generate skills from your codebase patterns"
echo ""
