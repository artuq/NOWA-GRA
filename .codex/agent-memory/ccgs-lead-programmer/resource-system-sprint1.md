---
name: resource-system-sprint1
description: Architectural sign-off context for Resource System epic Sprint 1 (Stories 001-006, Formulas A-E) in King of Cringe
metadata:
  type: project
---

Resource System epic's first sprint (Stories 001-006, "King of Cringe", Godot 4.6.3)
shipped 5 GDD formulas (A-E) plus the core mutation mechanism, all APPROVED at
final LP-CODE-REVIEW gate on 2026-06-23, 51/51 tests passing.

**Architecture pattern established:**
- `src/core/resource_formulas.gd` — stateless `RefCounted` static-function utility
  class (Formulas A-D: haters_growth_rate, morale_drain_rate,
  action_effectiveness_multiplier, passive_zasiegi_income). Zero cross-calls
  between formulas (ADR-0006 "no hidden cross-calls" rule) — callers
  (ActionSystem, OfflineProgressSystem) compose them, formulas never call
  each other internally.
- Formula E (Cringe/Morale clamping to [0,100]) is deliberately NOT a
  `ResourceFormulas` function — it lives inline in
  `ResourceManager.apply_delta()` because it's a mutation-layer invariant
  (resource bounds enforcement), not a derived game-balance curve. This was
  an explicit, reasoned architectural choice per ADR-0001's "ownership-clear
  writes use direct calls, inline at the sole write path" guidance — not an
  oversight. Story 006 exists purely to give this inline behavior its own
  named test coverage since it's referenced by name in the GDD.

**Governing ADR**: `docs/architecture/adr-0001-autoload-singleton-vs-event-bus.md`
(Accepted) — Autoload singletons for Core/Foundation modules, direct calls for
ownership-clear mutations, signals for multi-subscriber notification only, no
central EventBus.

**Known non-blocking residual risk**: Polish/English resource-key naming drift
between `design/gdd/resource-system.md` / `design/registry/entities.yaml`
(show stale Polish keys like Zasięgi, Hatersi, Sponsorzy) and the English keys
(`Reach`, `Haters`, `Sponsors`, `Cringe`, `Morale`) actually used in
`resource_manager.gd`. Flagged as a separate doc-sync task, does not block
the next epic (Action System).

**Why this matters**: Next epic (Action System) will call into both
`ResourceFormulas` static functions and `ResourceManager.apply_delta()` — any
review of that epic should check it respects the same contracts (trusts
pre-clamped inputs, doesn't bypass `apply_delta()` as the sole write path,
doesn't reintroduce cross-formula calls).

**How to apply**: When reviewing future Resource-System-adjacent code (Action
System, Offline Progress System), verify callers obtain
`action_effectiveness_multiplier()` before passing it into
`passive_zasiegi_income()` (locked parameter signature/order — see
resource_formulas.gd doc comments) rather than recomputing Morale bands
inline, and verify no new code reaches into `ResourceManager`'s internal
`_resources` dict directly instead of going through `apply_delta()`/`get_resource()`.
