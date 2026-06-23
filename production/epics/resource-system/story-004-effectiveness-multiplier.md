# Story 004: Action Effectiveness Multiplier Lookup (Formula C)

> **Epic**: Resource System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-23

## Context

**GDD**: `design/gdd/resource-system.md`
**Requirement**: `TR-res-001`

**ADR Governing Implementation**: ADR-0006: Offline simulation loop implementation
**ADR Decision Summary**: Lives in the shared stateless `ResourceFormulas` static utility class — this exact lookup is also consumed by Action System (live reward scaling) and Offline Progress System (Formula D), so it must be correct and stable from this story onward.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Pure discrete lookup, no math library dependency.

**Control Manifest Rules (Core layer)**:
- Required: Offline/online resource formulas live in one stateless static utility class — source: ADR-0006

---

## Acceptance Criteria

*From GDD `design/gdd/resource-system.md`, scoped to this story:*

- [ ] GIVEN Morale=35 (Low band, 15-39), WHEN `action_effectiveness_multiplier(35)` is called, THEN it returns exactly 0.75. (Narrowed per `/story-readiness` review — this story implements the multiplier lookup only; the 25×0.75=18.75→19 reward-rounding example belongs to the caller, not this function's test obligation. See the worked example below for context only.)
- [ ] GIVEN Morale=0, THEN the effectiveness multiplier used is exactly 0.5x (Critical band floor).
- [ ] Boundaries (70/40/15) are inclusive-lower, tested as paired values on both sides of each boundary (per `qa-lead`'s QL-STORY-READY review — without the "just below" pairing, an off-by-one band-width bug would pass undetected): M=70→1.0 and M=69→0.9; M=40→0.9 and M=39→0.75; M=15→0.75 and M=14→0.5. Also M=100 (top of Full band) → 1.0, confirming the upper edge of the highest band.

**Context only (not a test obligation of this story)**: a caller applying the Low-band 0.75x multiplier to a 25 Zasięgi base reward computes `25×0.75=18.75`, then round-half-up to 19 Zasięgi at the call site (Action System / Offline Progress System) — illustrates why this lookup matters, not something `action_effectiveness_multiplier()` itself does.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

Implement `ResourceFormulas.action_effectiveness_multiplier(morale: float) -> float` as a static function with this exact discrete lookup (no interpolation — legible math is the explicit design intent):

```
Mult(M) = 1.00  if 70 ≤ M ≤ 100
        = 0.90  if 40 ≤ M < 70
        = 0.75  if 15 ≤ M < 40
        = 0.50  if  0 ≤ M < 15
```

Note the inclusive-lower boundary convention: use `>=` for the lower bound of each band, `<` for the upper. Rounding of the *final reward* (not the multiplier itself) uses round-half-up — implement this at the call site (Action System / Offline Progress System), not inside this function, since this function's job is the multiplier lookup only.

**Performance**: O(1) discrete branch lookup (no math library calls) — negligible relative to the offline simulation loop's confirmed sub-millisecond budget even at its 1440-iteration worst case (ADR-0006). No profiling required at this scale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: Morale drain itself (this story only reads the resulting Morale value).
- Round-half-up reward rounding at the call site — implemented where the reward is actually applied, not here.

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-1-2026-06-20.md`:*

- **AC**: Morale=35% (Low band) → reward 25×0.75=18.75 → round-half-up → 19
  - Given: Morale=35
  - When: `action_effectiveness_multiplier(35)` is called, result applied to a 25-base reward
  - Then: multiplier=0.75, final reward=19 (rounding done at call site, not inside this function)
- **AC**: Morale=0 → multiplier exactly 0.5x
  - Given: Morale=0
  - When: `action_effectiveness_multiplier(0)` is called
  - Then: result = 0.5
- **AC**: Boundaries are inclusive-lower
  - Given: M=70, M=69, M=40, M=39, M=15, M=14
  - When: each is passed to the function
  - Then: {1.0, 0.9, 0.9, 0.75, 0.75, 0.5} respectively — boundary value belongs to the higher band

**Estimated test count**: ~7 unit tests | **Test file**: `tests/unit/resource_system/effectiveness_multiplier_test.gd`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_system/effectiveness_multiplier_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Core Resource Mutation) must be DONE
- Unlocks: Story 005 (Passive Zasięgi Income reads this multiplier)

## Completion Notes
**Completed**: 2026-06-23
**Criteria**: 3/3 passing (12 tests covering 9 specified values + 3 bonus tests)
**Deviations**: Implementation initially used inline magic numbers instead of named constants — caught during code review, fixed by extracting `E_*` prefixed constants.
**Test Evidence**: Logic — `tests/unit/resource_system/effectiveness_multiplier_test.gd` (12 tests, confirmed passing — 33/33 across the whole Resource System suite via real GdUnit4 execution)
**Code Review**: Complete (APPROVED)
