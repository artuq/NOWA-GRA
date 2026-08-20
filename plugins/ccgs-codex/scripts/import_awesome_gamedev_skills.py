#!/usr/bin/env python3
"""Import awesome-gamedev-agent-skills into the flat CCGS Codex skill bundle.

The upstream catalog is grouped by category, while Codex plugin skills are
stored as sibling folders. This importer keeps each upstream skill intact,
adds Codex UI metadata, preserves Apache-2.0 notices, and installs a CCGS-aware
router whose production workflow remains subordinate to $ccgs-studio.
"""

from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path


UPSTREAM_REPOSITORY = "https://github.com/gamedev-skills/awesome-gamedev-agent-skills"
ROUTER_NAME = "gamedev-skill-router"


def parse_args() -> argparse.Namespace:
	parser = argparse.ArgumentParser()
	parser.add_argument("source", type=Path, help="Upstream repository checkout")
	parser.add_argument("destination", type=Path, help="CCGS plugin root")
	return parser.parse_args()


def skill_name(skill_file: Path) -> str:
	text = skill_file.read_text(encoding="utf-8")
	match = re.search(r"(?m)^name:\s*([^\n]+)$", text)
	if match is None:
		raise ValueError(f"Missing skill name in {skill_file}")
	return match.group(1).strip().strip('"\'')


def ui_metadata(name: str) -> str:
	display_name = name.replace("-", " ").title()
	return (
		"interface:\n"
		f"  display_name: \"{display_name}\"\n"
		f"  short_description: \"Imported game-development capability: {display_name}.\"\n"
		f"  default_prompt: \"Use ${name} for this game-development task.\"\n"
	)


def import_skills(source: Path, plugin_root: Path) -> list[str]:
	skills_root = plugin_root / "skills"
	imported: list[str] = []
	for skill_file in sorted((source / "skills").glob("*/*/SKILL.md")):
		name = skill_name(skill_file)
		target = skills_root / name
		if target.exists():
			shutil.rmtree(target)
		shutil.copytree(skill_file.parent, target)
		agents = target / "agents"
		agents.mkdir(exist_ok=True)
		(agents / "openai.yaml").write_text(ui_metadata(name), encoding="utf-8")
		imported.append(name)
	return imported


def import_router(source: Path, plugin_root: Path) -> None:
	upstream_router = (source / "router" / "SKILL.md").read_text(encoding="utf-8")
	upstream_router = re.sub(
		r"(?m)^name:\s*router\s*$", f"name: {ROUTER_NAME}", upstream_router, count=1
	)
	# The upstream repository groups skills by category; the Codex plugin API
	# discovers a flat set of sibling directories.
	upstream_router = re.sub(r"`skills/[^`]+/`", "`sibling skill folders`", upstream_router)
	upstream_router = re.sub(r"skills/(?:godot|unity|unreal|web-engines|other-engines)/", "", upstream_router)
	upstream_router = upstream_router.replace(
		"skills/<category>/<name>/SKILL.md", "../<name>/SKILL.md"
	)
	upstream_router = upstream_router.replace("`../docs/VERSION-SUPPORT.md`", "`references/version-support.md`")
	compatibility = """

## CCGS integration contract

This file is adapted for the CCGS Codex plugin from the upstream router. Use
`$ccgs-studio` first for production workflow, ownership, design gates, QA, and
release coordination. Use this router inside the selected CCGS workflow to load
the smallest engine, discipline, genre, and shipping capability set.

The current project's pinned engine version always overrides an imported skill's
catalog baseline. Read `AGENTS.md` and the project's engine-version reference
before using an API. Never migrate the engine merely because an imported skill
documents a newer baseline.
"""
	frontmatter_end = upstream_router.find("\n---", 4)
	if frontmatter_end < 0:
		raise ValueError("Router frontmatter is malformed")
	insert_at = frontmatter_end + 4
	upstream_router = upstream_router[:insert_at] + compatibility + upstream_router[insert_at:]

	target = plugin_root / "skills" / ROUTER_NAME
	if target.exists():
		shutil.rmtree(target)
	shutil.copytree(source / "router", target)
	(target / "SKILL.md").write_text(upstream_router, encoding="utf-8")
	for reference in (target / "references").glob("*.md"):
		text = reference.read_text(encoding="utf-8")
		text = re.sub(r"`skills/[^`]+/`", "`sibling skill folders`", text)
		text = re.sub(r"skills/(?:godot|unity|unreal|web-engines|other-engines|disciplines|genres|workflows)/", "", text)
		text = text.replace("../../docs/VERSION-SUPPORT.md", "version-support.md")
		reference.write_text(text, encoding="utf-8")
	shutil.copy2(source / "docs" / "VERSION-SUPPORT.md", target / "references" / "version-support.md")
	(target / "agents" / "openai.yaml").write_text(
		ui_metadata(ROUTER_NAME), encoding="utf-8"
	)


def copy_legal(source: Path, plugin_root: Path) -> None:
	legal_root = plugin_root / "licenses" / "awesome-gamedev-agent-skills"
	legal_root.mkdir(parents=True, exist_ok=True)
	shutil.copy2(source / "LICENSE", legal_root / "LICENSE")
	shutil.copy2(source / "NOTICE", legal_root / "NOTICE")
	(legal_root / "SOURCE.md").write_text(
		"# awesome-gamedev-agent-skills\n\n"
		f"Source: {UPSTREAM_REPOSITORY}\n\n"
		"Imported into CCGS as portable Agent Skills. The CCGS-aware router and "
		"flat plugin layout are local modifications.\n",
		encoding="utf-8",
	)


def main() -> None:
	args = parse_args()
	source = args.source.resolve()
	plugin_root = args.destination.resolve()
	if not (source / "skills").is_dir() or not (source / "router" / "SKILL.md").is_file():
		raise SystemExit(f"Not an awesome-gamedev-agent-skills checkout: {source}")
	if not (plugin_root / ".codex-plugin" / "plugin.json").is_file():
		raise SystemExit(f"Not a Codex plugin root: {plugin_root}")
	imported = import_skills(source, plugin_root)
	import_router(source, plugin_root)
	copy_legal(source, plugin_root)
	print(f"Imported {len(imported)} upstream skills plus {ROUTER_NAME}.")


if __name__ == "__main__":
	main()
