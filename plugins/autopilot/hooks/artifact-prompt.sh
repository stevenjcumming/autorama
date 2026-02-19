#!/bin/bash

set -e

# ============================================================================
# Unified Artifact Prompt Script
# Generates prompts for justification, dependency, risk, debt, and review hints
# Usage: artifact-prompt.sh <agent-type>
#   agent-type: "coder" or "refactorer"
# ============================================================================

AGENT_TYPE="${1:-coder}"

# Check for jq dependency (required)
if ! command -v jq &> /dev/null; then
  echo "Warning: jq not found, skipping artifact prompts" >&2
  exit 0
fi

# Check for yq dependency (optional - enables config customization)
YQ_AVAILABLE=false
if command -v yq &> /dev/null; then
  YQ_AVAILABLE=true
fi

# Config file path
CONFIG_FILE=".claude/autopilot.yml"
CONFIG_LOADED=false

# Prompt counter and limit
PROMPTS_EMITTED=0
MAX_PROMPTS_PER_EDIT=2

# Cache file for recursion prevention
CACHE_FILE="/tmp/.artifact-prompt-cache-$$"
CACHE_TTL=60

# ============================================================================
# Configuration Loading
# ============================================================================

load_config() {
  if [ "$YQ_AVAILABLE" = "true" ] && [ -f "$CONFIG_FILE" ]; then
    # Verify config has valid YAML structure
    if yq -e '.' "$CONFIG_FILE" > /dev/null 2>&1; then
      CONFIG_LOADED=true
    fi
  fi
}

# Artifacts are always enabled (hardcoded)
is_artifacts_enabled() {
  return 0
}

# Check if justification section is present (presence = active)
is_justification_enabled() {
  if [ "$CONFIG_LOADED" = "true" ]; then
    local section
    section=$(yq '.justification // empty' "$CONFIG_FILE" 2>/dev/null)
    if [ -z "$section" ] || [ "$section" = "null" ]; then
      return 1
    fi
  fi
  return 0  # Default: enabled when no config
}

# All artifact types are always enabled (hardcoded)
is_artifact_type_enabled() {
  return 0
}

# ============================================================================
# Recursion Prevention
# ============================================================================

# Check if path should be skipped (recursion prevention)
should_skip_path() {
  local file="$1"

  # Skip artifact directories
  if [[ "$file" == *"/artifacts/"* ]]; then
    return 0
  fi

  # Skip plan directories
  if [[ "$file" == *"/plans/"* ]]; then
    return 0
  fi

  # Skip template directories
  if [[ "$file" == *"/templates/"* ]]; then
    return 0
  fi

  # Skip .claude directory internal files (but not artifacts)
  if [[ "$file" == *".claude/specs/"*"/SPEC.md" ]] || \
     [[ "$file" == *".claude/specs/"*"/PLAN.md" ]] || \
     [[ "$file" == *".claude/specs/"*"/TODO.md" ]]; then
    return 0
  fi

  return 1
}

# Check cache for recent prompts on same file
was_recently_prompted() {
  local file="$1"
  local artifact_type="$2"
  local cache_key="${artifact_type}:${file}"

  # Create cache file if doesn't exist
  touch "$CACHE_FILE" 2>/dev/null || return 1

  # Check if entry exists and is recent
  local now
  now=$(date +%s)
  while IFS='|' read -r ts key; do
    if [ "$key" = "$cache_key" ]; then
      local age=$((now - ts))
      if [ "$age" -lt "$CACHE_TTL" ]; then
        return 0  # Recently prompted
      fi
    fi
  done < "$CACHE_FILE"

  return 1  # Not recently prompted
}

# Add entry to cache
add_to_cache() {
  local file="$1"
  local artifact_type="$2"
  local cache_key="${artifact_type}:${file}"
  local now
  now=$(date +%s)

  echo "${now}|${cache_key}" >> "$CACHE_FILE"

  # Clean old entries (older than CACHE_TTL)
  if [ -f "$CACHE_FILE" ]; then
    local temp_file="${CACHE_FILE}.tmp"
    while IFS='|' read -r ts key; do
      local age=$((now - ts))
      if [ "$age" -lt "$CACHE_TTL" ]; then
        echo "${ts}|${key}"
      fi
    done < "$CACHE_FILE" > "$temp_file" 2>/dev/null
    mv "$temp_file" "$CACHE_FILE" 2>/dev/null || true
  fi
}

