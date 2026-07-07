#!/usr/bin/env bash
#
# read-config.sh - Shared, indentation-safe YAML config reader for the
# autocode plugin.
#
# This file is meant to be *sourced*, never executed directly. It has no
# top-level side effects and does not set `set -e`/`set -u`/`set -o
# pipefail` itself, so sourcing it never changes the caller's shell
# options (same convention as scripts/lib.sh). Every internal command
# that can fail is guarded with `|| ...` so it is also safe to source
# into a caller running under `set -euo pipefail` (check-edit.sh,
# on-agent-complete.sh) without tripping errexit on a deliberate
# not-found/default result.
#
# How to source it (path depends on how deep the call site is under the
# plugin root; both are known, fixed layouts today):
#
#   Skill scripts at skills/<name>/scripts/foo.sh (3 levels down):
#     source "$(dirname "$0")/../../../scripts/read-config.sh"
#
#   Hooks at hooks/foo.sh (1 level down):
#     source "$(dirname "$0")/../scripts/read-config.sh"
#
# Why this exists: `grep -A2 '^key:'` style config gates break the
# moment a comment line separates a parent key from its child, or when
# any other `enabled:` key elsewhere in the file falls inside the
# grepped window. This library walks the YAML tracking indentation
# depth so it only matches a key when it sits at the exact position in
# the dotted path being asked for.
#
# Functions provided:
#   read_config_value <config_file> <dot_path> [default]
#
# Usage caveat (set -e): `val=$(read_config_value "$f" "a.b")` will
# propagate a non-zero exit under the caller's `set -e` if the path is
# not found and no default is given. Callers that want the "check $?"
# form documented above should guard it explicitly, e.g.:
#   val=$(read_config_value "$f" "a.b") || val=""
# or simply always pass a default, which never returns non-zero.

# ==============================================================================
# read_config_value - read a nested YAML value by dotted key path.
#
# Usage: read_config_value <config_file> <dot_path> [default]
#
#   config_file  path to the YAML file (e.g. .claude/autocode.yml)
#   dot_path     dotted key path, e.g. "static_analysis.on_edit.enabled".
#                Only letters, digits, and underscores are allowed in
#                each segment; anything else is treated as invalid and
#                never reaches yq or the awk parser (defends against a
#                caller-controlled dot_path being used to inject a yq
#                expression), and resolves the same as "not found".
#   default      optional. Printed (and 0 returned) when the file is
#                missing/unreadable, the path is invalid, or the path
#                is not found in the file.
#
# Behavior:
#   - Prefers `yq` (mikefarah/yq) when present on PATH, querying the
#     path directly (".a.b.c") rather than string-building a `//`
#     fallback expression: yq/jq's `//` operator treats `false` as
#     falsy, which would silently replace a real `enabled: false` with
#     the default/sentinel. Instead the raw value is queried and only
#     an actual `null` (path absent or explicitly null) is treated as
#     not-found.
#   - Falls back to an indentation-anchored awk parser when yq is not
#     on PATH. The awk parser tracks a stack of (indentation, key)
#     pairs as it scans the file; a line only extends the matched path
#     when its indentation is deeper than the current stack top, so a
#     comment line or a blank line between a parent and child key never
#     breaks the match (they're skipped, not pushed), and a same-named
#     key nested at a different depth (e.g. two `enabled:` keys, one
#     under `on_edit:` and one directly under `static_analysis:`) is
#     only matched when the *entire* accumulated path equals dot_path,
#     not just the final segment.
#   - YAML booleans are returned as the literal strings "true"/"false"
#     (never converted to 0/1), matching how callers currently do
#     string comparison (`[ "$val" = "true" ]`).
#
# Returns 0 and prints the value (or default) on stdout. Returns 1 and
# prints nothing when the path isn't found and no default was given.
# ==============================================================================
read_config_value() {
  local config_file="${1:-}"
  local dot_path="${2:-}"
  local have_default=0
  local default=""
  if [ "$#" -ge 3 ]; then
    have_default=1
    default="$3"
  fi

  _rcv_fallback() {
    if [ "$have_default" -eq 1 ]; then
      printf '%s\n' "$default"
      return 0
    fi
    return 1
  }

  if [ -z "$config_file" ] || [ ! -f "$config_file" ] || [ ! -r "$config_file" ]; then
    _rcv_fallback
    return $?
  fi

  # Defend against a caller-controlled dot_path being used to build a
  # yq expression: only letters, digits, underscores, dot-separated.
  if ! [[ "$dot_path" =~ ^[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)*$ ]]; then
    _rcv_fallback
    return $?
  fi

  local value=""
  local found=1

  if command -v yq &>/dev/null; then
    local yq_out="" yq_status=0
    # Query the raw path only; deliberately NOT ".path // default" -
    # yq's `//` treats `false` as falsy and would clobber a real
    # `enabled: false` with the fallback.
    yq_out=$(yq -r ".${dot_path}" "$config_file" 2>/dev/null) || yq_status=$?
    if [ "$yq_status" -eq 0 ] && [ "$yq_out" != "null" ]; then
      value="$yq_out"
      found=0
    fi
  else
    local awk_out="" awk_status=0
    awk_out=$(_read_config_value_awk "$config_file" "$dot_path") || awk_status=$?
    if [ "$awk_status" -eq 0 ]; then
      value="$awk_out"
      found=0
    fi
  fi

  if [ "$found" -eq 0 ]; then
    printf '%s\n' "$value"
    return 0
  fi

  _rcv_fallback
  return $?
}

