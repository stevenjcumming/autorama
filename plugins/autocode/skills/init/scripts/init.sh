#!/usr/bin/env bash

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR=".claude"

# Parse arguments: accept both `init.sh <template>` and
# `init.sh --justifications <template>`
TEMPLATE_NAME=""
if [ "${1:-}" = "--justifications" ]; then
  TEMPLATE_NAME="${2:-}"
else
  TEMPLATE_NAME="${1:-}"
fi

echo "=== Autocode Initialization ==="
echo ""

# Create .claude directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR"
  echo "Created $TARGET_DIR directory"
fi

# Copy autocode.yml configuration
CONFIG_SOURCE="$PLUGIN_DIR/templates/autocode.yml"
CONFIG_TARGET="$TARGET_DIR/autocode.yml"

if [ -f "$CONFIG_TARGET" ]; then
  echo "Config already exists: $CONFIG_TARGET"
  echo "  (delete it manually if you want to reset to defaults)"
else
  if [ -f "$CONFIG_SOURCE" ]; then
    cp "$CONFIG_SOURCE" "$CONFIG_TARGET"
    echo "Created config: $CONFIG_TARGET"
  else
    # Fallback: create minimal config if template not found
    # (schema matches templates/autocode.yml: justification.default has
    # title and questions only)
    cat > "$CONFIG_TARGET" << 'EOF'
# Autocode Configuration
# See docs for full options: https://github.com/stevenjcumming/autorama

justification:
  # Default behavior for files that don't match any category
  default:
    title: "File Modification"
    questions:
      - "What is the purpose of this change?"
      - "Does this change affect other parts of the codebase?"
      - "Is this change reversible?"
EOF
    echo "Created minimal config: $CONFIG_TARGET"
  fi
fi

# Check for yq
echo ""
echo "=== Checking Dependencies ==="

if command -v yq &> /dev/null; then
  YQ_VERSION=$(yq --version 2>&1 | head -1)
  echo "yq is installed: $YQ_VERSION"
else
  echo "yq is not installed (optional - enables config customization)"
  echo ""

  # Detect OS and suggest installation. Prompts only run on a terminal;
  # non-interactive sessions print the command and continue. Privileged
  # (sudo) installs are never executed by this script.
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
      if [ -t 0 ]; then
        echo "Install yq with Homebrew? (y/n)"
        read -r INSTALL_YQ
        if [[ "$INSTALL_YQ" == "y" || "$INSTALL_YQ" == "Y" ]]; then
          brew install yq
          echo "yq installed successfully"
        else
          echo "Skipping yq installation"
          echo "  Install later with: brew install yq"
        fi
      else
        echo "Non-interactive session; skipping yq installation."
        echo "  Install later with: brew install yq"
      fi
    else
      echo "Homebrew not found. Install yq manually:"
      echo "  brew install yq"
      echo "  or: https://github.com/mikefarah/yq#install"
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux: installation needs sudo, which this script never runs.
    # Print the commands for the user instead.
    echo "Install yq manually with one of:"
    if command -v snap &> /dev/null; then
      echo "  sudo snap install yq"
    fi
    echo "  sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 && sudo chmod +x /usr/local/bin/yq"
    echo "  or: https://github.com/mikefarah/yq#install"
  else
    echo "Unknown OS. Install yq manually:"
    echo "  https://github.com/mikefarah/yq#install"
  fi
fi

# Add specs to gitignore
echo ""
echo "=== Checking .gitignore ==="

if [ -f ".gitignore" ]; then
  if grep -qxF ".specs/" .gitignore 2>/dev/null; then
    echo ".specs/ already in .gitignore"
  else
    echo "" >> .gitignore
    echo "# Autocode specs (generated)" >> .gitignore
    echo ".specs/" >> .gitignore
    echo "Added .specs/ to .gitignore"
  fi
else
  echo "# Autocode specs (generated)" > .gitignore
  echo ".specs/" >> .gitignore
  echo "Created .gitignore with .specs/"
fi

# Bootstrap AUTOCODE_PLUGIN_ROOT into .claude/settings.local.json
echo ""
echo "=== Bootstrapping Plugin Root ==="

SETTINGS_FILE=".claude/settings.local.json"

