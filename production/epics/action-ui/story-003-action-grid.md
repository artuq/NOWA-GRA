# Story 003: Action Grid

> **Epic**: Action UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/action-ui.md`
**Requirement**: Action Grid + Button enable/disable sections of the GDD's Core Rules and Acceptance Criteria (no dedicated TR-ID yet — registry-completeness gap, see EPIC.md)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 (primary); ADR-0001 (secondary)
**ADR Decision Summary**: `ActionGrid` is one of 3 sibling Control scripts under `ActionScreen`. Each of the 6 slot buttons' `pressed` signal connects directly to a handler calling `ActionSystem.start_action(action_id)`. Connects to `ActionSystem.action_completed` to re-enable buttons. Locked-slot buttons are `disabled = true` set once at `_ready()`.

**Engine**: Godot 4.6.3 | **Risk**: MEDIUM (ADR-0007's self-rated risk, same as Story 002)
**Engine Notes**: `Button` (not `TouchScreenButton`) confirmed correct by ADR-0007's engine specialist review. **Open verification item from that review**: each slot button's `custom_minimum_size` must meet a real touch-target minimum (commonly ~48x48dp-equivalent) per `technical-preferences.md`'s "large, touch-friendly" requirement — this is a real, unverified risk, not just a formality. Verify on an actual touch-sized hit area during this story's implementation, not assumed.

**Control Manifest Rules (this layer)**:
- Required: PascalCase class name (`ActionGrid`), snake_case file name
- Forbidden: Reading `RunningActionOverlay`'s state directly (ADR-0007's no-cross-zone-coupling decision) — `ActionGrid` re-enables its own buttons via its own `action_completed` connection, it does not ask the Overlay zone whether it's done
- Guardrail: No `_process()` in this zone — only `RunningActionOverlay` uses `_process()`, per ADR-0007

---

## Acceptance Criteria

*From GDD `design/gdd/action-ui.md`, scoped to this story:*

**Layout:**
- [ ] The Action Grid renders exactly 6 slots: 3 unlocked + 3 locked
- [ ] A slot unlocking (milestone reached) does not add/remove/reposition any slot — the same slot switches 🔒→active in place

**Button enable/disable:**
- [ ] Given `idle` state, when rendered, all 3 unlocked buttons are enabled
- [ ] Given `idle`, when tapping an unlocked button, the choice is sent to `ActionSystem.start_action(action_id)`
- [ ] Given `idle`, when tapping a locked slot, it's a no-op with no visible change
- [ ] Given `running` state (an action is active), when rendered, all 6 buttons are disabled
- [ ] Given `running`, when tapping any button, it's a no-op
- [ ] Given the `running→resolved→idle` transition completes, unlocked buttons re-enable

**Button anatomy:**
- [ ] Each unlocked button shows: action name, duration, and reward values (e.g. "Zrób dramę / 9s — +10Z, +20C, -3M"), formatted via `ActionUIFormatting.format_number()` (Story 001) for the numeric values — pulled from the registry's action tuning values, never hardcoded in this script

**Defined edge cases:**
- [ ] A locked slot with `unlock_threshold = null` shows a generic 🔒 state, no number
- [ ] An action name exceeding button width truncates with an ellipsis; button dimensions stay unchanged

---

## Implementation Notes

*Derived from ADR-0007's Implementation Guidelines:*

Create `res://scenes/action_screen/action_grid.tscn` (root `Control`, script `action_grid.gd`, `class_name ActionGrid`) as a sibling under the `ActionScreen` root scene created by Story 002.

