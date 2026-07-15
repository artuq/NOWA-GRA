# Story 006: Choice B (Defer) — Morale Floor, No Grant

> **Epic**: Prestige/Checkpoint System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-15


## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §2 (orchestration — Choice B is the path *not* taken through `on_burnout_accepted()`)
**ADR Decision Summary**: Choice B (Defer) is a distinct, much simpler path than Choice A — no `ClassPathSystem` read, no reset, no META_BONUS grant. Only a Morale cost and a meta-persistent flag write.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff. This story's logic is owned by BurnoutSystem's own quick-spec (`final-burnout-2026-07-01.md`) for the Morale-cost mechanic itself; this story covers only the Prestige-side guarantee that Defer touches none of PrestigeSystem's state.

**Control Manifest Rules (this layer)**:
- Required: n/a
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD §Choice B (Defer) — Morale Floor, No Grant, scoped to this story:*

- [ ] GIVEN Choice B (Defer) is taken with Morale below `BURNOUT_DEFER_MORALE_COST`, WHEN Defer resolves, THEN Morale clamps to `0` (never negative), no path read occurs (`get_active_path()`/`get_tier()` are not called), AND all four `META_BONUS_total[type]` remain unchanged
- [ ] GIVEN Choice B is taken with Morale exactly equal to `BURNOUT_DEFER_MORALE_COST`, WHEN Defer resolves, THEN Morale becomes exactly `0` (clamp is a no-op at this boundary, not an off-by-one underflow), and no path read or META_BONUS grant occurs
- [ ] GIVEN Choice B resolves (either Morale case above), WHEN the meta-persistent flag write happens, THEN `burnout_deferred_era_N` (matching the current era) is written via `HistoryFlagManager` and survives a subsequent `reset_era_state()`/era transition — distinguishing it from an era-local flag

---

## Implementation Notes

The critical assertion here is a *negative* one: Choice B must call zero of `PrestigeSystem`'s grant machinery. Test this by spying on `ClassPathSystem.get_active_path()`/`get_tier()` and `PrestigeFormulas.grant_magnitude()` — assert zero calls during a Defer resolution, not just "totals unchanged" (an implementation that reads-then-discards would pass a totals-unchanged-only test while still violating the intent).

`burnout_deferred_era_N` is written via `HistoryFlagManager` — same milestone-flag mechanism as `burnout_accepted_era_N` (Story 007) and Class Path's own `class_path.{path}.best_tier.{N}` pattern (ADR-0010 §1).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The Morale-cost mechanic itself (Choice B's core behavior) — owned by `final-burnout-2026-07-01.md`'s own quick-spec, not this GDD/ADR

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (Defer below cost, floor + no grant)**:
  - Given: Morale below `BURNOUT_DEFER_MORALE_COST`
  - When: Defer resolves
  - Then: Morale = 0; spy confirms zero calls to `get_active_path()`/`get_tier()`/`grant_magnitude()`; all 4 totals unchanged; `burnout_deferred_era_N` set
  - Edge cases: Morale far below cost (large negative pre-clamp) — still clamps to exactly 0

- **AC-2 (Defer at exact cost boundary)**:
  - Given: Morale exactly equal to `BURNOUT_DEFER_MORALE_COST`
  - When: Defer resolves
  - Then: Morale = 0 exactly, no underflow, no path read, no grant

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/prestige/prestige_defer_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (orchestration skeleton — Defer is the code path that deliberately does NOT call into the Choice A sequence)
- Unlocks: None

## Completion Notes
**Completed**: 2026-07-15
**Criteria**: 3/3 passing
**Deviations**: ADVISORY — era numbering uses unincremented `era_count` (logged as tech debt); 3 non-blocking test gaps (logged as tech debt)
**Test Evidence**: Logic — `tests/unit/prestige/prestige_defer_test.gd` (6 tests)
**Code Review**: Complete — APPROVED
