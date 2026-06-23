# Story 006: Cringe Delta Clamping (Formula E)

> **Epic**: Resource System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (1h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-23

## Context

**GDD**: `design/gdd/resource-system.md`
**Requirement**: `TR-res-001`

**ADR Governing Implementation**: ADR-0001: Autoload singleton architecture vs event bus
**ADR Decision Summary**: This clamping behavior is part of `ResourceManager.apply_delta()`'s internal logic (Story 001), not a separate formula class function — Cringe clamping is simple enough to inline at the mutation layer rather than route through `ResourceFormulas`.

**Engine**: Godot 4.6.3 | **Risk**: LOW

**Control Manifest Rules (Foundation layer)**:
- Required: Use direct method calls when the caller is the sole trigger of a state mutation it owns — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/resource-system.md`, scoped to this story:*

- [ ] GIVEN Cringe=95, WHEN an action with nominal ΔCringe=+20 completes, THEN actual increase = `clamp(115,0,100)-95=5`, not 20 (natural clamp behavior, not a separate curve).
- [ ] GIVEN Cringe=0, WHEN an action with nominal ΔCringe=-15 completes, THEN actual change = `clamp(-15,0,100)-0=0` (floor case — symmetric to the ceiling case above). (Promoted from QA Test Cases per `/story-readiness` review — Logic stories require ≥3 ACs.)
- [ ] GIVEN Cringe=50, WHEN an action with nominal ΔCringe=+20 completes, THEN actual change = `clamp(70,0,100)-50=20` exactly — sanity check confirming no clamping occurs (and thus no unintended dampening) when the delta stays well within bounds.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines:*

This is a thin wrapper documenting the exact clamp formula for Cringe specifically (already implemented generically in Story 001's `apply_delta()` for both Cringe and Morale):

```
ΔCringe_actual = clamp(C + Cringe_delta_action, 0, 100) - C
```

No new code beyond Story 001 should be required if Story 001's clamp is implemented correctly — this story exists primarily to give this specific formula (and its near-ceiling "soft brake" behavior) an explicit, isolated test case, since it's referenced by name in the GDD as Formula E and economy-designer flagged it as an intentional design mechanism (not an incidental side effect of generic clamping).

**Performance**: N/A — no new code; this story only adds isolated test coverage for Story 001's existing `apply_delta()` clamp behavior.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the generic `apply_delta()` clamping mechanism this story tests a specific case of.

---

## QA Test Cases

*From `production/qa/qa-plan-sprint-1-2026-06-20.md`:*

- **AC**: Cringe=95, nominal delta=+20 → actual delta=5
  - Given: C=95
  - When: a +20 delta is applied via `apply_delta()`
  - Then: actual change = `clamp(115,0,100)-95 = 5`, not 20
  - Edge cases: C=0, nominal delta=-15 → actual delta=0; C=50, nominal delta=+20 → actual delta=20 (no clamping needed, sanity check)

**Estimated test count**: ~3 unit tests | **Test file**: `tests/unit/resource_system/cringe_clamping_test.gd`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/resource_system/cringe_clamping_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Core Resource Mutation) must be DONE
- Unlocks: None

## Completion Notes
**Completed**: 2026-06-23
**Criteria**: 3/3 passing (7 tests total — 3 ACs + 4 bonus). Verified via real GdUnit4 — 51/51 across the Resource System suite at the time of closing this story (now 55/55 after Story 007 added 4 tests).
**Deviations**: (1) Pure-test story — zero production code changed (Formula E was already implemented generically in Story 001's `apply_delta()` clamp). (2) QL-TEST-COVERAGE and LP-CODE-REVIEW gates were initially performed inline rather than by independent director subagents — the Task/Agent infrastructure returned persistent 500 errors at closure time (root cause later identified: transient server-side incident on the sonnet model, which most ccgs agents pin). **RESOLVED 2026-06-23**: both gates were re-run formally by independent subagents with a `model: opus` override (bypassing the broken sonnet path) — qa-lead QL-TEST-COVERAGE = ADEQUATE, lead-programmer LP-CODE-REVIEW = APPROVE, both confirming the inline verdicts. Independent audit trail now exists.
**Test Evidence**: Logic — `tests/unit/resource_system/cringe_clamping_test.gd` (7 tests)
**Code Review**: Complete — APPROVE (independent lead-programmer re-run on opus, 2026-06-23)
