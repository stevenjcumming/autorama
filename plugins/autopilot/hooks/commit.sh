#!/bin/bash

set -e

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  exit 0
fi

# Check for git
if ! command -v git &> /dev/null; then
  exit 0
fi

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool name and file path using jq
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Skip if not a file-modifying tool
case "$TOOL_NAME" in
  Write|Edit)
    # These tools modify files, continue
    ;;
  Bash)
    # Only trigger for Bash commands that might modify files
    # Skip git commands (handled by sync-pr), read-only commands, and other safe operations
    if [[ "$COMMAND" =~ ^(git|cat|head|tail|ls|find|grep|rg|echo|pwd|cd|which|type|test|true|false|:|read|printf|env|export|source|\.) ]]; then
      exit 0
    fi
    # Skip if command starts with these read patterns
    if [[ "$COMMAND" =~ ^(npm\ (list|ls|info|view|show|outdated|search|help)|yarn\ (list|info|why|help)|pip\ (list|show|freeze|check|help)|cargo\ (tree|metadata|help)|go\ (list|mod\ graph|mod\ why|help)) ]]; then
      exit 0
    fi
    ;;
  *)
    # Not a file-modifying tool
    exit 0
    ;;
esac

# Exit silently if we couldn't extract necessary info
if [ -z "$TOOL_NAME" ]; then
  exit 0
fi

# Skip .claude/ directory files (internal operations)
if [ -n "$FILE_PATH" ]; then
  if [[ "$FILE_PATH" == *".claude/"* ]]; then
    exit 0
  fi
fi

# Check if we're in a git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
  exit 0
fi

# Check if there are any uncommitted changes (staged or unstaged)
if git diff --quiet && git diff --cached --quiet; then
  # No changes to commit
  exit 0
fi

# Check for untracked files (excluding .claude/ directory)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | grep -v "^\.claude/" || true)
MODIFIED=$(git diff --name-only 2>/dev/null | grep -v "^\.claude/" || true)
STAGED=$(git diff --cached --name-only 2>/dev/null | grep -v "^\.claude/" || true)

# If all changes are in .claude/ directory, skip
if [ -z "$UNTRACKED" ] && [ -z "$MODIFIED" ] && [ -z "$STAGED" ]; then
  exit 0
fi

# Output skill invocation directive
cat << 'EOF'

<skill-invoke skill="commit">
Uncommitted changes detected. Create a commit for the changes made.
</skill-invoke>
EOF
