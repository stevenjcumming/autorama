# Master Flowchart

Complete flow of the Autopilot workflow pipeline showing commands, agents, hooks, artifacts, handoffs, and human checkpoints.

---

## Overview Workflow

```
  Requirements
      ↓
     Spec ←─────┬── ←──┐
      ↓         │      │
     Plan       │      │
      ↓         │      │
    Tasks ←─────┴── ←──┤
      ↕                │
     Test ←─────┐      │
      ↓         │      │
     Code       │      │
      ↓         │      │
   Analysis     │      │
      ↓         │      │
   Refactor ────┘      │
      ↕                │
    Review ────────────┘
      ↓
    Submit
```


## End-to-End Pipeline

```
  HUMAN            /autopilot:new-spec           /autopilot:create-plan         /autopilot:create-tasks
    |                  |                    |                     |
    v                  v                    v                     v
Requirements ──> [1] Spec ──> HUMAN ──> [2] Plan ──> HUMAN ──> [3] Tasks ──> HUMAN
                                                                                |
               ┌────────────────────────────────────────────────────────────────┘
               v
           [4] Autopilot (/autopilot:execute) ──────────────────────────┐
               |                                                        |
               |  ┌──────────────────────────────────────────────┐      |
               |  │  Execute Command (per task, fresh context)   │      |
               |  │     Test → Code → Analysis → Refactor ─┐     │      |
               |  │      ^                                 |     │      |
               |  │      └──── if changes made ────────────┘     │      |
               |  │                                              │      |
               |  │  Hooks: save-state, commit                   │      |
               |  │  Hook: on-agent-complete (handoff, context)  │      |
               |  └──────────────────────────────────────────────┘      |
               |                                                        |
               |  (repeats for each task)                                |
               |                                                        |
               v                                                        |
     HUMAN (optional between tasks)                                     |
               |                                                        |
               v                                                        |
           [5] Review (/autopilot:review) ──> HUMAN DECISION ───────────┤
               |          |              |                              |
           Approve    Request Changes   Reject                          |
               |          |              |                              |
               v          v              v                              |
           [6] Submit   [4] Autopilot  [1] Spec  <──────────────────────┘
           (/autopilot:commit, /autopilot:sync-pr)
               |
               v
           HUMAN (code review, merge)
```

---

## Stage Detail

### [1] Spec

```
/autopilot:new-spec <id>
    |
    v
new-spec.sh script
    |
    ├── Creates .claude/specs/<id>/
    ├── Creates REQUIREMENT.md (template)
    └── Creates SPEC.md (template)
    |
    v
HUMAN ACTION
    ├── Paste requirements into REQUIREMENT.md
    └── Fill out SPEC.md (overview, acceptance criteria, scope)
```

**Command**: `/autopilot:new-spec <id>`
**Agents**: None (script only)
**Artifacts Generated**: `REQUIREMENT.md`, `SPEC.md`
**Human Action**: Fill in requirements and spec details

---

### [2] Plan

```
/autopilot:create-plan <id>
    |
    v
plan-builder (opus)
    |
    ├── Spawns plan-researcher (sonnet)
    │       └── Analyzes codebase patterns, dependencies
    │       └── Writes RESEARCH.md
    |
    ├── Synthesizes findings into PLAN.md
    |
    └── Spawns plan-analyzer (sonnet)
            └── Validates plan against spec
            └── Reports gaps, risks, feasibility issues
    |
    v
HUMAN ACTION
    ├── Review PLAN.md and analysis report
    ├── Address identified gaps and risks
    └── Approve plan before proceeding
```

**Command**: `/autopilot:create-plan <id>`
**Agents**: `plan-builder` -> `plan-researcher`, `plan-analyzer`
**Artifacts Generated**: `RESEARCH.md`, `PLAN.md`
**Human Action**: Review plan, address gaps, approve

---

### [3] Tasks

```
/autopilot:create-tasks <id>
    |
    v
task-builder (sonnet, leaf)
    |
    ├── Reads PLAN.md
    └── Creates TODO.md (phased, atomic tasks with IDs)
    |
    v
HUMAN ACTION
    ├── Review task list for completeness
    ├── Verify task ordering
    └── Approve before implementation
        |
        └── (Loop back to Spec if tasks reveal missing requirements)
```

