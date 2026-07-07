#!/usr/bin/env bats
#
# read-config.bats - tests for scripts/read-config.sh's read_config_value,
# exercised against both the yq path and the awk (no-yq) fallback path.

bats_require_minimum_version 1.5.0

setup() {
  PLUGIN_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  RC="$PLUGIN_ROOT/scripts/read-config.sh"
  TEST_TMPDIR="$(mktemp -d "${BATS_TEST_TMPDIR:-/tmp}/rc-bats.XXXXXX")"

  # A restricted PATH that has no yq on it, to force the awk fallback,
  # while keeping the handful of external commands read-config.sh and
  # its awk helper actually need (only awk itself, plus standard shell
  # builtins for the rest of read_config_value).
  NO_YQ_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
}

teardown() {
  rm -rf "$TEST_TMPDIR"
}

# ------------------------------------------------------------------
# fixtures
# ------------------------------------------------------------------

write_comment_fixture() {
  cat > "$TEST_TMPDIR/config.yml" << 'EOF'
static_analysis:
  on_edit:
    # a comment line sitting between the parent and child key
    enabled: true
EOF
}

write_same_name_depth_fixture() {
  # Two "enabled:" keys at different depths - one directly under
  # static_analysis, one nested under on_edit. Must not conflate them.
  cat > "$TEST_TMPDIR/config.yml" << 'EOF'
static_analysis:
  enabled: false
  on_edit:
    enabled: true
EOF
}

# ------------------------------------------------------------------
# yq path (yq is present on PATH in this dev/CI environment)
# ------------------------------------------------------------------

@test "read_config_value (yq path): comment between parent and child key does not break the match" {
  write_comment_fixture
  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.enabled'"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "read_config_value (yq path): same-named key at a different depth resolves to the exact path" {
  write_same_name_depth_fixture
  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.enabled'"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.enabled'"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "read_config_value (yq path): missing file returns default" {
  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/nope.yml' 'a.b' 'fallback'"
  [ "$status" -eq 0 ]
  [ "$output" = "fallback" ]
}

@test "read_config_value (yq path): missing file with no default returns 1 and prints nothing" {
  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/nope.yml' 'a.b'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "read_config_value (yq path): missing key with default returns default" {
  write_comment_fixture
  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.nonexistent' 'fallback'"
  [ "$status" -eq 0 ]
  [ "$output" = "fallback" ]
}

@test "read_config_value (yq path): missing key with no default returns 1 and prints nothing" {
  write_comment_fixture
  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.nonexistent'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

# ------------------------------------------------------------------
# awk fallback path (yq forced off PATH)
# ------------------------------------------------------------------

@test "read_config_value (awk fallback): comment between parent and child key does not break the match" {
  write_comment_fixture
  run env PATH="$NO_YQ_PATH" bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.enabled'"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]
}

@test "read_config_value (awk fallback): same-named key at a different depth resolves to the exact path" {
  write_same_name_depth_fixture
  run env PATH="$NO_YQ_PATH" bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.enabled'"
  [ "$status" -eq 0 ]
  [ "$output" = "true" ]

  run env PATH="$NO_YQ_PATH" bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.enabled'"
  [ "$status" -eq 0 ]
  [ "$output" = "false" ]
}

@test "read_config_value (awk fallback): missing file returns default" {
  run env PATH="$NO_YQ_PATH" bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/nope.yml' 'a.b' 'fallback'"
  [ "$status" -eq 0 ]
  [ "$output" = "fallback" ]
}

@test "read_config_value (awk fallback): missing file with no default returns 1 and prints nothing" {
  run env PATH="$NO_YQ_PATH" bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/nope.yml' 'a.b'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "read_config_value (awk fallback): missing key with default returns default" {
  write_comment_fixture
  run env PATH="$NO_YQ_PATH" bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.nonexistent' 'fallback'"
  [ "$status" -eq 0 ]
  [ "$output" = "fallback" ]
}

@test "read_config_value (awk fallback): missing key with no default returns 1 and prints nothing" {
  write_comment_fixture
  run env PATH="$NO_YQ_PATH" bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis.on_edit.nonexistent'"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "read_config_value: invalid dot_path characters are treated as not-found (never reach yq/awk)" {
  write_comment_fixture
  run bash -c "source '$RC'; read_config_value '$TEST_TMPDIR/config.yml' 'static_analysis; rm -rf /' 'safe-default'"
  [ "$status" -eq 0 ]
  [ "$output" = "safe-default" ]
}
