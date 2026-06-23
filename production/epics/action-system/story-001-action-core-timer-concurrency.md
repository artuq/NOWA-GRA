# Story 001: ActionSystem Core — Timer, Single-Concurrency & Progress

> **Epic**: Action System
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/action-system.md`
**Requirement**: `TR-act-001`

**ADR Governing Implementation**: ADR-0004: Action System timer and single-concurrency enforcement
**ADR Decision Summary**: A single `Timer` node (one_shot, child of the `ActionSystem` Autoload) plus a `current_action_id: StringName` field that is `&""` when idle. `start_action()` returns `false` if one is already running; `get_progress()` guards divide-by-zero; `_on_action_timeout()` resets state and emits `action_completed`.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: `Timer` is a stable pre-4.3 API; no 4.4–4.6 breaking change touches it (ADR-0004 Engine Compatibility). No post-cutoff APIs. No verification required.

**Control Manifest Rules (Core layer)**:
- Required: Action timing uses a single `Timer` node (child of `ActionSystem` Autoload, `one_shot = true`), guarded by `current_action_id: StringName` (`start_action()` returns `false` if one is already running) — source: ADR-0004
- Required: `get_progress()` must guard divide-by-zero — return `0.0` if `current_action_id == &""` or `wait_time <= 0.0` — source: ADR-0004
- Forbidden: Never use per-action `Timer` nodes or a manual `_process()` countdown — the single shared `Timer` + state guard is sufficient — source: ADR-0004

---

## Acceptance Criteria

*From GDD `design/gdd/action-system.md` (State transitions, Single-concurrency rule, get_progress validation), scoped to this story:*

- [ ] GIVEN `idle` (`current_action_id == &""`), WHEN `start_action(id)` is called for a known action, THEN it returns `true`, `current_action_id` becomes `id`, and the `Timer` starts with that action's duration.
- [ ] GIVEN `idle`, WHEN `start_action(id)` is called for an `id` not present in `ACTION_DURATIONS`, THEN it returns `false`, `current_action_id` remains `&""`, and the `Timer` is not started or mutated (no crash from indexing a missing key).
- [ ] GIVEN an action is `running`, WHEN `start_action(any_id)` is called again (same or different), THEN it returns `false`, `current_action_id` is unchanged, and the running `Timer` is not restarted or interrupted.
- [ ] GIVEN `running`, WHEN the `Timer`'s duration elapses, THEN `_on_action_timeout()` runs, `current_action_id` resets to `&""`, and `action_completed` is emitted exactly once carrying the completed `action_id`.
- [ ] GIVEN `idle` (`current_action_id == &""`), WHEN `get_progress()` is called, THEN it returns exactly `0.0` (divide-by-zero guard — no `Timer` access that could divide by a zero `wait_time`).
- [ ] GIVEN `running`, WHEN `get_progress()` is polled near the start, midpoint, and just before completion, THEN it returns approximately `0.0`, `0.5`, and `1.0` respectively, computed as `1.0 - (time_left / wait_time)`.
- [ ] GIVEN an action has just reset to `idle`, WHEN `start_action(same_id)` is called immediately, THEN it is accepted (returns `true`) — no cooldown between actions.

---

## Implementation Notes

*Derived from ADR-0004 Decision + Implementation Guidelines:*

Implement the `ActionSystem` Autoload (registered after `ResourceManager` in boot order per ADR-0003 — it does not call ResourceManager in THIS story, but Story 002 will, so the boot order must already be correct).

```gdscript
var current_action_id: StringName = &""
var _timer: Timer

func _ready() -> void:
    _timer = Timer.new()
    _timer.one_shot = true
    _timer.timeout.connect(_on_action_timeout)
    add_child(_timer)

func start_action(action_id: StringName) -> bool:
    if current_action_id != &"":
        return false  # single-concurrency: reject if one is already running
    if not ACTION_DURATIONS.has(action_id):
        return false  # unknown action_id: reject, no Timer mutation, no crash
    current_action_id = action_id
    _timer.wait_time = ACTION_DURATIONS[action_id]
    _timer.start()
    return true

func get_progress() -> float:
    if current_action_id == &"" or _timer.wait_time <= 0.0:
        return 0.0
    return 1.0 - (_timer.time_left / _timer.wait_time)
