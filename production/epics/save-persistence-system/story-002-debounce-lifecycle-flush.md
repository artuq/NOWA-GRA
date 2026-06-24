# Story 002: Debounce/Coalescing & Mobile Lifecycle Flush

> **Epic**: Save/Persistence System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: S (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/save-persistence-system.md`
**Requirement**: `TR-save-001`
*(No dedicated sub-ID exists for the debounce/coalescing mechanism specifically in `docs/architecture/tr-registry.yaml` — it currently only registers the general save-I/O-interface requirement. This is the same registry hygiene gap pattern flagged for History Flag System's Story 002; recommend registering a dedicated `TR-save-004` via `/architecture-review` at some point, not blocking. Requirement text for `TR-save-001` lives in `tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0002: Save file format and atomic write (primary — debounce sits on top of `save_now()`); ADR-0001: Autoload singleton vs. event bus (secondary)
**ADR Decision Summary**: `mark_dirty()` starts/resets a 2-second trailing-edge debounce `Timer`; when it fires, `save_now()` (Story 001) is called. A mobile lifecycle signal (app backgrounding/suspension) bypasses the remaining debounce window and calls `save_now()` immediately.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Uses a standard `Timer` node (one_shot, restartable) — no post-cutoff API. The mobile lifecycle signal is `Node.NOTIFICATION_APPLICATION_PAUSED` (or `get_tree().get_root().connect("close_requested", ...)` is NOT the right hook for backgrounding — confirm `NOTIFICATION_APPLICATION_PAUSED` via `_notification()` is the correct Godot 4.6 signal for Android backgrounding before implementing; this is the one engine-risk item in this story, worth a quick doc check since it's the first story to need an OS lifecycle hook).

**Control Manifest Rules (Foundation layer)**:
- Required: Save format/atomic write rules from Story 001 apply unchanged — this story only adds timing logic around the existing `save_now()` call, source: ADR-0002
- Required: Implement every Core/Foundation module as a Godot Autoload singleton — source: ADR-0001 (already satisfied by Story 001; this story only adds methods/a Timer child to the existing `SaveSystem` Autoload)

---

## Acceptance Criteria

*From GDD `design/gdd/save-persistence-system.md` § Acceptance Criteria, scoped to this story:*

- [ ] GIVEN `ready` and idle, WHEN one trigger fires (`mark_dirty()`) and nothing else for 2s, THEN exactly one save is written.
- [ ] GIVEN a trigger has fired and the 2s timer is running, WHEN a second trigger fires at 1.0s into the window, THEN only one save is written, 2s after the *second* (latest) trigger.
- [ ] GIVEN multiple triggers within one debounce window leave peer systems in different states, WHEN the trailing-edge save executes, THEN the written file reflects the state at the *last* trigger, not an earlier one.
- [ ] GIVEN the debounce timer is at 1.9s, WHEN a new trigger fires at that moment, THEN the timer resets to 0, save fires 2 full seconds after this newest event.
- [ ] GIVEN `ready` with no triggers, WHEN any amount of time passes, THEN no write occurs, state remains `ready`.
- [ ] GIVEN a debounced save is pending, WHEN the OS signals backgrounding/suspension, THEN the save fires immediately, bypassing the remaining debounce window.

---

## Implementation Notes

*Derived from ADR-0002 Implementation Guidelines + GDD Detailed Design § Core Rules (rule 5, mobile lifecycle flush) and Tuning Knobs (`save_debounce_interval_sec`):*

```gdscript
# Added to SaveSystem (Story 001's Autoload)

const _DEBOUNCE_INTERVAL_SEC: float = 2.0  # Tuning Knob: save_debounce_interval_sec, safe range 1-5

var _debounce_timer: Timer

func _ready() -> void:
    # ...Story 001's existing _ready() body...
    _debounce_timer = Timer.new()
    _debounce_timer.one_shot = true
    _debounce_timer.wait_time = _DEBOUNCE_INTERVAL_SEC
    _debounce_timer.timeout.connect(save_now)
    add_child(_debounce_timer)

func mark_dirty() -> void:
    _debounce_timer.stop()
    _debounce_timer.start()  # restarting resets wait_time countdown to full duration — trailing-edge

func _notification(what: int) -> void:
    if what == NOTIFICATION_APPLICATION_PAUSED:
        if not _debounce_timer.is_stopped():
            _debounce_timer.stop()
            save_now()
```

- **Trailing-edge semantics**: `mark_dirty()` always restarts the timer rather than letting an existing one run to completion — this single restart-on-call behavior is what produces both "multiple triggers in one window → exactly one save" and "timer resets on a trigger at 1.9s" without separate code paths.
- **Read `_DEBOUNCE_INTERVAL_SEC` from this named constant**, never a bare `2.0`/`2` literal elsewhere in the algorithm or tests, mirroring the same constants-not-literals rule already applied in `action_system.gd`/`history_flag_manager.gd`.
- **Mobile lifecycle flush only fires if a save is actually pending** (`not _debounce_timer.is_stopped()`) — backgrounding with no dirty state pending must NOT trigger a spurious save.
- **Testing note**: per the GDD's own testing guidance and this codebase's established pattern (`action_system_timer_concurrency_test.gd`'s AC-5), debounce timing tests should drive the real `Timer` for short, bounded real-time waits (`await get_tree().create_timer(...).timeout`) rather than attempting to fake `Timer.time_left`/`wait_time` directly — `Timer.time_left` is read-only in Godot 4.6.x (already-logged tech debt from ActionSystem's Story 001). Keep waits bounded to a few seconds total, not flaky.
- **`NOTIFICATION_APPLICATION_PAUSED` cannot be triggered for real in a headless test** — simulate by calling `_notification(NOTIFICATION_APPLICATION_PAUSED)` directly on the Autoload instance (a legitimate GDScript pattern — `_notification` is just a regular method despite its underscore-prefix naming convention).

---

## Out of Scope

*Handled by Story 001 / future epics — do not implement here:*

- Story 001: `save_now()`/`load_save()`'s atomic write, schema fallback, and state-transition mechanics — this story only adds timing/triggering logic on top.
- Any UI/visual indication of "saving" state — not in this epic's GDD scope (Visual/Audio Requirements: None).
- Desktop/PC-specific lifecycle signals (e.g., window close) — this story targets the mobile lifecycle flush specifically, per the GDD's stated player fantasy ("my progress is safe" on a mobile device that gets backgrounded routinely).

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-24.md` (Automated Tests Required § 3-2 and Manual QA Checklist), split to this story's scope.*

- **AC-1**: single trigger, isolated
  - Given: `ready`, idle
  - When: one `mark_dirty()` call, nothing else for `_DEBOUNCE_INTERVAL_SEC`
  - Then: exactly one save written
  - Edge cases: confirm via a save-count spy/counter, not just "a save happened"

- **AC-2**: two triggers coalesce, trailing-edge
  - Given: a trigger has fired, timer running
  - When: a second `mark_dirty()` fires at ~1.0s into the window
  - Then: only one save written, timed `_DEBOUNCE_INTERVAL_SEC` after the *second* trigger, not the first
  - Edge cases: assert the save count is exactly 1, and that it lands after the expected total elapsed time from test start

- **AC-3**: trailing-edge reflects latest state
  - Given: multiple triggers within one window, with peer systems' state differing between triggers
  - When: the trailing-edge save executes
  - Then: written file reflects the state at the *last* trigger
  - Edge cases: change a `ResourceManager` value between two triggers and confirm the saved value matches the post-second-trigger state, not the first

- **AC-4**: timer reset near the boundary
  - Given: debounce timer at 1.9s
  - When: a new trigger fires at that moment
  - Then: timer resets to 0, save fires 2 full seconds after this newest trigger
  - Edge cases: this is a real-time-bounded test (~2s total) per the Implementation Notes testing guidance — not flaky if bounded correctly

- **AC-5**: no triggers, no write
  - Given: `ready`, no triggers
  - When: any amount of time passes
  - Then: no write occurs, state remains `ready`
  - Edge cases: wait at least `_DEBOUNCE_INTERVAL_SEC` with zero triggers and confirm zero saves

- **AC-6**: mobile lifecycle flush
  - Given: a debounced save is pending (timer running, not yet fired)
  - When: `_notification(NOTIFICATION_APPLICATION_PAUSED)` is invoked directly (headless simulation)
  - Then: save fires immediately, bypassing the remaining debounce window
  - Edge cases: also confirm backgrounding with NO pending save does not trigger a spurious write

**Manual QA note** (per `qa-plan-sprint-3-2026-06-24.md`): the mobile lifecycle flush's real OS-level trigger (actually backgrounding the app on a device/emulator) cannot be exercised by GdUnit4 headlessly — AC-6 above tests the code path via direct `_notification()` invocation. A manual walkthrough on a real Android target remains advisable before this story is fully trusted in production, per the QA plan's Manual QA Checklist, but is not a blocking gate for `/story-done`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/save_persistence_system/save_debounce_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Core Save/Load) must be DONE; this story calls Story 001's `save_now()` on a timer.
- Unlocks: None within this epic. Downstream: Offline Progress System (will eventually trigger saves too, once it exists).

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 6/6 passing (none deferred)
**Deviations**: 1 advisory, logged as tech debt — ADR-0002's Key Interfaces section specifies a `save_flushed` signal on successful save; the implementation omits it. Only matters once a future consumer (e.g., a "saving..." UI indicator) needs it.
**Test Evidence**: Integration — `tests/integration/save_persistence_system/save_debounce_test.gd`, 8/8 passing (full regression 111/111 passing)
**Code Review**: Complete — `/code-review` APPROVED; LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
