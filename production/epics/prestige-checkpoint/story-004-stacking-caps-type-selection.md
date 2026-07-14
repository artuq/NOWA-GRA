# Story 004: META_BONUS Stacking/Caps + Bonus Type Selection (F2, Core Rule 1/3)

> **Epic**: Prestige/Checkpoint System
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**:


## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §3 (`PrestigeFormulas.apply_stacking_and_cap()`)
**ADR Decision Summary**: Grants apply additively per type, clamped by `META_BONUS_MAX[type]`. `PrestigeSystem` owns the running totals (`meta_bonus_totals` Dictionary); the formula function itself is stateless.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: same stateless-static pattern as Story 003
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD §META_BONUS Stacking, Caps, and Absorption (F2) + §Bonus Type Selection by Active Path, scoped to this story:*

- [ ] GIVEN `META_REACH_MULT_total_prev=0.4944`, WHEN a further grant of `0.1010` is applied, THEN the total clamps to `0.50`, absorbing `0.0954` with no effect and no compensating grant elsewhere
- [ ] GIVEN `total=0.0`, WHEN two grants resolve in separate eras (first-ever `0.1071`, then Tier-5-stacked `0.3873`), THEN running total is `0.1071` after the first and `0.4944` after the second
- [ ] GIVEN a player accepts burnout once on `pato_streamer` and once (different era) on `guru_celebryta`, THEN `META_REACH_MULT_total` and `META_SPONSOR_MULT_total` both hold independent nonzero values simultaneously — neither multiplies into the other
- [ ] GIVEN `META_HATERS_RESIST_total` is already at cap `0.40`, WHEN a further `ekspert_niszowy` burnout grants an increment, THEN the total remains exactly `0.40`
- [ ] GIVEN `META_SPONSOR_MULT_total` is already at cap `0.50`, WHEN a further grant is applied, THEN the total remains exactly `0.50`
- [ ] GIVEN all four totals are already at cap, WHEN Choice A resolves with a valid active path, THEN the burnout still resolves normally (`era_count` increments, resources reset, `era_transitioned` fires) but the grant is fully absorbed with zero effect — no softlock
- [ ] GIVEN Choice A resolves while each of the 4 paths is, in turn, active, THEN the grant targets `META_REACH_MULT`/`META_SPONSOR_MULT`/`META_HATERS_RESIST`/`META_SPONSOR_FLOOR` respectively — never mismatched
- [ ] GIVEN `ClassPathSystem.get_active_path()` returns empty at the exact moment Choice A resolves, WHEN the burnout resolves, THEN no META_BONUS of any type is granted, all four totals unchanged, AND the era still resets normally
- [ ] GIVEN Choice A resolves with no active path AND all four `first_burnout_bonus_used[type]` are `false`, WHEN the burnout resolves, THEN all four flags remain `false` — a zero-reward burnout never consumes a one-time multiplier that was never spent

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD F2, Core Rule 1/3:*

```gdscript
static func apply_stacking_and_cap(bonus_type: StringName, current_total: float,
        grant: float, cap: float) -> float:
    return minf(current_total + grant, cap)
```

Path→type mapping (Core Rule 3):

```gdscript
const _BONUS_TYPE_BY_PATH: Dictionary[StringName, StringName] = {
    &"pato_streamer": &"META_REACH_MULT",
    &"guru_celebryta": &"META_SPONSOR_MULT",
    &"ekspert_niszowy": &"META_HATERS_RESIST",
    &"biznesmen_contentu": &"META_SPONSOR_FLOOR",
}
```

The no-active-path case (empty `get_active_path()`) must still let `on_burnout_accepted()` (Story 001) proceed through reset/era_count/save — the absence of a reward never blocks the reset itself. This is the same "trigger is Cringe-driven, not reward-driven" principle as the all-caps-absorbed case.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the raw grant magnitude computation (this story only applies stacking/caps to an already-computed grant)
- Story 001: the orchestration call site

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1/AC-2 (additive stacking below and at cap)**: direct unit tests against `apply_stacking_and_cap()` with the stated prev/grant/cap values
  - Edge cases: grant exactly reaches the cap (no absorption, no overshoot)

- **AC-3 (independent per-type totals)**:
  - Given: grants applied to two different types in sequence
  - When: both resolve
  - Then: each type's total reflects only its own grants — no cross-type leakage
  - Edge cases: N/A

- **AC-4/AC-5 (cap holds under repeated grants)**:
  - Given: a type already at its cap
  - When: another grant of that type is applied
  - Then: total unchanged

- **AC-6 (all-caps-absorbed, reset still proceeds)**:
  - Given: mocked all-4-totals-at-cap state
  - When: `on_burnout_accepted()` (Story 001's orchestrator) runs with a valid active path
  - Then: `era_count` increments, `era_transitioned` fires, grant is absorbed with zero total change — assert both halves in one test

- **AC-7 (type mapping correctness)**:
  - Given: each of the 4 paths active in turn
  - When: Choice A resolves
  - Then: the grant lands on the correct type, verified via `_BONUS_TYPE_BY_PATH` lookup match

- **AC-8 (no active path, no grant, reset proceeds)**:
  - Given: `get_active_path()` returns `""`
  - When: burnout resolves
  - Then: all 4 totals unchanged, era still resets

- **AC-9 (zero-reward burnout doesn't consume first-burnout flags)**:
  - Given: no active path, all `first_burnout_bonus_used[type]` false
  - When: burnout resolves
  - Then: all 4 flags remain false

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/prestige/prestige_formulas_stacking_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (needs grant magnitude values to stack)
- Unlocks: Story 005 (F3a-d reads these totals), Story 007 (flag sweep must preserve these totals unchanged)
