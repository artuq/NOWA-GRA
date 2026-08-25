---
name: project-king-of-cringe
description: Core facts about the King of Cringe project relevant to QA gate reviews
metadata:
  type: project
---

"King of Cringe" (Polish: Król Cringe'u) is a Godot 4.6.3 / GDScript mobile
idle-satire game, built solo via the 49-subagent Claude Code Game Studios
architecture. GDDs are frequently authored in "Lean mode" (specialist agents
like game-designer/systems-designer not consulted for every section) — this
means some GDD sections (Player Fantasy, Detailed Design framing) are
lower-confidence than Formulas/Acceptance Criteria sections, which do get
specialist review even in Lean mode for HIGH-risk (D/H) categories.

Core loop is "select-and-wait": Action System (3 actions: Nagraj vloga /
Zrób dramę / Przeproś w internecie) feeds Resource System (Zasięgi/Cringe/
Morale) feeds Decision Card System. Architecture uses Godot Autoload
singletons (ADR-0001) with direct calls for ownership-clear writes and
signals for multi-subscriber events — no central EventBus.

**Why this matters**: Resource System is DONE and stable
(ResourceFormulas.action_effectiveness_multiplier, ResourceManager.apply_delta).
Action System stories build directly on top of it. Round-half-up reward
rounding is owned by the call site (Action System), not ResourceFormulas —
this was an explicit story-level assignment (Story 1-4), not derivable from
the GDD alone (GDD flags it as an open provenance question).

**How to apply**: When reviewing Action System (or downstream Decision Card
System) story readiness, always check whether Resource System's existing
public interface already satisfies what the new story needs before assuming
new Resource System work is required.
