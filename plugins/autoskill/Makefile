SHELL := /bin/bash

.PHONY: test shellcheck jsonlint consistency

# All shell scripts shipped by the plugin: scripts/ and every per-skill
# skills/<name>/scripts/ subdirectory. Unlike autocode, this plugin has no
# hooks/ directory. May be empty (autoskill ships no bats-testable shell
# scripts of its own).
SHELL_SCRIPTS := $(shell find scripts skills -name '*.sh' 2>/dev/null)

# JSON config files that ship with the plugin.
JSON_FILES := .claude-plugin/plugin.json

# Mirrors the CI workflow (.github/workflows/autoskill-ci.yml) so that
# `make test` and CI stay in sync: keep logic here, have CI just call
# `make -C plugins/autoskill test`.
#
# Each check runs as its own `$(MAKE)` invocation (rather than as plain
# make prerequisites) so that one failing check does not prevent the
# rest from running: everything executes, failures are collected, and
# the target exits non-zero at the end if anything failed.
test:
	@fail=0; \
	$(MAKE) --no-print-directory shellcheck || fail=1; \
	$(MAKE) --no-print-directory jsonlint || fail=1; \
	$(MAKE) --no-print-directory consistency || fail=1; \
	exit $$fail

shellcheck:
	@echo "==> shellcheck"
	@if [ -n "$(SHELL_SCRIPTS)" ]; then \
		shellcheck $(SHELL_SCRIPTS); \
	else \
		echo "no shell scripts to check, skipping"; \
	fi

jsonlint:
	@echo "==> jq (JSON validation)"
	@for f in $(JSON_FILES); do \
		echo "  checking $$f"; \
		jq empty "$$f" || exit 1; \
	done

consistency:
	@echo "==> consistency (skills/agents frontmatter + version)"
	@python3 scripts/check-consistency.py
