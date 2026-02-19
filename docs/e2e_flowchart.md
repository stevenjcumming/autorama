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
    Reflect
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
           [4] Autopilot (/autopilot:execute) ──────────────────────────────────┐
               |                                                        |
               |  ┌──────────────────────────────────────────────┐      |
               |  │  Loop Controller (per task)                  │      |
               |  │     Test → Code → Analysis → Refactor ─┐     │      |
               |  │      ^                                 |     │      |
               |  │      └──── if changes made ────────────┘     │      |
               |  │                                              │      |
               |  │  Hook: save-state → auto-commit → handoff    │      |
               |  │  Hook: check pause signals                   │      |
               |  └──────────────────────────────────────────────┘      |
               |                                                        |
               |  (repeats for each task, or pauses for HUMAN)          |
               |                                                        |
               v                                                        |
     HUMAN (optional between tasks / on pause)                          |
               |                                                        |
               v                                                        |
           [5] Review (/autopilot:review) ──> HUMAN DECISION ─────────────────────┤
               |          |              |                              |
           Approve    Request Changes   Reject                          |
               |          |              |                              |
               v          v              v                              |
           [6] Reflect  [4] Autopilot  [1] Spec  <──────────────────────┘
           (/autopilot:reflect)
               |
               v
           HUMAN (select rules)
               |
               v
           [7] Submit (/autopilot:commit, /autopilot:sync-pr)
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
spec-writer agent (leaf)
    |
    ├── Creates .claude/specs/<id>/
    ├── Creates REQUIREMENT.md (template)
    ├── Creates SPEC.md (template)
    └── Creates artifacts/ directory
    |
    v
HUMAN ACTION
    ├── Paste requirements into REQUIREMENT.md
    └── Fill out SPEC.md (overview, acceptance criteria, scope)
```

**Command**: `/autopilot:new-spec <id>`
**Agents**: `spec-writer`
**Artifacts Generated**: `REQUIREMENT.md`, `SPEC.md`, `artifacts/`
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
│ LOOP CONTROLLER (sonnet) - Sequential task queue                         │
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
│  │  │       │  Generates: test files, signals                      │  │  │
│  │  │       v                                                      │  │  │
│  │  │   Bash: run tests (expect RED — tests should fail)           │  │  │
│  │  │       v                                                      │  │  │
│  │  │   autopilot-coder (opus)                                     │  │  │
│  │  │       │  Implements task                                     │  │  │
│  │  │       │  Generates: justifications, decisions, assumptions,  │  │  │
│  │  │       │             risks, debt, review_hints, signals       │  │  │
│  │  │       v                                                      │  │  │
│  │  │   Bash: run tests (expect GREEN — tests should pass)         │  │  │
│  │  │       │                                                      │  │  │
│  │  │       v                                                      │  │  │
│  │  │   autopilot-analyzer (sonnet)                                │  │  │
│  │  │       │  Runs static analysis (lint, type checks)            │  │  │
│  │  │       │  Generates: signals                                  │  │  │
│  │  │       v                                                      │  │  │
│  │  │   autopilot-refactorer (sonnet)                              │  │  │
│  │  │       │  Cleanup refactoring                                 │  │  │
│  │  │       │  Generates: signals                                  │  │  │
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
│  │  │  2. Generate handoff.md (git diff, next task context)         │ │  │
│  │  │  3. Check context limits (check-context.sh)                   │ │  │
│  │  │     ├── OK (<150k tokens): continue                           │ │  │
│  │  │     ├── WARNING (150-200k): emit <context-warning>            │ │  │
│  │  │     └── CRITICAL (>200k): emit <context-critical>             │ │  │
│  │  └───────────────────────────────────────────────────────────────┘ │  │
│  │                          |                                         │  │
│  │                          v                                         │  │
│  │  ┌─── BETWEEN-TASK CHECKS ───────────────────────────────────────┐ │  │
│  │  │  evaluate-signals.sh:                                         │ │  │
│  │  │    ├── Repeated violation (same rule 3+ times) ──> PAUSE      │ │  │
│  │  │    ├── High severity (security, breaking change) ──> PAUSE    │ │  │
│  │  │    └── Human review flag ──> PAUSE                            │ │  │
│  │  │                                                               │ │  │
│  │  │  Context critical?                                            │ │  │
│  │  │    └── Spawn session-summarizer (haiku)                       │ │  │
│  │  │        └── Writes SESSION_SUMMARY.md (500-1000 tokens)        │ │  │
│  │  │                                                               │ │  │
│  │  │  single_task_mode?                                            │ │  │
│  │  │    └── true: exit loop, return control to HUMAN               │ │  │
│  │  └───────────────────────────────────────────────────────────────┘ │  │
│  │                          |                                         │  │
│  │                  next task (loop)                                  │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  Manual pause: /autopilot:pause-autopilot <id>                                     │
│    └── Writes artifacts/state/paused.md (full state for resumption)      │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

**Command**: `/autopilot:execute <id> [T<n>|P<n>]`
**Agents**: `loop-controller` -> `autopilot-task-runner` -> `autopilot-tester`, `autopilot-coder`, `autopilot-analyzer`, `autopilot-refactorer`; `session-summarizer`
**Human Action**: Optional review between tasks (single_task_mode), intervention on pause

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
    ├── APPROVE ──────────> Proceed to Reflect
    ├── REQUEST CHANGES ──> Return to Autopilot (specific fixes)
    └── REJECT ───────────> Return to Spec (fundamental issues)
```

**Command**: `/autopilot:review`
**Agents**: None (script + command orchestration)
**Human Action**: Review all items, make approve/change/reject decision

---

### [6] Reflect

