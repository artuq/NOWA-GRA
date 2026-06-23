# Story 002: Hatersi Passive Growth Rate (Formula A)

> **Epic**: Resource System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-23

## Completion Notes
**Completed**: 2026-06-23
**Criteria**: 5/5 passing
**Deviations**: 1 advisory (logged to docs/tech-debt-register.md) — H_EXP must stay a whole number for the out-of-contract NaN-safety guarantee, discovered during code review
**Test Evidence**: Logic — `tests/unit/resource_system/haters_growth_rate_test.gd` (6 functions). CORRECTION (2026-06-23): "confirmed passing locally" above was inaccurate — the project had no `project.godot` and no installed GdUnit4 addon at the time, so these tests had never actually executed. Now genuinely verified: 6/6 passing via real `addons/gdUnit4/runtest.sh` execution. See `docs/tech-debt-register.md` and Story 003's Completion Notes.
**Code Review**: Complete (APPROVED) — `extends RefCounted` added for clarity

## Context

**GDD**: `design/gdd/resource-system.md`
**Requirement**: `TR-res-001`

**ADR Governing Implementation**: ADR-0006: Offline simulation loop implementation
**ADR Decision Summary**: All Resource System formulas (including this one) live in a single stateless static utility class `ResourceFormulas` (`res://src/core/resource_formulas.gd`), called identically by both live-play (Action System) and offline simulation (Offline Progress System) — guarantees the two contexts can never silently diverge.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Pure float math (`pow`/exponentiation). No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: Offline/online resource formulas live in one stateless static utility class (`ResourceFormulas`) — source: ADR-0006
- Forbidden: Never add instance vars or `@export` fields to `ResourceFormulas` — must stay stateless — source: ADR-0006

---

## Acceptance Criteria

*From GDD `design/gdd/resource-system.md`, scoped to this story:*

- [ ] GIVEN Cringe=10 vs Cringe=80 in two identical states, WHEN 10 minutes elapse, THEN the Cringe=80 state produces Hatersi growth per `H_rate(80)=0.02+0.64×1.0=0.66/min` (±0.001), vs Cringe=10's `H_rate(10)=0.03/min` (±0.001) — strictly greater growth at higher Cringe. (Tolerance added per `qa-lead`'s QL-STORY-READY review — "≈" values are not directly assertable in a deterministic unit test without an explicit precision bound.)
- [ ] GIVEN Cringe held at 100 for 50+ minutes, WHEN Hatersi growth is evaluated each minute, THEN the rate stays at `H_base+H_max_add=1.02/min` (±0.001) with no hard cap on Hatersi count.
- [ ] GIVEN Cringe=0, WHEN `haters_growth_rate(0)` is called, THEN result = `H_base` exactly (0.02, ±0.0001) — the floor case (promoted from the QA Test Cases edge case to a formal AC per `/story-readiness` review).
- [ ] GIVEN Cringe=50 (midpoint), WHEN `haters_growth_rate(50)` is called, THEN result = `0.02 + 0.5^2.0 × 1.0 = 0.27/min` (±0.001) — pins the `H_exp=2.0` curve shape at an interior point, not just the endpoints. (Added per `qa-lead`'s QL-STORY-READY review.)
- [ ] GIVEN an out-of-contract input (Cringe < 0 or Cringe > 100 — should never happen, since `ResourceManager` already clamps Cringe to `[0,100]` before any caller reaches this function), WHEN `haters_growth_rate()` is called anyway, THEN it returns a finite float (never NaN/Infinity) — this function does NOT re-clamp or validate its input; it trusts the caller's contract and simply must not crash or produce a non-finite result if that contract is ever violated. (Added per `qa-lead`'s QL-STORY-READY review — a defensive "no crash" guarantee, not a "correct value" guarantee.)

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

Implement `ResourceFormulas.haters_growth_rate(cringe: float) -> float` as a static function:

```
H_rate(C) = H_base + (C / 100)^H_exp × H_max_add
```

Tuning constants (from `design/registry/entities.yaml`, locked — do not redefine): `H_base = 0.02`, `H_exp = 2.0`, `H_max_add = 1.0`. ΔHatersi per tick is computed by the *caller* (`H_rate(C) × Δt / 60`), not by this function — this function returns the rate only, per-minute. No hard cap on the returned rate or on accumulated Hatersi count anywhere in this function — the GDD explicitly states this is the intended pressure peak, not a bug to fix.

**Performance**: O(1) pure float arithmetic (one `pow`/exponentiation) — negligible relative to the offline simulation loop's confirmed sub-millisecond budget even at its 1440-iteration worst case (ADR-0006). No profiling required at this scale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the `apply_delta()` mechanism this formula's output eventually writes through.
- Story 003 (Formula B): Morale drain — a separate function, do not combine.

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-1-2026-06-20.md`:*

- **AC**: Cringe=10 vs Cringe=80 → strictly greater growth at higher Cringe
  - Given: `H_base=0.02, H_exp=2.0, H_max_add=1.0`
  - When: `haters_growth_rate(10)` and `haters_growth_rate(80)` are called
  - Then: results = 0.03/min (±0.001) and 0.66/min (±0.001) respectively; 80's result > 10's result
- **AC**: Cringe=100 sustained 50+ min → rate stays at max, no cap
  - Given: C=100
  - When: `haters_growth_rate(100)` is called repeatedly (simulating sustained sessions)
  - Then: result = `H_base + H_max_add = 1.02/min` (±0.001) every time, never decays or caps differently
- **AC**: Cringe=0 → floor case
  - Then: result = 0.02 exactly (±0.0001)
- **AC**: Cringe=50 → midpoint, pins curve shape
  - Then: result = 0.27/min (±0.001)
- **AC**: out-of-contract input (C<0 or C>100) → no crash, finite result
  - Given: C=-10 and C=150 (two separate calls)
  - When: `haters_growth_rate()` is called with each
  - Then: both return a finite float (`is_finite()` true), no exception, no NaN/Infinity — value correctness not asserted (out of contract)

**Estimated test count**: ~7 unit tests | **Test file**: `tests/unit/resource_system/haters_growth_rate_test.gd`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_system/haters_growth_rate_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Core Resource Mutation) must be DONE
- Unlocks: Story 003 (Morale Drain Rate reads Hatersi count produced by this formula's downstream application)