```

`ACTION_DURATIONS` is the per-action duration lookup (Nagraj vloga 6s / Zrób dramę 9s / Przeproś 4s) — defined as a typed const lookup keyed by `action_id`. The *reward* table and the reward-write logic are **Story 002**, not here; in this story `_on_action_timeout()` only resets `current_action_id` and emits `action_completed` with the bare `action_id` (Story 002 extends `_on_action_timeout()` to scale + write rewards and enrich the payload).

**Testing note**: `get_progress()` mid-values are time-dependent — drive the Timer deterministically in tests (e.g. set `wait_time` then manually set `time_left`, or use GdUnit4's scene-runner frame stepping) rather than `await`-ing real seconds, to keep tests deterministic per `coding-standards.md`.

---

## Out of Scope

*Handled by neighbouring stories / other epics — do not implement here:*

- Story 002: the reward table, Morale-multiplier scaling, and the `ResourceManager.apply_delta()` write on resolution.
- Action UI epic: progress-bar rendering and disabling action controls during `running` (this story only enforces the backend rejection via `start_action()` returning `false`).
- Offline Progress System: resuming a mid-flight action across app restarts — explicitly out of scope (ADR-0004; `current_action_id` simply resets to idle on launch).

---

## QA Test Cases

*Written by qa-lead (QL-STORY-READY gate, on opus). The developer implements against these.*

- **AC-1 (start from idle)**: 
  - Given: fresh ActionSystem, `current_action_id == &""`
  - When: `start_action(&"nagraj_vloga")`
  - Then: returns `true`; `current_action_id == &"nagraj_vloga"`; `_timer.wait_time == 6.0`; timer is running
- **AC-1b (unknown action_id rejected)**:
  - Given: fresh ActionSystem, `current_action_id == &""`
  - When: `start_action(&"does_not_exist")`
  - Then: returns `false`; `current_action_id` remains `&""`; `_timer` is not started (no crash from indexing a missing key)
- **AC-2 (single-concurrency rejection)**:
  - Given: an action is running (`current_action_id != &""`)
  - When: `start_action(&"zrob_drame")` (and separately, `start_action` with the SAME id)
  - Then: both return `false`; `current_action_id` unchanged; `_timer.time_left` not reset
- **AC-3 (completion resets + emits)**:
  - Given: a running action
  - When: the timer times out (`_on_action_timeout()` invoked)
  - Then: `current_action_id == &""`; `action_completed` emitted exactly once with the completed `action_id`
  - Edge: confirm signal fires exactly once, not zero or twice
- **AC-4 (progress idle guard)**:
  - Given: `current_action_id == &""`
  - When: `get_progress()`
  - Then: returns exactly `0.0`; no divide-by-zero error even if `_timer.wait_time` is 0
- **AC-5 (progress mid-run)**:
  - Given: running action, `wait_time = 6.0`
  - When: `time_left` is 6.0 / 3.0 / ~0.0 (driven deterministically)
  - Then: `get_progress()` returns ~0.0 / 0.5 / ~1.0 (`is_equal_approx`)
- **AC-6 (no cooldown)**:
  - Given: an action just completed (`current_action_id == &""`)
  - When: `start_action(same_id)` immediately
  - Then: returns `true` (accepted)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/action_system/action_system_timer_concurrency_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/unit/action_system/action_system_timer_concurrency_test.gd`, 8/8 passing (verified via `addons/gdUnit4/runtest.sh`, 2026-06-23)

---

## Dependencies

- Depends on: ADR-0001 (ActionSystem Autoload interface) and ADR-0003 (boot order) — both Accepted. No story dependency (this is the Action System epic's first story).
- Unlocks: Story 002 (reward resolution extends `_on_action_timeout()`).

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 7/7 passing (none deferred)
**Deviations**: 2 advisory, already logged in `docs/tech-debt-register.md` — (1) `Timer.time_left` is read-only in Godot 4.6.x, AC-5's test drives the real Timer for ~0.6s instead of setting `time_left` directly; (2) `GdUnitSignalAssert.is_count()` doesn't exist in real GdUnit4 v6.2.0-rc1, signal-count test uses a manual counter callable instead.
**Test Evidence**: Logic — `tests/unit/action_system/action_system_timer_concurrency_test.gd`, 8/8 passing (full regression 63/63 passing)
**Code Review**: Complete — `/code-review` APPROVED; LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
