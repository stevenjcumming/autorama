# Autopilot Workflow Stages

A structured framework for AI-autonomous software development with human oversight.

## Workflow Structure

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

---

## Stage Descriptions

### 1. Requirements

**Type**: Human action

Gather and document the original requirements for the feature or task. This is the starting point before any automated workflow begins.

**Actions**:
- Collect requirements from stakeholders, tickets, or discussions
- Document verbatim requirements for reference
- Identify any ambiguities or gaps to clarify

---

### 2. Spec

**Command**: `/autopilot:new-spec <identifier>`

Create a specification folder with structured documentation of the requirements.

**What It Does**:
1. Creates `.claude/specs/<identifier>/` directory
2. Creates `REQUIREMENT.md` for original requirements (verbatim)
3. Creates `SPEC.md` from template

**Human Actions**:
- Paste original requirements into `REQUIREMENT.md`
- Fill out `SPEC.md` with overview, acceptance criteria, and scope

**Loop Back**: Tasks stage returns here if task breakdown reveals missing requirements.

---

### 3. Plan

**Command**: `/autopilot:create-plan <identifier>`

Generate an implementation plan from the spec using automated research and analysis.

**What It Does**:
1. Validates spec folder and `SPEC.md` exist
2. Spawns `plan-builder` agent, which:
   - Spawns `plan-researcher` to analyze codebase patterns and dependencies
   - Writes `RESEARCH.md` with findings
   - Creates `PLAN.md`
   - Spawns `plan-analyzer` to validate the plan

**Human Actions**:
- Review `PLAN.md` and analysis report
- Address identified gaps and risks
- Approve plan before proceeding

---

### 4. Tasks

**Command**: `/autopilot:create-tasks <identifier>`

Convert the implementation plan into a phased TODO checklist.

**What It Does**:
1. Validates `PLAN.md` exists
2. Spawns `task-builder` agent to extract tasks from plan
3. Creates `TODO.md` with atomic, ordered tasks

**Human Actions**:
- Review task list for completeness
- Verify task ordering makes sense
- Approve before starting implementation

**Loop Back**: Returns to Spec if tasks reveal missing requirements or unclear scope.

---

### 5. Test → Code → Analysis → Refactor Loop

**Command**: `/autopilot:execute <identifier> [T<n>|P<n>]`

Execute the implementation loop autonomously for a spec using the Agent Harness architecture.

#### Agent Harness Architecture

Autopilot uses background agents with clean handoffs between tasks:

```
Execute Command
    ├── Load context (handoff)
    ├── Spawn Task Agent (background)
    │   └── Test → Code → Analysis → Refactor
    ├── Save state (handoff, commit)
    └── Continue to next task
```

**Key features**:
- **Fresh context per task** - Each task agent starts clean
- **Handoff artifacts** - Context preserved between tasks
- **Auto-commits** - Git history tracks each task completion

#### Test Phase (Write Tests + Run)

**What It Does**:
- Writes failing tests from acceptance criteria via `autopilot-tester` agent (TDD red phase)
- Task-runner executes tests via Bash (expecting failure, then pass after coding)


**Artifacts Generated**: Test files

#### Code Phase

**What It Does**:
- Implements current task via `autopilot-coder` agent
- Requires justifications for flagged file modifications
- Documents decisions, assumptions, and risks

**Artifacts Generated**: All artifacts are written to `.claude/specs/<identifier>/artifacts/`:
- `justifications/` - Why changes were made
- `decisions/` - Approach choices
- `assumptions/` - Inferred requirements
- `risks/` - Potential problems
- `review_hints/` - Human review needed
- `debt/` - Shortcuts taken

#### Analysis Phase

**What It Does**:
- Runs static analysis tools via `autopilot-analyzer` agent
- Reports lint errors, type issues, and code quality problems
- Provides fix instructions for blocking issues



#### Refactor Phase

**What It Does**:
- Cleans up implementation via `autopilot-refactorer` agent
- Applies code quality improvements
- Returns to Test phase to verify changes

#### Loop Behavior

- Continues Test → Code → Analysis → Refactor until tests pass and no refactoring needed
- **Auto-commits** after each task completion (configurable)
- **Generates handoff** with session summary for next task
- Marks task complete in `TODO.md`
- Moves to next task
- **Pauses automatically** on:
  - Repeated analyzer violations (same rule 3+ times)
  - Explicit human review flags
- Pauses for human input on repeated failures or spec gaps

---

### 6. Review

**Command**: `/autopilot:review <identifier>`

Human checkpoint to review all changes and artifacts before finalizing.

**What It Does**:
1. Summarizes git changes and file modifications
2. Lists artifacts from `.claude/specs/<identifier>/artifacts/` by type with counts
3. Highlights high-risk items requiring attention
4. Presents review hints with questions for human judgment
5. Shows review checklist

**Human Actions**:
- Review code changes against stated intent
- Validate assumptions documented during implementation
- Accept or address technical debt
- Check all high-risk items
- Decide: Approve, Request changes, or Reject

**Loop Back**: Returns to Spec stage if fundamental issues discovered.

---

### 7. Submit

**Commands**: `/autopilot:commit`, `/autopilot:sync-pr`

Finalize implementation by creating commits and managing pull requests.

#### /autopilot:commit

**What It Does**:
1. Stages all changes
2. Analyzes diff for context
3. Creates conventional commit with detailed message

#### /autopilot:sync-pr

**What It Does**:
1. Creates feature branch if on main/master
2. Pushes to remote
3. Creates or updates GitHub PR with description

**Human Actions**:
- Review commit messages
- Monitor PR for review feedback
- Address review comments
- Merge when approved

---

## Quick Reference

| Stage | Command | Input | Output |
|-------|---------|-------|--------|
| Spec | `/autopilot:new-spec <id>` | Requirements | `REQUIREMENT.md`, `SPEC.md` |
| Plan | `/autopilot:create-plan <id>` | Spec | `RESEARCH.md`, `PLAN.md` |
| Tasks | `/autopilot:create-tasks <id>` | Plan | `TODO.md` |
| Autopilot | `/autopilot:execute <id>` | Tasks | Code changes, per-spec artifacts, commits |
| Review | `/autopilot:review <id>` | Changes, per-spec artifacts | Human decision |
| Submit | `/autopilot:commit`, `/autopilot:sync-pr` | Changes | Commits, PR |
