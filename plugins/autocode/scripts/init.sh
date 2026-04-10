#!/bin/bash

set -e

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR=".claude"

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
    cat > "$CONFIG_TARGET" << 'EOF'
# Autocode Configuration
# See docs for full options: https://github.com/stevenjcumming/autopilot

justification:
  enabled: true

  default:
    enabled: true
    title: "File Modification"
    questions:
      - "What is the purpose of this change?"
      - "Does this change affect other parts of the codebase?"
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

  # Detect OS and offer installation
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v brew &> /dev/null; then
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
      echo "Homebrew not found. Install yq manually:"
      echo "  brew install yq"
      echo "  or: https://github.com/mikefarah/yq#install"
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux
    echo "Install yq? (y/n)"
    read -r INSTALL_YQ
    if [[ "$INSTALL_YQ" == "y" || "$INSTALL_YQ" == "Y" ]]; then
      if command -v snap &> /dev/null; then
        sudo snap install yq
        echo "yq installed successfully via snap"
      elif command -v apt-get &> /dev/null; then
        sudo wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        sudo chmod +x /usr/local/bin/yq
        echo "yq installed successfully"
      else
        echo "Could not auto-install. Install manually:"
        echo "  sudo wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq"
      fi
    else
      echo "Skipping yq installation"
      echo "  Install later with: sudo snap install yq"
    fi
  else
    echo "Unknown OS. Install yq manually:"
    echo "  https://github.com/mikefarah/yq#install"
  fi
fi

# Add specs to gitignore
echo ""
echo "=== Checking .gitignore ==="

if [ -f ".gitignore" ]; then
  if grep -q ".claude/specs" .gitignore 2>/dev/null; then
    echo ".claude/specs already in .gitignore"
  else
    echo "" >> .gitignore
    echo "# Autocode specs (generated)" >> .gitignore
    echo ".claude/specs/" >> .gitignore
    echo "Added .claude/specs/ to .gitignore"
  fi
else
  echo "# Autocode specs (generated)" > .gitignore
  echo ".claude/specs/" >> .gitignore
  echo "Created .gitignore with .claude/specs/"
fi

# Bootstrap AUTOCODE_PLUGIN_ROOT into .claude/settings.local.json
echo ""
echo "=== Bootstrapping Plugin Root ==="

SETTINGS_FILE=".claude/settings.local.json"

# Function to merge env into settings JSON
merge_env_setting() {
  local file="$1"
  local plugin_dir="$2"

  if command -v jq &> /dev/null; then
    # Use jq if available
    if [ -f "$file" ]; then
      local tmp
      tmp=$(jq --arg dir "$plugin_dir" '.env["AUTOCODE_PLUGIN_ROOT"] = $dir' "$file")
      echo "$tmp" > "$file"
    else
      jq -n --arg dir "$plugin_dir" '{"env": {"AUTOCODE_PLUGIN_ROOT": $dir}}' > "$file"
    fi
  elif command -v python3 &> /dev/null; then
    # Fallback to python3
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
data['env']['AUTOCODE_PLUGIN_ROOT'] = plugin_dir
with open(file_path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" "$file" "$plugin_dir"
  else
    echo "WARNING: Neither jq nor python3 found. Cannot write settings."
    echo "  Manually add to $file:"
    echo "  {\"env\": {\"AUTOCODE_PLUGIN_ROOT\": \"$plugin_dir\"}}"
    return 1
  fi
}

merge_env_setting "$SETTINGS_FILE" "$PLUGIN_DIR"

if [ $? -eq 0 ]; then
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

# Create justifications.yml from template if requested
echo ""
echo "=== Justifications Setup ==="

JUSTIFICATION_TARGET="$TARGET_DIR/justifications.yml"
JUSTIFICATION_TEMPLATE_DIR="$PLUGIN_DIR/templates/justifications"

if [ -f "$JUSTIFICATION_TARGET" ]; then
  echo "Justifications config already exists: $JUSTIFICATION_TARGET"
else
  # Check if a template was specified via arguments
  TEMPLATE_NAME="${1:-}"

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