# Function to merge env into settings JSON
merge_env_setting() {
  local file="$1"
  local plugin_dir="$2"
  local tmp

  if command -v jq &> /dev/null; then
    # Use jq if available; write to a temp file and mv so a mid-write
    # failure cannot truncate the user's settings
    tmp=$(mktemp "${file}.XXXXXX")
    if [ -f "$file" ]; then
      if ! jq --arg dir "$plugin_dir" '.env["AUTOCODE_PLUGIN_ROOT"] = $dir' "$file" > "$tmp"; then
        rm -f "$tmp"
        return 1
      fi
    else
      if ! jq -n --arg dir "$plugin_dir" '{"env": {"AUTOCODE_PLUGIN_ROOT": $dir}}' > "$tmp"; then
        rm -f "$tmp"
        return 1
      fi
    fi
    mv "$tmp" "$file"
  elif command -v python3 &> /dev/null; then
    # Fallback to python3 (same temp-file-then-replace approach)
    python3 -c "
import json, os, sys, tempfile
file_path = sys.argv[1]
plugin_dir = sys.argv[2]
data = {}
if os.path.exists(file_path):
    with open(file_path) as f:
        data = json.load(f)
if 'env' not in data:
    data['env'] = {}
data['env']['AUTOCODE_PLUGIN_ROOT'] = plugin_dir
fd, tmp = tempfile.mkstemp(dir=os.path.dirname(file_path) or '.')
with os.fdopen(fd, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
os.replace(tmp, file_path)
" "$file" "$plugin_dir"
  else
    echo "WARNING: Neither jq nor python3 found. Cannot write settings."
    echo "  Manually add to $file:"
    echo "  {\"env\": {\"AUTOCODE_PLUGIN_ROOT\": \"$plugin_dir\"}}"
    return 1
  fi
}

if merge_env_setting "$SETTINGS_FILE" "$PLUGIN_DIR"; then
  echo "Set AUTOCODE_PLUGIN_ROOT=$PLUGIN_DIR"
  echo "  in $SETTINGS_FILE"
else
  echo "Failed to write settings. See above for manual instructions."
fi

# Ensure CLAUDE_PLUGIN_DATA directory exists for persistent storage
echo ""
echo "=== Plugin Data Directory ==="

if [ -n "${CLAUDE_PLUGIN_DATA:-}" ]; then
  mkdir -p "$CLAUDE_PLUGIN_DATA"
  echo "Plugin data directory: $CLAUDE_PLUGIN_DATA"
  echo "  Usage logs, failure history, and cross-spec data are stored here."
else
  echo "CLAUDE_PLUGIN_DATA is not set (set automatically by Claude Code for installed plugins)."
  echo "  Usage logging and cross-spec persistence will be available once the plugin is installed."
fi

# Offer to import autocode.yml from the project CLAUDE.md so every
# session (and every spawned agent that inherits project context) sees
# the test/analysis config without a Read round-trip.
echo ""
echo "=== CLAUDE.md Import ==="

CLAUDE_MD="CLAUDE.md"
IMPORT_BLOCK="## Autocode

@.claude/autocode.yml"

append_claude_import() {
  if [ -f "$CLAUDE_MD" ]; then
    printf '\n%s\n' "$IMPORT_BLOCK" >> "$CLAUDE_MD"
    echo "Appended autocode section (with @.claude/autocode.yml import) to $CLAUDE_MD"
  else
    printf '%s\n' "$IMPORT_BLOCK" > "$CLAUDE_MD"
    echo "Created $CLAUDE_MD with the @.claude/autocode.yml import"
  fi
}

if [ -f "$CLAUDE_MD" ] && grep -qF "@.claude/autocode.yml" "$CLAUDE_MD" 2>/dev/null; then
  echo "$CLAUDE_MD already imports .claude/autocode.yml"
elif [ -t 0 ]; then
  echo "Add an autocode section to $CLAUDE_MD that imports @.claude/autocode.yml?"
  echo "  (keeps the config in context for every session and agent) (y/n)"
  read -r ADD_IMPORT
  if [[ "$ADD_IMPORT" == "y" || "$ADD_IMPORT" == "Y" ]]; then
    append_claude_import
  else
    echo "Skipping. Add manually later by appending to $CLAUDE_MD:"
    printf '  %s\n' "## Autocode" "" "  @.claude/autocode.yml"
  fi
else
  echo "Non-interactive session; not modifying $CLAUDE_MD."
  echo "  Recommended: append this to $CLAUDE_MD so the config loads every session:"
  printf '  %s\n' "## Autocode" "" "  @.claude/autocode.yml"
fi

# Create justifications.yml from template if requested
echo ""
echo "=== Justifications Setup ==="

JUSTIFICATION_TARGET="$TARGET_DIR/justifications.yml"
JUSTIFICATION_TEMPLATE_DIR="$PLUGIN_DIR/templates/justifications"

if [ -f "$JUSTIFICATION_TARGET" ]; then
  echo "Justifications config already exists: $JUSTIFICATION_TARGET"
else
  if [ -n "$TEMPLATE_NAME" ]; then
    TEMPLATE_FILE="$JUSTIFICATION_TEMPLATE_DIR/$TEMPLATE_NAME.yml"
    if [ -f "$TEMPLATE_FILE" ]; then
      cp "$TEMPLATE_FILE" "$JUSTIFICATION_TARGET"
      echo "Created justifications config from template: $TEMPLATE_NAME"
      echo "  $JUSTIFICATION_TARGET"
    else
      echo "WARNING: Template not found: $TEMPLATE_NAME"
      echo "  Available templates:"
      for t in "$JUSTIFICATION_TEMPLATE_DIR"/*.yml; do
        [ -f "$t" ] && echo "    - $(basename "$t" .yml)"
      done
    fi
  else
    echo "No justification template specified."
    echo "  Available templates:"
    for t in "$JUSTIFICATION_TEMPLATE_DIR"/*.yml; do
      [ -f "$t" ] && echo "    - $(basename "$t" .yml)"
    done
    echo ""
    echo "  To use a template, run: /autocode:init --justifications <template>"
    echo "  Example: /autocode:init --justifications rails"
  fi
fi

echo ""
echo "=== Initialization Complete ==="
echo ""
echo "Next steps:"
echo "  1. Customize $CONFIG_TARGET (optional)"
echo "  2. Run /autocode:new-spec <identifier> to start a feature"
echo ""