# ============================================================================
# File Category Detection (from justify.sh)
# ============================================================================

match_glob() {
  local file="$1"
  local pattern="$2"

  # Simple patterns (no /) match basename only
  if [[ "$pattern" != *"/"* ]]; then
    local basename
    basename=$(basename "$file")
    [[ "$basename" == $pattern ]] && return 0
    return 1
  fi

  # Path patterns - strip leading ./ or / for consistent matching
  local normalized_file
  normalized_file=$(echo "$file" | sed 's|^\./||' | sed 's|^/||')

  # Use bash glob matching
  [[ "$normalized_file" == $pattern ]] && return 0
  return 1
}

get_category_from_config() {
  local file="$1"

  if [ "$CONFIG_LOADED" != "true" ]; then
    return 1
  fi

  # Get list of category names
  local categories
  categories=$(yq -r '.justification.categories | keys | .[]' "$CONFIG_FILE" 2>/dev/null) || return 1

  for category in $categories; do
    # Get patterns for this category
    local patterns
    patterns=$(yq -r ".justification.categories.${category}.patterns[]" "$CONFIG_FILE" 2>/dev/null) || continue

    for pattern in $patterns; do
      if match_glob "$file" "$pattern"; then
        echo "$category"
        return 0
      fi
    done
  done

  # No match found - check if default section is present
  local default_section
  default_section=$(yq '.justification.default // empty' "$CONFIG_FILE" 2>/dev/null)
  if [ -z "$default_section" ] || [ "$default_section" = "null" ]; then
    return 1
  fi

  echo "general"
  return 0
}

