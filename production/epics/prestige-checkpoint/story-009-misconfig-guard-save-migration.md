# Story 009: Misconfiguration Guard + Save Migration

> **Epic**: Prestige/Checkpoint System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-15


## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-005`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §6 (Save/Load — `restore_state()`)
**ADR Decision Summary**: `PrestigeSystem.restore_state(data: Dictionary)` follows the same default-on-missing-key pattern as `OnboardingGate`/`SettingsSystem`/Class Path's own migration (ADR-0003 boot protocol) — no special-case migration code.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: `restore_state(data: Dictionary)` boot protocol (ADR-0003)
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD §Misconfiguration Guard + §Persistence — Save Migration, scoped to this story:*

- [ ] GIVEN `BASE_INCREMENT[META_REACH_MULT]` is misconfigured to `-0.02` (or `0`), WHEN F1 computes a Tier-3 grant, THEN it clamps to `max(0.0, computed)=0.0`, no exception, a config warning is logged
- [ ] GIVEN such a clamped zero grant, THEN the running total is unchanged — Core Rule 5's never-reduced guarantee holds even under misconfiguration
- [ ] GIVEN a save predates this system (no `prestige` key), WHEN `PrestigeSystem` initializes, THEN `era_count` defaults to `0`, all four `META_BONUS_total[type]` default to `0.0`, no meta-persistent burnout flags exist — same default-on-missing-key pattern as `OnboardingGate`/`SettingsSystem`/Class Path migration

---

## Implementation Notes

The misconfiguration guard wraps `PrestigeFormulas.grant_magnitude()`'s output (Story 003) — add a `maxf(0.0, computed)` clamp plus a `push_warning()` when the pre-clamp value would have been negative or the config value itself is non-positive. This is defensive, not expected to trigger in normal balance tuning — it exists so a bad `balance.json` edit degrades gracefully instead of corrupting a permanent, never-reduced total.

```gdscript
func restore_state(data: Dictionary) -> void:
    era_count = int(data.get("era_count", 0))
    var totals_in: Dictionary = data.get("meta_bonus_totals", {})
    for key: String in totals_in:
        meta_bonus_totals[StringName(key)] = float(totals_in[key])
    # missing meta_bonus_totals key -> meta_bonus_totals stays at its
    # zero-initialized default — no special migration branch needed
```

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: the grant formula itself (this story only adds the defensive clamp around its output)

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (misconfigured negative BASE_INCREMENT)**:
  - Given: `BASE_INCREMENT[META_REACH_MULT] = -0.02`
  - When: `grant_magnitude()` computes a Tier-3 grant
  - Then: returns `0.0`, no exception thrown, a warning is logged (assert via a log-capture or warning-count check)
  - Edge cases: `BASE_INCREMENT = 0` (should also clamp to 0.0, not divide-by-zero or similar)

- **AC-2 (clamped zero grant doesn't reduce total)**:
  - Given: a nonzero pre-existing total, then a misconfigured zero grant applied
  - When: `apply_stacking_and_cap()` runs with the zero grant
  - Then: total unchanged (not reduced — Core Rule 5)

- **AC-3 (save migration, missing prestige key)**:
  - Given: a save Dictionary with no `prestige`/`era_count`/`meta_bonus_totals` keys
  - When: `PrestigeSystem.restore_state({})` runs
  - Then: `era_count == 0`, all 4 totals `== 0.0`, no meta-persistent burnout flags set
  - Edge cases: partial data (e.g. `era_count` present but `meta_bonus_totals` missing) — each field defaults independently

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/prestige/prestige_persistence_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (wraps its output), Story 001 (restore_state is part of the orchestration skeleton)
- Unlocks: None

## Completion Notes
**Completed**: 2026-07-15
**Criteria**: 3/3 passing
**Deviations**: None remaining (1 test-quality gap found in review, fixed and reverified before close)
**Test Evidence**: Logic — `tests/unit/prestige/prestige_persistence_test.gd` (13 tests)
**Code Review**: Complete — APPROVED
