# Story 004: Running Action Overlay

> **Epic**: Action UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/action-ui.md`
**Requirement**: `TR-aui-001` (progress bar updates every frame via cheap poll, not throttled) plus the GDD's Running Action Overlay / Progress Bar Fill sections
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time; TR-aui-001 is now `covered` per `/architecture-review` 2026-06-24, citing ADR-0004 + ADR-0007)*

**ADR Governing Implementation**: ADR-0007 (primary); ADR-0004 (secondary — `get_progress()`'s polling contract, scoped by ADR-0007 to exactly this zone); ADR-0001 (secondary)
**ADR Decision Summary**: `RunningActionOverlay` is the **sole** `_process()`-using zone in Action UI, gated by `set_process(bool)` toggled on `ActionSystem.action_completed`, with an **explicit initial-state check in `_ready()`** (Control nodes process by default — without this check, the overlay would poll needlessly from scene load until the first completion signal ever fires).

**Engine**: Godot 4.6.3 | **Risk**: MEDIUM (ADR-0007's self-rated risk)
**Engine Notes**: `_process()` toggling via `set_process(bool)` takes effect the *next* frame, not retroactively — confirmed safe by ADR-0007's engine specialist review for this non-mid-frame-critical use case.

**Control Manifest Rules (this layer)**:
- Required: PascalCase class name (`RunningActionOverlay`), snake_case file name
- Forbidden: Any other zone using `_process()` — this is the only zone permitted to (ADR-0007's explicit scoping decision)
- Guardrail: `_process()` must be disabled while idle — verify via the Validation Criteria below, this is the single most important behavior this story implements correctly

---

## Acceptance Criteria

*From GDD `design/gdd/action-ui.md`, scoped to this story:*

**Progress bar fill (rendering, not the math — math is Story 001):**
- [ ] Given elapsed_time=0, duration=D>0, when the first frame renders, fill_ratio=0, no flicker
- [ ] Given 0<elapsed_time<duration, when rendered, the bar fill matches `ActionUIFormatting.fill_ratio()`'s output
- [ ] Given elapsed_time≥duration, when rendered, the bar shows fully filled (clamped)
- [ ] Given running, when successive frames render, the bar updates every frame, not throttled
- [ ] Given the overlay is visible, when rendered, the action name and remaining time are both shown alongside the bar

**State transitions:**
- [ ] Given `running→resolved→idle` transition completes, the overlay hides

**`_process()` discipline (this story's core architectural requirement, per ADR-0007):**
- [ ] `_process()` does not run while `ActionSystem.current_action_id` is empty — including immediately after scene load, not just after the first `action_completed` signal

---

## Implementation Notes

*Derived from ADR-0007's Implementation Guidelines — implement exactly as specified:*

Create `res://scenes/action_screen/running_action_overlay.tscn` (root `Control`, script `running_action_overlay.gd`, `class_name RunningActionOverlay`) as a sibling under the `ActionScreen` root scene.

In `_ready()`:
```gdscript
func _ready() -> void:
    ActionSystem.action_completed.connect(_on_action_completed)
    # Explicit initial-state check -- Control nodes process by default.
    # Without this, the overlay polls needlessly from scene load until the
    # first action_completed signal ever fires (ADR-0007 engine specialist
    # finding, 2026-06-24).
    set_process(not ActionSystem.current_action_id.is_empty())
    visible = not ActionSystem.current_action_id.is_empty()
```

In `_process(_delta)`: call `ActionSystem.get_progress()` and `ActionUIFormatting.fill_ratio()` (or use `get_progress()`'s output directly if it's already a 0.0-1.0 ratio — confirm against `ActionSystem`'s actual return contract before assuming `fill_ratio()` needs a second calculation here; `get_progress()` and `fill_ratio()` may turn out to compute the same clamp, in which case use `get_progress()` directly and treat `fill_ratio()` as the Story 001 test-proven reference implementation, not a second runtime call).

On `_on_action_completed`: `set_process(false)`, `visible = false`. Whoever starts an action (Story 003's `ActionGrid`) is responsible for making this overlay visible and calling `set_process(true)` — per ADR-0007's no-cross-zone-coupling decision, `RunningActionOverlay` does not listen for a "start" event from `ActionGrid` directly; instead, it should connect to whatever signal/state `ActionSystem` exposes for "action started" (check `ActionSystem`'s existing public surface — if no such signal exists yet, that's a real gap to flag, not to silently route around via a cross-zone call to `ActionGrid`).

**Important note for `/dev-story`**: if `ActionSystem` has no "action started" signal (only `action_completed`), this story may need a small `ActionSystem` addition (e.g., emit on `start_action()` success) — check before implementing, and if needed, treat that as a small in-scope addition to `ActionSystem`, not a new story, since it's a one-line signal emission consistent with the system's existing public surface, not a new architectural decision.

**Performance**: the only zone in Action UI using `_process()` (per ADR-0007's explicit scoping decision) — O(1) per frame while active (one `get_progress()` call, one fill update), but zero cost while idle, per the `_ready()` initial-state guard documented above.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001 (Number Formatting & Progress Bar Math): this story calls `ActionUIFormatting.fill_ratio()`, does not implement it
- Story 002 (Resource HUD), Story 003 (Action Grid): separate sibling zones
- Juice/Feedback System resolution effects (undesigned downstream system, per the GDD's own "Not testable against this GDD alone" note)

---

## QA Test Cases

*Test specs reused/adapted from `production/qa/qa-plan-sprint-6-2026-06-24.md`.*

- **Manual check: `_process()` disabled while idle, including at scene load**
  - Setup: run `action_screen.tscn` directly with `ActionSystem.current_action_id` empty from the start (no action ever started)
  - Verify: add a temporary print/counter inside `_process()` and confirm it never increments while idle, from the very first frame
  - Pass condition: zero `_process()` calls observed while idle — this is the most important check in this story, per ADR-0007's explicit finding

- **Manual check: progress bar fill behavior**
  - Setup: start an action with a known duration (e.g. 9s)
  - Verify: at t=0 the bar shows empty with no flicker; partway through, the fill matches the expected ratio; at/after completion, the bar shows full, never overflowing
  - Pass condition: correct fill at all 3 checkpoints (start, mid, end)

- **Manual check: action name and remaining time shown**
  - Setup: same running action as above
  - Verify: the overlay displays the action's name and a remaining-time value alongside the bar
  - Pass condition: both pieces of information visible and updating correctly as time elapses

- **Manual check: overlay hides on completion**
  - Setup: let the running action complete
  - Verify: the overlay becomes hidden (`visible = false`) and `_process()` stops (re-confirm via the same counter as the first check)
  - Pass condition: overlay hidden, `_process()` confirmed stopped, not just visually hidden while still polling underneath

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/running-action-overlay-evidence.md` — manual walkthrough doc or interaction test, with sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Number Formatting & Progress Bar Math), Story 003 (Action Grid) — must be DONE first; this story's visibility/process-enable is conceptually paired with the Grid's button-disable on action start, and may require checking/extending `ActionSystem`'s signal surface (see Implementation Notes)
- Unlocks: None — this is the last story in the Action UI epic