get_category_builtin() {
  local file="$1"

  case "$file" in
    *_spec.rb|*_test.rb|*.spec.ts|*.test.ts|*_test.go|*_test.py|*.spec.js|*.test.js)
      echo "spec_modification" ;;
    */db/migrate/*|*/migrations/*)
      echo "migration" ;;
    */Gemfile|*/package.json|*/Cargo.toml|*/go.mod|*/requirements.txt|*/pyproject.toml|*package.json|*Gemfile)
      echo "dependency" ;;
    */config/*.yml|*/config/*.yaml|*.env|*.env.*|*.config.*)
      echo "configuration" ;;
    *_controller.rb|*Controller.ts|*Controller.js|*/api/*|*/controllers/*)
      echo "api_change" ;;
    *auth*|*security*|*permission*|*policy*|*credential*)
      echo "security" ;;
    *)
      echo "general" ;;
  esac
}

get_category() {
  local file="$1"

  if [ "$CONFIG_LOADED" = "true" ]; then
    local category
    category=$(get_category_from_config "$file")
    if [ $? -eq 0 ] && [ -n "$category" ]; then
      echo "$category"
      return 0
    elif [ $? -ne 0 ]; then
      return 1
    fi
  fi

  get_category_builtin "$file"
}

# ============================================================================
# Justification Helpers (from justify.sh)
# ============================================================================

get_title_from_config() {
  local category="$1"

  if [ "$CONFIG_LOADED" != "true" ]; then
    return 1
  fi

  local title
  if [ "$category" = "general" ]; then
    title=$(yq -r '.justification.default.title // empty' "$CONFIG_FILE" 2>/dev/null)
  else
    title=$(yq -r ".justification.categories.${category}.title // empty" "$CONFIG_FILE" 2>/dev/null)
  fi

  if [ -n "$title" ] && [ "$title" != "null" ]; then
    echo "$title"
    return 0
  fi
  return 1
}

get_title_builtin() {
  local category="$1"
  case "$category" in
    spec_modification) echo "Test/Spec Modification" ;;
    migration) echo "Database Migration" ;;
    dependency) echo "Dependency Change" ;;
    configuration) echo "Configuration Change" ;;
    api_change) echo "API/Controller Modification" ;;
    security) echo "Security-Sensitive File" ;;
    *) echo "File Modification" ;;
  esac
}

get_title() {
  local category="$1"

  if [ "$CONFIG_LOADED" = "true" ]; then
    local title
    title=$(get_title_from_config "$category")
    if [ $? -eq 0 ] && [ -n "$title" ]; then
      echo "$title"
      return
    fi
  fi

  get_title_builtin "$category"
}

get_questions_from_config() {
  local category="$1"

  if [ "$CONFIG_LOADED" != "true" ]; then
    return 1
  fi

  local questions
  if [ "$category" = "general" ]; then
    questions=$(yq -r '.justification.default.questions[]' "$CONFIG_FILE" 2>/dev/null)
  else
    questions=$(yq -r ".justification.categories.${category}.questions[]" "$CONFIG_FILE" 2>/dev/null)
  fi

  if [ -n "$questions" ]; then
    echo "$questions" | while read -r question; do
      echo "- [ ] $question"
    done
    return 0
  fi
  return 1
}

get_questions_builtin() {
  local category="$1"
  case "$category" in
    spec_modification)
      cat << 'QUESTIONS'
- [ ] Is this adding new specs for extracted code?
- [ ] Is this refactoring spec structure (no assertion changes)?
- [ ] Is this updating test doubles for extracted collaborators?
- [ ] Is this removing specs for deleted code?
- [ ] Is this fixing specs that tested implementation details?
- [ ] Are you changing assertions to make a failing test pass? **(STOP IF YES)**
QUESTIONS
      ;;
    migration)
      cat << 'QUESTIONS'
- [ ] Is this a new migration?
- [ ] Is this editing an unmigrated migration?
- [ ] Is this editing a deployed migration? **(CREATE NEW MIGRATION INSTEAD)**
QUESTIONS
      ;;
    dependency)
      cat << 'QUESTIONS'
- [ ] Why is this dependency needed?
- [ ] What is the security/maintenance status?
- [ ] Are there lighter alternatives?
- [ ] Does this require approval (e.g., enterprise requirements)?
QUESTIONS
      ;;
    configuration)
      cat << 'QUESTIONS'
- [ ] What behavior does this change?
- [ ] Does this affect production?
- [ ] Are secrets or credentials involved?
- [ ] Is this environment-specific?
QUESTIONS
      ;;
    api_change)
      cat << 'QUESTIONS'
- [ ] Does this change the API contract?
- [ ] Are there frontend/mobile consumers to coordinate with?
- [ ] Is this endpoint versioned?
- [ ] Is this a breaking change?
QUESTIONS
      ;;
    security)
      cat << 'QUESTIONS'
- [ ] What security implications does this change have?
- [ ] Have you verified this doesn't weaken access controls?
- [ ] Does this need security review?
QUESTIONS
      ;;
    *)
      cat << 'QUESTIONS'
- [ ] What is the purpose of this change?
- [ ] Does this change affect other parts of the codebase?
- [ ] Is this change reversible?
QUESTIONS
      ;;
  esac
}

get_questions() {
  local category="$1"

  if [ "$CONFIG_LOADED" = "true" ]; then
    local questions
    questions=$(get_questions_from_config "$category")
    if [ $? -eq 0 ] && [ -n "$questions" ]; then
      echo "$questions"
      return
    fi
  fi

  get_questions_builtin "$category"
}

# ============================================================================
# New Artifact Detection Functions
# ============================================================================

# Detect if file is in a shared code path (for dependency analysis)
detect_dependency() {
  local file="$1"

  # Hardcoded shared code patterns
  local patterns="lib/**/*
shared/**/*
common/**/*
utils/**/*
helpers/**/*
core/**/*
foundation/**/*"

  # Normalize file path
  local normalized_file
  normalized_file=$(echo "$file" | sed 's|^\./||' | sed 's|^/||')

  # Check each pattern
  echo "$patterns" | while read -r pattern; do
    [ -z "$pattern" ] && continue
    if match_glob "$normalized_file" "$pattern"; then
      echo "shared"
      return 0
    fi
  done

  return 1
}

# Detect if file category indicates high risk (for coder only)
detect_risk() {
  local category="$1"

  if [ "$AGENT_TYPE" != "coder" ]; then
    return 1  # Refactorer doesn't generate risk artifacts
  fi

  # Hardcoded high-risk categories
  local risk_categories="security
migration
api_change"

  # Check if current category is high-risk
  echo "$risk_categories" | while read -r risk_cat; do
    [ -z "$risk_cat" ] && continue
    if [ "$category" = "$risk_cat" ]; then
      echo "high_risk"
      return 0
    fi
  done

  return 1
}

