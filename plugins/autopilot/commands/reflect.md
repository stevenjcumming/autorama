---
description: Analyze session signals and propose rules for .claude/rules/
allowed-tools: Bash, Read, Glob, Grep, Task, AskUserQuestion
argument-hint: <identifier>
model: opus
---

# Reflect

Analyze session signals and artifacts to propose rules for `.claude/rules/`.

## Overview

The Reflect stage reviews what happened during implementation and proposes rules:

1. **Gather Data** - Count signals and artifacts available
2. **Analyze** - Read and categorize findings by confidence
3. **Propose Rules** - Present a table of potential rules
4. **User Selection** - User chooses which rules to create
5. **Create Rules** - Spawn rules-builder agent for selected rules

## Step 1: Run Reflect Script

Execute the reflect script to gather summary data:

```bash
bash $CLAUDE_PLUGIN_ROOT/scripts/reflect.sh $ARGUMENTS
```

## Step 2: Analyze Signals and Artifacts

### Read Signals

Use the spec identifier from `$ARGUMENTS` to locate artifacts:

```
SPEC_ID = $ARGUMENTS (or extracted from context)
Glob(".claude/specs/{SPEC_ID}/artifacts/signals/**/*.md")
```

For each signal file:
1. Read the content
2. Extract `signal_type`, `confidence`, `context` from frontmatter
3. Note the "Potential Improvement" section

Categorize by signal type:
- **Corrections** (High confidence) - Agent changed approach after feedback
- **Rejections** (High confidence) - Tests caught incorrect changes
- **Repetitions** (High confidence) - Same issue occurred multiple times
- **Approvals** (Medium confidence) - Approach was validated
- **Clarifications** (Medium confidence) - Missing info was discovered
- **Praise** (Low confidence) - Positive feedback received

### Read Artifacts

```
Glob(".claude/specs/{SPEC_ID}/artifacts/decisions/**/*.md")
Glob(".claude/specs/{SPEC_ID}/artifacts/assumptions/**/*.md")
```

Look for:
- Decisions that could become defaults
- Assumptions that were validated or invalidated

## Step 3: Generate Rule Proposals

For each finding, determine if it should become a rule:

**High Confidence** (corrections, rejections, repetitions):
- Direct feedback indicates a clear convention needed
- Should become a rule

**Medium Confidence** (approvals, clarifications):
- Pattern worked but needs more validation
- Consider as a rule candidate

**Low Confidence** (praise, single instances):
- Not enough data for a rule
- Document for monitoring only

For each proposed rule, determine:
1. **Rule name** - Descriptive filename (e.g., `api-error-format.md`)
2. **Paths** - Glob patterns if path-specific, or empty for global rules
3. **Title** - Human-readable title
4. **Content** - The actual rule guidelines
5. **Confidence** - High/Medium/Low
6. **Source** - Which signal/artifact triggered this

## Step 4: Present Proposals Table

Present the proposals to the user:

```markdown
## Proposed Rules

Based on {X} signals and {Y} artifacts analyzed:

| # | Rule | Paths | Confidence | Source |
|---|------|-------|------------|--------|
| 1 | {rule-name.md} | {paths or "global"} | {High/Medium/Low} | {signal type: context} |
| 2 | ... | ... | ... | ... |

### Rule Details

#### 1. {rule-name.md}

**Paths**: {glob patterns or "Global (applies to all files)"}
**Confidence**: {level}
**Source**: {signal/artifact reference}

**Proposed content**:
```markdown
{the rule content that would be written}
```

---

#### 2. ...
```

## Step 5: User Selection

Ask the user which rules to create:

```
AskUserQuestion(
  question: "Which rules would you like to create?",
  options: [
    { label: "All rules", description: "Create all proposed rules" },
    { label: "High confidence only", description: "Create only high-confidence rules" },
    { label: "Select specific rules", description: "Choose which rules to create" },
    { label: "None", description: "Don't create any rules now" }
  ]
)
```

If "Select specific rules", ask follow-up to get the rule numbers.

## Step 6: Spawn Rules Builder

For selected rules, spawn the rules-builder agent:

```
Task(
  subagent_type="rules-builder",
  prompt="Create the following rules in .claude/rules/:

  RULES:
  {list of selected rules with all details:
   - name
   - paths (if any)
   - title
   - content
   - source
  }

  Create each rule file and return a summary of what was created."
)
```

## Step 7: Present Results

After the agent completes:

```markdown
## Reflect Complete

### Rules Created
{list from rules-builder output}

### Rules Skipped
{any rules the user chose not to create}

### Patterns to Monitor
{low-confidence patterns that weren't made into rules}

### Next Steps
- Review created rules in `.claude/rules/`
- Adjust rule content or paths as needed
- Rules will automatically apply in future sessions
```

## Notes

- Rules with `paths` frontmatter only apply to matching files
- Rules without `paths` apply globally
- User controls what rules get created
- Low-confidence findings are reported but not proposed as rules
- Even without signals, artifacts can suggest useful rules
