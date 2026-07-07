#!/usr/bin/env python3
"""Consistency checks for the autoskill plugin.

Stdlib-only (no PyYAML): this repo's frontmatter is flat `key: value`
pairs, so a minimal line-based parser is sufficient. Run from the plugin
root (invoked by `make consistency` / `make test`).

Checks:
  1. Every skills/*/SKILL.md and agents/*.md has parseable frontmatter
     with a `name:` and a `description:` field.
  2. Each skill's frontmatter `name:` matches its containing directory name.
  3. Each `description:` is under 1024 characters (the loader's hard limit;
     see references/skill-output-guide.md's "Hard Limits" section).
  4. Every `subagent_type="autoskill:<x>"` referenced in a SKILL.md has a
     corresponding agent file whose frontmatter `name:` is exactly `<x>`.
  5. The version in .claude-plugin/plugin.json matches the version recorded
     for autoskill in the repo-root .claude-plugin/marketplace.json.

Exits non-zero and prints every failure found (does not stop at the first).
Exits 0 with a short summary if everything passes.
"""

import json
import re
import sys
from pathlib import Path

DESCRIPTION_LIMIT = 1024

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
REPO_ROOT = PLUGIN_ROOT.parent.parent


def parse_frontmatter(text):
    """Parse a flat `key: value` YAML-ish frontmatter block delimited by
    `---` lines. Returns (dict, error) where error is a string describing
    why parsing failed, or None on success.

    Only top-level scalar `key: value` pairs are supported (this repo does
    not use nested maps, lists, or multi-line values in frontmatter).
    """
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return None, "missing opening '---' frontmatter delimiter"

    end_index = None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_index = i
            break
    if end_index is None:
        return None, "missing closing '---' frontmatter delimiter"

    fields = {}
    for raw_line in lines[1:end_index]:
        if not raw_line.strip():
            continue
        if ":" not in raw_line:
            return None, f"unparseable frontmatter line: {raw_line!r}"
        key, _, value = raw_line.partition(":")
        fields[key.strip()] = value.strip()

    return fields, None


def collect_failures():
    failures = []

    skills_dir = PLUGIN_ROOT / "skills"
    agents_dir = PLUGIN_ROOT / "agents"

    skill_files = sorted(skills_dir.glob("*/SKILL.md")) if skills_dir.is_dir() else []
    agent_files = sorted(agents_dir.glob("*.md")) if agents_dir.is_dir() else []

    agent_names = {}  # name field -> file path (for check 4)

    # --- Checks 1-2: skills ---
    for skill_path in skill_files:
        rel = skill_path.relative_to(PLUGIN_ROOT)
        text = skill_path.read_text()
        fields, err = parse_frontmatter(text)
        if err is not None:
            failures.append(f"{rel}: {err}")
            continue

        name = fields.get("name")
        description = fields.get("description")

        if not name:
            failures.append(f"{rel}: missing required 'name' field in frontmatter")
        if not description:
            failures.append(f"{rel}: missing required 'description' field in frontmatter")

        expected_dir_name = skill_path.parent.name
        if name and name != expected_dir_name:
            failures.append(
                f"{rel}: frontmatter name '{name}' does not match "
                f"containing directory name '{expected_dir_name}'"
            )

        if description and len(description) >= DESCRIPTION_LIMIT:
            failures.append(
                f"{rel}: description is {len(description)} characters, "
                f"exceeds the {DESCRIPTION_LIMIT}-character hard limit"
            )

    # --- Checks 1, 3: agents ---
    for agent_path in agent_files:
        rel = agent_path.relative_to(PLUGIN_ROOT)
        text = agent_path.read_text()
        fields, err = parse_frontmatter(text)
        if err is not None:
            failures.append(f"{rel}: {err}")
            continue

        name = fields.get("name")
        description = fields.get("description")

        if not name:
            failures.append(f"{rel}: missing required 'name' field in frontmatter")
        if not description:
            failures.append(f"{rel}: missing required 'description' field in frontmatter")

        if description and len(description) >= DESCRIPTION_LIMIT:
            failures.append(
                f"{rel}: description is {len(description)} characters, "
                f"exceeds the {DESCRIPTION_LIMIT}-character hard limit"
            )

        if name:
            agent_names[name] = rel

    # --- Check 4: cross-file subagent_type consistency ---
    subagent_pattern = re.compile(r'subagent_type="autoskill:([^"]+)"')
    for skill_path in skill_files:
        rel = skill_path.relative_to(PLUGIN_ROOT)
        text = skill_path.read_text()
        for match in subagent_pattern.finditer(text):
            referenced = match.group(1)
            if referenced not in agent_names:
                failures.append(
                    f"{rel}: references subagent_type=\"autoskill:{referenced}\" "
                    f"but no agent under agents/ declares name: {referenced}"
                )

    # --- Check 5: version consistency ---
    plugin_json_path = PLUGIN_ROOT / ".claude-plugin" / "plugin.json"
    marketplace_json_path = REPO_ROOT / ".claude-plugin" / "marketplace.json"

    plugin_version = None
    if plugin_json_path.is_file():
        try:
            plugin_data = json.loads(plugin_json_path.read_text())
            plugin_version = plugin_data.get("version")
            if not plugin_version:
                failures.append(
                    f"{plugin_json_path.relative_to(PLUGIN_ROOT)}: missing 'version' field"
                )
        except json.JSONDecodeError as e:
            failures.append(f"{plugin_json_path.relative_to(PLUGIN_ROOT)}: invalid JSON ({e})")
    else:
        failures.append(f"{plugin_json_path}: file not found")

    marketplace_version = None
    if marketplace_json_path.is_file():
        try:
            marketplace_data = json.loads(marketplace_json_path.read_text())
            for entry in marketplace_data.get("plugins", []):
                if entry.get("name") == "autoskill":
                    marketplace_version = entry.get("version")
                    break
            if marketplace_version is None:
                failures.append(
                    f"{marketplace_json_path}: no 'autoskill' entry with a 'version' field found"
                )
        except json.JSONDecodeError as e:
            failures.append(f"{marketplace_json_path}: invalid JSON ({e})")
    else:
        failures.append(f"{marketplace_json_path}: file not found")

    if plugin_version and marketplace_version and plugin_version != marketplace_version:
        failures.append(
            f"{plugin_json_path.relative_to(PLUGIN_ROOT)}: version '{plugin_version}' "
            f"does not match marketplace.json's autoskill version '{marketplace_version}'"
        )

    return failures


def main():
    failures = collect_failures()

    if failures:
        print(f"autoskill consistency check: {len(failures)} failure(s) found\n")
        for failure in failures:
            print(f"  - {failure}")
        return 1

    print("autoskill consistency check: all checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
