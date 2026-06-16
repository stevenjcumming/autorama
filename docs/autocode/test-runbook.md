# Integration Test Scenarios

This document describes the integration test scenarios for the Autopilot.

## Test Setup

Each test requires:
1. A test spec folder at `.specs/test-<scenario>/`
2. Required files: REQUIREMENT.md, SPEC.md, PLAN.md, TODO.md
3. Clean git state (commit or stash any changes)

## Test Scenarios

### T1: Single Task Completion

**Purpose:** Verify that a single task completes correctly.

**Setup:**
```bash
# Create minimal spec
mkdir -p .specs/test-single-task/artifacts
echo "# Requirement\nAdd hello function" > .specs/test-single-task/REQUIREMENT.md
echo "# Spec\nCreate hello.js with hello() function" > .specs/test-single-task/SPEC.md
echo "# Plan\n1. Create hello.js" > .specs/test-single-task/PLAN.md
echo "- [ ] [T1] Create hello.js with hello() function" > .specs/test-single-task/TODO.md
```

**Execution:**
```bash
/autocode:execute test-single-task
```

**Expected Results:**
- [ ] Task T1 is marked complete in TODO.md
- [ ] hello.js file is created
- [ ] handoff.md is generated at `artifacts/handoff/handoff.md`

**Verification Commands:**
```bash
grep -q "\[x\] \[T1\]" .specs/test-single-task/TODO.md
test -f hello.js
test -f .specs/test-single-task/artifacts/handoff/handoff.md
```

---

### T2: Multi-Task Loop with Handoffs

**Purpose:** Verify the loop continues across multiple tasks with proper handoffs.

**Setup:**
```bash
mkdir -p .specs/test-multi-task/artifacts
cat > .specs/test-multi-task/TODO.md << 'EOF'
## Phase 1: Setup
- [ ] [T1] Create config.js with default settings
- [ ] [T2] Create utils.js with helper functions
- [ ] [T3] Create index.js that imports config and utils
EOF
# ... create other required files
```

**Execution:**
```bash
/autocode:execute test-multi-task
```

**Expected Results:**
- [ ] All 3 tasks are marked complete
- [ ] handoff.md updated after each task
- [ ] Session summaries included in handoffs

**Verification:**
```bash
grep -c "\[x\]" .specs/test-multi-task/TODO.md  # Should be 3
```

---

### T3: Resume from Incomplete State

**Purpose:** Verify autocode correctly resumes from incomplete tasks.

**Setup:**
```bash
mkdir -p .specs/test-resume/artifacts
cat > .specs/test-resume/TODO.md << 'EOF'
- [x] [T1] Completed task
- [ ] [T2] Task that was in progress
- [ ] [T3] Pending task
EOF
# ... create other required files
```

**Execution:**
```bash
/autocode:execute test-resume
```

**Expected Results:**
- [ ] Autocode resumes from T2 (not T1)
- [ ] Context from handoff is loaded
- [ ] T2 and T3 complete successfully

**Verification:**
```bash
grep -q "\[x\] \[T2\]" .specs/test-resume/TODO.md
```

---

### T4: Context Limit Handling

**Purpose:** Verify session summarizer triggers when context approaches limit.

**Setup:**
```bash
mkdir -p .specs/test-context/artifacts
# Create spec with many tasks that generate lots of artifacts
cat > .specs/test-context/TODO.md << 'EOF'
- [ ] [T1] Generate large artifact 1
- [ ] [T2] Generate large artifact 2
- [ ] [T3] Generate large artifact 3
- [ ] [T4] Generate large artifact 4
- [ ] [T5] Generate large artifact 5
EOF
```

**Execution:**
```bash
/autocode:execute test-context
```

**Expected Results:**
- [ ] Session summaries are generated after tasks
- [ ] Context check script runs between tasks
- [ ] Summaries are compressed (target: 500-1000 tokens)
- [ ] Later tasks still have access to relevant context

**Verification:**
```bash
# Check session summaries exist in handoffs
grep -q "Session Summary" .specs/test-context/artifacts/handoff/handoff.md
```

---

### T5: Background Agent Completion

**Purpose:** Verify background agents complete and trigger hooks correctly.

**Setup:**
```bash
mkdir -p .specs/test-background/artifacts
cat > .specs/test-background/TODO.md << 'EOF'
- [ ] [T1] Simple task for background execution
EOF
```

**Execution:**
```bash
/autocode:execute test-background
```

**Expected Results:**
- [ ] Task runner spawns via Task tool
- [ ] SubagentStop hook (on-agent-complete.sh) triggers on agent stop
- [ ] The `<task-completed>` tag is parsed and the artifact audit and context check run after task completes

**Verification:**
```bash
# Verify hook artifacts
test -f .specs/test-background/artifacts/handoff/handoff.md
```

---

## Hook Integration Tests

### H1: PreToolUse Hook - Context Loading

**Purpose:** Verify context is loaded before task agent starts.

**Test:**
1. Create handoff.md with known content
2. Run autocode
3. Verify task agent receives context

**Verification:** Check task agent output references handoff content.

---

### H2: SubagentStop Hook - Agent Complete

**Purpose:** Verify on-agent-complete.sh triggers correctly.

**Test:**
1. Run a task to completion
2. Verify the hook parses the `<task-completed>` structured tag from the agent output
3. Verify the artifact audit runs and emits `<artifact-audit>` when the trail is missing
4. Verify context check runs and emits `<context-warning>` or `<context-critical>` signals when appropriate

---

## Error Handling Tests

### E1: Missing Prerequisites

**Test:** Run `/autocode:execute` without TODO.md
**Expected:** Clear error message, no crash

### E2: Invalid Task Filter

**Test:** Run `/autocode:execute spec T99` (non-existent task)
**Expected:** Error message indicating task not found

### E3: Hook Script Failure

**Test:** Make hook script return non-zero exit
**Expected:** Graceful handling, error reported, autocode can continue or pause

### E4: Git Commit Failure

**Test:** Create scenario where git commit fails (e.g., no changes)
**Expected:** Warning logged, autocode continues

---

## Running Tests

To run these tests manually:

```bash
# Run all tests
for test in test-single-task test-multi-task test-resume test-context test-background; do
  echo "Running $test..."
  # Setup test
  # Run autocode
  # Verify results
  # Cleanup
done
```

## Success Criteria

All scenarios must pass:
- [ ] T1: Single task completion
- [ ] T2: Multi-task loop with handoffs
- [ ] T3: Resume from incomplete state
- [ ] T4: Context limit handling
- [ ] T5: Background agent completion
- [ ] H1-H2: Hook integration tests
- [ ] C1: Configuration tests
- [ ] E1-E4: Error handling tests