**Command**: `/autopilot:create-tasks <id>`
**Agents**: `task-builder`
**Artifacts Generated**: `TODO.md`
**Human Action**: Review tasks, verify ordering, approve

---

### [4] Autopilot

```
/autopilot:execute <id> [T<n>|P<n>]
    |
    v
┌──────────────────────────────────────────────────────────────────────────┐
│ EXECUTE COMMAND - Sequential task queue (fresh context per task)         │
│                                                                          │
│  Parse TODO.md ──> pending_tasks queue                                   │
│                                                                          │
│  while pending_tasks.length > 0:                                         │
│  ┌────────────────────────────────────────────────────────────────────┐  │
│  │                                                                    │  │
│  │  ┌─── HOOK: PreToolUse (load-context.sh) ────────────────────────┐ │  │
│  │  │  Reads handoff.md from previous task                          │ │  │
│  │  │  Parses TODO.md for current task + subtasks                   │ │  │
│  │  │  Injects <handoff-context>, <current-task>,                   │ │  │
│  │  │         <progress-summary>                                    │ │  │
│  │  └───────────────────────────────────────────────────────────────┘ │  │
│  │                          |                                         │  │
│  │                          v                                         │  │
│  │  ┌─── TASK AGENT: autopilot-task-runner (opus, background) ─────┐  │  │
│  │  │                                                              │  │  │
│  │  │   autopilot-tester (sonnet)                                  │  │  │
│  │  │       │  Writes tests from acceptance criteria (TDD red)     │  │  │
│  │  │       │  Generates: test files                                │  │  │
│  │  │       v                                                      │  │  │
│  │  │   Bash: run tests (expect RED — tests should fail)           │  │  │
│  │  │       v                                                      │  │  │
│  │  │   autopilot-coder (opus)                                     │  │  │
│  │  │       │  Implements task                                     │  │  │
│  │  │       │  Generates: justifications, decisions, assumptions,  │  │  │
│  │  │       │             risks, debt, review_hints                 │  │  │
│  │  │       v                                                      │  │  │
│  │  │   Bash: run tests (expect GREEN — tests should pass)         │  │  │
│  │  │       │                                                      │  │  │
│  │  │       v                                                      │  │  │
│  │  │   autopilot-analyzer (sonnet)                                │  │  │
│  │  │       │  Runs static analysis (lint, type checks)            │  │  │
│  │  │       v                                                      │  │  │
│  │  │   autopilot-refactorer (sonnet)                              │  │  │
│  │  │       │  Cleanup refactoring                                 │  │  │
│  │  │       │                                                      │  │  │
│  │  │       ├── If changes made ──> loop back to tester + tests    │  │  │
│  │  │       └── If no changes ──> task complete                    │  │  │
│  │  │                                                              │  │  │
│  │  │   Exit: 3+ consecutive test failures = task failure          │  │  │
│  │  │   Exit: all checks pass, no refactoring = task success       │  │  │
│  │  └──────────────────────────────────────────────────────────────┘  │  │
│  │                          |                                         │  │
│  │                          v                                         │  │
│  │  ┌─── HOOK: PostToolUse (save-state.sh) ─────────────────────────┐ │  │
│  │  │  Writes artifacts/state/current.json (task status tracker)    │ │  │
│  │  └───────────────────────────────────────────────────────────────┘ │  │
│  │                          |                                         │  │
│  │                          v                                         │  │
│  │  ┌─── HOOK: SubagentStop (on-agent-complete.sh) ─────────────────┐ │  │
│  │  │  1. Auto-commit (git add -A, commit with task summary)        │ │  │
│  │  │  2. Signal <handoff-needed> for execute to spawn handoff-writer│ │  │
│  │  │  3. Check context limits (check-context.sh)                   │ │  │
│  │  │     ├── OK (<150k tokens): continue                           │ │  │
│  │  │     ├── WARNING (150-200k): emit <context-warning>            │ │  │
│  │  │     └── CRITICAL (>200k): emit <context-critical>             │ │  │
│  │  └───────────────────────────────────────────────────────────────┘ │  │
│  │                          |                                         │  │
│  │                          v                                         │  │
│  │  ┌─── BETWEEN-TASK CHECKS ───────────────────────────────────────┐ │  │
│  │  │  Context critical?                                            │ │  │
│  │  │    └── Spawn session-summarizer (haiku)                       │ │  │
│  │  │        └── Writes SESSION_SUMMARY.md (500-1000 tokens)        │ │  │
│  │  │                                                               │ │  │
│  │  └───────────────────────────────────────────────────────────────┘ │  │
│  │                          |                                         │  │
│  │                  next task (loop)                                  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

**Command**: `/autopilot:execute <id> [T<n>|P<n>]`
**Agents**: `autopilot-task-runner` (fresh per task) -> `autopilot-tester`, `autopilot-coder`, `autopilot-analyzer`, `autopilot-refactorer`; `session-summarizer`
**Human Action**: Optional review between tasks

---

### [5] Review

```
/autopilot:review
    |
    v
