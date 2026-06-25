# ADR-0008: Card UI Modal, Swipe Gesture, and Decision Card System Integration

## Status
Proposed

## Date
2026-06-25

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | UI / Input |
| **Knowledge Risk** | MEDIUM — touch/drag gesture handling (`InputEventScreenTouch`/`InputEventScreenDrag`), `Tween`-based bounce-back, and full-screen modal input-blocking are stable Control/Input APIs, but this is the project's FIRST gesture-input and FIRST modal; the exact input-routing and multi-touch-rejection behavior must be verified in-engine, not assumed |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None — `Control`, `Tween` (`create_tween`), `InputEventScreenTouch`/`InputEventScreenDrag`, `mouse_filter`, `pivot_offset`/`rotation` are all stable well before 4.4 |
| **Verification Required** | (1) confirm `mouse_filter = STOP` on a full-rect Control fully blocks input to sibling zones beneath while shown; (2) confirm single-touch tracking correctly ignores a second simultaneous touch; (3) confirm GdUnit4's `simulate_screen_touch_*` drives `_gui_input`/`_input` for headless gesture tests |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload direct-call/signal consume pattern), ADR-0007 (UI zone = Control scene consuming Autoloads directly) |
| **Enables** | Card UI epic stories (the modal that finally surfaces DecisionCardSystem's already-complete backend in actual play) |
| **Blocks** | None |
| **Ordering Note** | Second Presentation-layer ADR. Extends ADR-0007's "UI consumes Autoload via direct calls + signals" pattern to a modal + gesture context; introduces one small DecisionCardSystem addition (a presentation signal), mirroring the `action_started` signal ADR-0007's work added to ActionSystem |

## Context

### Problem Statement
`DecisionCardSystem` (Complete since Sprint 4) owns the full card lifecycle —
cooldown, weighted selection, `present_next_card()`, `resolve_choice()`, and a
`State` enum (`COOLDOWN`/`CHECKING`/`PRESENTING`/`RESOLVING`) — but it has **no
signals at all**, so nothing in the UI is ever notified when a card should be
shown. As a result, cards are selected silently in the background and never
appear on screen. `card-ui.md` specifies the missing piece: a full-screen modal
that appears when a card is presented, lets the player swipe left/right to
choose, and blocks the Action UI beneath it until resolved. This ADR fixes the
integration seam and the modal/gesture implementation pattern.

### Constraints
- Godot 4.6.3, GDScript, touch-only input (`technical-preferences.md`); no
  threading
- Must consume `DecisionCardSystem` via ADR-0001's pattern (direct calls for
  ownership-clear writes, signals for notifications) — no new coupling style
- `DecisionCardSystem` is Complete and test-covered; any addition must be
  additive (a new signal), never a breaking change to its existing API
- Swipe math (rotation, commitment threshold) is precisely specified in the GDD
  with exact numeric acceptance criteria — must be deterministically testable

### Requirements
- Card UI appears when `DecisionCardSystem` enters `PRESENTING`, reads the
  presented card's content, and on commit calls `resolve_choice(option_index)`
- The modal blocks all input to Resource HUD / Action Grid while shown, and
  fully releases it once hidden
- Rotation and commitment-threshold formulas must be unit-testable without a
  scene tree (same precedent as `ResourceFormulas` / `ActionUIFormatting`)

## Decision

**1. DecisionCardSystem gains a `card_presented(card: Dictionary)` signal.**
Emitted by `present_next_card()` immediately after `_presented_card` is set and
`state` becomes `PRESENTING` — never on an empty pool. This is the sole new
addition to the Complete `DecisionCardSystem`, exactly mirroring the
`action_started` signal ADR-0007 added to `ActionSystem`: a one-line additive
emission, not a redesign. Card UI connects to it; the card `Dictionary` is
passed by the signal so Card UI never needs to read `DecisionCardSystem`'s
private `_presented_card`. On commit, Card UI calls
`DecisionCardSystem.resolve_choice(option_index)` directly (ownership-clear
write, ADR-0001). No other signal is added.

