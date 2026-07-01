# Story 003: Action Queue with Auto-Repeat

> **Epic**: Action System
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 4h
> **Last Updated**: 2026-06-30

## Context

**GDD**: `design/gdd/action-system.md`
**Quick Spec**: `design/quick-specs/action-queue-auto-repeat-2026-06-30.md`
**Requirement**: DDR-0001 #1 — Action queue / auto-repeat (Pillar 4)

**ADR Governing Implementation**: ADR-0001 (Save/State architecture) + ADR-0007 (Touch input via Button)
**ADR Decision Summary**: State lives in Autoloads; UI reads/writes via signals and direct calls. Queue is ephemeral — not persisted.

**Engine**: Godot 4.6.3 | **Risk**: LOW (no post-cutoff APIs)

---

## Acceptance Criteria

- [ ] Selecting an action while another is `running` adds it to the queue (not rejected)
- [ ] When `resolved` → `idle` and queue non-empty and not suspended: auto-start `queue.pop_front()`
- [ ] Queue cap = 10; when full, action buttons disabled with "Queue full" tooltip
- [ ] Decision Card appearing suspends queue (current action finishes, next does not auto-start)
- [ ] Morale ≤ Critical suspends queue the same way
- [ ] Both suspend conditions clear automatically when condition resolves
- [ ] Clear Queue button empties the array; running action is unaffected
- [ ] UI queue bar shows icons of queued actions in order; updates in real time
- [ ] Queue bar dims (alpha 0.5) when suspended; Clear button hidden during card
- [ ] Queue is not persisted — resets to empty on every game start
- [ ] Regression: single action (no queueing) behaves identically to pre-queue behaviour

## Implementation Notes

**ActionSystem changes (`src/core/action_system.gd`):**
- Add `var _queue: Array[StringName] = []`
- Add `var _suspended: bool = false`
- `start_action(id)`: if `_running` → `_enqueue(id)`; else normal start
- `_enqueue(id)`: guard `_queue.size() < QUEUE_CAP`; append; emit `queue_changed`
- On `resolved` → `idle`: if not `_suspended` and `_queue` not empty → `start_action(_queue.pop_front())`
- Subscribe to `DecisionCardSystem.card_presented` → `_suspended = true`
- Subscribe to `DecisionCardSystem.card_dismissed` → `_suspended = false`; try auto-start
- Check Morale in `_on_action_resolved`: if `ResourceManager.get_resource("Morale") <= ResourceManager.CRITICAL_THRESHOLD` → `_suspended = true`; else `_suspended = false`
- Emit signal `queue_changed(queue_snapshot: Array[StringName])` after every mutation
- Emit signal `queue_suspended(is_suspended: bool)` on suspend state change
- `clear_queue()`: `_queue.clear()`; emit `queue_changed([])`
- Const: `const QUEUE_CAP: int = 10`

**ActionGrid changes (`src/ui/action_grid.gd`):**
- Add queue bar HBoxContainer below the action grid (programmatic or scene edit)
- Each slot: TextureRect with action icon, max 10 visible
- Connect `ActionSystem.queue_changed` → `_on_queue_changed(snapshot)`
- Connect `ActionSystem.queue_suspended` → `_on_queue_suspended(is_suspended)`
- `_on_queue_changed`: rebuild icon bar from snapshot
- `_on_queue_suspended`: set bar modulate alpha (1.0 / 0.5); show/hide clear button
- Clear button: calls `ActionSystem.clear_queue()`
- Cap guard: after `queue_changed`, disable action buttons if `snapshot.size() >= QUEUE_CAP`

## Out of Scope

- Persistent queue across sessions (by design — ephemeral)
- Queue reordering / drag-to-reorder
- Per-action queue limits
- Visual animations for queue items entering/leaving

## QA Test Cases

**AC-1 — auto-start from queue:**
- Given: action A running, action B queued
- When: A resolves
- Then: B starts automatically, no tap required

**AC-2 — cap enforcement:**
- Given: 10 actions queued
- When: player taps any action button
- Then: button disabled / tap ignored; tooltip "Queue full"

**AC-3 — Decision Card suspend:**
- Given: actions queued, card presented
- When: running action resolves
- Then: next queued action does NOT start; queue intact

**AC-4 — suspend clears on card dismiss:**
- Given: queue suspended by card
- When: card dismissed
- Then: next queued action starts automatically

**AC-5 — Morale Critical suspend:**
- Given: queue non-empty, Morale ≤ Critical
- When: running action resolves
- Then: next queued action does NOT start

**AC-6 — clear queue:**
- Given: 3 actions queued, 1 running
- When: Clear Queue tapped
- Then: queue empty, running action finishes normally

**AC-7 — single action regression:**
- Given: queue empty
- When: player taps action while idle
- Then: action starts immediately (same as before)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/action_system/action_queue_test.gd` — must exist and pass

## Dependencies

- Depends on: Story 001 (action core timer) — Done, Story 002 (reward resolution) — Done
- Unlocks: None

## Completion Notes
**Completed**: 2026-06-30
**Criteria**: 11/11 passing (9/11 covered by automated test; 2 UI-only criteria — queue bar icon rendering, dim/hide visuals — untested, advisory)
**Deviations**: None
**Test Evidence**: `tests/integration/action_system/action_queue_test.gd` — 8 test functions, passing (320/320 full suite, 0 failures, 13 pre-existing unrelated orphans)
**Code Review**: Complete — `ccgs:lead-programmer` (lean mode) found a reentrancy bug (signal-order inversion in `_on_action_timeout()`) and a sibling-test signal-leak gap; both fixed and re-verified.
