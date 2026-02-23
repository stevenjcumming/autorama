# Rules

Rules live in `.claude/rules/` and are automatically loaded by Claude Code in all future sessions.

## Rule Format

**Global rule** (applies everywhere):

```markdown
# API Error Format

Always return JSON error responses with `error`, `message`, and `code` fields.
```

**Path-specific rule** (applies to matching files):

```markdown
---
paths:
  - "src/api/**/*.ts"
---

# API Controller Conventions

- All endpoints must validate input before processing
- Use the shared error formatter for all error responses
```

## Storage

Rules are written to `.claude/rules/` and version-controlled. Claude Code loads them automatically based on the working context -- path-specific rules only apply when working on matching files.

## Configuration

| Key | Default | Effect |
|-----|---------|--------|
| `static_analysis.max_fix_attempts` | `2` | Fix attempts before logging and continuing |

## Related Documentation

- [Evaluation Pipeline](evaluation_pipeline.md)
- [Agent Handoff](agent-handoff.md)
- [Configuration](configuration.md)
- [Artifacts](artifacts.md)