review.sh (data gathering)
    |
    ├── Summarize git changes (file counts, flagged files)
    ├── Count artifacts by type from .claude/specs/<id>/artifacts/
    ├── Find high-risk items (risk:high, priority:critical)
    └── Extract review hints (files, lines, questions)
    |
    v
Present enhanced summary to HUMAN
    |
    ├── Changes summary with context
    ├── Artifacts summary (justifications, decisions, risks, etc.)
    ├── High-risk items with full details and mitigation
    ├── Review hints with questions for human judgment
    └── Structured review checklist
    |
    v
HUMAN DECISION
    |
    ├── APPROVE ──────────> Proceed to Submit
    ├── REQUEST CHANGES ──> Return to Autopilot (specific fixes)
    └── REJECT ───────────> Return to Spec (fundamental issues)
```

**Command**: `/autopilot:review`
**Agents**: None (script + command orchestration)
**Human Action**: Review all items, make approve/change/reject decision

---

### [6] Submit

```
/autopilot:commit
    |
    v
    ├── git add -A (stage all changes)
    ├── Analyze diff + recent commits for context
    └── Create conventional commit (type(scope): subject)
    |
    v
/autopilot:sync-pr [pr-number]
    |
    ├── Read PR template (.claude/templates/pr_description.md)
    ├── Create feature branch if on main/master
    ├── git push -u origin HEAD
    └── gh pr create / gh pr edit --body
    |
    v
HUMAN ACTION
    ├── Monitor PR for review feedback
    ├── Address review comments
    └── Merge when approved
```

**Command**: `/autopilot:commit`, `/autopilot:sync-pr`
**Agents**: None (command orchestration)
**Human Action**: Monitor PR, address feedback, merge

---

## Hook Lifecycle (Autopilot Loop)

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOOK LIFECYCLE PER TASK                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PreToolUse ─── load-context.sh (10s timeout)                │
│     │  Matcher: Task                                            │
│     │  Input: handoff.md, TODO.md                               │
│     │  Output (injected into agent prompt):                     │
│     │    <handoff-context>   Previous task summary              │
│     │    <current-task>      Next uncompleted task              │
│     │    <progress-summary>  Completed/remaining counts         │
│     │                                                           │
│  2. (Agent executes task)                                       │
│     │                                                           │
│  3a. PostToolUse ─── save-state.sh (30s timeout)                │
│     │  Matcher: Task                                            │
│     │  Output: artifacts/state/current.json                     │
│     │    { last_agent, last_task, task_completed, timestamp }   │
│     │                                                           │
│  3b. PostToolUse ─── commit.sh (10s timeout)                    │
│     │  Matcher: Write|Edit|Bash                                 │
│     │  Output: <skill-invoke> for auto-commit                   │
│     │                                                           │
│  4. SubagentStop ─── on-agent-complete.sh (60s timeout)         │
│     │  Matcher: None (fires for all subagents, filters inside)  │
│     │  Actions:                                                 │
│     │    a) Auto-commit ──> <auto-commit>                       │
│     │    b) Signal handoff needed ──> <handoff-needed>           │
│     │    c) Check context ──> <context-warning> or              │
│     │                         <context-critical>                │
│     │    d) Always ──> <agent-completed>                        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Agent Handoff Flow

```
Task N completes
    |
    v
