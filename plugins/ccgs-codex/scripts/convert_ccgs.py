#!/usr/bin/env python3
"""Convert the local CCGS 1.0.0 Claude package into Codex project assets.

The generated skills and agent profiles are intentionally mechanical ports of
the upstream MIT-licensed package. Codex-specific compatibility guidance is
prepended without deleting the original domain playbooks.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import sys
from pathlib import Path

import yaml


DEFAULT_SOURCE = Path(
    "/Users/magda/.claude/plugins/cache/ccgs-local/ccgs/1.0.0"
)
FRONTMATTER_RE = re.compile(
    r"\A---\r?\n(?P<header>.*?)\r?\n---\r?\n?(?P<body>.*)\Z", re.DOTALL
)
REASONING_MAP = {"haiku": "low", "sonnet": "high", "opus": "xhigh"}
MANUALLY_PORTED_SKILLS = {"skill-test", "skill-improve"}
MANUALLY_PORTED_DOCS = {
    "coordination-rules.md",
    "directory-structure.md",
    "technical-preferences.md",
}


def parse_document(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    match = FRONTMATTER_RE.match(text)
    if not match:
        raise ValueError(f"Missing YAML frontmatter: {path}")
    metadata = yaml.safe_load(match.group("header"))
    if not isinstance(metadata, dict):
        raise ValueError(f"Invalid YAML frontmatter: {path}")
    return metadata, match.group("body").rstrip() + "\n"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_text(path: Path, text: str, force: bool = True) -> bool:
    if path.exists() and not force:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return True


def replace_known_skill_commands(text: str, skill_names: list[str]) -> str:
    for name in sorted(skill_names, key=len, reverse=True):
        pattern = re.compile(
            rf"(?<![A-Za-z0-9_./-])/{re.escape(name)}(?![A-Za-z0-9-])"
        )
        text = pattern.sub(f"${name}", text)
    return text


def port_common_text(text: str, skill_names: list[str]) -> str:
    replacements = (
        ("Claude Code Game Studios", "Codex Game Studios (CCGS)"),
        ("Claude Code", "Codex"),
        ("CLAUDE.md", "AGENTS.md"),
        (
            ".claude/docs/director-gates.md",
            "plugins/ccgs-codex/references/director-gates.md",
        ),
        (
            ".claude/docs/workflow-catalog.yaml",
            "plugins/ccgs-codex/references/workflow-catalog.yaml",
        ),
        (
            ".claude/docs/templates/",
            "plugins/ccgs-codex/assets/templates/",
        ),
        (".claude/agents/", ".codex/agents/"),
        (".claude/docs/", ".codex/docs/"),
        (".claude/skills/", "plugins/ccgs-codex/skills/"),
        ("AskUserQuestion", "Codex user-input mechanism"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    text = text.replace("/clear", "start a fresh thread")
    text = text.replace("/validate", "$localize validate")
    text = text.replace("/command", "$command")
    text = text.replace("/skill-name", "$skill-name")
    text = text.replace("via Task", "through Codex subagent delegation")
    text = text.replace("Task calls", "subagent tasks")
    text = text.replace("Task prompt", "subagent prompt")
    text = text.replace("Task agents", "Codex subagents")
    text = text.replace("Task agent", "Codex subagent")
    text = text.replace(
        "Task in this skill spawns a SUBAGENT",
        "Codex subagent delegation in this skill starts a SUBAGENT",
    )
    text = re.sub(r"\bClaude\b", "Codex", text)
    text = replace_known_skill_commands(text, skill_names)
    return text


def invocation_text(body: str, skill_name: str) -> str:
    body = re.sub(
        r"\$ARGUMENTS\[(\d+)\]",
        lambda match: (
            f"invocation argument {int(match.group(1)) + 1} "
            f"from the user text after ${skill_name}"
        ),
        body,
    )
    return body.replace(
        "$ARGUMENTS", f"the invocation arguments after ${skill_name}"
    )


def skill_compatibility(metadata: dict) -> str:
    name = metadata["name"]
    allowed = str(metadata.get("allowed-tools", "not specified"))
    allowed = allowed.replace("AskUserQuestion", "user-input")
    allowed = re.sub(r"\bTask\b", "subagent delegation", allowed)
    role = metadata.get("agent")
    context = metadata.get("context")
    isolation = metadata.get("isolation")
    lines = [
        "## Codex compatibility",
        "",
        f"Invoke this workflow as `${name}` followed by any arguments in the user's prompt.",
        (
            "Map the legacy Read/Glob/Grep/Write/Edit/Bash names to the available "
            "Codex tools; use `apply_patch` for repository edits."
        ),
        (
            "Use the available user-input mechanism only when a decision materially "
            "changes the result. If running as a subagent, return 2–4 concise options "
            "and a recommendation to the parent instead of questioning the user directly."
        ),
        (
            "Delegate independent work through Codex subagents when useful, respecting "
            "the active concurrency limit and batching larger teams."
        ),
        (
            "A direct user request to build or change something authorizes in-scope edits; "
            "do not repeat legacy per-file approval prompts. Audits and reviews remain "
            "read-only unless the user also asks for changes. Never commit or push unless asked."
        ),
        f"Legacy tool profile (guidance only): `{allowed}`.",
    ]
    if role:
        lines.append(
            f"Recommended role: `{role}` from `.codex/agents/{role}.toml`. Keep the "
            "primary thread responsible for user-facing choices."
        )
    if context:
        compact = " ".join(str(context).split())
        lines.append(
            "Legacy dynamic context becomes an explicit read-only preflight when relevant: "
            f"`{compact}`"
        )
    if isolation:
        lines.append(
            "This workflow requested isolated worktree execution upstream. Use an isolated "
            "worktree only when the parent environment explicitly provides one; otherwise "
            "keep edits narrowly scoped in the current workspace."
        )
    lines.extend(("", "---", ""))
    return "\n".join(lines)


def convert_skill(metadata: dict, body: str, skill_names: list[str]) -> str:
    name = str(metadata["name"])
    description = " ".join(str(metadata["description"]).split())
    description = port_common_text(description, skill_names)
    header = yaml.safe_dump(
        {"name": name, "description": description},
        sort_keys=False,
        allow_unicode=True,
        width=1000,
    ).strip()
    body = invocation_text(body, name)
    body = port_common_text(body, skill_names)
    body = body.replace("the `Task` tool", "Codex subagent delegation")
    body = body.replace("the Task tool", "Codex subagent delegation")
    body = body.replace("Task tool", "Codex subagent delegation")
    if name == "dev-story":
        body = body.replace(
            (
                "**If no argument**: check `production/session-state/active.md` for the active\n"
                "story. If found, confirm: \"Continuing work on [story title] — is that correct?\"\n"
                "If not found, ask: \"Which story are we implementing?\" Glob\n"
                "`production/epics/**/*.md` and list stories with Status: Ready."
            ),
            (
                "**If no argument**: read `production/sprint-status.yaml` first. Resolve only\n"
                "entries whose `file` field is non-empty: prefer a single `in-progress` story,\n"
                "otherwise a single `ready-for-dev` story. Confirm the resolved title and path\n"
                "before implementation. If there is no unique valid path, ask \"Which story are\n"
                "we implementing?\" and list candidate IDs/titles without inventing paths. Use\n"
                "`production/session-state/active.md` only as supplemental context after a story\n"
                "path is known. If sprint status is absent, scan story files for an explicit\n"
                "Ready status and proceed only when exactly one candidate exists."
            ),
        )
        body = re.sub(
            r"- \*\*File writes are delegated\*\*.*\n",
            (
                "- **File ownership is delegated** — assign each source/test/evidence file "
                "to one implementation owner. The user's `$dev-story` request authorizes "
                "those in-scope writes; subagents must not ask for redundant per-file "
                "approval. The primary thread coordinates overlaps and decisions.\n"
            ),
            body,
        )
    if name == "gate-check":
        body = body.replace(
            (
                "Before generating the final verdict, spawn all four directors as **parallel "
                "subagents** through Codex subagent delegation using the parallel gate protocol "
                "from `plugins/ccgs-codex/references/director-gates.md`. Issue all four subagent "
                "tasks simultaneously — do not wait for one before starting the next."
            ),
            (
                "Before generating the final verdict, delegate all four director reviews using "
                "the protocol in `plugins/ccgs-codex/references/director-gates.md`. Start as many "
                "independent reviews as the active slot limit permits, collect them, then run the "
                "remaining reviews as the next batch. Never exceed the concurrency limit."
            ),
        )
        body = body.replace("**Spawn in parallel:**", "**Director review batch:**")
    if name == "balance-check":
        body = body.replace(
            "If no argument, ask the user which system to check.",
            (
                "If no argument, infer the domain from the request and repository evidence. "
                "For a general balance request, default to a project-wide economy + progression "
                "audit. Ask only when multiple plausible domains would materially change scope."
            ),
        )
        body = body.replace(
            (
                "Read relevant files from `assets/data/` and `design/balance/` for the identified domain.\n"
                "Note every file read — they will appear in the Data Sources section of the report."
            ),
            (
                "Discover the project's actual balance sources instead of assuming fixed folders. "
                "Start with an explicit path argument when provided, then inspect existing sources "
                "in this order:\n\n"
                "1. `design/balance/` and `assets/data/`, when they exist;\n"
                "2. `design/registry/entities.yaml` and the relevant `design/gdd/` documents;\n"
                "3. formula, manager, content-database, and progression code under `src/`;\n"
                "4. unit/integration tests that lock expected values or boundary behavior.\n\n"
                "Missing conventional folders are not a blocker. Use focused search for formulas, "
                "rates, costs, rewards, caps, cooldowns, weights, and multipliers. Note every file "
                "read for the report's Data Sources section."
            ),
        )
        body = body.replace(
            (
                "- Guide the user to update the relevant data file in `assets/data/` or formula in "
                "`design/balance/`"
            ),
            (
                "- Change the authoritative source actually discovered during the audit: prefer "
                "data/config when present, otherwise the governing GDD/registry or formula code"
            ),
        )
    return f"---\n{header}\n---\n\n{skill_compatibility(metadata)}{body}"


def reasoning_effort(metadata: dict) -> str:
    model = str(metadata.get("model", "sonnet"))
    if model == "sonnet" and int(metadata.get("maxTurns", 20)) <= 10:
        return "medium"
    return REASONING_MAP.get(model, "high")


def agent_compatibility(metadata: dict) -> str:
    name = str(metadata["name"])
    tools = str(metadata.get("tools", ""))
    tools = re.sub(r"\bTask\b", "subagent delegation", tools)
    tools = tools.replace("WebSearch", "web search")
    disallowed = metadata.get("disallowedTools")
    memory = metadata.get("memory")
    preferred = metadata.get("skills", [])
    isolation = metadata.get("isolation")
    lines = [
        "# Codex CCGS compatibility layer",
        "",
        f"You are the project-scoped `{name}` custom agent. Follow the nearest AGENTS.md.",
        (
            "The legacy playbook below remains the domain authority, with these Codex "
            "execution rules taking precedence over its tool and approval wording:"
        ),
        "",
        (
            "- If asked to analyze, audit, explain, or review, inspect and report without "
            "editing. If asked to build, fix, or change, the request authorizes in-scope "
            "workspace edits; do not pause for redundant per-file approval."
        ),
        "- Never commit, push, publish, or message external systems unless explicitly asked.",
        (
            "- Map Read/Glob/Grep to focused repository inspection, Write/Edit to "
            "`apply_patch`, WebSearch to current official sources, and Task to Codex "
            "subagent delegation."
        ),
        (
            "- The Codex user-input mechanism is available only to the parent thread. "
            "When acting as a subagent, return decision-ready options and your recommendation."
        ),
        f"- Legacy tool profile (guidance only): `{tools}`.",
        (
            f"- Treat the original maxTurns={metadata.get('maxTurns', 'unspecified')} as a "
            "soft reminder to stay bounded, not as a hard runtime limit."
        ),
    ]
    if disallowed:
        lines.append(
            "- Legacy Bash restriction: use shell commands only for read-only inspection "
            "(`rg`, `rg --files`, `sed`, `head`, `tail`, `wc`, `git status`, `git diff`). "
            "Do not run builds, project scripts, binaries, or mutating shell commands; edit "
            "only through `apply_patch`."
        )
    if preferred:
        workflows = ", ".join(f"`${item}`" for item in preferred)
        lines.append(f"- Preferred workflows: {workflows}.")
    if isolation:
        lines.append(
            "- Upstream requested worktree isolation. Ask the parent to provide an isolated "
            "worktree when supported; otherwise keep work narrowly scoped and disclose that "
            "the current workspace is shared."
        )
    if memory:
        if memory == "user":
            primary = f"~/.codex/agent-memory/ccgs-{name}/MEMORY.md"
            fallback = f"~/.claude/agent-memory/ccgs-{name}/MEMORY.md"
        else:
            primary = f".codex/agent-memory/ccgs-{name}/MEMORY.md"
            fallback = f".claude/agent-memory/ccgs-{name}/MEMORY.md"
        lines.append(
            f"- Memory scope `{memory}`: if present, read `{primary}` first and fall back "
            f"to `{fallback}`. Follow only links relevant to the current task. Current repo "
            "state and newer dated evidence override historical memory."
        )
    lines.extend(("", "# Ported role playbook", ""))
    return "\n".join(lines)


def convert_agent(metadata: dict, body: str, skill_names: list[str]) -> str:
    body = port_common_text(body, skill_names)
    body = re.sub(r'Read path="([^"]+)"', r'Read `\1`', body)
    body = body.replace("the `Task` tool", "Codex subagent delegation")
    body = body.replace("Task tool", "Codex subagent delegation")
    body = body.replace("Task subagent", "Codex subagent")
    body = body.replace("Task agents", "Codex subagents")
    instructions = agent_compatibility(metadata) + body
    if "'''" in instructions:
        encoded = json.dumps(instructions, ensure_ascii=False)
        value = encoded
    else:
        value = "'''\n" + instructions.rstrip() + "\n'''"
    description = " ".join(str(metadata["description"]).split())
    description = port_common_text(description, skill_names)
    return "\n".join(
        (
            "# Generated by plugins/ccgs-codex/scripts/convert_ccgs.py",
            f"# Upstream model: {metadata.get('model')}; maxTurns: {metadata.get('maxTurns')}",
            f"name = {json.dumps(str(metadata['name']), ensure_ascii=False)}",
            f"description = {json.dumps(description, ensure_ascii=False)}",
            f'model_reasoning_effort = "{reasoning_effort(metadata)}"',
            "# Permissions intentionally inherit from the parent Codex session.",
            f"developer_instructions = {value}",
            "",
        )
    )


def router_skill(skills: list[tuple[dict, str]]) -> str:
    rows = []
    for metadata, _ in skills:
        name = str(metadata["name"])
        description = " ".join(str(metadata["description"]).split())
        description = port_common_text(description, [str(item[0]["name"]) for item in skills])
        description = description.replace("|", "\\|")
        role = metadata.get("agent") or "primary"
        rows.append(f"| `${name}` | `{role}` | {description} |")
    table = "\n".join(rows)
    return f'''---
name: ccgs-studio
description: Route any game-development task through the CCGS Codex studio, including design, implementation, production, QA, release, UX, art, audio, economy, progression, and balance work.
---

# CCGS Studio Router

Use this skill when the user asks for CCGS generally, when the exact workflow is
unclear, or when a specialized workflow may be missing from the initial skill
discovery budget.

1. Identify the smallest workflow or set of workflows that covers the request.
2. Open only those workflow `SKILL.md` files from the sibling skill folders.
3. Keep user-facing decisions in the primary thread. Delegate bounded analysis
   or implementation to the matching profile under `.codex/agents/` when useful.
4. Batch team workflows to respect the active concurrency limit.
5. For balance and economy review, choose `$balance-check` and the
   `economy-designer` profile.
6. For story implementation, require an explicit story path. If none is given,
   consult `production/sprint-status.yaml`; ask the user when it does not resolve
   to exactly one ready story.
7. For release readiness, invoke `$gate-check release` explicitly so the current
   `production/stage.txt` does not redirect the audit to an earlier phase gate.
8. Follow the nearest `AGENTS.md`; do not commit or push unless asked.

## Workflow index

| Workflow | Recommended role | Use when |
|---|---|---|
{table}
'''


def testing_category(name: str) -> str:
    if name.startswith("team-"):
        return "team"
    if name in {
        "architecture-decision", "art-bible", "asset-spec", "brainstorm",
        "create-architecture", "create-control-manifest", "create-epics",
        "create-stories", "design-system", "map-systems", "quick-design",
        "ux-design",
    }:
        return "authoring"
    if name in {
        "architecture-review", "asset-audit", "balance-check", "consistency-check",
        "content-audit", "design-review", "perf-profile", "project-stage-detect",
        "review-all-gdds", "security-audit", "test-evidence-review", "ux-review",
    }:
        return "audit"
    if name in {
        "gate-check", "launch-checklist", "milestone-review", "release-checklist",
        "scope-check", "story-done", "story-readiness",
    }:
        return "gate"
    if name in {
        "day-one-patch", "dev-story", "hotfix", "localize", "prototype",
        "setup-engine", "vertical-slice",
    }:
        return "implementation"
    if name in {
        "bug-report", "bug-triage", "playtest-report", "qa-plan",
        "regression-suite", "smoke-check", "soak-test", "test-flakiness",
        "test-helpers", "test-setup",
    }:
        return "testing"
    if name in {
        "changelog", "content-audit", "estimate", "patch-notes", "retrospective",
        "sprint-plan", "sprint-status",
    }:
        return "production"
    return "utility"


def testing_catalog(skills: list[tuple[dict, str]]) -> str:
    entries = []
    for metadata, _ in sorted(skills, key=lambda item: str(item[0]["name"])):
        name = str(metadata["name"])
        entries.append({"name": name, "category": testing_category(name), "spec": None})
    return yaml.safe_dump(
        {"version": 1, "skills": entries},
        sort_keys=False,
        allow_unicode=True,
        width=1000,
    )


def port_hooks_once(source: Path, destination: Path, skill_names: list[str]) -> None:
    destination.mkdir(parents=True, exist_ok=True)
    for source_file in sorted(source.glob("*.sh")):
        target = destination / source_file.name
        if target.exists():
            continue
        text = source_file.read_text(encoding="utf-8")
        text = port_common_text(text, skill_names)
        text = text.replace("CLAUDE_PROJECT_DIR", "CODEX_PROJECT_DIR")
        write_text(target, text)
        target.chmod(0o755)


def copy_project_material(root: Path, force: bool, skill_names: list[str]) -> int:
    copied = 0
    source_docs = root / ".claude" / "docs"
    destination_docs = root / ".codex" / "docs"
    if source_docs.is_dir():
        for source_file in sorted(source_docs.rglob("*")):
            if not source_file.is_file():
                continue
            relative = source_file.relative_to(source_docs)
            target = destination_docs / relative
            if relative.as_posix() in MANUALLY_PORTED_DOCS and target.exists():
                continue
            text = port_common_text(source_file.read_text(encoding="utf-8"), skill_names)
            copied += int(write_text(target, text, force=force))

    source_memory = root / ".claude" / "agent-memory"
    destination_memory = root / ".codex" / "agent-memory"
    if source_memory.is_dir():
        for source_file in sorted(source_memory.rglob("*")):
            if not source_file.is_file():
                continue
            relative = source_file.relative_to(source_memory)
            copied += int(
                write_text(
                    destination_memory / relative,
                    source_file.read_text(encoding="utf-8"),
                    force=force,
                )
            )
    return copied


def copy_user_memory(role_names: list[str], force: bool) -> int:
    copied = 0
    source_root = Path.home() / ".claude" / "agent-memory"
    destination_root = Path.home() / ".codex" / "agent-memory"
    for role_name in role_names:
        source_dir = source_root / f"ccgs-{role_name}"
        if not source_dir.is_dir():
            continue
        for source_file in sorted(source_dir.rglob("*")):
            if not source_file.is_file():
                continue
            relative = source_file.relative_to(source_dir)
            copied += int(
                write_text(
                    destination_root / f"ccgs-{role_name}" / relative,
                    source_file.read_text(encoding="utf-8"),
                    force=force,
                )
            )
    return copied


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", type=Path, default=DEFAULT_SOURCE)
    parser.add_argument("--project", type=Path, default=Path.cwd())
    parser.add_argument("--force", action="store_true", help="overwrite generated skills, agents, docs, and project memory")
    parser.add_argument(
        "--copy-user-memory",
        action="store_true",
        help="copy only CCGS roles declared with user-scoped memory into ~/.codex/agent-memory",
    )
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    root = args.project.expanduser().resolve()
    plugin = root / "plugins" / "ccgs-codex"
    if not (source / "agents").is_dir() or not (source / "skills").is_dir():
        parser.error(f"Not a CCGS package: {source}")

    skill_sources = sorted((source / "skills").glob("*/SKILL.md"))
    agent_sources = sorted((source / "agents").glob("*.md"))
    skills = [(parse_document(path)[0], path) for path in skill_sources]
    skill_names = [str(metadata["name"]) for metadata, _ in skills]

    converted_skills: list[tuple[dict, str]] = []
    skill_hashes = {}
    for metadata, source_file in skills:
        parsed_metadata, body = parse_document(source_file)
        converted = convert_skill(parsed_metadata, body, skill_names)
        target = plugin / "skills" / str(parsed_metadata["name"]) / "SKILL.md"
        if str(parsed_metadata["name"]) in MANUALLY_PORTED_SKILLS and target.exists():
            actual_metadata, _ = parse_document(target)
            converted_skills.append((actual_metadata, target.read_text(encoding="utf-8")))
        else:
            write_text(target, converted, force=args.force or not target.exists())
            converted_skills.append((parsed_metadata, converted))
        skill_hashes[str(parsed_metadata["name"])] = sha256(source_file)

    router = plugin / "skills" / "ccgs-studio" / "SKILL.md"
    write_text(router, router_skill(converted_skills), force=args.force or not router.exists())

    agent_hashes = {}
    user_memory_roles = []
    for source_file in agent_sources:
        metadata, body = parse_document(source_file)
        converted = convert_agent(metadata, body, skill_names)
        name = str(metadata["name"])
        project_target = root / ".codex" / "agents" / f"{name}.toml"
        portable_target = plugin / "assets" / "agents" / f"{name}.toml"
        write_text(project_target, converted, force=args.force or not project_target.exists())
        write_text(portable_target, converted, force=args.force or not portable_target.exists())
        agent_hashes[name] = sha256(source_file)
        if metadata.get("memory") == "user":
            user_memory_roles.append(name)

    project_files = copy_project_material(root, args.force, skill_names)
    user_memory_files = (
        copy_user_memory(user_memory_roles, args.force) if args.copy_user_memory else 0
    )
    port_hooks_once(source / "hooks", plugin / "hooks", skill_names)

    index_rows = [
        "# CCGS workflow index",
        "",
        "Generated from the upstream CCGS package. Use `$ccgs-studio` as the primary router.",
        "",
        "| Workflow | Agent | Source description |",
        "|---|---|---|",
    ]
    for metadata, _ in converted_skills:
        description = " ".join(str(metadata["description"]).split())
        description = port_common_text(description, skill_names).replace("|", "\\|")
        index_rows.append(
            f"| `${metadata['name']}` | `{metadata.get('agent') or 'primary'}` | {description} |"
        )
    write_text(
        plugin / "references" / "workflow-index.md",
        "\n".join(index_rows) + "\n",
        force=True,
    )
    write_text(
        plugin / "references" / "testing" / "catalog.yaml",
        testing_catalog(converted_skills + [(parse_document(router)[0], router.read_text(encoding="utf-8"))]),
        force=True,
    )

    manifest = {
        "source": str(source),
        "source_version": "1.0.0",
        "source_license": "MIT",
        "source_repository": "https://github.com/Donchitos/Claude-Code-Game-Studios",
        "generated": {
            "skills": len(skill_sources),
            "router_skills": 1,
            "agents": len(agent_sources),
            "project_files_copied": project_files,
            "user_memory_files_copied": user_memory_files,
        },
        "skill_sha256": skill_hashes,
        "agent_sha256": agent_hashes,
        "memory_policy": {
            "project": "copied from .claude/agent-memory to .codex/agent-memory",
            "user": (
                "copied to ~/.codex/agent-memory"
                if args.copy_user_memory
                else "not duplicated; profiles fall back to ~/.claude/agent-memory"
            ),
        },
        "notes": [
            "Hook files are copied only when absent so Codex-specific manual fixes survive regeneration.",
            "Custom agent permissions inherit from the parent Codex session.",
            "Legacy worktree isolation is preserved as an instruction because it has no standalone skill key.",
        ],
    }
    write_text(
        plugin / "assets" / "conversion-manifest.json",
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        force=True,
    )

    print(
        f"Converted {len(skill_sources)} skills (+ router), {len(agent_sources)} agents, "
        f"{project_files} project docs/memory files, and {user_memory_files} user-memory files into {plugin}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
