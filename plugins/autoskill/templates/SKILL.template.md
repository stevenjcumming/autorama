---
name: {{skill_name}}
description: >
  {{Trigger description. This field sits in Claude's context at all times and
  is the only thing Claude sees before deciding to load the skill body. It
  must stand alone as a trigger: do not write "see below" or "as described in
  Steps". Enumerate the phrases a developer would actually say and reference
  the pattern shape, not the internal base-class name.}}
---

# {{Skill Name}}

## When to Use

{{Clear conditions under which this skill applies. Include positive signals
("when you see X") and negative signals ("do not use this for Y"). Be specific
enough that Claude can distinguish this pattern from similar ones.}}

## Quick Checklist

{{One-line-per-step checkbox list mirroring the Steps below. Each item must be
concrete enough to verify against a PR diff. Omit this section entirely if
Steps has fewer than four items.}}

- [ ] {{concise checklist item for Step 1}}
- [ ] {{concise checklist item for Step 2}}
- [ ] {{concise checklist item for Step 3}}
- [ ] {{concise checklist item for Step 4}}

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

## Examples

{{Two or three before/after pairs showing the triggering context for this
pattern. Use the Input/Output format below. Draw examples from real moments
observed in the source files. Omit this section only if discovery produced
no concrete triggering moments to anchor against.}}

**Input:** {{what the developer said, or the shape of the request that should
trigger the pattern}}

**Output:** {{the concrete artifact or change that should result}}

## References

{{List paths to other files in this skill folder, if any. Remove this section
entirely if the skill only contains SKILL.md and metadata.json.}}

- `templates/example.md` - {{structural template for the main artifact}}
- `references/edge-cases.md` - {{detailed edge case documentation}}
