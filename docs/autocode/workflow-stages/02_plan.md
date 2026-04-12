# Workflow: Create Plan

## Purpose

Create a `PLAN.md` implementation plan from the contents of the specified spec folder using automated research and analysis.

## Command

```
/autocode:create-plan <identifier>
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `identifier` | Yes | Name of existing spec folder |

## Prerequisites

- Spec folder must exist at `.claude/specs/<identifier>/`
- `SPEC.md` must be present and filled out
- `REQUIREMENT.md` should contain the original requirements

## What It Does

1. Validates spec folder and `SPEC.md` exist
2. Creates `PLAN.md` from template
3. Spawns `plan-builder` agent which orchestrates:
   - `plan-researcher` - Analyzes codebase for patterns and dependencies
   - `plan-analyzer` - Validates the completed plan

## Agent Pipeline

```
plan-builder
├── Reads SPEC.md + REQUIREMENT.md
├── Spawns plan-researcher → writes RESEARCH.md
├── Writes PLAN.md
├── Spawns plan-analyzer → returns analysis
└── Returns summary + analysis to user
```

### Agents

| Agent | Purpose | Output |
|-------|---------|--------|
| `plan-builder` | Orchestrates plan creation | PLAN.md + summary |
| `plan-researcher` | Finds relevant files and patterns | RESEARCH.md |
| `plan-analyzer` | Validates plan against codebase | Analysis report |

## Directory Structure

```
.claude/
└── specs/
    └── <identifier>/
        ├── REQUIREMENT.md
        ├── SPEC.md
        ├── RESEARCH.md   <-- Created by plan-researcher
        └── PLAN.md       <-- Created and filled by plan-builder
```

## PLAN.md Sections

| Section | Purpose |
|---------|---------|
| Overview | 1-2 sentence summary of approach |
| Current State Analysis | What exists, patterns, constraints |
| Desired End State | Target state and verification |
| What We're NOT Doing | Explicit scope boundaries |
| Implementation Approach | High-level strategy |
| Phases | Ordered implementation steps with success criteria |
| Testing Strategy | Unit, integration, and manual tests |
| Risks & Considerations | Issues and mitigations |
| References | Links to spec and codebase |

## Analysis Checklist

The `plan-analyzer` agent validates:

- [ ] Does the plan reference the right files?
- [ ] Are there existing patterns it should follow?
- [ ] Are dependencies and side effects identified?
- [ ] Is the scope appropriate (not too big, not too small)?
- [ ] Is the testing strategy adequate?
- [ ] Are there edge cases or error scenarios missing?
- [ ] Is the phasing logical?
- [ ] Are success criteria specific and verifiable?

## Output

The command returns:
- Location of completed PLAN.md
- Research summary from RESEARCH.md
- Full analysis with strengths, gaps, risks, and suggestions
- Next steps for user review

## Next Steps

After the command completes:

1. Review PLAN.md and the analysis
2. Address identified gaps and risks
3. Resolve any open questions
4. Approve plan before implementation

### Resolving Open Questions

You can resolve open questions either inline or in the SPEC.md body

#### Inline Resolution

- [x] How should XYZ lookup the file? → Convention-based directory structure

#### Update the SPEC.md body

For more complex answer, update the SPEC.md body and point to the section  

- [x] How should cassette lookup work? → See "Cassette Resolution" section
