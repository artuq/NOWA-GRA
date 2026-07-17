# Story 001: Trigger Detection — Sustained Cringe Timer + Warning Countdown

> **Epic**: Burnout & Challenge System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-17


## Context

**GDD**: `design/quick-specs/final-burnout-2026-07-01.md`
**Requirement**: `TR-pcs-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0013 (BurnoutSystem/ChallengeSystem — Trigger Detection, Card Injection, and Challenge Selection)
**ADR Decision Summary**: `BurnoutSystem` is a new Autoload that owns exactly the trigger-detection state (`_cringe_sustained_seconds`, `_card_pending`) — never `era_count`/resets/grants, which stay on `PrestigeSystem` (ADR-0012).

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: `_process(delta)` per-frame reads only — same class of cost as `ActionSystem`'s existing progress polling (ADR-0004/ADR-0007 precedent). No post-cutoff API concerns.

**Control Manifest Rules (this layer)**:
- Required: `restore_state(data: Dictionary)` boot protocol (ADR-0003) — this story's persisted fields feed Story 004
- Forbidden: n/a
- Guardrail: `_process(delta)` must be O(1) — one `ResourceManager.get_resource()` call, one comparison, occasional signal emit; no allocation

---

## Acceptance Criteria

*From `design/quick-specs/final-burnout-2026-07-01.md` §1-2 (Trigger, Warning State), scoped to this story:*

- [x] GIVEN Cringe is at 100.0 for `delta` seconds of live play, THEN `_cringe_sustained_seconds` increments by exactly `delta` each frame
- [x] GIVEN Cringe drops below 100.0, THEN `_cringe_sustained_seconds` resets to `0.0` on the same frame the drop is observed
- [x] GIVEN `_cringe_sustained_seconds >= BURNOUT_WARNING_THRESHOLD` (180.0s default), THEN `burnout_warning_changed(true, seconds_remaining)` emits every frame while the warning is active, with `seconds_remaining = BURNOUT_THRESHOLD - _cringe_sustained_seconds`
- [x] GIVEN the warning is active and Cringe drops below 100.0, THEN `burnout_warning_changed(false, 0.0)` emits exactly once (not every frame after)

---

## Implementation Notes

*Derived from ADR-0013's `BurnoutSystem` pseudocode:*

```gdscript
var _cringe_sustained_seconds: float = 0.0
var _card_pending: bool = false

func _process(delta: float) -> void:
	var cringe: float = ResourceManager.get_resource(&"Cringe")
	if cringe >= 100.0:
		_cringe_sustained_seconds += delta
		if _cringe_sustained_seconds >= BURNOUT_WARNING_THRESHOLD:
			burnout_warning_changed.emit(true, BURNOUT_THRESHOLD - _cringe_sustained_seconds)
		# Card injection trigger (>= BURNOUT_THRESHOLD) is Story 002 — this
		# story stops at detecting the threshold-crossing state, not acting on it.
	else:
		if _cringe_sustained_seconds > 0.0:
			burnout_warning_changed.emit(false, 0.0)
		_cringe_sustained_seconds = 0.0
```

`BURNOUT_THRESHOLD` (300.0s default), `BURNOUT_WARNING_THRESHOLD` (180.0s default) must live in `assets/data/balance.json`, not hardcoded — same convention as every other tuning knob in this codebase (`ResourceFormulas`, `PrestigeFormulas`).

**Offline exclusion (Pillar 4)**: `OfflineProgressSystem.simulate_offline()` must never call into `BurnoutSystem` — the trigger timer only advances during live-play `_process()`. No code change needed in `OfflineProgressSystem` for this story; verify by grep that no cross-call exists (same verification technique `ResourceFormulas`' cross-call test already established).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the actual card injection when the threshold is crossed
- Story 004: `_card_pending`/`_cringe_sustained_seconds` persistence semantics (this story only defines the runtime field, not save/restore)

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (timer increments at Cringe=100)**:
  - Given: `ResourceManager` mocked/set to Cringe=100.0
  - When: `_process(delta)` called with a known `delta`
  - Then: `_cringe_sustained_seconds` increases by exactly `delta`
  - Edge cases: multiple consecutive frames accumulate correctly (no drift)

- **AC-2 (timer resets below 100)**:
  - Given: `_cringe_sustained_seconds` nonzero, Cringe set below 100.0
  - When: `_process(delta)` called
  - Then: `_cringe_sustained_seconds == 0.0` immediately

- **AC-3 (warning signal fires at threshold, every frame while active)**:
  - Given: `_cringe_sustained_seconds` at exactly `BURNOUT_WARNING_THRESHOLD`
  - When: `_process(delta)` called
  - Then: `burnout_warning_changed(true, seconds_remaining)` emitted, `seconds_remaining` matches the formula exactly
  - Edge cases: `seconds_remaining` at the exact moment `BURNOUT_THRESHOLD` is crossed (should be `0.0` or negative-clamped — verify no negative countdown display)

- **AC-4 (warning cancels exactly once)**:
  - Given: warning active, Cringe drops below 100.0
  - When: `_process(delta)` called once, then called again on a subsequent frame
  - Then: `burnout_warning_changed(false, 0.0)` emits on the first call only, not the second (since `_cringe_sustained_seconds` is already `0.0` by then)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/burnout/burnout_trigger_timer_test.gd` — must exist and pass

**Status**: [x] Created and passing

---

## Dependencies

- Depends on: None (first story in this epic)
- Unlocks: Story 002 (card injection reads this story's threshold-crossing state)

## Completion Notes
**Completed**: 2026-07-17
**Criteria**: 4/4 passing
**Deviations**: ADVISORY — process_mode/pause interaction open (logged as tech debt, resolve before Story 002/003); test add_child() technique will need revisiting for Story 003 (logged as tech debt)
**Test Evidence**: Logic — `tests/unit/burnout/burnout_trigger_timer_test.gd` (11 tests)
**Code Review**: Complete — APPROVED