**2. Card UI is a full-screen modal Control, the top sibling under ActionScreen.**
Instanced as the last child of `action_screen.tscn` (drawn above the Resource
HUD / Action Grid / Running Action Overlay zones). Its root is a full-rect
`Control` with `mouse_filter = STOP`, and it carries a full-rect dimming
backdrop Panel. **Mechanism (corrected per engine-specialist review,
2026-06-25)**: `mouse_filter` does NOT "block siblings" directly — GUI input
is delivered to the *topmost* Control under the touch point, and a full-rect
`STOP` Control drawn last (on top) is that topmost node, so it consumes the
touch and the sibling zones beneath simply never receive it. The blocking is
therefore a consequence of draw/hit order + STOP consuming the event, not of
`mouse_filter` reaching down to siblings — correct outcome, accurate rationale.
When no card is active the modal is `visible = false`; invisible Controls
receive no `_gui_input` at all, so the Action UI beneath is fully interactive
again with no per-state `mouse_filter` juggling. This is the same mounting
precedent as `RunningActionOverlay` (a sibling overlay), extended with
input-blocking for a true modal.

**3. Swipe math is a stateless static utility; gesture state lives in the script.**
A new `CardSwipeMath` static class (`res://src/ui/card_swipe_math.gd`,
`class_name CardSwipeMath`, `extends RefCounted` — same shape as
`ResourceFormulas`/`ActionUIFormatting`) holds the two pure functions the GDD
specifies with exact numeric ACs:
- `rotation_degrees(drag_x: float, half_screen_width: float) -> float` =
  `clamp(drag_x / half_screen_width, -1.0, 1.0) * MAX_ROTATION` (MAX_ROTATION = 12.0)
- `is_committed(drag_x_at_release: float, velocity: float, screen_width: float) -> bool` =
  `absf(drag_x_at_release) >= 0.30 * screen_width OR absf(velocity) >= 800.0`

These are unit-tested headlessly (no scene). The gesture **state machine**
(`hidden`/`entering`/`awaiting_swipe`/`dragging`/`resolving`), `Tween`-based
bounce-back, single-touch tracking, and `card_presented`/`resolve_choice`
wiring live in the Card UI scene's script (`card_screen.gd`), tested via
GdUnit4 `scene_runner()` with simulated screen-touch input.

