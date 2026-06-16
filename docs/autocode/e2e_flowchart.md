# Master Flowchart

Complete flow of the Autopilot workflow pipeline showing skills, agents, hooks, artifacts, handoffs, and human checkpoints.

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
  HUMAN            /autocode:new-spec           /autocode:create-plan         /autocode:create-tasks
    |                  |                    |                     |
    v                  v                    v                     v
Requirements ──> [1] Spec ──> HUMAN ──> [2] Plan ──> HUMAN ──> [3] Tasks ──> HUMAN
                                                                                |
               ┌────────────────────────────────────────────────────────────────┘
               v
           [4] Autocode (/autocode:execute) ──────────────────────────┐
               |                                                        |
               |  ┌──────────────────────────────────────────────┐      |
               |  │  Execute Skill (per task, fresh context)     │      |
               |  │     Test → Code → Analysis → Refactor ─┐     │      |
               |  │      ^                                 |     │      |
               |  │      └──── if changes made ────────────┘     │      |
               |  │                                              │      |
               |  │  Hook: on-agent-complete (tag parse,         │      |
               |  │         artifact audit, context check)       │      |
               |  └──────────────────────────────────────────────┘      |
               |                                                        |
               |  (repeats for each task)                               |
               |                                                        |
               v                                                        |
     HUMAN (optional between tasks)                                     |
               |                                                        |
               v                                                        |
           [5] Review (/autocode:review) ──> HUMAN DECISION ───────────┤
               |          |              |                              |
           Approve    Request Changes   Reject                          |
               |          |              |                              |
               v          v              v                              |
           [6] Submit   [4] Autocode  [1] Spec  <──────────────────────┘
           (/autocode:commit, /autocode:sync-pr)
               |
               v
           HUMAN (code review, merge)
```

---

## Stage Detail

### [1] Spec

```
/autocode:new-spec <id>
    |
    v
new-spec.sh script
    |
    ├── Creates .specs/<id>/
    ├── Creates REQUIREMENT.md (template)
    └── Creates SPEC.md (template)
    |
    v
HUMAN ACTION
    ├── Paste requirements into REQUIREMENT.md
    └── Fill out SPEC.md (overview, acceptance criteria, scope)
```

**Skill**: `/autocode:new-spec <id>`
**Agents**: None (script only)
**Artifacts Generated**: `REQUIREMENT.md`, `SPEC.md`
**Human Action**: Fill in requirements and spec details

---

### [2] Plan

```
/autocode:create-plan <id>
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

**Skill**: `/autocode:create-plan <id>`
**Agents**: `plan-builder` -> `plan-researcher`, `plan-analyzer`
**Artifacts Generated**: `RESEARCH.md`, `PLAN.md`
**Human Action**: Review plan, address gaps, approve

---

### [3] Tasks

```
/autocode:create-tasks <id>
    |
    v
create-tasks skill (inline)
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

**Skill**: `/autocode:create-tasks <id>`
**Agents**: None (skill writes TODO.md inline)
**Artifacts Generated**: `TODO.md`
**Human Action**: Review tasks, verify ordering, approve

---

### [4] Autopilot

```
/autocode:execute <id> [T<n>|P<n>]
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
│  │  ┌─── TASK AGENT: task-runner (opus, background) ───────────────┐  │  │
│  │  │                                                              │  │  │
│  │  │   tester (sonnet)                                            │  │  │
│  │  │       │  Writes tests from acceptance criteria (TDD red)     │  │  │
│  │  │       │  Generates: test files                               │  │  │
│  │  │       v                                                      │  │  │
│  │  │   Bash: run tests (expect RED — tests should fail)           │  │  │
│  │  │       v                                                      │  │  │
│  │  │   coder (opus)                                               │  │  │
│  │  │       │  Implements task                                     │  │  │
│  │  │       │  Generates: justifications, decisions, assumptions,  │  │  │
│  │  │       │             risks, debt, review_hints                │  │  │
│  │  │       v                                                      │  │  │
│  │  │   Bash: run tests (expect GREEN — tests should pass)         │  │  │
│  │  │       │                                                      │  │  │
│  │  │       v                                                      │  │  │
│  │  │   analyzer (sonnet)                                          │  │  │
│  │  │       │  Runs static analysis (lint, type checks)            │  │  │
│  │  │       v                                                      │  │  │
│  │  │   refactorer (sonnet)                                        │  │  │
│  │  │       │  Cleanup refactoring                                 │  │  │
│  │  │       │                                                      │  │  │
│  │  │       ├── If changes made ──> loop back to tester + tests    │  │  │
│  │  │       └── If no changes ──> task complete                    │  │  │
│  │  │                                                              │  │  │
│  │  │   Exit: retry limit exceeded = structured failure tag        │  │  │
│  │  │   Exit: all checks pass, no refactoring = task success       │  │  │
│  │  └──────────────────────────────────────────────────────────────┘  │  │
│  │                          |                                         │  │
│  │                          v                                         │  │
│  │  ┌─── HOOK: SubagentStop (on-agent-complete.sh) ─────────────────┐ │  │
│  │  │  1. Recover agent output from transcript                      │ │  │
│  │  │  2. Parse <task-completed> structured failure tag             │ │  │
│  │  │  3. Audit artifacts/; emit <artifact-audit> if trail missing  │ │  │
│  │  │  4. Check context limits (check-context.sh)                   │ │  │
│  │  │     ├── OK (<150k tokens): continue                           │ │  │
│  │  │     ├── WARNING (150-200k): emit <context-warning>            │ │  │
│  │  │     └── CRITICAL (>200k): emit <context-critical>             │ │  │
│  │  │  (signals emitted as JSON additionalContext/systemMessage)    │ │  │
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