```
/autopilot:reflect [id]
    |
    v
reflect.sh (count signals, artifacts, existing rules)
    |
    v
Analyze signals from .claude/specs/<id>/artifacts/signals/
    |
    ├── Corrections (high confidence) ──> propose rule
    ├── Rejections (high confidence) ──> propose rule
    ├── Repetitions (high confidence) ──> propose rule
    ├── Approvals (medium confidence) ──> propose with caveats
    ├── Clarifications (medium) ──> propose with caveats
    └── Praise (low) ──> report only, no rule
    |
    v
Analyze artifacts (decisions, assumptions)
    |
    v
Generate proposals table
    |
    v
HUMAN ACTION
    ├── Review proposed rules
    ├── Select which rules to create
    └── Adjust content or paths as needed
    |
    v
rules-builder agent (sonnet)
    |
    ├── Creates selected rules in .claude/rules/
    └── Rules auto-loaded in all future sessions
    |
    v
(Optional) Promote valuable per-spec artifacts to .claude/artifacts/
```

**Command**: `/autopilot:reflect [id]`
**Agents**: `rules-builder`
**Artifacts Generated**: `.claude/rules/*.md`
**Human Action**: Select rules to create, adjust content, promote artifacts

---

### [7] Submit

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
│     │  Matcher: Task tool (autopilot-* agents only)             │
│     │  Input: handoff.md, TODO.md                               │
│     │  Output (injected into agent prompt):                     │
│     │    <handoff-context>   Previous task summary              │
│     │    <current-task>      Next uncompleted task              │
│     │    <progress-summary>  Completed/remaining counts         │
│     │                                                           │
│  2. (Agent executes task)                                       │
│     │                                                           │
│  3. PostToolUse ─── save-state.sh (30s timeout)                 │
│     │  Matcher: Task tool (autopilot-* agents only)             │
│     │  Output: artifacts/state/current.json                     │
│     │    { last_agent, last_task, task_completed, timestamp }   │
│     │                                                           │
│  4. SubagentStop ─── on-agent-complete.sh (60s timeout)         │
│     │  Matcher: None (fires for all subagents, filters inside)  │
│     │  Actions:                                                 │
│     │    a) Auto-commit ──> <auto-commit>                       │
│     │    b) Generate handoff.md ──> <handoff-generated>         │
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
    ├── Generate handoff.md
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
| `signals/` | tester, coder, analyzer, refactorer | Notable patterns (correction, rejection, repetition, approval, clarification) |

### Generated by Hooks

| Artifact | Hook | Trigger |
|----------|------|---------|
| `state/current.json` | save-state.sh | After each task agent completes |
| `handoff/handoff.md` | on-agent-complete.sh | After each task completes |
| `handoff/SESSION_SUMMARY.md` | session-summarizer (via loop-controller) | Context usage critical (>200k tokens) |
| `state/paused.md` | /autopilot:pause-autopilot | Manual pause or signal-triggered pause |

### Generated During Other Stages

| Artifact | Stage | Location |
|----------|-------|----------|
| `REQUIREMENT.md` | Spec | `.claude/specs/<id>/` |
| `SPEC.md` | Spec | `.claude/specs/<id>/` |
| `RESEARCH.md` | Plan | `.claude/specs/<id>/` |
| `PLAN.md` | Plan | `.claude/specs/<id>/` |
| `TODO.md` | Tasks | `.claude/specs/<id>/` |
| `.claude/rules/*.md` | Reflect | `.claude/rules/` |
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
| **Autopilot (between tasks)** | Inspect changes when single_task_mode is on | Optional |
| **Autopilot (on pause)** | Review signals, decide to continue or intervene | When triggered |
| **Autopilot (manual pause)** | `/autopilot:pause-autopilot` to stop and review | Optional |
| **Review** | Review summary, checklist; approve/change/reject | Yes |
| **Reflect** | Select which proposed rules to create | Yes |
| **Submit** | Review commits, monitor PR, merge | Yes |

### Automatic Pause Triggers (require human)

| Trigger | Condition | Source |
|---------|-----------|--------|
| Repeated violation | Same analysis rule broken 3+ times | evaluate-signals.sh |
| High severity | Security issue or breaking change detected | evaluate-signals.sh |
| Human review flag | Agent flagged `human_review: required` | evaluate-signals.sh |
| Context critical | Token usage exceeds 200k threshold | check-context.sh |

---

## Agent Tree

```
/autopilot:new-spec ────────── spec-writer (leaf)

/autopilot:create-plan ─────── plan-builder (opus)
                       ├── plan-researcher (sonnet)
                       └── plan-analyzer (sonnet)

/autopilot:create-tasks ────── task-builder (sonnet, leaf)

/autopilot:execute ───────── loop-controller (sonnet)
                       ├── autopilot-task-runner (opus)
                       │     ├── autopilot-tester (sonnet)
                       │     ├── autopilot-coder (opus)
                       │     ├── autopilot-analyzer (sonnet)
                       │     └── autopilot-refactorer (sonnet)
                       └── session-summarizer (haiku)

/autopilot:reflect ─────────── rules-builder (sonnet, leaf)

(hooks) ──────────── handoff-writer (haiku, leaf)
```

---

## Signals-to-Rules Feedback Loop

```
Phase 1: GENERATION (during Autopilot)
    All agents ──> write signal artifacts

Phase 2: ANALYSIS (/autopilot:reflect)
    Reads all signals + artifacts
    └── Identifies patterns across full session

Phase 3: SELECTION (human)
    Engineer reviews proposed rules
    └── Selects which to create

Phase 4: PERSISTENCE
    rules-builder writes .claude/rules/
    └── Auto-loaded in all future sessions
```
