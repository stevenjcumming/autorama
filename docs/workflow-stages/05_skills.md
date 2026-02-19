# Skills: Custom Coding Patterns

## Overview

Skills are reusable coding patterns that teach the autopilot agents how to write code in your project's style. The autopilot agent dynamically selects the most appropriate skill based on task context.

## Directory Structure

```
.claude/
├── skills/
│   ├── service-object-skill/
│   │   └── SKILL.md
│   ├── controller-skill/
│   │   └── SKILL.md
│   └── react-component-skill/
│       └── SKILL.md
└── autopilot.yml           # Registers skills for autopilot
```

## Skill File Format

Each skill lives in `.claude/skills/<skill-name>/SKILL.md`:

```markdown
---
name: service-object-skill
description: Use for business logic classes in app/services/. Follows command
  pattern with .call method, result objects, and dependency injection.
---

# Service Object Skill

## When to Use

- Creating business logic in `app/services/`
- Operations that need to be testable in isolation
- Multi-step processes with validation

## Pattern

\`\`\`ruby
class MyService
  def initialize(dependency:)
    @dependency = dependency
  end

  def call(input)
    # validation
    # business logic
    # return result object
  end
end
\`\`\`

## Conventions

- Single public method: `.call`
- Inject dependencies via constructor
- Return result objects, not raw values
- Validate inputs before processing

## Examples

[Include real examples from your codebase]
```

## Frontmatter Requirements

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique skill identifier |
| `description` | Yes | When to use this skill (used for dynamic selection) |

### Writing Good Descriptions

The `description` field is critical - it's how the autopilot agent decides which skill to use. Include:

- **File patterns**: Where this skill applies (`app/services/`, `src/components/`)
- **Task types**: What kind of work (`business logic`, `API endpoints`, `UI components`)
- **Key patterns**: What makes this distinct (`command pattern`, `hooks`, `REST conventions`)

**Good descriptions:**
```yaml
description: Use for business logic classes in app/services/. Follows command
  pattern with .call method, result objects, and dependency injection.

description: Use for React components in src/components/. Follows functional
  component pattern with TypeScript, custom hooks, and CSS modules.

description: Use for Rails controllers in app/controllers/. Thin controller
  pattern that delegates to services, handles params/responses only.
```

**Bad descriptions:**
```yaml
description: For services  # Too vague
description: Ruby code     # Not specific enough
description: Use this skill when writing service objects in the services
  folder of the application  # Redundant, doesn't mention patterns
```

## Registering Skills

Add skills to `.claude/autopilot.yml`:

```yaml
agents:
  tester: autopilot-tester
  coder: autopilot-coder
  refactorer: autopilot-refactorer

# Skills available to coder agent
coding_skills:
  - service-object-skill
  - controller-skill
  - react-component-skill

# Skills available to tester agent
testing_skills:
  - rspec-skill
  - jest-skill

# Skills available to refactorer agent
refactoring_skills:
  - dry-refactor-skill
```

## How Selection Works

When the autopilot-coder receives a task:

1. **Analyzes the task** to determine:
   - What type of code will be created/modified
   - What file paths are involved
   - What patterns are needed

2. **Matches against skill descriptions** by evaluating each registered skill

3. **Selects the best match**:
   - One skill clearly fits → use that skill
   - Multiple skills apply → use the most specific one
   - No skill fits → proceed without a skill

4. **Loads skill instructions** and follows its patterns during implementation

### Example Selection

**Task:** `[T1] Create OrderProcessor at app/services/order_processor.rb`

**Available skills:**
- `service-object-skill`: "Use for business logic classes in app/services/..."
- `controller-skill`: "Use for Rails controllers in app/controllers/..."

**Selection reasoning:**
- Task mentions `app/services/` → matches service-object-skill
- Task is about "processor" (business logic) → matches service-object-skill
- No controller patterns needed → controller-skill doesn't match

**Result:** Uses `service-object-skill`

## Skill Content Guidelines

### What to Include

1. **When to Use** - Clear criteria for skill applicability
2. **Pattern** - Code template showing the structure
3. **Conventions** - Rules and standards to follow
4. **Examples** - Real code from your codebase
5. **Anti-patterns** - Common mistakes to avoid (optional)
6. **Testing** - How to test code written with this skill (optional)

### Keep It Focused

- One skill = one pattern
- Don't combine multiple unrelated patterns
- If a skill gets too long, split it

### Use Your Codebase

- Reference real files as examples
- Link to existing implementations
- Keep patterns consistent with your actual code

## Integration with Autopilot

```
/autopilot:execute my-feature
       │
       ▼
┌──────────────────┐
│ Load autopilot   │
│ config + skills  │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ For each task:   │
│ 1. Select skill  │◄── Based on task + skill descriptions
│ 2. Load skill    │
│ 3. Implement     │◄── Following skill patterns
│ 4. Test/Refactor │
└──────────────────┘
```

## Creating Your First Skill

1. **Identify a pattern** you use repeatedly in your codebase

2. **Create the skill directory**:
   ```bash
   mkdir -p .claude/skills/my-pattern-skill
   ```

3. **Write SKILL.md** with frontmatter and content

4. **Register in autopilot.yml**:
   ```yaml
   coding_skills:
     - my-pattern-skill
   ```

5. **Test it** by running `/autopilot:execute` on a task that should use this skill

## Troubleshooting

### Skill Not Being Selected

- Check that skill is registered in `autopilot.yml`
- Verify description matches task characteristics
- Make description more specific to the task type

### Wrong Skill Selected

- Make descriptions more distinct between skills
- Add file path patterns to descriptions
- Be more specific about when NOT to use a skill

### Skill Applied Incorrectly

- Add more examples to the skill
- Clarify conventions section
- Add anti-patterns section showing what to avoid
