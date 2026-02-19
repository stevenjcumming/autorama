#!/bin/bash

set -e

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR=".claude"

echo "=== Autopilot Initialization ==="
echo ""

# Create .claude directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
  mkdir -p "$TARGET_DIR"
  echo "Created $TARGET_DIR directory"
fi

# Copy autopilot.yml configuration
CONFIG_SOURCE="$PLUGIN_DIR/templates/autopilot.yml"
CONFIG_TARGET="$TARGET_DIR/autopilot.yml"

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
# Autopilot Configuration
# See docs for full options: https://github.com/stevenjcumming/claude-code-autopilot

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
    echo "# Autopilot specs (generated)" >> .gitignore
    echo ".claude/specs/" >> .gitignore
    echo "Added .claude/specs/ to .gitignore"
  fi
else
  echo "# Autopilot specs (generated)" > .gitignore
  echo ".claude/specs/" >> .gitignore
  echo "Created .gitignore with .claude/specs/"
fi

echo ""
echo "=== Initialization Complete ==="
echo ""
echo "Next steps:"
echo "  1. Customize $CONFIG_TARGET (optional)"
echo "  2. Run /autopilot:new-spec <identifier> to start a feature"
echo ""
