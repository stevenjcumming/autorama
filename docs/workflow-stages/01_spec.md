# Workflow: New Spec

## Purpose

Create a new spec folder with `REQUIREMENT.md` and `SPEC.md` files to begin the requirements analysis process.

## Command

```
/autopilot:new-spec <identifier>
```

## Arguments

| Argument | Required | Description |
|----------|----------|-------------|
| `identifier` | Yes | Unique name for the spec folder |

### Suggested Identifier Patterns

- `{ticket_id}` - e.g., `PROJ-123`
- `{N}` - e.g., `001`
- `{date}-{slug}` - e.g., `2026-01-15-auth-refactor`

## What It Does

1. Creates `.claude/specs/<identifier>/` directory
2. Creates `REQUIREMENT.md` for original requirements (verbatim)
3. Creates `SPEC.md` from template

## Directory Structure

```
.claude/
└── specs/
    └── <identifier>/
        ├── REQUIREMENT.md
        └── SPEC.md
```

## Next Steps

After creating the spec:

1. Paste original requirements in `REQUIREMENT.md`
2. Fill out `SPEC.md` with:
   - Overview and problem context
   - Requirements summary
   - Success metrics
   - Acceptance criteria
   - Out of scope items
3. Run `/autopilot:create-plan <identifier>` to generate the implementation plan

### Optional Next Step

If you with to generate the contents of SPEC.md, direct Claude to 

> Fill out the SPEC.md based on the requirements

