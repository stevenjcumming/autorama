SHELL := /bin/bash

.PHONY: test shellcheck jsonlint yamllint nodecheck bats-test

# All shell scripts shipped by the plugin: hooks/, scripts/, and every
# per-skill skills/<name>/scripts/ subdirectory.
SHELL_SCRIPTS := $(shell find hooks scripts skills -name '*.sh' 2>/dev/null)

# JSON config files that ship with the plugin.
JSON_FILES := hooks/hooks.json .claude-plugin/plugin.json

# YAML config templates that ship with the plugin.
YAML_FILES := templates/autocode.yml

# Mirrors the CI workflow (.github/workflows/autocode-ci.yml) so that
# `make test` and CI stay in sync: keep logic here, have CI just call
# `make -C plugins/autocode test`.
#
# Each check runs as its own `$(MAKE)` invocation (rather than as plain
# make prerequisites) so that one failing check does not prevent the
# rest from running: everything executes, failures are collected, and
# the target exits non-zero at the end if anything failed.
test:
	@fail=0; \
	$(MAKE) --no-print-directory shellcheck || fail=1; \
	$(MAKE) --no-print-directory jsonlint || fail=1; \
	$(MAKE) --no-print-directory yamllint || fail=1; \
	$(MAKE) --no-print-directory nodecheck || fail=1; \
	$(MAKE) --no-print-directory bats-test || fail=1; \
	exit $$fail

# SC1091 (can't statically follow a $(dirname "$0")-relative `source`) and
# SC2016 (literal backticks intentionally kept inert inside single-quoted
# grep patterns matching markdown) are both known-safe here; every other
# finding should be treated as real.
shellcheck:
	@echo "==> shellcheck"
	@shellcheck -e SC1091,SC2016 $(SHELL_SCRIPTS)

jsonlint:
	@echo "==> jq (JSON validation)"
	@for f in $(JSON_FILES); do \
		echo "  checking $$f"; \
		jq empty "$$f" || exit 1; \
	done

yamllint:
	@echo "==> yaml validation"
	@for f in $(YAML_FILES); do \
		echo "  checking $$f"; \
		python3 -c "import yaml, sys; yaml.safe_load(open(sys.argv[1]))" "$$f" || exit 1; \
	done

nodecheck:
	@echo "==> node --check"
	@node --check hooks/judge-artifacts.mjs

bats-test:
	@echo "==> bats"
	@if compgen -G "tests/*.bats" > /dev/null; then \
		bats tests/*.bats; \
	else \
		echo "no bats tests yet, skipping"; \
	fi
