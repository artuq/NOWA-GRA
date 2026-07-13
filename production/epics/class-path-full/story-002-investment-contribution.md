# Story 002: Investment Contribution (F2, Core Rule 4a)

> **Epic**: Class Path System (Full)
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**:

## Context

**GDD**: `design/gdd/class-path-system.md`
**Requirement**: `TR-cps-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 §8 (Investment Contribution)
**ADR Decision Summary**: `invest()` goes live, gated on `card_contribution[path] > 0` (Core Rule 4a). Requires splitting the currently-conflated `_recalculate_affiliation()` into separately-tracked F1 (card) and F2 (investment) terms, summed and clamped by a new `_recalculate_total_affiliation()` (F3).

**Engine**: Godot 4.6.3 | **Risk**: LOW (MEDIUM implementation risk per ADR-0010's own Risks section — structural refactor of existing MVP code, not purely additive)
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: n/a — no ADR-0004/0005/0006 pattern touched directly (this is ClassPathSystem's own domain, ADR-0010)
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD `design/gdd/class-path-system.md`, scoped to this story:*

- [ ] GIVEN `pato_streamer` has `card_contribution = 0` (no path-tagged card choice made yet this era), WHEN the player attempts to invest any amount of Cringe, THEN no resource is deducted, `investment_contribution["pato_streamer"]` remains `0`, and the Invest control reports itself disabled
- [ ] GIVEN `pato_streamer` has `card_contribution = 20.0` (gate satisfied) and 0 investment contribution, WHEN the player invests 200 Cringe, THEN `investment_contribution["pato_streamer"]` becomes `20.0` (200 × rate 0.1)
- [ ] GIVEN the same 200-unit spend is applied to `guru_celebryta` (rate 0.2) and `biznesmen_contentu` (rate 0.02) instead, both gate-satisfied, THEN `guru_celebryta` gains `40.0` and `biznesmen_contentu` gains `4.0` — confirming 4 independent per-path rates, not one shared global constant
- [ ] GIVEN a path's total affiliation is already `100.0`, WHEN the player invests further, THEN the resource is still deducted via ResourceManager but `get_affiliation(path)` remains `100.0`
- [ ] GIVEN the player cannot afford a path's investment cost, WHEN they tap Invest, THEN no resource is deducted and no affiliation change occurs
- [ ] GIVEN `card_contribution["pato_streamer"] = 60.0` and the player invests enough to add `50.0` more investment contribution, WHEN `get_affiliation("pato_streamer")` is queried, THEN it returns `100.0` (F3 clamp — `min(60+50, 100)`, not `110`)
- [ ] The existing `class_path_core_test.gd` suite (25 MVP tests) stays green after the `_recalculate_affiliation()` split

---

## Implementation Notes

*Derived from ADR-0010 §8:*

```gdscript
func invest(path_id: StringName, resource_id: StringName, amount: float) -> bool:
    if _card_contribution.get(path_id, 0.0) <= 0.0:  # gate — Core Rule 4a
        return false
    if not ResourceManager.can_afford(resource_id, amount):
        return false
    var rate: float = _investment_rate_table.get(path_id, 0.0)
    ResourceManager.apply_delta(resource_id, -amount)
    _investment_contribution[path_id] = _investment_contribution.get(path_id, 0.0) + amount * rate
    _recalculate_total_affiliation(path_id)  # F3 clamp, then _check_tier_progression + _update_active_path
    return true
```

**Required refactor**: split `_affiliation[path_id]` into `_card_contribution[path_id]` (F1) and `_investment_contribution[path_id]` (F2), summed+clamped by `_recalculate_total_affiliation()` (F3), called from both the existing `card_resolved` handler and this new `invest()`. This touches existing shipped code — verify the 25-test MVP suite stays green, not just that new tests pass.

`_investment_rate_table` (`INVESTMENT_AFFILIATION_RATE[path]` per GDD F2) sourced from `assets/data/balance.json` under `class_path.investment_rate`, same pattern as `_path_multiplier_table` (ADR-0010 §5). Per-path rates: `{pato_streamer: 0.1, guru_celebryta: 0.2, ekspert_niszowy: 0.125, biznesmen_contentu: 0.02}` (GDD Formulas F2).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: 4-path multiplier table (this story only needs `card_contribution`/tier data to exist for whichever paths are registered)
- Story 005: Invest button UI, disabled-state visual rendering (this story implements the system-level gate only; UI reads `get_affiliation`/gate state)

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (gate rejection)**:
  - Given: `card_contribution[path] == 0`
  - When: `invest(path, resource, amount)` is called
  - Then: returns `false`, no resource deducted, `investment_contribution[path]` unchanged
  - Edge cases: `card_contribution` exactly `0.0` vs a tiny positive epsilon

- **AC-2 (gate satisfied, successful invest)**:
  - Given: `card_contribution[path] > 0`, sufficient resource
  - When: `invest()` called with a valid amount
  - Then: resource deducted, `investment_contribution[path]` increases by `amount * rate`
  - Edge cases: amount = 0 (should be a no-op, not an error)

- **AC-3 (per-path rate independence)**:
  - Given: identical 200-unit spend applied to all 4 paths (each gate-satisfied)
  - When: each `invest()` resolves
  - Then: each path's gain matches its own rate exactly — no shared/global rate leakage
  - Edge cases: N/A

- **AC-4 (F3 clamp at 100)**:
  - Given: total affiliation already 100.0
  - When: further investment attempted
  - Then: resource deducted (per Edge Cases' "at-100 is defensive, not blocked" pattern), affiliation stays 100.0
  - Edge cases: card_contribution alone already at CARD_CONTRIBUTION_MAX (60.0), investment pushes to exactly 100.0 boundary

- **AC-5 (insufficient resource)**:
  - Given: player cannot afford the resource cost
  - When: `invest()` called
  - Then: returns `false`, no deduction, no affiliation change

- **AC-6 (regression)**: existing `class_path_core_test.gd` 25 tests pass unchanged after the F1/F2 split refactor

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/class-path/class_path_investment_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (not a hard blocker — investment logic is path-agnostic — but sequencing after 001 avoids re-touching `_recalculate_affiliation()` twice)
- Unlocks: Story 005 (UI needs a working gate to render disabled/enabled state against)