Each of the 6 slot buttons (`Button` nodes, per ADR-0007's confirmed node type) connects its `pressed` signal to a single handler. For unlocked slots, the handler calls `ActionSystem.start_action(action_id)` directly — no intermediate dispatch layer. For locked slots, the button's `disabled = true` is sufficient; do not add a redundant guard inside the handler (a disabled button never fires `pressed`).

Connect to `ActionSystem.action_completed(action_id: String, payload: Dictionary)` in `_ready()` to re-enable the 3 unlocked buttons. Also disable all 6 buttons when a `start_action()` call succeeds (i.e., on the button-press handler itself, immediately — do not wait for a separate "running" signal, since the GDD requires the grid to go disabled the instant an action starts, and `ActionSystem.start_action()` returning `true` is the synchronous confirmation that it did).

Locked-slot threshold display: read `unlock_threshold` per slot. If `null`, render the generic 🔒 with no number (per the Defined Edge Cases AC) — do not invent a placeholder number.

**Real touch-target verification required**: set each button's `custom_minimum_size` explicitly (do not rely on theme defaults) and verify the resulting hit area against `technical-preferences.md`'s touch requirement before marking this story done — this was flagged as an open, unverified item by ADR-0007's engine specialist review.

**Performance**: event-driven only (button `pressed` signals + the `action_completed` connection) — no `_process()` work in this zone, per ADR-0007's decision that `RunningActionOverlay` is the sole `_process()`-using zone.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 (Resource HUD): separate sibling zone, no interaction with this story's buttons
- Story 004 (Running Action Overlay): the progress bar overlay itself — this story only disables the grid's own buttons on action start, it does not render the overlay
- Actual `unlock_threshold` values for the 3 locked slots — no source of truth exists yet (blocked on a future Milestone-Unlock System), per the GDD's own "Not testable against this GDD alone" note. Use placeholder/test values for development; do not block this story on that future system.

---

## QA Test Cases

*Test specs reused/adapted from `production/qa/qa-plan-sprint-6-2026-06-24.md`'s Manual QA Checklist.*

- **Manual check: 6-slot grid, 3 unlocked + 3 locked, layout stability on unlock**
  - Setup: run `action_screen.tscn` with a test state where 3 actions are unlocked and 3 are locked
  - Verify: exactly 6 slots visible; simulate an unlock (toggle a locked slot's state) and confirm the slot itself switches 🔒→active without any slot being added, removed, or repositioned
  - Pass condition: slot count and positions identical before/after unlock; only the changed slot's visual state differs

- **Manual check: idle-state button behavior**
  - Setup: `ActionSystem.current_action_id` is empty (idle)
  - Verify: all 3 unlocked buttons are enabled and tappable; tapping one calls `start_action()` (confirm via a breakpoint or print); tapping a locked slot does nothing observable
  - Pass condition: correct enable state and correct tap behavior for both unlocked and locked slots

- **Manual check: running-state button behavior**
  - Setup: start an action so `ActionSystem.current_action_id` is non-empty
  - Verify: all 6 buttons are disabled immediately (not after a delay); tapping any of them does nothing
  - Pass condition: all 6 disabled the instant the action starts

- **Manual check: re-enable on completion**
  - Setup: let a running action complete naturally (or trigger `action_completed` directly for a faster test cycle)
  - Verify: the 3 unlocked buttons re-enable; locked buttons remain disabled
  - Pass condition: correct enable state restored, locked slots stay locked

- **Manual check: button anatomy and truncation**
  - Setup: an unlocked button with a real action (name, duration, reward values) and a separate test case with an artificially long action name
  - Verify: normal button shows "[name] / [duration]s — [Reach]Z, [Cringe]C, [Morale]M" with correctly formatted numbers; long-name button truncates with an ellipsis, button size unchanged
  - Pass condition: correct anatomy and stable button dimensions in both cases

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `production/qa/evidence/action-grid-evidence.md` — manual walkthrough doc or interaction test, with sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Number Formatting & Progress Bar Math) — calls `ActionUIFormatting.format_number()` for button labels; Story 002 (Resource HUD) — must be DONE first since it creates the shared `ActionScreen` root scene this story adds a sibling node to
- Unlocks: Story 004 (Running Action Overlay) — the overlay's visibility is conceptually tied to this grid's disabled state
