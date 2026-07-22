# Interaction Pattern Library

> **Status**: In Design
> **Author**: user + ux-designer
> **Last Updated**: 2026-07-22
> **Template**: Interaction Pattern Library

---

## Overview

This library catalogs the touch-interaction patterns used in "Król Cringe'u," originally extracted from the 3 GDDs with UI Requirements sections (Action UI, Card UI, Offline Report Screen), and extended by later `/ux-design` sessions (Meta-Bonus Visibility). The game is touch-first (Android + Web with mouse-emulated touch) — every pattern assumes large touch areas and zero hover-only interactions, per `technical-preferences.md`. Goal: new screens (Vertical Slice+) reference these patterns by name rather than reinventing them.

---

## Pattern Catalog

| Pattern | Category | Used In |
|---|---|---|
| Large Touch Button (state-gated) | Input | Action UI |
| Per-Frame Progress Bar | Feedback | Action UI |
| Swipe-to-Commit (distance OR velocity) | Input | Card UI |
| Full-Screen Blocking Modal | Modal | Card UI, Offline Report Screen |
| Headline Count-Up Number | Feedback | Offline Report Screen |
| Locked/Muted Slot | Data Display | Action UI |
| Tap-Anywhere-or-Button Dismiss | Input | Offline Report Screen |
| Event-Driven Progress-to-Cap Bar | Feedback | Meta-Bonus Visibility |

---

## Patterns

### Large Touch Button (state-gated)

**Category**: Input
**Used In**: Action UI (Action Grid)

**Description**: A large, touch-friendly button representing a single player action. Visually communicates its content (label, duration, reward preview) and is enabled/disabled based on system state — never hidden, even when disabled.