# Detect if file contains debt markers (for refactorer only)
detect_debt() {
  local file="$1"

  if [ "$AGENT_TYPE" != "refactorer" ]; then
    return 1  # Coder doesn't get debt prompts from hook
  fi

  # File must exist and be readable
  if [ ! -f "$file" ]; then
    return 1
  fi

  # Hardcoded debt markers
  local markers="TODO
FIXME
HACK
XXX"

  # Hardcoded threshold
  local threshold=1

  # Count markers in file
  local count=0
  for marker in $markers; do
    [ -z "$marker" ] && continue
    local marker_count
    marker_count=$(grep -c "$marker" "$file" 2>/dev/null || echo "0")
    count=$((count + marker_count))
  done

  if [ "$count" -ge "$threshold" ]; then
    echo "debt_markers:$count"
    return 0
  fi

  return 1
}

# Detect if file category indicates need for review hint
detect_review_hint() {
  local category="$1"

  # Hardcoded review hint categories
  local review_categories="security
migration
api_change"

  # Check if current category needs review
  echo "$review_categories" | while read -r review_cat; do
    [ -z "$review_cat" ] && continue
    if [ "$category" = "$review_cat" ]; then
      echo "needs_review"
      return 0
    fi
  done

  return 1
}

# ============================================================================
# Spec Directory Detection
# ============================================================================

