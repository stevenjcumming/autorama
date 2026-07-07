#!/usr/bin/env bats
#
# review.bats - tests for skills/review/scripts/review.sh: the
# three-section changes summary (committed/uncommitted/untracked) always
# appears, the high-risk scan matches structured frontmatter fields only
# (not risk-mentioning prose), and the artifact-type list (and its count)
# includes handoff.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$PLUGIN_ROOT/skills/review/scripts/review.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/review-bats.XXXXXX")"
  PROJECT_DIR="$TEST_TMPDIR/project"
  mkdir -p "$PROJECT_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

init_repo_with_spec() {
  cd "$PROJECT_DIR"
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "hello" > README.md
  git add README.md
  git commit -q -m "initial commit"

  mkdir -p .specs/demo/artifacts
  echo "# Spec" > .specs/demo/SPEC.md
}

# ------------------------------------------------------------------
# three-section changes summary always appears
# ------------------------------------------------------------------

@test "always shows all three change-summary sections, even with no base branch and no changes" {
  init_repo_with_spec
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  local report=".specs/demo/SUMMARY.md"
  [ -f "$report" ]
  grep -q '^### Committed on Branch$' "$report"
  grep -q '^### Uncommitted$' "$report"
  grep -q '^### Untracked$' "$report"
}

@test "lists untracked and uncommitted files under their respective sections" {
  init_repo_with_spec
  echo "modified" >> README.md
  echo "new file" > untracked.txt
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  local report=".specs/demo/SUMMARY.md"
  awk '/^### Uncommitted$/{f=1;next}/^### /{f=0}f' "$report" | grep -q 'README.md'
  awk '/^### Untracked$/{f=1;next}/^### /{f=0}f' "$report" | grep -q 'untracked.txt'
}

@test "reports 'Not a git repository' summary when run outside a git repo" {
  cd "$PROJECT_DIR"
  mkdir -p .specs/demo/artifacts
  echo "# Spec" > .specs/demo/SPEC.md
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  grep -q 'Not a git repository' ".specs/demo/SUMMARY.md"
}

# ------------------------------------------------------------------
# high-risk scan: structured frontmatter only, not prose
# ------------------------------------------------------------------

@test "high-risk scan matches overall_risk: high frontmatter" {
  init_repo_with_spec
  mkdir -p .specs/demo/artifacts/risks
  cat > .specs/demo/artifacts/risks/r1.md << 'EOF'
---
overall_risk: high
title: Data loss risk in migration
---

Body text.
EOF
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  local report=".specs/demo/SUMMARY.md"
  awk '/^## High-Risk Items$/{f=1;next}/^## /{f=0}f' "$report" | grep -q 'r1.md'
  ! grep -q 'No high-risk items found.' "$report"
}

@test "high-risk scan matches priority: critical frontmatter" {
  init_repo_with_spec
  mkdir -p .specs/demo/artifacts/review_hints
  cat > .specs/demo/artifacts/review_hints/h1.md << 'EOF'
---
priority: critical
title: Review the auth bypass carefully
---

## Files to Review

| File | Lines | Focus |
|------|-------|-------|
| auth.rb | 10-20 | bypass check |
EOF
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  awk '/^## High-Risk Items$/{f=1;next}/^## /{f=0}f' ".specs/demo/SUMMARY.md" | grep -q 'h1.md'
}

@test "high-risk scan does NOT flag risk-mentioning prose without matching frontmatter" {
  init_repo_with_spec
  mkdir -p .specs/demo/artifacts/justifications
  cat > .specs/demo/artifacts/justifications/j1.md << 'EOF'
---
title: Simplify the config loader
---

This change reduces risk overall and follows a high-level design that
keeps the overall_risk of regressions low. priority is not a frontmatter
field here, just prose.
EOF
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  local report=".specs/demo/SUMMARY.md"
  run bash -c "awk '/^## High-Risk Items\$/{f=1;next}/^## /{f=0}f' '$report' | grep -q 'j1.md'"
  [ "$status" -ne 0 ]
  grep -q 'No high-risk items found.' "$report"
}

# ------------------------------------------------------------------
# artifact type list includes handoff
# ------------------------------------------------------------------

@test "artifact count includes the handoff type and rolls up into the total" {
  init_repo_with_spec
  mkdir -p .specs/demo/artifacts/handoff .specs/demo/artifacts/decisions
  echo "handoff body" > .specs/demo/artifacts/handoff/handoff.md
  echo "decision body" > .specs/demo/artifacts/decisions/d1.md
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  local report=".specs/demo/SUMMARY.md"
  grep -qE '^\| handoff \| 1 \|$' "$report"
  grep -qE '^\| decisions \| 1 \|$' "$report"
  grep -q 'Total artifacts: 2' "$report"
}

@test "prints a one-line pointer summary with file/artifact/high-risk counts" {
  init_repo_with_spec
  mkdir -p .specs/demo/artifacts/handoff
  echo "handoff body" > .specs/demo/artifacts/handoff/handoff.md
  run "$SCRIPT" "demo"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Wrote .specs/demo/SUMMARY.md"* ]]
  [[ "$output" == *"1 artifact(s)"* ]]
}

@test "rejects an invalid spec identifier" {
  cd "$PROJECT_DIR"
  run --separate-stderr "$SCRIPT" "bad/id"
  [ "$status" -eq 1 ]
  # review.sh passes its own custom usage message to require_identifier,
  # which is printed instead of lib.sh's default "invalid identifier" text.
  [[ "$stderr" == *"Usage: bash"* ]]
  [[ "$stderr" == *"<spec-identifier>"* ]]
}