**Specification**:
- Minimum touch target per platform accessibility guidance (44×44dp Android minimum) — exact size set by `/ux-design` per-screen spec
- Three states: enabled (idle, unlocked), disabled-temporarily (running), disabled-permanently (locked, shown muted not hidden)
- Tap on enabled state → fires the associated action immediately, no confirmation step
- Tap on disabled state → no-op, no error feedback (silence is the correct response, per Action UI's Acceptance Criteria)

**When to Use**: Any primary, frequent player action with a fixed, known outcome (Pillar 1 — predictable result before tapping).
**When NOT to Use**: Irreversible or high-stakes choices — those use Swipe-to-Commit instead, which has a built-in commitment gesture.

---

### Per-Frame Progress Bar

**Category**: Feedback
**Used In**: Action UI (Running Action Overlay)

**Description**: A progress bar that fills smoothly every rendered frame (not throttled to e.g. once per second), giving a legible, continuous sense of time passing during a timed action.

**Specification**:
- `fill_ratio = clamp(elapsed_time / duration, 0, 1)` — updates every frame
- Neutral, uniform visual style regardless of which action is active (no valence coding)
- Accompanied by the action name and remaining time as text, never the bar alone

**When to Use**: Any bounded-duration wait the player is meant to perceive as progressing (reinforces the select-and-wait loop's core feel).
**When NOT to Use**: Indeterminate-duration waits — use a different indicator (spinner) since a progress bar implies a known endpoint.

---

### Swipe-to-Commit (distance OR velocity)

**Category**: Input
**Used In**: Card UI

**Description**: A Tinder-style drag gesture where releasing past a distance threshold OR exceeding a velocity threshold commits to a binary choice; releasing short of both bounces the element back to center.

**Specification**:
- `is_committed = (abs(drag_x_at_release) >= commit_threshold_ratio × screen_width) OR (abs(release_velocity) >= flick_velocity_threshold)`
- Visual rotation proportional to drag distance gives physical "weight" feedback during the drag
- Bounce-back on non-commit is interruptible — a new touch cancels the bounce-back tween immediately
- Both directions/options share identical neutral visual treatment (no good/bad color coding)

**When to Use**: High-stakes, binary, narratively weighted player decisions where the gesture itself should feel deliberate.
**When NOT to Use**: Frequent, low-stakes actions — the gesture's "weight" would feel like friction, not meaning, at high frequency. Use Large Touch Button instead.

---

### Full-Screen Blocking Modal

**Category**: Modal
**Used In**: Card UI, Offline Report Screen

**Description**: A full-screen overlay that takes total input priority — all background UI (Resource HUD, Action Grid) becomes non-interactive for the modal's entire duration.

**Specification**:
- Background UI receives zero input while the modal is in any non-`hidden` state
- Entrance: slide-in + fade (~150-200ms), consistent timing across all uses of this pattern
- Exit: reverse of entrance, or an explicit dismiss gesture depending on the specific screen's resolution
- No auto-dismiss timer — every use of this pattern requires an active player gesture to close, never a timeout

**When to Use**: Moments requiring the player's undivided attention — a decision, a report, anything that shouldn't be skimmable while still tapping the background.
**When NOT to Use**: Passive notifications that don't need to block play — use a toast/banner pattern instead (not yet in this library — flagged in Gaps).

---

### Headline Count-Up Number

**Category**: Feedback
**Used In**: Offline Report Screen

**Description**: A large numeric display that animates from 0 up to its final value over a short, fixed duration — independent of the number's magnitude, so large and small results feel equally snappy.

**Specification**:
- Animation duration is fixed regardless of final value (large numbers don't count up slower)
- Skippable — the screen's dismiss gesture works immediately, doesn't wait for the count-up to resolve
- Uses the project's standard K/M number formatting once the count-up completes

**When to Use**: Any "reveal" moment where a number is the emotional payoff (rewards, totals, gains).
**When NOT to Use**: Real-time/continuously-updating values (e.g., live resource HUD) — count-up implies a one-time reveal, not an ongoing display.

---

### Locked/Muted Slot

**Category**: Data Display
**Used In**: Action UI (locked Action Grid slots)

**Description**: A slot reserved for future content, shown in-place with a muted (lower contrast/saturation) visual treatment rather than hidden — signals "more is coming" without revealing details prematurely.

**Specification**:
- Never removed from layout — same position before and after unlock, only the visual state changes (🔒 → active)
- Shows a generic locked icon when the unlock condition/threshold is unknown or undefined — never guesses a number
- Tap on a locked slot is a no-op, no error feedback

**When to Use**: Any content gated behind a milestone/threshold where building anticipation is a design goal (per Player Fantasy in Action UI).
**When NOT to Use**: Content the player has no path to ever unlock yet (would create false anticipation) — simply omit the slot instead.

---

### Tap-Anywhere-or-Button Dismiss

**Category**: Input
**Used In**: Offline Report Screen

**Description**: A modal dismiss gesture where both a labeled button and a tap anywhere else on the screen trigger the identical dismiss action — whichever input arrives first wins, with no distinction in outcome.

**Specification**:
- Both input sources connect to the same dismiss signal/handler — not two separate code paths
- Only the first tap during a dismiss-in-progress transition is honored; subsequent taps during the transition are no-ops (no double-dismiss)

**When to Use**: Low-friction modals where the only possible outcome is "acknowledge and continue" (no branching choice).
**When NOT to Use**: Modals with a real choice between 2+ outcomes — tap-anywhere would be ambiguous about which outcome was selected. Use Swipe-to-Commit or distinct buttons instead.

---

### Event-Driven Progress-to-Cap Bar

**Category**: Feedback
**Used In**: Meta-Bonus Visibility

**Description**: A progress bar showing how close a permanent value is to its lifetime ceiling. Unlike Per-Frame Progress Bar, it does not update continuously against elapsed time — it recomputes only when the underlying value changes (a grant event), then holds static until the next change.

**Specification**:
- `fill_ratio = clamp(current_value / cap_value, 0, 1)` — recomputed on grant/update events only, never per-frame
- Always paired with the numeric current value as text — the bar alone never carries the information (accessibility, no-color-alone rule)
- At `fill_ratio == 1.0` (capped), pairs with an explicit textual/iconic "MAX" indicator, not just a visually full bar — a full bar and a capped bar must be distinguishable without inferring from position alone

**When to Use**: Any permanent, slowly-accumulating value with a known ceiling that the player checks periodically, not something they watch tick up in real time.
**When NOT to Use**: Time-bounded waits with a known duration — use Per-Frame Progress Bar instead, which implies "this is currently running," not "this is where you stand."

---

## Gaps & Patterns Needed

- **Toast/banner pattern** (passive, non-blocking notification) — needed once a system requires a notification that doesn't block play; flagged above as the right tool versus Full-Screen Blocking Modal for low-urgency notices.
- **Locked-content reveal pattern** — Action UI's locked slots show *that* something is locked, but no pattern yet exists for the moment a slot actually unlocks (animate? flash? silent switch?). Undefined — already an Open Question in `action-ui.md`.
- **Navigation/screen-transition pattern** — Main Navigation/Screen Flow (Vertical Slice tier, undesigned) will need a pattern for moving between top-level screens; none of the 3 current GDDs define one since none are top-level screens yet.

---

## Open Questions

- **Exact touch-target sizing** — patterns reference "44×44dp Android minimum" as platform guidance, but no per-screen spec has pinned final dimensions yet. *Owner: per-screen `/ux-design` sessions. Target: Pre-Production.*
