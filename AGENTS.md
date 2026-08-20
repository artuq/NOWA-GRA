# CCGS for Codex — King of Cringe

This repository uses the Codex-native port in `plugins/ccgs-codex`: 73 CCGS
production workflows, 67 portable engine/discipline/genre skills, the central
`$ccgs-studio` and `$gamedev-skill-router` routers, 49 project custom agents,
lifecycle hooks, and migrated project memory.

## Project

- Engine: Godot 4.6.3
- Primary language: GDScript
- Version control: Git, trunk-based development
- Asset pipeline: Godot import system plus project resources
- Current design source of truth: `design/gdd/`, `design/registry/`, and
  `docs/architecture/`
- Production state: `production/stage.txt`, `production/sprint-status.yaml`,
  `production/sprints/`, and `production/session-state/active.md`

Read the relevant project references before changing their domain:

- `.codex/docs/directory-structure.md`
- `.codex/docs/technical-preferences.md`
- `.codex/docs/coordination-rules.md`
- `.codex/docs/coding-standards.md`
- `.codex/docs/context-management.md`
- `docs/engine-reference/godot/VERSION.md`

## CCGS routing

Use `$ccgs-studio` when the correct workflow is unclear. Use a focused skill
directly when it is obvious. The full workflow index is at
`plugins/ccgs-codex/references/workflow-index.md`.

Within a selected CCGS workflow, use `$gamedev-skill-router` when engine,
discipline, or genre-specific implementation guidance is needed. Existing
project constraints, including the pinned Godot version, override catalog
baselines in imported skills.

Project custom agent profiles live in `.codex/agents/`. Delegate bounded,
independent work when doing so materially improves speed or quality. Keep
user-facing creative decisions in the primary thread and batch large team
workflows to the active concurrency limit.

For economy, progression, loot, or resource-flow balance, use `$balance-check`
with the `economy-designer` profile. An audit is read-only; save a report or
change tuning only when the user requests it.

## Execution policy

- An answer, audit, diagnosis, review, or status request authorizes read-only
  inspection, not edits.
- A request to build, fix, port, implement, or change authorizes the necessary
  in-scope workspace edits. Do not interrupt the work with redundant per-file
  approval prompts.
- Ask the user only when a missing choice would materially change the outcome.
  For creative decisions, present concise options, tradeoffs, and a
  recommendation.
- Preserve unrelated user changes in the working tree.
- Use `apply_patch` for manual edits and prefer `rg`/`rg --files` for search.
- Do not commit, push, publish, or contact external systems unless explicitly
  asked.

## Verification

Validate changes in proportion to risk. For gameplay work, follow the testing
rules in `.codex/docs/coding-standards.md` and the relevant production story or
GDD acceptance criteria. Record evidence only when the selected workflow asks
for it or the user requests it.

## Memory

Project role memory is under `.codex/agent-memory/ccgs-<role>/`. Load only the
role's `MEMORY.md` and then only links relevant to the current task. Treat it as
historical context: current repository state and newer dated evidence win.