# ==============================================================================
# _read_config_value_awk - internal helper for read_config_value's
# no-yq fallback. Not intended to be called directly.
#
# Walks the file line by line maintaining a stack of (indentation,
# key) pairs. Comment-only and blank lines are skipped without
# touching the stack (fixing the comment-between-parent-and-child
# case). On each real "key: value" line, the stack is popped back to
# the deepest entry whose indentation is less than the current line's,
# then the current key is pushed; the accumulated stack of keys is the
# line's full dotted path. A match requires the full path to equal
# dot_path exactly, not just the last segment (fixing the same-named
# nested key at a different depth case).
#
# Prints the raw value (quotes/inline comments still attached) on
# stdout and returns 0 on match; returns 1 with no output otherwise.
# Quote-stripping and inline-comment-stripping are done by the caller
# in plain bash/sed, not inside the awk program, to avoid fighting
# single-quote escaping inside a single-quoted awk script.
# ==============================================================================
_read_config_value_awk() {
  local config_file="$1"
  local dot_path="$2"
  local raw="" awk_status=0

  raw=$(awk -v target="$dot_path" '
    BEGIN {
      n = split(target, tp, ".")
      depth = 0
      found = 0
    }
    {
      line = $0
      t = line
      sub(/^[ \t]*/, "", t)
      if (t == "" || substr(t, 1, 1) == "#") next

      indent = 0
      while (substr(line, indent + 1, 1) == " ") indent++

      if (match(t, /^[A-Za-z0-9_]+:/)) {
        key = substr(t, 1, RLENGTH - 1)
        val = substr(t, RLENGTH + 1)
        sub(/^[ \t]*/, "", val)

        while (depth > 0 && indent <= stack_indent[depth]) depth--
        depth++
        stack_indent[depth] = indent
        stack_key[depth] = key

        if (depth == n) {
          ok = 1
          for (i = 1; i <= n; i++) {
            if (stack_key[i] != tp[i]) { ok = 0; break }
          }
          if (ok) {
            print val
            found = 1
            exit
          }
        }
      }
    }
    END { if (!found) exit 1 }
  ' "$config_file" 2>/dev/null) || awk_status=$?

  if [ "$awk_status" -ne 0 ]; then
    return 1
  fi

  # If the value opens with a quote, take everything up to the matching
  # closing quote and discard the rest of the line (an inline comment
  # may follow the closing quote, e.g. `command: "" # explanation`).
  # Otherwise strip a trailing inline comment and trailing whitespace
  # from the bare scalar.
  case "$raw" in
    \"*)
      raw="${raw#\"}"
      raw="${raw%%\"*}"
      ;;
    \'*)
      raw="${raw#\'}"
      raw="${raw%%\'*}"
      ;;
    *)
      raw=$(printf '%s' "$raw" | sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]+$//')
      ;;
  esac

  printf '%s\n' "$raw"
  return 0
}
