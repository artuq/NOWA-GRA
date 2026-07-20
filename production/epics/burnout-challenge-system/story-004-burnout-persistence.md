# Story 004: BurnoutSystem Persistence

> **Epic**: Burnout & Challenge System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-20


## Context

**GDD**: `design/quick-specs/final-burnout-2026-07-01.md`
**Requirement**: `TR-pcs-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013 (`BurnoutSystem.restore_state()`/`serialize_state()`) + ADR-0003 (boot protocol)
**ADR Decision Summary**: `BurnoutSystem` persists `_card_pending` only — `_cringe_sustained_seconds` deliberately does NOT persist (resets to `0.0` on every boot, "no surprise burnout on app open," Pillar 4). This is a narrower persistence surface than the quick-spec originally assumed, since `era_count`/`_deferred_this_era` moved to `PrestigeSystem` (ADR-0012).

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff. Same `restore_state(data: Dictionary)` pattern as every other Autoload in this codebase.

**Control Manifest Rules (this layer)**:
- Required: `restore_state(data: Dictionary)` boot protocol (ADR-0003)
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From `design/quick-specs/final-burnout-2026-07-01.md` §6, scoped to this story per ADR-0013's corrected persistence surface:*

- [ ] GIVEN `_card_pending == true` at save time, WHEN `serialize_state()` runs and a fresh `BurnoutSystem.restore_state()` is called against that output, THEN the restored `_card_pending == true`
- [ ] GIVEN a save predates this system (empty Dictionary or missing `_card_pending` key), WHEN `restore_state({})` runs, THEN `_card_pending` defaults to `false` — same default-on-missing-key pattern as every other Autoload in this project (ADR-0012 §6 precedent)
- [ ] GIVEN any value of `_cringe_sustained_seconds` at save time, WHEN `restore_state()` runs (regardless of what's in the input Dictionary), THEN `_cringe_sustained_seconds` is always `0.0` after restore — this field is intentionally excluded from persistence, not merely defaulted
- [ ] GIVEN `_card_pending` was persisted as `true` and the app restarts, THEN the Burnout Card must re-present on the next available frame — this AC covers the persisted-flag contract only; the actual boot-time re-injection trigger wiring is covered by the trigger-timer's own logic (Story 001/002) reacting to `_card_pending` already being `true` at boot, not new code in this story

---

## Implementation Notes

*Derived from ADR-0013's persistence pseudocode (already fully specified — implement as written):*

```gdscript
func restore_state(data: Dictionary) -> void:
	_card_pending = bool(data.get("_card_pending", false))
	# _cringe_sustained_seconds intentionally NOT restored -- resets to 0.0,
	# per the quick-spec's own Pillar 4 "no surprise burnout on app open" rule.

func serialize_state() -> Dictionary:
	return {"_card_pending": _card_pending}
```

This closes the deferred half of prestige-checkpoint's `story-008-transition-atomicity.md` Scope Note (2026-07-15), which explicitly punted "card re-presentation on boot" pending this ADR/epic. Once this story ships, a follow-up test could be added to Story 008's atomicity suite proving the full kill-mid-choice → restart → card re-presents flow — not required by this story's own ACs (which only cover the flag's save/restore contract in isolation), but worth flagging to the team as the natural next verification step.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The actual re-injection call when `_card_pending` is found `true` at boot — this is Story 002's `_try_inject_burnout_card()` logic, unmodified; this story only ensures the flag survives save/restore correctly so that logic has accurate state to act on
- prestige-checkpoint Story 008's own atomicity test suite — not modified by this story, though this story's shipped code is a prerequisite for a future follow-up there

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (round-trip persistence of true)**:
  - Given: `_card_pending = true`
  - When: `serialize_state()` then a fresh instance's `restore_state()` on that output
  - Then: restored `_card_pending == true`

- **AC-2 (missing-key default)**:
  - Given: `restore_state({})`
  - When: called on a fresh instance
  - Then: `_card_pending == false`
  - Edge cases: `restore_state({"_card_pending": true})` on a fresh instance still restores `true` correctly (not just the missing-key path)

- **AC-3 (_cringe_sustained_seconds never persists)**:
  - Given: `_cringe_sustained_seconds` set to a nonzero value, `serialize_state()` called
  - When: the serialized Dictionary is inspected
  - Then: it contains no `_cringe_sustained_seconds` key at all (not just a zeroed one) — confirms deliberate exclusion, not accidental omission
  - Edge cases: `restore_state()` called with a Dictionary that DOES contain a stray `_cringe_sustained_seconds` key (e.g. hand-edited save file) — must still ignore it and leave the field at `0.0`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/burnout/burnout_persistence_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (defines the `_cringe_sustained_seconds`/`_card_pending` fields this story persists)
- Unlocks: None (last BurnoutSystem story in this epic)

---

## Completion Notes
**Completed**: 2026-07-20
**Criteria**: 4/4 passing (AC-4's flag-contract half proven by AC-1's test; the re-presentation trigger itself is correctly out of this story's scope, per this story's own Implementation Notes)
**Deviations**: None — implementation is a literal match to ADR-0013's persistence pseudocode
**Test Evidence**: `tests/unit/burnout/burnout_persistence_test.gd` — 5/5 passing, 0 errors, 0 orphans (verified live via gdUnit4 headless run)
**Code Review**: Complete — godot-gdscript-specialist (CLEAN) + qa-tester (TESTABLE, no gaps), both APPROVED with zero required changes
