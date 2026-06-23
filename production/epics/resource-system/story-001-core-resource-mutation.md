# Story 001: Core Resource Mutation & Clamping

> **Epic**: Resource System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-23

## Completion Notes
**Completed**: 2026-06-23
**Criteria**: 4/4 passing
**Deviations**: 2 advisory (logged to docs/tech-debt-register.md) — stale Polish resource-key docs (GDD/entities.yaml vs. English production code), `_CLAMPED_KEYS` hardcoded rather than data-file-driven
**Test Evidence**: Logic — `tests/unit/resource_system/core_mutation_test.gd` (7 functions). CORRECTION (2026-06-23): "confirmed passing locally" above was inaccurate — the project had no `project.godot` and no installed GdUnit4 addon at the time, so these tests had never actually executed. Now genuinely verified: 7/7 passing via real `addons/gdUnit4/runtest.sh` execution, after fixing two real bugs found in the process (untyped dictionary literals against `apply_delta()`'s typed parameter; a double-free in `after_test()`). See `docs/tech-debt-register.md` and Story 003's Completion Notes.
**Code Review**: Complete (APPROVED) — one bug found and fixed (tautological test assertion)

## Context

**GDD**: `design/gdd/resource-system.md`
**Requirement**: `TR-res-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Autoload singleton architecture vs event bus
**ADR Decision Summary**: `ResourceManager` is implemented as an Autoload singleton; `apply_delta()` is the sole ownership-clear write path for resource mutations, called directly by callers (no signal indirection for the write itself); `resource_changed` signal notifies peer/UI listeners after the fact.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs used. Pure GDScript dictionary/float operations.

**Control Manifest Rules (Foundation layer)**:
- Required: Implement `ResourceManager` as a Godot Autoload singleton — source: ADR-0001
- Required: Use direct method calls when the caller is the sole trigger of a state mutation it owns — source: ADR-0001
- Forbidden: Never introduce a central `EventBus` autoload — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/resource-system.md`, scoped to this story:*

- [ ] GIVEN an action in progress with defined Zasięgi/Cringe/Morale deltas, WHEN the action completes, THEN all three values update by exactly their defined deltas, with no partial write before completion.
- [ ] GIVEN Cringe=0, WHEN the player completes a safe action (ΔCringe≤0), THEN Cringe remains at 0 — no negative value is ever stored.
- [ ] GIVEN Morale=0 and a drain tick is due, WHEN drain is computed, THEN Morale remains at 0 (never negative).
- [ ] GIVEN the player takes only Cringe-reducing actions continuously, WHEN this pattern is sustained across a session, THEN no penalty, soft-lock, or forced escalation is triggered at this system's level as a consequence.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

Implement `apply_delta(deltas: Dictionary) -> void` as the single entry point for all resource mutations. For each key in `deltas`, compute `new_value = old_value + deltas[key]`; clamp to `[0, 100]` only for `Cringe` and `Morale` (Zasięgi/Hatersi/Sponsorzy have no registered floor or ceiling — see GDD Open Questions, do not invent one). Emit `resource_changed(name, new_value, old_value)` per changed key, after the mutation is applied — this is a notification signal, not the write mechanism itself. Do not introduce any async/deferred write path; this must be a synchronous, atomic-within-the-call operation (no intermediate observable partial state).

The "no penalty for clean path" criterion requires no special-case code — it is a negative assertion verified by the *absence* of any clean-path-specific logic anywhere in `ResourceManager`. Do not add a check *inside* `apply_delta()` for this. However (per `qa-lead`'s QL-STORY-READY review), code inspection alone is not sufficient evidence for this criterion — a future caller could introduce an escalation hook elsewhere in the loop that code inspection of `apply_delta()` wouldn't catch. See the updated QA Test Cases below for the required automated sequence test.

**Performance**: `apply_delta()` runs in the gameplay loop's hot path — called on every completed action and every card resolution. Expected cost: O(1) per resource key in the delta dictionary, no allocations beyond the dictionary iteration itself — negligible relative to the 16.6ms frame budget (`technical-preferences.md`). No profiling pass is required at this scale; revisit only if a future profiling pass shows otherwise.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002-005 (Formulas A-D): the math formulas themselves — this story only covers the mutation/clamping mechanism they write through.
- **Action System epic, single-concurrency story**: "GIVEN an action is currently running, WHEN the player attempts to start a second action, THEN the request is rejected" — this criterion appears in `resource-system.md`'s Acceptance Criteria section but tests `ActionSystem`'s guard (ADR-0004), not `ResourceManager`. Covered by the Action System epic.

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-1-2026-06-20.md`:*

- **AC**: action completes → all three values update atomically, no partial write
  - Given: an action with defined Zasięgi/Cringe/Morale deltas
  - When: `apply_delta()` is called
  - Then: all changed resources update; `resource_changed` fires once per key with correct old/new values
  - Edge cases: delta with multiple keys at once; delta of 0 (no-op, signal still fires)
- **AC**: Cringe=0, safe action → Cringe stays 0
  - Given: Cringe=0
  - When: a negative delta is applied
  - Then: Cringe remains 0, never negative
  - Edge cases: exactly-zero delta vs. any negative magnitude
- **AC**: Morale=0, drain due → Morale stays 0
  - Given: Morale=0
  - When: a negative delta is applied
  - Then: Morale remains 0, never negative
- **AC**: "clean path" sustained → no penalty (per `qa-lead`'s QL-STORY-READY review: upgraded from code-inspection-only to an automated test, since the original evidence wasn't sufficient for a Logic-tier story)
  - Given: a fresh `ResourceManager` state
  - When: N (e.g., 20) consecutive Cringe-reducing deltas are applied via `apply_delta()` in sequence
  - Then: no exception is raised, no signal/flag indicating "penalty" or "escalation" fires, and tracked values (Morale, Hatersi) stay within their normal bounds throughout — not just at the end
  - Secondary check (supplementary, not sole evidence): code inspection confirms no clean-path-specific branch exists in `apply_delta()`

**Estimated test count**: ~7 unit tests | **Test file**: `tests/unit/resource_system/core_mutation_test.gd`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_system/core_mutation_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002, Story 003, Story 004, Story 005, Story 006, Story 007 (all write through `apply_delta()`)
