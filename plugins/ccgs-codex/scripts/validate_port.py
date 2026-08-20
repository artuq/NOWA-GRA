#!/usr/bin/env python3
"""Validate the generated CCGS Codex port and its project installation."""

from __future__ import annotations

import json
import re
import subprocess
import sys
import tomllib
from pathlib import Path

import yaml


FRONTMATTER_RE = re.compile(
    r"\A---\r?\n(?P<header>.*?)\r?\n---\r?\n?(?P<body>.*)\Z", re.DOTALL
)
NAME_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
SKILL_TOKEN_RE = re.compile(r"\$([a-z][a-z0-9-]*)")
PLACEHOLDERS = {"command", "name", "other-skill", "skill-name"}
SUPPORTED_HOOKS = {
    "SessionStart",
    "SessionEnd",
    "PreToolUse",
    "PostToolUse",
    "PreCompact",
    "PostCompact",
    "SubagentStart",
    "SubagentStop",
    "UserPromptSubmit",
    "PermissionRequest",
    "Stop",
}


def parse_skill(path: Path) -> tuple[dict, str]:
    match = FRONTMATTER_RE.match(path.read_text(encoding="utf-8"))
    if not match:
        raise ValueError("missing frontmatter")
    metadata = yaml.safe_load(match.group("header"))
    if not isinstance(metadata, dict):
        raise ValueError("frontmatter is not a mapping")
    return metadata, match.group("body")


