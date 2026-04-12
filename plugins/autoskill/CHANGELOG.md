# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-04-12

### Added

- **`/autoskill:build` command** — 7-phase workflow (detect, discover, handle empty results, clarify, synthesize, register, summarize) for generating reusable skill files from codebase patterns. Accepts optional user-provided documentation (URLs or absolute paths) as authoritative context for naming and framing.
- **`/autoskill:update` command** — Dedicated command for maintaining existing skills. Replaces the in-place rerun flow from the build command. Resolves name conflicts via numeric suffix instead of diff-and-confirm.
- **`/autoskill:init` command** — Plugin bootstrapping via `init.sh` script.
- **`discovery` agent (sonnet)** — Pattern search and example selection. Surfaces test files alongside source files so the synthesizer can find them without re-searching. Includes a mandatory companion-file sweep (Step 4.5) to surface registration manifests and middleware config files that must be edited for every new pattern instance.
- **`synthesizer` agent (opus)** — `SKILL.md` and `metadata.json` generation. Emits a "Register the new instance" step for companion files. Treats user-provided docs as the team's intent layer while grounding observations in the code.
- **`quality-check` agent (sonnet)** — Output validation with stricter rules that block when listed companion files are missing from `SKILL.md`.
- **`SKILL.template.md`** — Language-agnostic skill output template.
- **`metadata.template.json`** — Metadata template including companion file registration fields.
- **`skill-output-guide.md` reference** — Language-agnostic conventions for skill authoring, used by the synthesizer and quality-check agents.
- **Marketplace registration** — Plugin registered in `.claude-plugin/marketplace.json`.
- **User-facing docs** (`docs/autoskill/`) covering overview, usage guide, how it works, agent architecture, and generated output format.