**Skill**: `/autocode:execute <id> [T<n>|P<n>]`
**Agents**: `task-runner` (fresh per task) -> `tester`, `coder`, `analyzer`, `refactorer`; `session-summarizer` (on context-critical)
**Human Action**: Optional review between tasks

---

### [5] Review

```
/autocode:review
    |
    v
review.sh (data gathering)
    |
    ├── Summarize git changes (file counts, flagged files)
    ├── Count artifacts by type from .specs/<id>/artifacts/
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
    ├── REQUEST CHANGES ──> Return to Autocode (specific fixes)
    └── REJECT ───────────> Return to Spec (fundamental issues)
```

**Skill**: `/autocode:review`
**Agents**: None (script + skill orchestration)
**Human Action**: Review all items, make approve/change/reject decision

---

### [6] Submit

```
/autocode:commit
    |
    v
    ├── git add -A (stage all changes)
    ├── Analyze diff + recent commits for context
    └── Create conventional commit (type(scope): subject)
    |
    v
/autocode:sync-pr [pr-number]
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

**Skill**: `/autocode:commit`, `/autocode:sync-pr`
**Agents**: None (skill orchestration)
**Human Action**: Monitor PR, address feedback, merge

---

## Hook Lifecycle (Autopilot Loop)

```
┌─────────────────────────────────────────────────────────────────┐
│                    HOOK LIFECYCLE PER TASK                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. PreToolUse ─── load-context.sh + log-skill-usage.sh         │
│     │  Matcher: Task                                            │
│     │  Input: handoff.md, TODO.md                               │
│     │  load-context rewrites the Task prompt via                │
│     │  hookSpecificOutput.updatedInput (plain stdout from       │
│     │  PreToolUse never reaches model context), injecting:      │
│     │    <handoff-context>   Previous task summary              │
│     │    <current-task>      Next uncompleted task              │
│     │    <progress-summary>  Completed/remaining counts         │
│     │  log-skill-usage logs the agent spawn to usage.jsonl      │
│     │                                                           │
│  2. (Agent executes task)                                       │
│     │  PostToolUse ─── check-edit.sh (Write|Edit|MultiEdit)     │
│     │    Runs per-file static analysis from                     │
│     │    static_analysis.on_edit; exits 2 to feed errors back   │
│     │                                                           │
│  3. SubagentStop ─── on-agent-complete.sh                       │
│     │  Matcher: None (fires for all subagents, filters inside)  │
│     │  Actions (emitted as JSON additionalContext/systemMessage)│
│     │    a) Recover output, parse <task-completed> tag          │
│     │    b) Audit artifacts ──> <artifact-audit> if missing     │
│     │    c) Check context ──> <context-warning> or              │
│     │                         <context-critical>                │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Agent Handoff Flow

```
Task N completes
    |
    v
task-runner ──> writes handoff.md (Step 8)
    |
    v
on-agent-complete.sh
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

All artifacts written to `.specs/<id>/artifacts/` unless noted.

### Generated During Autocode (by agent)

| Artifact | Agent | Trigger |
|----------|-------|---------|
| `justifications/` | coder | File modified in flagged category |
| `decisions/` | coder | Choice between approaches |
| `assumptions/` | coder | Requirement inferred |
| `risks/` | coder | Potential problem identified |
| `debt/` | coder | Shortcut taken |
| `review_hints/` | coder | Human judgment needed |
### Generated by Handoff Pipeline

| Artifact | Writer | Trigger |
|----------|--------|---------|
| `handoff/handoff.md` | task-runner (Step 8) | After each task completes |
| `handoff/SESSION_SUMMARY.md` | session-summarizer (via execute skill) | Context usage critical (>200k tokens) |

### Generated During Other Stages

| Artifact | Stage | Location |
|----------|-------|----------|
| `REQUIREMENT.md` | Spec | `.specs/<id>/` |
| `SPEC.md` | Spec | `.specs/<id>/` |
| `RESEARCH.md` | Plan | `.specs/<id>/` |
| `PLAN.md` | Plan | `.specs/<id>/` |
| `TODO.md` | Tasks | `.specs/<id>/` |
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
/autocode:new-spec ────────── (script only, no agent)

/autocode:create-plan ─────── plan-builder (opus)
                       ├── plan-researcher (sonnet)
                       └── plan-analyzer (sonnet)

/autocode:create-tasks ────── (inline, no agent; skill writes TODO.md directly)

/autocode:execute (skill, lightweight loop owner)
                       ├── task-runner (opus, fresh per task)
                       │     ├── tester (sonnet)
                       │     ├── coder (opus)
                       │     ├── analyzer (sonnet)
                       │     └── refactorer (sonnet)
                       └── session-summarizer (haiku)
```

---

