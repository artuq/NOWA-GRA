# Story 001: 4-Path Registration + Tier 3-5 Expansion

> **Epic**: Class Path System (Full)
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-13

## Context

**GDD**: `design/gdd/class-path-system.md`
**Requirement**: `TR-cps-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 §11 (4-Path Registration Expansion)
**ADR Decision Summary**: `_MULTIPLIER_TABLE` and path-registration dictionaries currently cover 2 paths × Tiers 1-2 only. Expansion to 4 paths × Tiers 1-5 is pure data growth within the existing structure (§5) — no new API surface. `TIER_THRESHOLDS` is already a 6-element array and needs no structural change.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None beyond standard Dictionary literal syntax.

**Control Manifest Rules (this layer)**:
- Required: n/a (this story is pure data — no Timer/RNG/cooldown surface touched)
- Forbidden: n/a
- Guardrail: n/a — data-table lookups stay O(1), no perf concern at this scale

---

## Acceptance Criteria

*From GDD `design/gdd/class-path-system.md`, scoped to this story:*

- [ ] `ekspert_niszowy` and `biznesmen_contentu` are registered in `class_path_system.gd`'s path dictionaries alongside the existing `pato_streamer`/`guru_celebryta` (currently 2 of 4 paths registered per the MVP-scope header comment)
- [ ] `_MULTIPLIER_TABLE` contains all 5 tiers (1-5) for all 4 paths, sourced from GDD's Tier Bonuses by Path table (§Detailed Design)
- [ ] GIVEN affiliation `= 79.9`, THEN `get_tier(path)` returns `3`; GIVEN `= 80.0`, THEN returns `4`; GIVEN `= 100.0`, THEN returns `5` — for all 4 paths, not just the 2 MVP paths
- [ ] GIVEN a path jumps from Tier 0 directly to affiliation `45.0` in one update, THEN `tier_unlocked` fires twice in the same pass (Tier 1, then Tier 2) — never skipping an intermediate tier
- [ ] GIVEN a path is at Tier 2, THEN no code path may ever set `get_tier(path)` back below 2 within the same era (monotonicity)
- [ ] GIVEN `pato_streamer` is active at T1 (+30% Reach) and a second, independent Reach modifier source also applies +10% to the same action, THEN the combined bonus is +40% (additive), never multiplicative — test against a stubbed second bonus source (DI-over-singletons testability standard)

---

## Implementation Notes

*Derived from ADR-0010 §11:*

This is pure data expansion — `TIER_THRESHOLDS` (already 6 elements, `_check_tier_progression()`'s `range(old_tier + 1, TIER_THRESHOLDS.size())` already generalizes past 2 tiers) needs no structural change. Populate `_MULTIPLIER_TABLE` and the 2 new path entries from the GDD's Tier Bonuses table:

| Tier | Pato-Streamer | Guru-Celebryta | Ekspert Niszowy | Biznesmen Contentu |
|---|---|---|---|---|
| T1 | +30% Reach "Zrób dramę" | +20% Sponsor income | +15% passive Reach floor | +25% Sponsor income, -10% acquisition cooldown |
| T2 | +25% Haters→Reach | Morale floor 20 | +20% Reach "Nagraj vloga" | Card-choice Morale costs -25% |
| T3 | "Hazardowi" sponsor tier | "Przeproś" +50% Morale | Haters gain rate -30% | Haters→Sponsor conversion |
| T4 | "Zrób dramę" duration -20% | Passive Reach floor 15% peak | +1 Action Slot | Action unlock cost -20% |
| T5 | Signature: Viral Moment | Signature: Brand Deal | Signature: Kult Niszowy | Signature: IPO Influencera |

Multipliers are additive within the same resource, never multiplicative — the last AC above regression-tests this against a stubbed second modifier source, since no second real source exists in the codebase yet.

**Performance**: no impact — `_MULTIPLIER_TABLE` lookup stays O(1) regardless of table size (Dictionary), same as ADR-0010's existing Performance Implications.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: Investment Contribution mechanic
- Story 003: Tie-Break Resolution fix (BUG-003)
- Story 004: Signature card pool wiring (T4/T5 mechanics beyond the multiplier data itself — T3/T4's non-multiplier effects like "Hazardowi sponsor tier unlocked" or "+1 Action Slot" are data/flags only in this story; their actual gameplay hooks belong to whichever system consumes them, e.g. Action System slot count — flag as a follow-up if no consumer exists yet)

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (tier boundaries, all 4 paths)**:
  - Given: a path at affiliation 79.9, 80.0, 100.0
  - When: `get_tier(path_id)` is called
  - Then: returns 3, 4, 5 respectively
  - Edge cases: repeat for all 4 path_ids, not just the 2 MVP ones; boundary values exactly at threshold (20.0, 40.0, 60.0, 80.0, 100.0)

- **AC-2 (multi-tier jump, single emit-per-tier)**:
  - Given: path at Tier 0, affiliation 0.0
  - When: affiliation set directly to 45.0 in one update
  - Then: `tier_unlocked` fires exactly twice, with tier=1 then tier=2, in that order
  - Edge cases: jump spanning all 5 tiers in one update (affiliation 0→100)

- **AC-3 (monotonicity)**:
  - Given: path at Tier 2
  - When: any sequence of card resolutions/investments within the era
  - Then: `get_tier(path)` never returns < 2 for the remainder of the era
  - Edge cases: N/A — this is a property test, not a boundary test

- **AC-4 (additive stacking)**:
  - Given: `pato_streamer` active at T1, a stubbed second Reach modifier of +10% on the same action
  - When: the action resolves
  - Then: combined bonus is +40% (`base × 1.40`), not `base × 1.3 × 1.1`
  - Edge cases: stub returns 0% (no-op — result should equal T1 alone)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/class-path/class_path_multiplier_table_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational — extends existing shipped `class_path_system.gd`)
- Unlocks: Story 002 (Investment), Story 004 (Signature Cards — needs Tier 5 reachable on all 4 paths)

## Completion Notes
**Completed**: 2026-07-13
**Criteria**: 6/6 passing
**Deviations**: ADVISORY — `_check_tier_progression()` multi-emit fix (required by AC-2, confined to this story's owned file)
**Test Evidence**: Logic — `tests/unit/class-path/class_path_multiplier_table_test.gd` (11 tests, all passing)
**Code Review**: Complete — APPROVED