**Single-touch tracking (engine-specialist note, 2026-06-25)**:
`InputEventScreenTouch`/`InputEventScreenDrag` each carry an `index` field. On
the first touch that starts a drag, latch `event.index` into a tracked-index
member; for every subsequent touch/drag event, **reject any event whose
`index != tracked_index`** so a second simultaneous finger is ignored entirely
(per the GDD's multi-touch edge cases). Clear the latch on the tracked touch's
release. Input is handled via `_gui_input` (correct for a modal Control), not
`_input`. The bounce-back `Tween` is stored and `kill()`-ed before any restart
or on re-touch (interruptible per Core Rules rule 7); `pivot_offset` is set to
the card's center (on resize) so `rotation` tilts around the middle.

### Architecture Diagram
```
DecisionCardSystem.present_next_card()
        |  emits card_presented(card)
        v
CardScreen (modal Control, mouse_filter=STOP, top sibling under ActionScreen)
  - hidden -> entering(tween) -> awaiting_swipe
  - _gui_input: ScreenTouch/Drag -> dragging
        card.position follows finger; card.rotation = CardSwipeMath.rotation_degrees(...)
  - release -> CardSwipeMath.is_committed(...) ?
        yes -> DecisionCardSystem.resolve_choice(option_index) -> resolving -> hidden
        no  -> bounce-back tween -> awaiting_swipe
```

### Key Interfaces
- **New**: `DecisionCardSystem.card_presented(card: Dictionary)` signal.
- **New**: `CardSwipeMath.rotation_degrees()` / `CardSwipeMath.is_committed()` static functions.
- **Reused**: `DecisionCardSystem.resolve_choice(option_index: int)` (existing public method), `CardContentDatabase` reads for card content.

## Alternatives Considered

### Alternative 1: Poll DecisionCardSystem.state every frame from Card UI
- **Description**: Card UI runs `_process()` checking whether `state == PRESENTING`.
- **Pros**: No change to DecisionCardSystem.
- **Cons**: Per-frame polling for an event that fires rarely (once per ~2 actions) is wasteful and contradicts ADR-0001's "signals for notifications" rule; also Card UI would still need to read the private `_presented_card`.
- **Rejection Reason**: A signal is the idiomatic, cheaper, lower-coupling choice — and ADR-0007 already set the precedent (`action_started`) for adding a one-line notification signal to a Complete Autoload.

### Alternative 2: Card UI as its own top-level scene swapped via change_scene_to_file()
- **Description**: Make Card UI a separate main scene the game switches to when a card triggers, then switches back.
- **Pros**: Hard isolation.
- **Cons**: Loses the Action UI's live state underneath (the GDD wants the HUD/Grid *blocked but present beneath* the card, not unloaded); scene-swap also destroys/recreates the Action UI every card, which is heavy and loses transient state.
- **Rejection Reason**: The GDD explicitly describes a modal *over* the existing screen, not a screen replacement.

## Consequences

### Positive
- One small, additive, well-precedented change to DecisionCardSystem (a signal) unlocks the entire card-playability gap
- Swipe math is deterministically unit-testable against the GDD's exact numeric ACs, independent of any gesture/scene
- Modal-by-visibility (visible=false when idle) means zero input-blocking complexity when no card is active — no per-state mouse_filter management

### Negative
- The gesture state machine + tween logic is genuinely new territory (first gesture input in the project) and carries the most implementation risk of any UI work so far — mitigated by extracting the pure math out and testing the state machine via simulated touch

### Risks
- **Risk**: `simulate_screen_touch_*` in GdUnit4 may not perfectly reproduce real-device multi-touch rejection.
  - **Mitigation**: Unit-test the math exhaustively (deterministic); test the state machine's single-touch-tracking logic via simulated input where possible, and flag any behavior that can only be verified on a real device as a manual playtest item, not a silent assumption.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| card-ui.md | Modal appears when Decision Card System enters `presenting` | `card_presented` signal drives the `hidden → entering` transition |
| card-ui.md | Card blocks Resource HUD / Action Grid beneath it | Full-rect `mouse_filter=STOP` modal, top sibling under ActionScreen |
| card-ui.md | Rotation = linear in drag, clamped at ±12° | `CardSwipeMath.rotation_degrees()`, unit-tested against the GDD's exact cases |
| card-ui.md | Commitment = ≥30% screen width OR ≥800px/s velocity | `CardSwipeMath.is_committed()`, unit-tested against the GDD's exact cases |
| decision-card-system.md | `resolve_choice(option_index)` applies the chosen option | Card UI calls the existing public method on commit (ADR-0001 direct write) |

## Performance Implications
- **CPU**: Gesture handling is event-driven (`_gui_input`), not per-frame, except during an active drag where it updates one card's position/rotation per input event — negligible. Tweens are engine-driven. No `_process()` polling.
- **Memory**: One modal scene instance, shown/hidden. Negligible.
- **Load Time**: N/A.
- **Network**: N/A.

## Migration Plan
N/A — first implementation. The `card_presented` signal is purely additive to DecisionCardSystem; its existing tests are unaffected.

## Validation Criteria
- `CardSwipeMath.rotation_degrees(270, 540) == 6.0`; `(540,540)==12.0`; `(800,540)==12.0` (clamped); negative symmetric
- `CardSwipeMath.is_committed(324, 0, 1080) == true` (exact 30%); `(323,0,1080)==false`; `(50,800,?)==true`; `(50,799,?)==false`
- With Card UI mounted, emitting `DecisionCardSystem.card_presented(card)` makes the modal visible; a committed swipe calls `resolve_choice` with the correct option index; the modal hides afterward
- While the modal is visible, a tap that would hit the Action Grid beneath does not start an action

## Related Decisions
- ADR-0001 (Autoload architecture) — consume pattern this ADR applies to a modal
- ADR-0007 (Action UI scene structure) — sibling-zone + Autoload-binding precedent this extends; also the `action_started` signal precedent for the new `card_presented` signal
- `design/gdd/card-ui.md` — source GDD, including the exact swipe-math acceptance criteria
