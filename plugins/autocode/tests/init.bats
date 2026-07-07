#!/usr/bin/env bats
#
# init.bats - tests for skills/init/scripts/init.sh: PLUGIN_DIR
# self-resolution (script invoked from its real relative location, no
# --plugin-root override needed), the templates/ abort guard, and
# .gitignore variant detection for .specs / .specs/ / /.specs/.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  SCRIPT="$PLUGIN_ROOT/skills/init/scripts/init.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/init-bats.XXXXXX")"
  PROJECT_DIR="$TEST_TMPDIR/project"
  mkdir -p "$PROJECT_DIR"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ------------------------------------------------------------------
# PLUGIN_DIR self-resolution (real script invoked in place, no override)
# ------------------------------------------------------------------

@test "self-resolves PLUGIN_DIR from its real location and scaffolds .claude/autocode.yml from the real template" {
  cd "$PROJECT_DIR"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"=== Autocode Initialization ==="* ]]
  [ -f "$PROJECT_DIR/.claude/autocode.yml" ]
  # scaffolded config is byte-identical to the real shipped template,
  # proving PLUGIN_DIR resolved to the real plugin root via ../../../
  diff -q "$PROJECT_DIR/.claude/autocode.yml" "$PLUGIN_ROOT/templates/autocode.yml"
}

@test "self-resolution: bootstraps AUTOCODE_PLUGIN_ROOT pointing at the real plugin root" {
  cd "$PROJECT_DIR"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.claude/settings.local.json" ]
  root_in_settings="$(jq -r '.env.AUTOCODE_PLUGIN_ROOT' "$PROJECT_DIR/.claude/settings.local.json")"
  [ "$root_in_settings" = "$PLUGIN_ROOT" ]
}

@test "adds .specs/ to a newly created .gitignore" {
  cd "$PROJECT_DIR"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -f "$PROJECT_DIR/.gitignore" ]
  grep -qxE '\.specs/?' "$PROJECT_DIR/.gitignore"
}

# ------------------------------------------------------------------
# abort guard: PLUGIN_DIR resolves somewhere without templates/
# ------------------------------------------------------------------

@test "aborts loudly when the resolved plugin root has no templates/ directory" {
  local fake_root="$TEST_TMPDIR/fake-plugin-root"
  mkdir -p "$fake_root/skills/init/scripts"
  cp "$SCRIPT" "$fake_root/skills/init/scripts/init.sh"
  chmod +x "$fake_root/skills/init/scripts/init.sh"
  # deliberately no $fake_root/templates directory

  cd "$PROJECT_DIR"
  run --separate-stderr "$fake_root/skills/init/scripts/init.sh"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"ERROR: could not resolve plugin root"* ]]
  [ ! -d "$PROJECT_DIR/.claude" ]
}

@test "--plugin-root override is honored and still subject to the abort guard" {
  local fake_root="$TEST_TMPDIR/fake-plugin-root-2"
  mkdir -p "$fake_root"
  # no templates/ under fake_root

  cd "$PROJECT_DIR"
  run --separate-stderr "$SCRIPT" --plugin-root "$fake_root"
  [ "$status" -eq 1 ]
  [[ "$stderr" == *"ERROR: could not resolve plugin root"* ]]
}

# ------------------------------------------------------------------
# .gitignore variant detection: .specs / .specs/ / /.specs/
# ------------------------------------------------------------------

@test "recognizes an existing bare '.specs' entry and does not duplicate it" {
  cd "$PROJECT_DIR"
  printf '.specs\n' > .gitignore
  before_lines="$(wc -l < .gitignore | tr -d ' ')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *".specs/ already in .gitignore"* ]]
  after_lines="$(wc -l < .gitignore | tr -d ' ')"
  [ "$before_lines" = "$after_lines" ]
}

@test "recognizes an existing '.specs/' entry and does not duplicate it" {
  cd "$PROJECT_DIR"
  printf '.specs/\n' > .gitignore
  before_lines="$(wc -l < .gitignore | tr -d ' ')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *".specs/ already in .gitignore"* ]]
  after_lines="$(wc -l < .gitignore | tr -d ' ')"
  [ "$before_lines" = "$after_lines" ]
}

@test "recognizes an existing '/.specs/' entry and does not duplicate it" {
  cd "$PROJECT_DIR"
  printf '/.specs/\n' > .gitignore
  before_lines="$(wc -l < .gitignore | tr -d ' ')"
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *".specs/ already in .gitignore"* ]]
  after_lines="$(wc -l < .gitignore | tr -d ' ')"
  [ "$before_lines" = "$after_lines" ]
}

@test "a .gitignore without any .specs entry gets one appended, not duplicated on a second run" {
  cd "$PROJECT_DIR"
  printf '*.log\n' > .gitignore
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Added .specs/ to .gitignore"* ]]
  grep -qxE '\.specs/?' .gitignore

  # second run must recognize what was just added and not duplicate it
  run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *".specs/ already in .gitignore"* ]]
  [ "$(grep -cxE '\.specs/?|/\.specs/?' .gitignore)" = "1" ]
}
