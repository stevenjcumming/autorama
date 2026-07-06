# Changelog

All notable changes to the autocontext plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-07-06

### Added

- `init` skill: one-time project setup that resolves the plugin install path, writes `AUTOCONTEXT_PLUGIN_ROOT` to `.claude/settings.local.json`, and injects the CONTEXT.md execution contract into `.claude/CLAUDE.md` (idempotent)
- `create` skill: generates a `CONTEXT.md` for a directory via analyzer and generator agents, with external documentation prompts, `gh api` URL validation, and user confirmation before writing
- `update` skill: validates an existing `CONTEXT.md` via the validator agent (broken references, stale task bundles, missing Docs coverage, structural anti-patterns) and applies user-approved fixes with targeted edits
- `help` skill: skill table, typical workflow, and CONTEXT.md section summary
- `autocontext-analyzer` agent (sonnet, read-only): surveys a directory and returns structured analysis with per-section confidence ratings
- `autocontext-generator` agent (opus, read-only): composes CONTEXT.md content from analysis, marking low-confidence sections with review TODOs and never fabricating references
- `autocontext-validator` agent (sonnet): checks an existing CONTEXT.md against the codebase, classifying unreachable URLs as unverifiable rather than broken
- `templates/context.md`: canonical CONTEXT.md skeleton
- `references/context-format-guide.md`: single-source format specification, section criteria, path rules, six anti-patterns, confidence criteria, and examples
- `scripts/init.sh`: settings bootstrap with jq, python3, and manual fallbacks, atomic writes, and a project-root guard
