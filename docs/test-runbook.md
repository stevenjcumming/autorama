# Integration Test Scenarios

This document describes the integration test scenarios for the Autopilot.

## Test Setup

Each test requires:
1. A test spec folder at `.claude/specs/test-<scenario>/`
2. Required files: REQUIREMENT.md, SPEC.md, PLAN.md, TODO.md
3. Clean git state (commit or stash any changes)

## Test Scenarios

### T1: Single Task Completion with Auto-Commit

**Purpose:** Verify that a single task completes and auto-commits correctly.

**Setup:**
```bash
# Create minimal spec
mkdir -p .claude/specs/test-single-task/artifacts
echo "# Requirement\nAdd hello function" > .claude/specs/test-single-task/REQUIREMENT.md
echo "# Spec\nCreate hello.js with hello() function" > .claude/specs/test-single-task/SPEC.md
echo "# Plan\n1. Create hello.js" > .claude/specs/test-single-task/PLAN.md
echo "- [ ] [T1] Create hello.js with hello() function" > .claude/specs/test-single-task/TODO.md
```

**Execution:**
```bash
/autopilot:execute test-single-task
```

**Expected Results:**
- [ ] Task T1 is marked complete in TODO.md
- [ ] hello.js file is created
- [ ] Git commit exists with message matching `feat(test-single-task): complete T1 - *`
- [ ] handoff.md is generated at `artifacts/handoff/handoff.md`

**Verification Commands:**
```bash
grep -q "\[x\] \[T1\]" .claude/specs/test-single-task/TODO.md
test -f hello.js
git log -1 --oneline | grep -q "feat(test-single-task)"
test -f .claude/specs/test-single-task/artifacts/handoff/handoff.md
```

---

### T2: Multi-Task Loop with Handoffs

**Purpose:** Verify the loop continues across multiple tasks with proper handoffs.

**Setup:**
```bash
mkdir -p .claude/specs/test-multi-task/artifacts
cat > .claude/specs/test-multi-task/TODO.md << 'EOF'
## Phase 1: Setup
- [ ] [T1] Create config.js with default settings
- [ ] [T2] Create utils.js with helper functions
- [ ] [T3] Create index.js that imports config and utils
EOF
# ... create other required files
```

**Execution:**
```bash
/autopilot:execute test-multi-task
```

**Expected Results:**
- [ ] All 3 tasks are marked complete
- [ ] 3 separate git commits exist (one per task)
- [ ] handoff.md updated after each task
- [ ] Session summaries included in handoffs

**Verification:**
```bash
grep -c "\[x\]" .claude/specs/test-multi-task/TODO.md  # Should be 3
git log --oneline | head -3 | grep -c "feat(test-multi-task)"  # Should be 3
```

---

### T3: Resume from Incomplete State

**Purpose:** Verify autopilot correctly resumes from incomplete tasks.

**Setup:**
```bash
mkdir -p .claude/specs/test-resume/artifacts
cat > .claude/specs/test-resume/TODO.md << 'EOF'
- [x] [T1] Completed task
- [ ] [T2] Task that was in progress
- [ ] [T3] Pending task
EOF
# ... create other required files
```

**Execution:**
```bash
/autopilot:execute test-resume
```

**Expected Results:**
- [ ] Autopilot resumes from T2 (not T1)
- [ ] Context from handoff is loaded
- [ ] T2 and T3 complete successfully

**Verification:**
```bash
grep -q "\[x\] \[T2\]" .claude/specs/test-resume/TODO.md
```

---

### T4: Context Limit Handling

**Purpose:** Verify session summarizer triggers when context approaches limit.

**Setup:**
```bash
mkdir -p .claude/specs/test-context/artifacts
# Create spec with many tasks that generate lots of artifacts
cat > .claude/specs/test-context/TODO.md << 'EOF'
- [ ] [T1] Generate large artifact 1
- [ ] [T2] Generate large artifact 2
- [ ] [T3] Generate large artifact 3
- [ ] [T4] Generate large artifact 4
- [ ] [T5] Generate large artifact 5
EOF
```

