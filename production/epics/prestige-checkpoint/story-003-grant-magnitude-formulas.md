# Story 003: META_BONUS Grant Magnitude + Variety Bonus (F1, F1b)

> **Epic**: Prestige/Checkpoint System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Logic
> **Estimate**: L (4h+ — dense formula surface with many edge cases)
> **Manifest Version**: 2026-06-20
> **Last Updated**:

**BLOCKED**: ADR-0012 is Proposed — run `/architecture-review` in a fresh session to move it to Accepted before starting this story.

## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §3 (`PrestigeFormulas` stateless static methods)
**ADR Decision Summary**: `PrestigeFormulas.tier_factor()` and `grant_magnitude()` implement F1/F1b as pure static functions taking explicit arguments — no Autoload state, same precedent as `ResourceFormulas` (ADR-0006) / `FeedbackMath` (ADR-0011).

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: stateless static utility class pattern (mirrors ADR-0006's `ResourceFormulas` rule — never add instance vars/`@export` fields)
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD `design/gdd/prestige-checkpoint-system.md` §META_BONUS Grant Magnitude + §Variety Completionist Bonus, scoped to this story. All numeric values test formula correctness against pre-Alpha defaults, not final balance (GDD's own caveat).*

- [ ] GIVEN active path `pato_streamer`, `tier_at_burnout=1`, `combined_meta_multiplier=1.0`, player's first-ever accepted burnout with an active path, THEN `bonus_increment[META_REACH_MULT] = 0.1071` (`0.02 × 2.143 × 1.0^0.5 × 2.5`)
- [ ] GIVEN the same inputs but `first_burnout_bonus_used[META_REACH_MULT]=true`, THEN `bonus_increment = 0.0429` (`0.02 × 2.143 × 1.0 × 1.0`)
- [ ] GIVEN `tier_at_burnout=3`, `combined_meta_multiplier=2.0`, not first burnout, THEN `bonus_increment = 0.1010` (`0.02 × 3.571 × 2.0^0.5`)
- [ ] GIVEN `tier_at_burnout=5`, `combined_meta_multiplier=15.0`, not first burnout, THEN `bonus_increment = 0.3873` (`0.02 × 5.0 × 15.0^0.5`, `tier_factor(5)=5.0` unchanged from pre-revision formula)
- [ ] GIVEN `META_CHALLENGE_SCALING_EXPONENT` changes from `0.5` to `0.3` for the same Tier-5/multiplier-15.0 inputs, THEN result changes to `≈0.2253` pre-cap — confirms live tuning knob, not baked in
- [ ] GIVEN `TIER_FLAT_BASE` changes from `2` to `0` for a Tier-1/multiplier-1.0/non-first grant, THEN `tier_factor(1)` becomes exactly `1.0` and `bonus_increment = 0.02`
- [ ] GIVEN Tier 5/multiplier 15.0, first-ever burnout on `META_SPONSOR_MULT`, THEN `raw_increment=1.209` but `bonus_increment` clamps to `0.25` (`FIRST_BURNOUT_GRANT_CAP_FRACTION(0.5) × META_BONUS_MAX[META_SPONSOR_MULT](0.50)`)
- [ ] GIVEN the same inputs but not the first grant, THEN no 4b-i ceiling applies — `bonus_increment = raw_increment` unclamped (subject only to F2's cap, out of this story's scope)
- [ ] GIVEN 3 of 4 `META_BONUS_total[type]` are nonzero and the fourth is `0.0`, WHEN a grant makes the fourth nonzero for the first time, THEN all four types additionally receive `BASE_INCREMENT[type] × VARIETY_BONUS_MULT`, and `variety_bonus_used` is set `true`
- [ ] GIVEN `variety_bonus_used=true`, WHEN any subsequent grant resolves, THEN no additional completionist grant applies
- [ ] GIVEN one of the four types is already at cap when the completionist grant fires, THEN that type's variety grant is absorbed per F2's clamp — no exception, no compensating grant elsewhere

---

## Implementation Notes

*Derived from ADR-0012 §3 and GDD Formulas F1/F1b:*

```gdscript
static func tier_factor(tier: int, tier_flat_base: int) -> float:
    return (float(tier_flat_base) + float(tier)) * 5.0 / (float(tier_flat_base) + 5.0)

static func grant_magnitude(bonus_type: StringName, tier: int, challenge_mult: float,
        is_first_burnout: bool) -> float:
    # F1 — full derivation and worked examples in design/gdd/prestige-checkpoint-system.md
    var raw: float = BASE_INCREMENT[bonus_type] * tier_factor(tier, TIER_FLAT_BASE) \
        * pow(challenge_mult, META_CHALLENGE_SCALING_EXPONENT)
    if is_first_burnout:
        raw *= FIRST_BURNOUT_BONUS_MULT
        raw = minf(raw, FIRST_BURNOUT_GRANT_CAP_FRACTION * META_BONUS_MAX[bonus_type])
    return raw
```

Variety bonus (F1b) is a separate check the caller (Story 001's `on_burnout_accepted()`, or a dedicated `PrestigeSystem._check_variety_bonus()`) runs after every grant — not part of `grant_magnitude()` itself, since it's a cross-type check, not a per-grant formula. All constants (`BASE_INCREMENT`, `TIER_FLAT_BASE`, `FIRST_BURNOUT_BONUS_MULT`, `FIRST_BURNOUT_GRANT_CAP_FRACTION`, `META_CHALLENGE_SCALING_EXPONENT`, `VARIETY_BONUS_MULT`, `META_BONUS_MAX`) are already registered in `design/registry/entities.yaml` — read fresh, don't hardcode defaults into this story's implementation beyond what the registry states.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: F2's stacking/cap application of these grants to running totals (this story only computes the raw grant magnitude)
- Story 001: the orchestration call site that invokes these functions

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 through AC-6 (F1 worked examples)**: each is a direct unit test — given the stated inputs, assert `grant_magnitude()` / `tier_factor()` returns the exact stated value (float comparison with a small epsilon, e.g. `is_equal_approx`)
  - Edge cases: `TIER_FLAT_BASE=0` boundary (reduces to pure tier scaling); `META_CHALLENGE_SCALING_EXPONENT` at range bounds (0.3, 0.5)

- **AC-7/AC-8 (first-burnout ceiling)**:
  - Given: Tier 5, multiplier 15.0, first-ever grant on a type
  - When: `grant_magnitude()` computes
  - Then: raw exceeds the ceiling, clamped output is `FIRST_BURNOUT_GRANT_CAP_FRACTION × META_BONUS_MAX[type]` exactly
  - Edge cases: same inputs with `is_first_burnout=false` — no ceiling applied, raw value returned unclamped

- **AC-9/AC-10/AC-11 (variety bonus)**:
  - Given: mocked `META_BONUS_total` dictionary with 3 of 4 types nonzero
  - When: the 4th type's grant is applied and the variety check runs
  - Then: all 4 types receive the additional flat increment; `variety_bonus_used` flips to true; a second trigger attempt is a no-op
  - Edge cases: the triggering grant itself is what makes the 4th type nonzero (order-of-operations — variety check must run after the grant, not before)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/prestige/prestige_formulas_grant_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (orchestration skeleton must exist as the call site, though `PrestigeFormulas` itself is independently unit-testable without it)
- Unlocks: Story 004 (stacking/caps consumes these grant values)
