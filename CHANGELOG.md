# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.10.0] - 2025-02-19

Initial public release of Autopilot -- a Claude Code plugin for AI-autonomous software development with structured workflows and human oversight guardrails.

> **Note:** This is version 0.10.0 (not 1.0.0) because the plugin has not been fully tested.

### Added

- **8 workflow stages**: Spec, Plan, Tasks, Autopilot, Review, Reflect, Submit, Skills
- **10 slash commands**: `/new-spec`, `/create-plan`, `/create-tasks`, `/execute`, `/pause-autopilot`, `/review`, `/reflect`, `/commit`, `/sync-pr`, `/init`
- **14 specialized agents** across three model tiers (opus, sonnet, haiku) for planning, coding, testing, analysis, refactoring, and context management
- **Agent Harness architecture** with hook-based orchestration, background task execution, and sequential queue processing
- **Agent handoff system** with handoff.md, session summarization, and pause/resume state preservation
- **Hook system** with PreToolUse (context loading), PostToolUse (state saving), and SubagentStop (auto-commit, handoff generation, context limit checks)
- **7 artifact types**: justifications, decisions, assumptions, risks, debt, review hints, signals
- **Justification system** requiring written rationale for modifications to flagged file categories (tests, migrations, dependencies, config, API, security)
- **Evaluation pipeline** with real-time signal evaluation, automatic pause triggers, and structured review checklist
- **Signals-to-rules feedback loop**: test failures become signals, signals inform future tasks, `/reflect` proposes persistent rules in `.claude/rules/`
- **Configuration** via `.claude/autopilot.yml` for agent overrides, skills, loop behavior, auto-commit, handoff, justification categories, pause signals, and static analysis
- **17 utility scripts**, **14 templates**, and **21 documentation files**
