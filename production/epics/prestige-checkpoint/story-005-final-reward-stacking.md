# Story 005: F3a-d Final Reward Stacking Application Points

> **Epic**: Prestige/Checkpoint System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**:

**BLOCKED**: ADR-0012 is Proposed — run `/architecture-review` in a fresh session to move it to Accepted before starting this story.

## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §3 (`PrestigeFormulas`, consumption side); ADR-0010 §5a (`get_active_sponsor_multiplier()`, for F3b)
**ADR Decision Summary**: META_BONUS totals apply as ongoing multipliers/floors at the point resources are computed each action/era, not as one-time grants. Four independent multiplicative layers (Morale band, Class Path, Challenge, META_BONUS) compose together.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: `ResourceFormulas`-style stateless composition (ADR-0006) — these are read-time multiplier applications, not stored state mutations
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD §F3a-d, scoped to this story:*

- [ ] GIVEN `zrob_drame` (base 10), `Mult(M)=1.00`, `class_path_multiplier=1.30`, `challenge_modifier=1.0`, `META_REACH_MULT_total=0.3873`, THEN `final_reach=18` (`max(1, round(10×1.00×1.30×1.0×1.3873))`)
- [ ] GIVEN the same action with `Mult(M)=0.90`, `challenge_modifier=0.5`, `META_REACH_MULT_total=0.0429`, THEN `final_reach=6` (`max(1, round(10×0.90×1.30×0.5×1.0429))`)
- [ ] GIVEN a base-5 action, `Mult(M)=0.50`, `class_path_multiplier=1.0`, `challenge_modifier=0.05`, `META_REACH_MULT_total=0.0`, THEN `final_reach=1` (raw product rounds to 0, floored to 1 — a completed action never grants zero Reach)
- [ ] GIVEN `base_sponsors_roll=3`, `class_path_sponsor_multiplier=1.20`, `META_SPONSOR_MULT_total=0.50`, THEN `final_sponsors=5` (`round(3×1.20×1.50)`) — **against a mocked `class_path_sponsor_multiplier`, since `get_active_sponsor_multiplier()` (ADR-0010 §5a) exists but its call site at card resolution is a separate integration point**
- [ ] GIVEN `C=80` (`H_rate(C)=0.66`) and `META_HATERS_RESIST_total=0.30`, THEN `H_rate_final=0.462` Haters/min during active play (`0.66×0.70`)
- [ ] GIVEN `META_SPONSOR_FLOOR_total=9.0` at the moment era-start resource reset runs, THEN Sponsors is set to `9`, overriding the default `0`
- [ ] GIVEN `META_SPONSOR_FLOOR_total=0.0`, THEN Sponsors is `0`, unchanged from default
- [ ] GIVEN `META_HATERS_RESIST_total=0.30` and `OfflineProgressSystem.simulate_offline()` runs, WHEN offline Haters growth is computed, THEN accrual is exactly `0.70×` of what the same window produces with `META_HATERS_RESIST_total=0.0` — resistance applies identically online and offline (F3c, intentional divergence from Class Path/Challenge's offline-exclusion pattern)

---

## Implementation Notes

*Derived from GDD F3a-d:*

`final_reach = max(1, round(base × Mult(M) × class_path_multiplier × challenge_modifier × (1 + META_REACH_MULT_total)))` — the `max(1, ...)` floor rule (added post-`/design-review`) ensures a completed action never grants zero Reach.

`final_sponsors = round(base_sponsors_roll × class_path_sponsor_multiplier × (1 + META_SPONSOR_MULT_total))` — consumed at `DecisionCardSystem`'s Sponsor-roll resolution point (same call site as ADR-0010 §5a's `get_active_sponsor_multiplier()`).

`H_rate_final = H_rate(C) × (1 - META_HATERS_RESIST_total)` — applies identically in `ActionSystem` (active play) and `OfflineProgressSystem.simulate_offline()` (F3c locked scope — this is the one system where offline output is intentionally NOT identical to a no-system baseline, contrast with Class Path/Challenge).

`Sponsors_era_start = META_SPONSOR_FLOOR_total if META_SPONSOR_FLOOR_total > 0.0 else 0.0` (era-start default override) — applies inside the flag-sweep sequence (Story 007), ordering-sensitive: sweep writes defaults first, F3d's override must write Sponsors *after* (Story 007's own AC covers the ordering; this story only implements the override function itself).

These are pure functions taking explicit float arguments — implement as additional `PrestigeFormulas` static methods, same pattern as Stories 003/004.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: the ordering guarantee between the flag sweep's default write and F3d's override write (this story implements the override function itself, correctly, in isolation)
- The real `get_active_sponsor_multiplier()` call-site wiring at card resolution (ADR-0010 §5a) — a Class Path System epic concern, mocked here

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1/AC-2/AC-3 (Reach stacking + floor)**: direct unit tests against the stated inputs/outputs
  - Edge cases: the floor case (AC-3) is the critical one — verify `max(1, ...)` triggers correctly when the raw product rounds to 0

- **AC-4 (Sponsor stacking)**:
  - Given: mocked `class_path_sponsor_multiplier=1.20`, `META_SPONSOR_MULT_total=0.50`
  - When: sponsor formula computes
  - Then: returns `5`

- **AC-5 (Haters resistance)**: direct unit test at the stated `C`/resistance values
  - Edge cases: `META_HATERS_RESIST_total=0.0` (no-op, matches unmodified `H_rate(C)`)

- **AC-6/AC-7 (Sponsor floor)**: direct unit tests for both the active-floor and zero-floor cases

- **AC-8 (offline parity, F3c)**:
  - Given: identical elapsed window, `META_HATERS_RESIST_total=0.30` vs `0.0`
  - When: `simulate_offline()` runs both
  - Then: the `0.30` case's Haters accrual is exactly `0.70×` the `0.0` case's

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/prestige/prestige_formulas_reward_stacking_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (needs real `META_BONUS_total` values to compose against)
- Unlocks: Story 007 (sweep+F3d ordering test needs this story's override function to exist)
