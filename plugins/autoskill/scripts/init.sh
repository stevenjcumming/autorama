#!/bin/bash

set -e

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS_FILE=".claude/settings.local.json"

echo "=== Autoskill Initialization ==="
echo ""

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

  if command -v jq &> /dev/null; then
    if [ -f "$file" ]; then
      local tmp
      tmp=$(jq --arg dir "$plugin_dir" '.env["AUTOSKILL_PLUGIN_ROOT"] = $dir' "$file")
      echo "$tmp" > "$file"
    else
      jq -n --arg dir "$plugin_dir" '{"env": {"AUTOSKILL_PLUGIN_ROOT": $dir}}' > "$file"
    fi
  elif command -v python3 &> /dev/null; then
    python3 -c "
import json, os, sys
file_path = sys.argv[1]
plugin_dir = sys.argv[2]
data = {}
if os.path.exists(file_path):
    with open(file_path) as f:
        data = json.load(f)
if 'env' not in data:
    data['env'] = {}
data['env']['AUTOSKILL_PLUGIN_ROOT'] = plugin_dir
with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$file" "$plugin_dir"
  else
    echo "WARNING: Neither jq nor python3 found. Cannot write settings."
    echo "  Manually add to $file:"
    echo "  {\"env\": {\"AUTOSKILL_PLUGIN_ROOT\": \"$plugin_dir\"}}"
    return 1
  fi
}

merge_env_setting "$SETTINGS_FILE" "$PLUGIN_DIR"

if [ $? -eq 0 ]; then
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
