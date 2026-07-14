# Story 007: Flag Classification Sweep (Core Rule 7)

> **Epic**: Prestige/Checkpoint System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (4h+ — the ordering assertion for F3d is the highest-fragility test in this epic)
> **Manifest Version**: 2026-06-20
> **Last Updated**:


## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §5 (Flag classification sweep)
**ADR Decision Summary**: `PrestigeSystem._sweep_era_local_flags()` owns the list of what's era-local vs meta-persistent; `HistoryFlagManager` owns the actual clear/preserve mechanics. Absence of a clear call is the preservation mechanism, not a separate "preserve" call.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: n/a — delegates to `HistoryFlagManager`'s existing API, no new pattern
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD §Flag Classification Sweep (Core Rule 7), scoped to this story:*

- [ ] GIVEN a Choice A transition begins with concrete era-local state (all 5 resources nonzero, `pato_streamer` affiliation 65.0/tier 3, `pato_streamer_choices_count=12`, `challenge_active_bez_tlumu` set, `_deferred_this_era=true`), WHEN the flag sweep completes, THEN all 5 resources are at era-start defaults, Class Path affiliation/tier are zeroed, the counter is `0`, the challenge flag is cleared, and `_deferred_this_era=false`
- [ ] GIVEN the same transition, THEN `era_count` is incremented and preserved, all four `META_BONUS_total[type]` are unchanged, `best_tier_reached`/`eras_spent_as` for `pato_streamer` are preserved, `burnout_accepted_era_N` is set and preserved, and `first_burnout_bonus_used`/`variety_bonus_used` are preserved at whatever value this transition left them
- [ ] GIVEN the same transition AND `META_SPONSOR_FLOOR_total=9.0` at the moment the sweep runs, WHEN both the flag sweep and F3d's override resolve together, THEN Sponsors ends at `9` (F3d's override), not `0` (the sweep's own default) — **the test MUST assert call order directly (spy verifying the sweep's default-write runs before F3d's override write), not only the final value `9`**

---

## Implementation Notes

*Derived from ADR-0012 §5 and GDD Core Rule 7's classification table:*

**Era-local** (cleared): all 5 resources, Class Path affiliation/tier/counters, active Challenge flags, `BurnoutSystem._deferred_this_era`.

**Meta-persistent** (never cleared): `era_count`, all 4 `META_BONUS_total`, Class Path's `best_tier_reached`/`eras_spent_as`, `burnout_accepted_era_N`/`burnout_deferred_era_N` flags, `first_burnout_bonus_used[type]` (4 flags), `variety_bonus_used`.

`ClassPathSystem.reset_era_state()` (called earlier in Story 001's sequence, ADR-0010) already clears its own era-local counters — this story's sweep covers what's left: `_deferred_this_era`, active Challenge flags, and the 5 resource defaults via `ResourceManager` (per Final Burnout spec §4.2, locked, out of this ADR's scope beyond the call itself).

**The AC-3 ordering test is the load-bearing one in this story.** A naive implementation that special-cases Sponsors out of the sweep's default write would make an end-state-only assertion (`Sponsors == 9`) pass without actually exercising the "sweep writes defaults, F3d overwrites Sponsors only" contract. Use a spy/mock on the write calls themselves to assert order, not just the final value.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: F3d's override function itself (already implemented there — this story only tests it's called in the right order relative to the sweep's defaults)
- Story 001: the outer orchestration sequence (this story is the sweep step within it)

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (era-local flags cleared)**:
  - Given: the stated concrete pre-transition state
  - When: sweep completes
  - Then: every era-local field listed is at its default/zero/false state
  - Edge cases: a resource at exactly its era-start default already (sweep should be idempotent, not error)

- **AC-2 (meta-persistent flags preserved)**:
  - Given: same transition
  - When: sweep completes
  - Then: every meta-persistent field listed is unchanged from its pre-transition value (except `era_count`, which increments — verify the increment happened via Story 001, not this story's sweep itself)

- **AC-3 (sweep-then-override ordering, spy-verified)**:
  - Given: `META_SPONSOR_FLOOR_total=9.0`
  - When: sweep + F3d override both run in the same transition
  - Then: a call-order spy confirms the sweep's Sponsors-default write happens before F3d's override write; final value is `9`
  - Edge cases: `META_SPONSOR_FLOOR_total=0.0` — sweep's default (`0`) and F3d's override (`0`) coincide, so this case alone cannot distinguish correct ordering from a broken implementation — AC-3 only tests the `9.0` case for this reason, do not substitute the zero case as "equivalent coverage"

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/prestige/prestige_flag_sweep_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (orchestration sequence), Story 004 (META_BONUS totals must exist to verify preservation), Story 005 (F3d's override function)
- Unlocks: Story 008 (atomicity tests need the full sweep to exist)