def main() -> int:
    root = Path.cwd().resolve()
    plugin = root / "plugins" / "ccgs-codex"
    errors: list[str] = []
    warnings: list[str] = []

    manifest = json.loads(
        (plugin / "assets" / "conversion-manifest.json").read_text(encoding="utf-8")
    )
    expected_source_skills = int(manifest["generated"]["skills"])
    expected_agents = int(manifest["generated"]["agents"])

    skill_files = sorted((plugin / "skills").glob("*/SKILL.md"))
    skill_names = {path.parent.name for path in skill_files}
    expected_total_skills = expected_source_skills + int(
        manifest["generated"]["router_skills"]
    )
    if len(skill_files) != expected_total_skills:
        errors.append(
            f"skill count: expected {expected_total_skills}, found {len(skill_files)}"
        )

    known_alternation = "|".join(
        re.escape(name) for name in sorted(skill_names, key=len, reverse=True)
    )
    slash_skill_re = re.compile(
        rf"(?<![A-Za-z0-9_./-])/({known_alternation})(?![A-Za-z0-9-])"
    )
    plugin_path_re = re.compile(
        r"plugins/ccgs-codex/(?:references|assets)/[A-Za-z0-9_.@/+:-]+"
    )
    role_re = re.compile(r"\.codex/agents/([a-z0-9-]+)\.toml")

    for skill_file in skill_files:
        name = skill_file.parent.name
        try:
            metadata, body = parse_skill(skill_file)
        except Exception as exc:
            errors.append(f"{name}: {exc}")
            continue
        if set(metadata) != {"name", "description"}:
            errors.append(f"{name}: frontmatter keys are {sorted(metadata)}")
        if metadata.get("name") != name or not NAME_RE.fullmatch(name):
            errors.append(f"{name}: name/folder mismatch or invalid name")
        if not str(metadata.get("description", "")).strip():
            errors.append(f"{name}: empty description")

        openai_file = skill_file.parent / "agents" / "openai.yaml"
        if not openai_file.is_file():
            errors.append(f"{name}: missing agents/openai.yaml")
        else:
            try:
                openai_metadata = yaml.safe_load(openai_file.read_text(encoding="utf-8"))
                prompt = openai_metadata["interface"]["default_prompt"]
                short = openai_metadata["interface"]["short_description"]
                if f"${name}" not in prompt:
                    errors.append(f"{name}: default_prompt lacks ${name}")
                if not 25 <= len(short) <= 64:
                    errors.append(
                        f"{name}: short_description length {len(short)} is outside 25..64"
                    )
            except Exception as exc:
                errors.append(f"{name}: invalid agents/openai.yaml: {exc}")

        slash_refs = slash_skill_re.findall(body)
        if slash_refs:
            errors.append(f"{name}: legacy slash skill refs {sorted(set(slash_refs))}")

        if name != "skill-test":
            for residue in (
                "$ARGUMENTS",
                "AskUserQuestion",
                "CLAUDE.md",
                ".claude/skills",
                "Task tool",
            ):
                if residue in body:
                    errors.append(f"{name}: legacy residue {residue!r}")

        for token in sorted(set(SKILL_TOKEN_RE.findall(body))):
            if token not in skill_names and token not in PLACEHOLDERS:
                warnings.append(f"{name}: unrecognized $ token {token}")

        for raw_path in plugin_path_re.findall(body):
            normalized = raw_path.rstrip(".,:;)")
            if not (root / normalized).exists():
                errors.append(f"{name}: missing plugin dependency {normalized}")

        for role in role_re.findall(body):
            if not (root / ".codex" / "agents" / f"{role}.toml").is_file():
                errors.append(f"{name}: missing project role {role}")

    project_agents = sorted((root / ".codex" / "agents").glob("*.toml"))
    portable_agents = sorted((plugin / "assets" / "agents").glob("*.toml"))
    if len(project_agents) != expected_agents:
        errors.append(
            f"project agent count: expected {expected_agents}, found {len(project_agents)}"
        )
    if len(portable_agents) != expected_agents:
        errors.append(
            f"portable agent count: expected {expected_agents}, found {len(portable_agents)}"
        )
    for agent_file in project_agents + portable_agents:
        try:
            data = tomllib.loads(agent_file.read_text(encoding="utf-8"))
            missing = {"name", "description", "developer_instructions"} - set(data)
            if missing:
                errors.append(f"{agent_file}: missing {sorted(missing)}")
            if data.get("name") != agent_file.stem:
                errors.append(f"{agent_file}: name does not match filename")
        except Exception as exc:
            errors.append(f"{agent_file}: invalid TOML: {exc}")

    hooks_file = plugin / "hooks" / "hooks.json"
    try:
        hooks = json.loads(hooks_file.read_text(encoding="utf-8"))["hooks"]
        unknown = set(hooks) - SUPPORTED_HOOKS
        if unknown:
            errors.append(f"unsupported hooks: {sorted(unknown)}")
        if "Notification" in hooks or "Stop" in hooks:
            errors.append("hooks must not register Notification or turn-scoped Stop")
        if "SessionEnd" not in hooks:
            errors.append("missing SessionEnd hook")
    except Exception as exc:
        errors.append(f"invalid hooks.json: {exc}")

    for shell_file in sorted((plugin / "hooks").glob("*.sh")):
        result = subprocess.run(
            ["bash", "-n", str(shell_file)], capture_output=True, text=True, check=False
        )
        if result.returncode:
            errors.append(f"{shell_file.name}: bash -n failed: {result.stderr.strip()}")

    catalog_file = plugin / "references" / "testing" / "catalog.yaml"
    try:
        catalog = yaml.safe_load(catalog_file.read_text(encoding="utf-8"))
        catalog_names = {entry["name"] for entry in catalog["skills"]}
        if catalog_names != skill_names:
            errors.append(
                "testing catalog mismatch: "
                f"missing={sorted(skill_names - catalog_names)}, "
                f"extra={sorted(catalog_names - skill_names)}"
            )
    except Exception as exc:
        errors.append(f"invalid testing catalog: {exc}")

    print(
        f"Validated {len(skill_files)} skills, {len(project_agents)} project agents, "
        f"{len(portable_agents)} portable agents, and {len(list((plugin / 'hooks').glob('*.sh')))} hook scripts."
    )
    for warning in sorted(set(warnings)):
        print(f"WARN: {warning}")
    for error in errors:
        print(f"FAIL: {error}")
    if errors:
        print(f"Port validation failed with {len(errors)} error(s).")
        return 1
    print(f"Port validation passed with {len(set(warnings))} warning(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
