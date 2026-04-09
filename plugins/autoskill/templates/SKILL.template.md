---
name: {{skill_name}}
description: >
  {{trigger_description}}
---

# {{Skill Name}}

## When to Use

{{Clear conditions under which this skill applies. Include positive signals
("when you see X") and negative signals ("do not use this for Y"). Be specific
enough that Claude can distinguish this pattern from similar ones.}}

## Steps

1. {{First step, described as intent not commands}}
2. {{Second step}}
3. {{Continue as needed}}

Each step describes what to accomplish. Claude determines the right approach
based on the project's stack and structure. Do not prescribe specific tool calls
or language-specific commands.

## Inline Context

Key facts Claude needs while executing the pattern. This is not a tutorial;
it is contextual knowledge that prevents common mistakes.

- {{Convention or constraint from the project}}
- {{Convention or constraint from the project}}

## Edge Cases

- {{Situation that requires special handling and how to handle it}}
- {{Another edge case}}

## Testing

{{What a complete test looks like for this pattern. Describe the shape of a good
test without naming specific frameworks unless the project's stack makes the
choice unambiguous. Include what to assert, what to mock or stub, and what
constitutes sufficient coverage for one instance of this pattern.}}

## References

{{List paths to other files in this skill folder, if any. Remove this section
entirely if the skill only contains SKILL.md and metadata.json.}}

- `templates/example.md` - {{structural template for the main artifact}}
- `references/edge-cases.md` - {{detailed edge case documentation}}
