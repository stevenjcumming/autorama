# Context: {Directory Name}

## Purpose
<!-- Non-obvious domain context, ownership boundaries, or constraints specific to this directory. Not a README. Omit this section for conventional directories where the name says it all. -->

## Key References
<!-- Files the agent should load before acting here. Root-relative paths for local files, full URLs for external repositories. Each entry explains why it matters here. Keep the list short. -->
- [name] -- [why it matters here]

## Docs
<!-- Only include if the directory is flat and contains files from multiple unrelated domains. When a file matches a pattern, its references load alongside Key References (cumulative). -->

| When this file is opened | Load these references |
|---------|------------|
| [glob or substring] | [pointers] |

## Tasks
<!-- Only include if the directory has repeatable development actions requiring specific guidance. Each bundle is the complete specification for that task. All paths are root-relative. -->

| When doing this | Use these tools |
|------|-------|
| [project-specific task] | /instructions/[file].md, /rules/[file].md, /skills/[skill-name] |
| [framework-specific task] | /instructions/[file].md, /skills/[skill-name] |

## Never Do Here
<!-- Hard constraints that apply regardless of the active task. Axioms only: non-obvious, frequently violated, or catastrophic-if-missed. Do not duplicate what task bundles already enforce. -->
- [Hard constraint]
