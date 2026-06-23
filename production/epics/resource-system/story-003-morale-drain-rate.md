# Story 003: Morale Drain Rate (Formula B)

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
**ADR Decision Summary**: Lives in the shared stateless `ResourceFormulas` static utility class, called identically by live-play and offline simulation.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Pure float math. No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: Offline/online resource formulas live in one stateless static utility class — source: ADR-0006
- Forbidden: Never add instance vars or `@export` fields to `ResourceFormulas` — source: ADR-0006

---

## Acceptance Criteria

*From GDD `design/gdd/resource-system.md`, scoped to this story:*

- [ ] GIVEN Hatersi=10, WHEN `morale_drain_rate(10)` is called, THEN it returns the *rate* `0.15×(10-3)^1.3≈1.882` (±0.01) **per minute** — this function returns a rate, not a time-integrated delta; the caller (Story 001's `apply_delta()` consumer) is responsible for multiplying by `Δt/60` to get an actual Morale change. (Clarified per `qa-lead`'s QL-STORY-READY review — the AC tests the rate contract directly, not a 1-minute-elapsed scenario. Value corrected 2026-06-23 — original "1.85" was an arithmetic error caught during implementation; 7^1.3≈12.546, not ≈12.33.)
- [ ] GIVEN Hatersi=20 (well above buffer) and the resulting drain rate is applied to Morale=0, WHEN `apply_delta()` (Story 001) processes the resulting negative delta, THEN `morale_drain_rate(20)` itself still returns its unclamped value `0.15×(20-3)^1.3≈5.966` (±0.01) — this function does NOT floor at current Morale; flooring happens at `apply_delta()`, not here. (Added concrete expected value per `qa-lead`'s review — "drain is still computed" alone wasn't objectively verifiable. Value corrected 2026-06-23.)
- [ ] GIVEN Hatersi=0, WHEN `morale_drain_rate(0)` is called, THEN Morale drain rate = 0.
- [ ] GIVEN Hatersi=3 (exact buffer boundary), WHEN `morale_drain_rate(3)` is called, THEN result = 0 — the buffer is a hard cliff (`max(0, N-3)`), and the boundary value must be tested explicitly, not just inferred from N=0. (Added per `qa-lead`'s review.)

---

## Implementation Notes

*Derived from ADR-0006 Implementation Guidelines:*

Implement `ResourceFormulas.morale_drain_rate(hatersi_count: int) -> float` as a static function:

```
M_drain(N) = M_drain_per_hater × max(0, N - N_buffer)^M_drain_exp
```

Tuning constants (locked, from `entities.yaml`): `N_buffer = 3`, `M_drain_per_hater = 0.15`, `M_drain_exp = 1.3`. The first `N_buffer` Hatersi drain nothing — this is `max(0, N - N_buffer)`, not a separate conditional branch. This function returns a *rate* (%/min); the caller computes `ΔMorale = -M_drain(N) × Δt / 60` and is responsible for flooring the result at `-M_current` before calling `apply_delta()` (Story 001's clamping is the floor enforcement, not this function).

**NaN-safety note** (unlike Story 002's `H_EXP`, no whole-number constraint applies here): `M_drain_exp=1.3` is a fractional exponent, which would be unsafe on a negative base — but the `max(0, N - N_buffer)` clamp guarantees the base passed to `pow()` is always ≥0 regardless of what `N` is (even if a future bug fed a negative Hatersi count), so this formula is safe by construction without needing `M_drain_exp` to stay a whole number.

**Performance**: O(1) pure float arithmetic (one `max` + one `pow`) — negligible relative to the offline simulation loop's confirmed sub-millisecond budget even at its 1440-iteration worst case (ADR-0006). No profiling required at this scale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the actual floor-at-zero clamp on Morale (this function may mathematically return a drain larger than current Morale; clamping happens at the `apply_delta()` layer).
- Story 002: Hatersi growth (a separate function feeding the `N` input to this one).

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-1-2026-06-20.md`:*

- **AC**: Hatersi=10 → rate = 1.882%/min (±0.01)
  - Given: `N_buffer=3, M_drain_per_hater=0.15, M_drain_exp=1.3`
  - When: `morale_drain_rate(10)` is called
  - Then: result = `0.15×7^1.3 ≈ 1.882` (±0.01) — this is the per-minute rate, not a time-integrated delta
  - Edge cases: N=25 → ≈8.341%/min (±0.01, per GDD worked example, corrected 2026-06-23); negative N (out-of-contract) → finite, no crash (safe by construction via `max(0, ...)`, no NaN-safety caveat needed unlike Story 002)
- **AC**: Hatersi ≤ buffer (3) → drain = 0, including the exact boundary
  - Given: N=0, 1, 2, and 3 (each tested explicitly)
  - When: `morale_drain_rate(N)` is called for each
  - Then: result = 0 for all four (buffer inclusive, cliff at N=3 confirmed)
- **AC**: unclamped at high N, with a concrete expected value
  - Given: N=20
  - When: `morale_drain_rate(20)` is called
  - Then: result ≈ 5.966 (±0.01), unclamped — flooring against current Morale happens at `apply_delta()` (Story 001), not here; verify by both the numeric assertion and a code-inspection check that no clamping logic exists inside this function

**Estimated test count**: ~7 unit tests | **Test file**: `tests/unit/resource_system/morale_drain_rate_test.gd`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_system/morale_drain_rate_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Core Resource Mutation) must be DONE
- Unlocks: Story 004 (Effectiveness Multiplier reads the Morale value this formula drains)

## Completion Notes
**Completed**: 2026-06-23
**Criteria**: 5/5 passing — actually verified via real GdUnit4 execution (first real test run this session; 21/21 tests across the whole Resource System suite passed)
**Deviations**: Constant renamed `N_BUFFER`→`M_BUFFER` for naming consistency. Major infrastructure gap found and fixed: project had no `project.godot`, no installed GdUnit4 addon, and a fictional CI runner script — none of Stories 001-003's tests had ever actually executed before today. Two real bugs found and fixed once tests could run: untyped dictionary literals in `core_mutation_test.gd` rejected by `apply_delta()`'s typed parameter, and a double-free in `after_test()` caused by GdUnit4's own GC. See `docs/tech-debt-register.md`.
**Test Evidence**: Logic — `tests/unit/resource_system/morale_drain_rate_test.gd` (8 tests, confirmed passing)
**Code Review**: Complete (APPROVED)