detect_spec_dir() {
  local file="$1"

  # Try to extract spec dir from environment or file path
  if [ -n "$SPEC_DIR" ]; then
    echo "$SPEC_DIR"
    return 0
  fi

  # Look for .claude/specs directories
  if [ -d ".claude/specs" ]; then
    # Find the most recently modified spec
    local latest_spec
    latest_spec=$(ls -td .claude/specs/*/ 2>/dev/null | head -1)
    if [ -n "$latest_spec" ]; then
      echo "${latest_spec%/}"
      return 0
    fi
  fi

  # Fallback to .claude
  echo ".claude"
}

# ============================================================================
# Prompt Emission Functions
# ============================================================================

can_emit_prompt() {
  if [ "$PROMPTS_EMITTED" -ge "$MAX_PROMPTS_PER_EDIT" ]; then
    return 1
  fi
  return 0
}

increment_prompt_count() {
  PROMPTS_EMITTED=$((PROMPTS_EMITTED + 1))
}

emit_justification_prompt() {
  local file="$1"
  local category="$2"
  local tool_name="$3"
  local spec_dir="$4"

  if ! can_emit_prompt; then
    return 1
  fi

  if was_recently_prompted "$file" "justification"; then
    return 1
  fi

  # Generate timestamps
  local file_timestamp
  file_timestamp=$(date '+%Y%m%d_%H%M%S')
  local iso_timestamp
  iso_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  # Generate safe path for filename
  local safe_path
  safe_path=$(echo "$file" | sed 's|^\./||' | sed 's|^/||' | tr '/' '_' | tr '.' '_')

  local title
  title=$(get_title "$category")
  local questions
  questions=$(get_questions "$category")

  # Create output directory
  local output_dir="${spec_dir}/artifacts/justifications"
  mkdir -p "$output_dir"

  local output_file="${output_dir}/${file_timestamp}_${tool_name}_${safe_path}.md"
  local session_id="${CLAUDE_SESSION_ID:-unknown}"

  # Write template file
  cat > "$output_file" << EOF
---
category: ${category}
file: ${file}
tool: ${tool_name}
timestamp: ${iso_timestamp}
session: ${session_id}
---

## ${title}

**File:** \`${file}\`

### Checklist
${questions}

### Justification

### Alternatives Considered

### Risk Assessment
EOF

  # Output XML prompt
  cat << EOF

<justification-required>
## Justification Required: ${title}

**File:** \`${file}\`
**Category:** ${category}
**Output:** ${output_file}

### Checklist (answer each)
${questions}

### Provide:
1. **Justification** - Why is this change necessary?
2. **Alternatives** - What other approaches were considered? (or "None" if straightforward)
3. **Risk** - Low/Medium/High and why?

Respond with the justification, then use Edit to append your answers to ${output_file}
</justification-required>
EOF

  add_to_cache "$file" "justification"
  increment_prompt_count
  return 0
}

emit_dependency_prompt() {
  local file="$1"
  local tool_name="$2"
  local spec_dir="$3"

  if ! can_emit_prompt; then
    return 1
  fi

  if was_recently_prompted "$file" "dependency"; then
    return 1
  fi

  local file_timestamp
  file_timestamp=$(date '+%Y%m%d_%H%M%S')
  local iso_timestamp
  iso_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  local safe_path
  safe_path=$(echo "$file" | sed 's|^\./||' | sed 's|^/||' | tr '/' '_' | tr '.' '_')

  local output_dir="${spec_dir}/artifacts/dependencies"
  mkdir -p "$output_dir"

  local output_file="${output_dir}/${file_timestamp}_${safe_path}.md"

  # Write template file
  cat > "$output_file" << EOF
---
title: Dependency Analysis for ${file}
date: ${iso_timestamp}
type: internal
---

## Dependency Analysis

### Source

**File:** \`${file}\`
**Component:**

### Depends On

| Dependency | Type | Coupling |
|------------|------|----------|

### Impact of Change

### Alternatives

### Migration Path
EOF

  # Output XML prompt
  cat << EOF

<dependency-required>
## Dependency Analysis Required

**File:** \`${file}\`
**Reason:** This file is in a shared code location
**Output:** ${output_file}

### Provide:
1. **Component** - What component/module is this?
2. **Dependencies** - What does this code depend on? (internal/external, tight/loose coupling)
3. **Impact** - What breaks if this changes?
4. **Alternatives** - Other ways to achieve this without the dependency?

Use Edit to complete the dependency analysis in ${output_file}
</dependency-required>
EOF

  add_to_cache "$file" "dependency"
  increment_prompt_count
  return 0
}

emit_risk_prompt() {
  local file="$1"
  local category="$2"
  local tool_name="$3"
  local spec_dir="$4"

  if ! can_emit_prompt; then
    return 1
  fi

  if was_recently_prompted "$file" "risk"; then
    return 1
  fi

  local file_timestamp
  file_timestamp=$(date '+%Y%m%d_%H%M%S')
  local iso_timestamp
  iso_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  local safe_path
  safe_path=$(echo "$file" | sed 's|^\./||' | sed 's|^/||' | tr '/' '_' | tr '.' '_')

  local output_dir="${spec_dir}/artifacts/risks"
  mkdir -p "$output_dir"

  local output_file="${output_dir}/${file_timestamp}_${safe_path}.md"

  # Write template file
  cat > "$output_file" << EOF
---
title: Risk Assessment for ${file}
date: ${iso_timestamp}
overall_risk: medium
---

## Risk Summary

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|

## Details

### Description

### Trigger Conditions

### Impact Analysis

### Mitigation Strategy

## Rollback Plan
EOF

  # Output XML prompt
  cat << EOF

<risk-required>
## Risk Assessment Required

**File:** \`${file}\`
**Category:** ${category} (high-risk category)
**Output:** ${output_file}

### Provide:
1. **Risk Summary** - What could go wrong?
2. **Likelihood** - Low/Medium/High
3. **Impact** - Low/Medium/High
4. **Mitigation** - How to reduce the risk
5. **Rollback Plan** - How to undo if needed

Use Edit to complete the risk assessment in ${output_file}
</risk-required>
EOF

  add_to_cache "$file" "risk"
  increment_prompt_count
  return 0
}

emit_debt_prompt() {
  local file="$1"
  local marker_info="$2"
  local spec_dir="$3"

  if ! can_emit_prompt; then
    return 1
  fi

  if was_recently_prompted "$file" "debt"; then
    return 1
  fi

  local marker_count
  marker_count=$(echo "$marker_info" | cut -d: -f2)

  local file_timestamp
  file_timestamp=$(date '+%Y%m%d_%H%M%S')
  local iso_timestamp
  iso_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  local safe_path
  safe_path=$(echo "$file" | sed 's|^\./||' | sed 's|^/||' | tr '/' '_' | tr '.' '_')

  local output_dir="${spec_dir}/artifacts/debt"
  mkdir -p "$output_dir"

  local output_file="${output_dir}/${file_timestamp}_${safe_path}.md"

  # Write template file
  cat > "$output_file" << EOF
---
title: Technical Debt in ${file}
date: ${iso_timestamp}
type: code
severity: medium
effort_to_fix: medium
---

## What Is the Debt?

**Markers Found:** ${marker_count} (TODO/FIXME/HACK/XXX)

## Why Was It Taken?

## Location

**File(s):** \`${file}\`
**Lines:**

## Ideal Implementation

## Payback Plan

## Risk if Not Addressed
EOF

  # Output XML prompt
  cat << EOF

<debt-required>
## Technical Debt Documentation Required

**File:** \`${file}\`
**Markers Found:** ${marker_count} TODO/FIXME/HACK/XXX markers
**Output:** ${output_file}

### Provide:
1. **What Is the Debt?** - Describe the shortcuts or incomplete work
2. **Why Was It Taken?** - Justification for the shortcut
3. **Location** - Specific lines with markers
4. **Ideal Implementation** - What should be done instead
5. **Severity** - low/medium/high

Use Edit to complete the debt documentation in ${output_file}
</debt-required>
EOF

  add_to_cache "$file" "debt"
  increment_prompt_count
  return 0
}

emit_review_hint_prompt() {
  local file="$1"
  local category="$2"
  local spec_dir="$3"

  if ! can_emit_prompt; then
    return 1
  fi

  if was_recently_prompted "$file" "review_hint"; then
    return 1
  fi

  local file_timestamp
  file_timestamp=$(date '+%Y%m%d_%H%M%S')
  local iso_timestamp
  iso_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

  local safe_path
  safe_path=$(echo "$file" | sed 's|^\./||' | sed 's|^/||' | tr '/' '_' | tr '.' '_')

  local output_dir="${spec_dir}/artifacts/review_hints"
  mkdir -p "$output_dir"

  local output_file="${output_dir}/${file_timestamp}_${safe_path}.md"

  # Write template file
  cat > "$output_file" << EOF
---
title: Review Hint for ${file}
date: ${iso_timestamp}
priority: medium
category: ${category}
---

## Why Human Review Is Needed

## Files to Review

| File | Lines | Focus Area |
|------|-------|------------|
| \`${file}\` | | |

## Specific Questions

1.
2.

## Context

## Recommendation
EOF

  # Output XML prompt
  cat << EOF

<review-hint-required>
## Human Review Hint Required

**File:** \`${file}\`
**Category:** ${category} (sensitive category)
**Output:** ${output_file}

### Provide:
1. **Why Review Needed** - What can't be validated automatically?
2. **Focus Area** - What specific lines/sections need attention?
3. **Questions** - What should the reviewer verify?
4. **Priority** - low/medium/high/critical

Use Edit to complete the review hint in ${output_file}
</review-hint-required>
EOF

  add_to_cache "$file" "review_hint"
  increment_prompt_count
  return 0
}

# ============================================================================
# Main Script
# ============================================================================

# Read JSON input from stdin
INPUT=$(cat)

# Extract tool name and file path using jq
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // empty')

# Exit silently if we couldn't extract necessary info
if [ -z "$TOOL_NAME" ] || [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Check recursion prevention
if should_skip_path "$FILE_PATH"; then
  exit 0
fi

# Load configuration
load_config

# Check if artifacts are globally enabled
if ! is_artifacts_enabled; then
  # Still allow justifications if they have their own config
  if ! is_justification_enabled; then
    exit 0
  fi
fi

# Get file category
CATEGORY=$(get_category "$FILE_PATH")
if [ $? -ne 0 ] || [ -z "$CATEGORY" ]; then
  exit 0
fi

# Detect spec directory
SPEC_DIR=$(detect_spec_dir "$FILE_PATH")

# ============================================================================
# Emit Prompts Based on Agent Type and Detection
# Priority order: justification > dependency > risk > debt > review_hint
# ============================================================================

# 1. Justification (both coder and refactorer)
if is_justification_enabled; then
  emit_justification_prompt "$FILE_PATH" "$CATEGORY" "$TOOL_NAME" "$SPEC_DIR"
fi

# 2. Dependency Analysis (both coder and refactorer, shared-code paths)
dependency_result=$(detect_dependency "$FILE_PATH")
if [ -n "$dependency_result" ]; then
  emit_dependency_prompt "$FILE_PATH" "$TOOL_NAME" "$SPEC_DIR"
fi

# 3. Risk (coder only, high-risk categories)
risk_result=$(detect_risk "$CATEGORY")
if [ -n "$risk_result" ]; then
  emit_risk_prompt "$FILE_PATH" "$CATEGORY" "$TOOL_NAME" "$SPEC_DIR"
fi

# 4. Debt (refactorer only, TODO/FIXME markers)
debt_result=$(detect_debt "$FILE_PATH")
if [ -n "$debt_result" ]; then
  emit_debt_prompt "$FILE_PATH" "$debt_result" "$SPEC_DIR"
fi

# 5. Review Hint (both coder and refactorer, sensitive categories)
review_result=$(detect_review_hint "$CATEGORY")
if [ -n "$review_result" ]; then
  emit_review_hint_prompt "$FILE_PATH" "$CATEGORY" "$SPEC_DIR"
fi

exit 0
