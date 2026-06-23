# Story 005: Passive Zasięgi/Reach Income (Formula D)

> **Epic**: Resource System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-23

## Context

**GDD**: `design/gdd/resource-system.md`
**Requirement**: `TR-res-001`

**ADR Governing Implementation**: ADR-0006: Offline simulation loop implementation
**ADR Decision Summary**: Lives in the shared stateless `ResourceFormulas` static utility class — this is the formula whose online/offline consistency was the entire motivating reason for ADR-0006's shared-class decision.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Pure float math. No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: Offline/online resource formulas live in one stateless static utility class — source: ADR-0006

---

## Acceptance Criteria

*From GDD `design/gdd/resource-system.md`, scoped to this story:*

- [ ] GIVEN Hatersi=10, Morale=80% (Mult=1.0), WHEN 10 minutes elapse with no player action, THEN Zasięgi increases by exactly `10×0.2×1.0×10=20`.
- [ ] GIVEN Hatersi=0, WHEN any duration elapses with no player action, THEN passive Zasięgi = 0 for the entire duration.
- [ ] GIVEN any Hatersi count and Mult, WHEN elapsed_seconds=0, THEN passive Zasięgi = 0 (no time elapsed, no income). (Promoted from QA Test Cases per `/story-readiness` review — Logic stories require ≥3 ACs.)
- [ ] This function takes the already-computed `Mult(M)` as a parameter and never calls `action_effectiveness_multiplier()` internally — verified by code inspection, not a runtime test (per Implementation Notes' "no hidden cross-calls" requirement).
- [ ] **Signature is locked** (per `qa-lead`'s QL-STORY-READY review — ADR-0006 requires this exact signature to match what the future Offline Progress System's `simulate_offline()` loop expects): `ResourceFormulas.passive_zasiegi_income(hatersi_count: float, morale_mult: float, elapsed_seconds: float) -> float`, in this exact parameter order and these exact types.
- [ ] GIVEN a large `elapsed_seconds` value representing a multi-hour idle/offline session (e.g., 8 hours = 28800s), WHEN `passive_zasiegi_income()` is called with realistic Hatersi/Mult values, THEN the result is a finite float with no precision loss or overflow — this is the exact scenario ADR-0006 cites as the motivating use case (Offline Progress System), so it must be explicitly tested, not just the short 10-minute worked example.

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

Implement `ResourceFormulas.passive_zasiegi_income(hatersi_count: float, morale_mult: float, elapsed_seconds: float) -> float` as a static function:

```
Z_passive(N, Δt) = N × Z_per_hater × Mult(M) × (Δt / 60)
```

Tuning constant (locked): `Z_per_hater = 0.2`. Takes the *already-computed* `Mult(M)` as a parameter (from Story 004's function) rather than recomputing Morale band internally — keeps this function a pure arithmetic combination of its inputs, no hidden cross-calls. This is the exact function the Offline Progress System's `simulate_offline()` loop calls once per simulated minute — confirm the signature matches what that system's implementation expects (see `offline-progress-system.md`'s pseudocode) before considering this story done.

**Performance**: O(1) pure float arithmetic (no branches, no math library calls) — negligible relative to the offline simulation loop's confirmed sub-millisecond budget even at its 1440-iteration worst case (ADR-0006). No profiling required at this scale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: the Morale multiplier lookup itself (passed in as a parameter here).
- Offline Progress System epic: the stepped simulation loop that calls this function repeatedly — this story only implements the per-call formula.

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-1-2026-06-20.md`:*

- **AC**: Hatersi=10, Morale=80% (Mult=1.0), 10 min → Zasięgi +20
  - Given: `Z_per_hater=0.2`, N=10, Mult=1.0, Δt=600s
  - When: `passive_zasiegi_income(10, 1.0, 600)` is called
  - Then: result = exactly `10×0.2×1.0×10 = 20`
- **AC**: Hatersi=0 → passive income = 0
  - Given: N=0, any Mult, any Δt
  - When: `passive_zasiegi_income(0, mult, dt)` is called
  - Then: result = 0
  - Edge cases: Δt=0 with any N/Mult → result = 0
- **AC**: function takes `Mult(M)` as a parameter, doesn't recompute it
  - Verify by code inspection: no internal call to `action_effectiveness_multiplier()` inside this function
- **AC**: large idle/offline session (multi-hour) produces a finite, precise result
  - Given: N=15, Mult=0.9, Δt=28800s (8 hours)
  - When: `passive_zasiegi_income(15, 0.9, 28800)` is called
  - Then: result = `15×0.2×0.9×480 = 1296.0` exactly, finite, no precision loss

**Estimated test count**: ~6 unit tests | **Test file**: `tests/unit/resource_system/passive_income_test.gd`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_system/passive_income_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (Effectiveness Multiplier) must be DONE
- Unlocks: Offline Progress System epic's `simulate_offline()` story (consumes this function directly)

## Completion Notes
**Completed**: 2026-06-23
**Criteria**: 5/5 passing (11 tests)
**Deviations**: 1 advisory (logged to docs/tech-debt-register.md) — "no cross-call" AC4 guarantee enforced only by a documentation-only test, not real static analysis; lead-programmer recommends a one-time lint check across all formulas instead of per-story fixes.
**Test Evidence**: Logic — `tests/unit/resource_system/passive_income_test.gd` (11 tests, confirmed passing — 44/44 across the whole Resource System suite via real GdUnit4 execution)
**Code Review**: Complete (APPROVED)
