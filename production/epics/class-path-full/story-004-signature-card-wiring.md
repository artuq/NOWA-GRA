# Story 004: Signature Card Wiring (Tier 5)

> **Epic**: Class Path System (Full)
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-13

## Context

**GDD**: `design/gdd/class-path-system.md`
**Requirement**: `TR-cps-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 §10 (Signature Card Wiring)
**ADR Decision Summary**: Signature cards use an additive `trigger_condition` grammar entry on `DecisionCardSystem` (`"class_path_tier:{path_id}:{min_tier}"`) — pull model, no pool-mutation API, no new dependency direction. `_build_eligible_pool()` already re-evaluates `trigger_condition` on every pool build.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: n/a — extends `DecisionCardSystem`'s existing `trigger_condition` mechanism, not a new pattern
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD `design/gdd/class-path-system.md`, scoped to this story:*

- [ ] GIVEN a path's affiliation first reaches `100.0` this era, WHEN its tier resolves to 5, THEN `ClassPathSystem` emits `signature_card_unlocked(card_id)` exactly once and `DecisionCardSystem`'s pool contains that card afterward
- [ ] GIVEN era reset fires while a path is at Tier 5, WHEN `reset_era_state()` completes, THEN `signature_card_removed(card_id)` has been emitted and the card is no longer in the pool
- [ ] Each of the 4 paths' signature cards (`viral_moment`, `brand_deal_of_the_century`, `kult_niszowy`, `ipo_influencera`) exists in `CardContentDatabase` with `trigger_condition = "class_path_tier:{path_id}:5"`
- [ ] `_trigger_condition_met()` correctly parses and evaluates the new grammar entry against `ClassPathSystem.get_tier(path_id) >= min_tier`

---

## Implementation Notes

*Derived from ADR-0010 §10:*

```gdscript
func _trigger_condition_met(condition: String) -> bool:
    if condition == "always":
        return true
    if condition.begins_with("class_path_tier:"):
        var parts := condition.split(":")  # "class_path_tier:{path_id}:{min_tier}"
        return ClassPathSystem.get_tier(StringName(parts[1])) >= int(parts[2])
    return false
```

No pool-mutation call, no new signal consumer — `_build_eligible_pool()` already re-evaluates `trigger_condition` on every pool build (existing code), so the card becomes eligible the moment tier 5 is reached and ineligible again after era reset drops the tier back to 0, with zero new wiring beyond the grammar entry itself. `signature_card_unlocked`/`signature_card_removed` (GDD Signals table, already defined but unused by shipped code) remain UI-only notification signals — `DecisionCardSystem` does not subscribe to them; they exist purely so the HUD/Class Path Panel can show an unlock toast.

**Performance**: no impact — `_trigger_condition_met()` runs once per card per pool build (existing cost shape, ~16 cards today), the new `"class_path_tier:..."` branch is a single string split + one `get_tier()` Dictionary lookup, negligible at this scale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001: the Tier 5 multiplier-table entries themselves (this story only wires the card, not the tier's other bonus effects)
- Signature card flavor text / narrative content — narrative-director task, not architecture

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (card appears at Tier 5)**:
  - Given: a path's affiliation reaches 100.0
  - When: tier resolves to 5
  - Then: `signature_card_unlocked(card_id)` emitted exactly once; `_build_eligible_pool()`'s output includes that card
  - Edge cases: two paths reaching Tier 5 in the same update — both signature cards should appear, each exactly once

- **AC-2 (card disappears on era reset)**:
  - Given: a path at Tier 5 with its signature card in the pool
  - When: `reset_era_state()` completes
  - Then: `signature_card_removed(card_id)` emitted; `_build_eligible_pool()`'s output no longer includes the card
  - Edge cases: reset when no path is at Tier 5 (should be a no-op, no spurious removal signal)

- **AC-3 (grammar parsing)**:
  - Given: `trigger_condition = "class_path_tier:pato_streamer:5"`, `ClassPathSystem.get_tier("pato_streamer")` returns 4
  - When: `_trigger_condition_met()` evaluates it
  - Then: returns `false`
  - Edge cases: exactly at threshold (`get_tier` returns 5 → `true`); malformed condition string → `false`, not a crash

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/class-path/class_path_signature_card_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (needs all 4 paths + Tier 5 reachable to exist)
- Unlocks: None

## Completion Notes
**Completed**: 2026-07-13
**Criteria**: 4/4 passing
**Deviations**: ADVISORY — 2 pre-existing test suites fixed for the 12→16 card count. A BLOCKING int()-parsing bug and a self-introduced reset_era_state() regression were found and fixed during code review — not remaining deviations.
**Test Evidence**: Integration — `tests/integration/class-path/class_path_signature_card_test.gd` (21 tests, all passing)
**Code Review**: Complete — APPROVED
