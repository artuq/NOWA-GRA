# Story 002: Card Screen Modal & Resolution

> **Epic**: Card UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-26

## Context

**GDD**: `design/gdd/card-ui.md`
**Requirement**: `TR-cui-001` — Swipe/drag modal card presentation with commitment threshold (this story implements the modal shell + DecisionCardSystem integration; the swipe gesture itself is Story 003)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 (primary); ADR-0001 (secondary)
**ADR Decision Summary**: DecisionCardSystem gains a `card_presented(card)` signal (additive) emitted from `present_next_card()`; Card UI is a full-rect `mouse_filter=STOP` modal Control mounted as the top sibling under ActionScreen, `visible=false` when idle, blocking the Action UI zones beneath only while shown; on commit it calls the existing `DecisionCardSystem.resolve_choice(option_index)`.

**Engine**: Godot 4.6.3 | **Risk**: MEDIUM (ADR-0008 — first modal in the project)
**Engine Notes**: `mouse_filter=STOP` on the topmost full-rect Control consumes the touch so sibling zones beneath never receive it (it does NOT "block siblings" directly — it's hit-order + STOP consuming the event); `visible=false` fully releases input to the Action UI when idle (engine-specialist-confirmed, 2026-06-25). Use `Button` (not `TouchScreenButton`) for any tappable elements, per ADR-0007's precedent.

**Control Manifest Rules (this layer — Presentation)**:
- Required: PascalCase `class_name` (`CardScreen`), snake_case file name; consume DecisionCardSystem via direct calls + the new signal (ADR-0001 pattern)
- Forbidden: reading DecisionCardSystem's private `_presented_card` — the card `Dictionary` arrives via the `card_presented` signal; no cross-system private access
- Guardrail: no `_process()` polling — the modal is purely signal/event-driven (entrance/exit tweens are engine-driven)

---

## Acceptance Criteria

*From GDD `design/gdd/card-ui.md`, scoped to this story (the modal shell + resolution; gesture is Story 003):*

**Appearance & content:**
- [ ] Given DecisionCardSystem emits `card_presented(card)` (state → PRESENTING), when the modal receives it, the Card Screen becomes visible (from `hidden`)
- [ ] The modal displays the card's category icon, situation text, and BOTH option labels (left = option_A, right = option_B) — both visible without any gesture, so the player knows what each direction means
- [ ] The card occupies the full screen width

**Modal blocking:**
- [ ] While the modal is shown (any non-`hidden` state), a tap that would hit the Resource HUD / Action Grid beneath does NOT reach them (no action starts, no Action UI change)
- [ ] When the modal returns to `hidden`, the Action UI beneath is fully interactive again

**Resolution:**
- [ ] When a choice is resolved (option_index 0 or 1), the modal calls `DecisionCardSystem.resolve_choice(option_index)` exactly once with the correct index
- [ ] After resolution, the modal hides (returns to `hidden`) and unblocks the Action UI

**DecisionCardSystem integration (the new signal):**
- [ ] `DecisionCardSystem.present_next_card()` emits `card_presented(card)` after `_presented_card` is set and state becomes PRESENTING; never on an empty pool
- [ ] The signal carries the full card `Dictionary` (the modal never reads `_presented_card` directly)

---

## Implementation Notes

*Derived from ADR-0008's Decision §1 and §2:*

**DecisionCardSystem change (additive)** — add a signal and emit it. In `present_next_card()`, after `_presented_card = _weighted_pick(pool)` and `state = State.PRESENTING`, add `card_presented.emit(_presented_card)`. Declare `signal card_presented(card: Dictionary)`. This is a one-line additive emission mirroring ActionSystem's `action_started` (ADR-0007) — do not alter any existing DecisionCardSystem behavior or break its existing tests.

**CardScreen scene** — `res://scenes/card_screen/card_screen.tscn`, root `Control` (`class_name CardScreen`, script `card_screen.gd`), full-rect, `mouse_filter = STOP`, `visible = false` initially. Children: a full-rect dimming backdrop Panel; a centered card panel (full screen width) holding the category icon (TextureRect), situation text (Label), and the two option labels (left/right). Mounted as the last child of `action_screen.tscn` (top sibling, drawn over the Action UI zones).

In `_ready()`: connect to `DecisionCardSystem.card_presented`. On the signal: populate content from the card `Dictionary`, set `visible = true`, transition `hidden → entering` (a simple fade/scale tween, ~150-200ms) → `awaiting_swipe`. (The actual swipe handling that drives `awaiting_swipe → dragging → resolving` is Story 003 — for THIS story, expose a `resolve(option_index: int)` method as the test seam that performs the resolution path: call `DecisionCardSystem.resolve_choice(option_index)`, then hide.)

Content keys: read the card's category for the icon, the situation text key, and `card["options"][0]`/`[1]` labels — confirm the exact `CardContentDatabase` schema keys (`text`, `options[i]["label"]`, category) against `src/core/card_content_database.gd` before wiring, the same way Action UI confirmed ResourceManager's keys.

**State enum**: `hidden`, `entering`, `awaiting_swipe`, `resolving` (this story); `dragging` is added by Story 003. Keep the enum complete from the start so Story 003 only adds transitions, not new states.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001 (Card Swipe Math): the rotation/commitment formulas — this story's resolution seam is a direct `resolve(option_index)` method, not a gesture
- Story 003 (Swipe Gesture): drag tracking, rotation-on-drag, commitment detection, bounce-back, single-touch latch, label enlarge/dim feedback — Story 003 wires the swipe to call this story's resolution path
- Resolution-beat duration variance for milestone cards (GDD: data-driven from Card Content Database, no fallback duration defined) — out of scope for the whole epic

---

## QA Test Cases

*Interaction-test specs via GdUnit4 `scene_runner()` (the standing UI-evidence method), plus a unit check on the new signal.*

- **AC: card_presented signal fires correctly**
  - Given: a DecisionCardSystem instance with a non-empty pool
  - When: `present_next_card(pool)` is called
  - Then: `card_presented` is emitted exactly once, carrying the same card Dictionary that `_presented_card` was set to; not emitted when `_check_pool` hits an empty pool
  - Edge cases: confirm no emission on the empty-pool branch

- **AC: modal appears on signal and shows content**
  - Given: the CardScreen scene instanced via scene_runner, idle (`hidden`, `visible=false`)
  - When: `DecisionCardSystem.card_presented.emit(card)` is fired with a known card
  - Then: the screen becomes `visible`, and its icon/text/both option labels reflect that card's content
  - Pass condition: all three content pieces populated from the card Dictionary

- **AC: resolution calls resolve_choice and hides**
  - Given: a presented card on screen
  - When: `resolve(1)` (the test seam) is invoked
  - Then: `DecisionCardSystem.resolve_choice(1)` is called once, and the modal becomes `visible=false` (`hidden`)
  - Edge cases: resolve(0) vs resolve(1) pass the correct index

- **AC: modal blocks Action UI beneath while shown**
  - Given: the full `action_screen.tscn` with CardScreen shown over the Action Grid
  - When: input is simulated at a point over an Action Grid button
  - Then: no action starts (the CardScreen's STOP root consumed it); after the modal hides (`visible=false`), the same input reaches the Action Grid
  - Pass condition: ActionSystem.current_action_id stays empty while modal shown; the modal's mouse_filter is STOP and root is the topmost sibling

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/card_ui/card_screen_modal_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (the gesture-free modal shell; DecisionCardSystem is Complete and only gains an additive signal here)
- Unlocks: Story 003 (Swipe Gesture Interaction) — attaches the swipe gesture to this modal and routes it to this story's resolution path