**Execution:**
```bash
/autopilot:execute test-context
```

**Expected Results:**
- [ ] Session summaries are generated after tasks
- [ ] Context check script runs between tasks
- [ ] Summaries are compressed (target: 500-1000 tokens)
- [ ] Later tasks still have access to relevant context

**Verification:**
```bash
# Check session summaries exist in handoffs
grep -q "Session Summary" .claude/specs/test-context/artifacts/handoff/handoff.md
```

---

### T5: Background Agent Completion

**Purpose:** Verify background agents complete and trigger hooks correctly.

**Setup:**
```bash
mkdir -p .claude/specs/test-background/artifacts
cat > .claude/specs/test-background/TODO.md << 'EOF'
- [ ] [T1] Simple task for background execution
EOF
```

**Execution:**
```bash
/autopilot:execute test-background
```

**Expected Results:**
- [ ] Task runner spawns via Task tool
- [ ] PostToolUse hook (save-state.sh) triggers on Task completion
- [ ] SubagentStop hook (on-agent-complete.sh) triggers on agent stop
- [ ] Auto-commit and handoff directive are emitted after task completes

**Verification:**
```bash
# Verify hook artifacts
test -f .claude/specs/test-background/artifacts/handoff/handoff.md
git log -1 --oneline | grep -q "feat(test-background)"
```

---

## Hook Integration Tests

### H1: PreToolUse Hook - Context Loading

**Purpose:** Verify context is loaded before task agent starts.

**Test:**
1. Create handoff.md with known content
2. Run autopilot
3. Verify task agent receives context

**Verification:** Check task agent output references handoff content.

---

### H2: PostToolUse Hook - State Saving

**Purpose:** Verify state is saved after task completion.

**Test:**
1. Run autopilot on a single task
2. Verify `current.json` is written to `artifacts/state/` by save-state.sh (Task matcher)

---

### H3: SubagentStop Hook - Agent Complete

**Purpose:** Verify on-agent-complete.sh triggers correctly.

**Test:**
1. Run a task to completion
2. Verify auto-commit triggers on completed task
3. Verify `<handoff-needed>` directive is emitted for the execute command
4. Verify context check runs and emits `<context-warning>` or `<context-critical>` signals when appropriate

---

## Configuration Tests

### C1: Auto-Commit Format

**Expected:** Auto-commits use conventional commit format with body:
```
<type>(<spec_id>): <task_summary>

Complete [T<n>] for spec <spec_id>.

Files changed: <count>
Task: [T<n>]
```

### C2: Custom Agent Overrides

**Configuration:**
```yaml
# .claude/autopilot.yml
agents:
  tester: my-custom-tester
  coder: my-custom-coder
  refactorer: my-custom-refactorer
```

**Expected:** Custom agents are spawned instead of defaults.

---

## Error Handling Tests

### E1: Missing Prerequisites

**Test:** Run `/autopilot:execute` without TODO.md
**Expected:** Clear error message, no crash

### E2: Invalid Task Filter

**Test:** Run `/autopilot:execute spec T99` (non-existent task)
**Expected:** Error message indicating task not found

### E3: Hook Script Failure

**Test:** Make hook script return non-zero exit
**Expected:** Graceful handling, error reported, autopilot can continue or pause

### E4: Git Commit Failure

**Test:** Create scenario where git commit fails (e.g., no changes)
**Expected:** Warning logged, autopilot continues

---

## Running Tests

To run these tests manually:

```bash
# Run all tests
for test in test-single-task test-multi-task test-resume test-context test-background; do
  echo "Running $test..."
  # Setup test
  # Run autopilot
  # Verify results
  # Cleanup
done
```

## Success Criteria

All scenarios must pass:
- [ ] T1: Single task completion with auto-commit
- [ ] T2: Multi-task loop with handoffs
- [ ] T3: Resume from incomplete state
- [ ] T4: Context limit handling
- [ ] T5: Background agent completion
- [ ] H1-H3: Hook integration tests
- [ ] C1-C2: Configuration tests
- [ ] E1-E4: Error handling tests
