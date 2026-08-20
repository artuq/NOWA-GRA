---
name: skill-test
description: "Validate Codex skill files in four modes: static structure checks, optional behavioral specs, category quality rubrics, and a dynamic coverage audit."
---

# CCGS Codex Skill Test

This workflow is read-only unless the user explicitly asks to save a report.
Target the editable plugin source at `plugins/ccgs-codex/skills/*/SKILL.md`.
Never treat an installed cache copy as the source of truth.

## Modes

| Mode | Invocation | Purpose |
|---|---|---|
| Static | `$skill-test static <name|all>` | Codex format and reference lint |
| Spec | `$skill-test spec <name>` | Evaluate an available behavioral spec |
| Category | `$skill-test category <name|all>` | Apply the category quality rubric |
| Audit | `$skill-test audit` | Dynamic coverage and dependency report |

If the mode or required name is missing, show this table and stop. The plugin
root, number of skills, and number of agents must always be discovered from the
filesystem; never rely on historical fixed counts.

## Static mode

Read each target `SKILL.md` completely and run all seven checks.

### S1 — Frontmatter schema

Parse YAML between the opening delimiters. It must contain exactly `name` and
`description`; no Claude-only keys such as `argument-hint`, `user-invocable`,
`allowed-tools`, `model`, `agent`, `context`, or `isolation` may remain.

### S2 — Identity and description

- `name` equals the parent folder name.
- Name matches `^[a-z0-9]+(?:-[a-z0-9]+)*$`.
- Description is non-empty and states both capability and trigger/use case.

### S3 — UI metadata

`agents/openai.yaml` must exist and parse as YAML. Its
`interface.default_prompt` must mention the exact `$<skill-name>` invocation.

### S4 — Skill references

Collect actual `$other-skill` invocations in the body and verify each resolves
to a sibling skill folder. Ignore clearly marked placeholders such as
`$skill-name` and `$command`. Report unknown invocations with line numbers.

### S5 — Local resources

Verify every literal project/plugin path and local Markdown link used as an
instruction exists. Dynamic output paths and explicit "create this path"
examples are not dependencies. Flag missing required references as FAIL and
missing advisory examples as WARN.

### S6 — Legacy residue

FAIL on executable or instructional residue from the Claude format:

- `$ARGUMENTS`;
- a known skill invoked as `/skill`;
- `AskUserQuestion` or an instruction to use the `Task` tool;
- `CLAUDE.md` or `.claude/skills`;
- legacy frontmatter/runtime instructions for `model`, `context: fork`, or
  `isolation: worktree` instead of the Codex compatibility wording.

Historical attribution inside the conversion manifest is allowed.
The quoted tokens in this S6 definition are test fixtures, not executable
legacy instructions, and are exempt when validating `$skill-test` itself.

### S7 — Agent routing

For every `Recommended role: <name>` or `.codex/agents/<name>.toml` reference,
verify the project profile exists and parses as TOML with `name`, `description`,
and `developer_instructions`. The profile `name` must equal the referenced role.

### Static result

Use `PASS`, `WARN`, or `FAIL` per check. The overall result is:

- `COMPLIANT`: zero FAIL and zero WARN;
- `WARNINGS`: zero FAIL and one or more WARN;
- `NON-COMPLIANT`: one or more FAIL.

For `all`, show a compact table followed by detailed evidence only for WARN or
FAIL targets. Include discovered counts rather than fixed totals.

## Spec mode

Read `plugins/ccgs-codex/references/testing/catalog.yaml` and locate the target
entry's `spec`. If it is empty or the file is absent, return:

```text
BLOCKED: no behavioral spec is available for <name>.
Static and category checks are still available.
```

Do not invent coverage. When a spec exists, evaluate each fixture/assertion
against the written skill instructions and mark `PASS`, `PARTIAL`, or `FAIL`
with exact supporting lines. Saving results is optional and, when requested,
uses `production/qa/skill-tests/`, never the plugin cache.

## Category mode

Read the target category from
`plugins/ccgs-codex/references/testing/catalog.yaml` and its metrics from
`plugins/ccgs-codex/references/testing/quality-rubric.md`. Evaluate every metric
as `PASS`, `WARN`, or `FAIL`, cite the relevant instruction, and do not penalize
a skill for behavior outside its declared category.

If either resource or category is missing, return a concrete `BLOCKED` reason
and still offer static mode.

## Audit mode

Enumerate real files and report:

- number of skill folders and `SKILL.md` files;
- missing or invalid `agents/openai.yaml` files;
- number of project `.codex/agents/*.toml` profiles and parse failures;
- unresolved skill, role, reference, asset, and template dependencies;
- skills without testing-catalog entries, categories, or behavioral specs;
- count of static COMPLIANT/WARNINGS/NON-COMPLIANT results.

Lead with failures that make a workflow unusable. End with the smallest next
repair and the exact `$skill-improve <name>` or `$skill-test ...` invocation.

Do not modify, commit, or revert files while testing.