save-state.sh ──> writes current.json
    |
    v
on-agent-complete.sh
    ├── Auto-commit (git add -A, commit)
    ├── Signal <handoff-needed> (execute command spawns handoff-writer)
    │     ├── Completed Task (ID, status, timestamp)
    │     ├── Session Summary (300-500 tokens)
    │     ├── Files Modified
    │     ├── Key Decisions
    │     ├── Next Task Context
    │     ├── Blockers
    │     ├── Warnings
    │     └── Artifacts Generated
    └── Check context limits
          |
          ├── CRITICAL ──> session-summarizer ──> SESSION_SUMMARY.md
          └── OK/WARNING ──> continue
    |
    v
Task N+1 spawned
    |
    v
load-context.sh ──> read-handoff.sh
    ├── Reads handoff.md
    ├── Parses TODO.md for next task
    └── Injects XML context blocks into agent prompt
    |
    v
Task runner initializes with full previous context
```

---

## Artifact Map

All artifacts written to `.claude/specs/<id>/artifacts/` unless noted.

### Generated During Autopilot (by agent)

| Artifact | Agent | Trigger |
|----------|-------|---------|
| `justifications/` | coder | File modified in flagged category |
| `decisions/` | coder | Choice between approaches |
| `assumptions/` | coder | Requirement inferred |
| `risks/` | coder | Potential problem identified |
| `debt/` | coder | Shortcut taken |
| `review_hints/` | coder | Human judgment needed |
### Generated by Hooks

| Artifact | Hook | Trigger |
|----------|------|---------|
| `state/current.json` | save-state.sh | After each task agent completes |
| `handoff/handoff.md` | handoff-writer agent (spawned by execute command) | After each task completes |
| `handoff/SESSION_SUMMARY.md` | session-summarizer (via execute command) | Context usage critical (>200k tokens) |

### Generated During Other Stages

| Artifact | Stage | Location |
|----------|-------|----------|
| `REQUIREMENT.md` | Spec | `.claude/specs/<id>/` |
| `SPEC.md` | Spec | `.claude/specs/<id>/` |
| `RESEARCH.md` | Plan | `.claude/specs/<id>/` |
| `PLAN.md` | Plan | `.claude/specs/<id>/` |
| `TODO.md` | Tasks | `.claude/specs/<id>/` |
| Git commits | Submit | Git history |
| GitHub PR | Submit | GitHub |

### Promoted (by human)

| From | To | When |
|------|----|------|
| `specs/<id>/artifacts/decisions/` | `.claude/artifacts/decisions/` | Precedent-setting decision |

---

## Human-in-the-Loop Summary

| Stage | Human Activity | Required? |
|-------|---------------|-----------|
| **Requirements** | Gather and document requirements | Yes |
| **Spec** | Paste requirements, fill out SPEC.md | Yes |
| **Plan** | Review PLAN.md, address gaps, approve | Yes |
| **Tasks** | Review TODO.md, verify ordering, approve | Yes |
| **Execute (between tasks)** | Inspect changes between tasks | Optional |
| **Review** | Review summary, checklist; approve/change/reject | Yes |
| **Submit** | Review commits, monitor PR, merge | Yes |

---

## Agent Tree

```
/autopilot:new-spec ────────── (script only, no agent)

/autopilot:create-plan ─────── plan-builder (opus)
                       ├── plan-researcher (sonnet)
                       └── plan-analyzer (sonnet)

/autopilot:create-tasks ────── task-builder (sonnet, leaf)

/autopilot:execute (command — lightweight loop owner)
                       ├── autopilot-task-runner (opus, fresh per task)
                       │     ├── autopilot-tester (sonnet)
                       │     ├── autopilot-coder (opus)
                       │     ├── autopilot-analyzer (sonnet)
                       │     └── autopilot-refactorer (sonnet)
                       └── session-summarizer (haiku)

(via execute) ─────── handoff-writer (haiku, leaf)
```

---

