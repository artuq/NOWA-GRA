# Card UI

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 3 — Satyra przez mechanikę, nie wykład

## Overview

Card UI to ekran prezentacji kart decyzji — implementacja i scalenie wymagań już zadeklarowanych w Card Content Database (swipe, drag preview, ikony kategorii, brak kodowania moralnego) i Decision Card System (uniform entrance, blokowanie innych interakcji UI). Ten GDD nie wymyśla nowych reguł wizualnych — składa je w jeden spójny, kompletny ekran modalny: jak karta się pojawia, jak gracz wykonuje gest swipe, jak wygląda commitment threshold, i jak ekran znika po rozwiązaniu.

Dla gracza to jedyny moment w grze, w którym pętla idle przerywa się na refleksję — ekran musi być w pełni skoncentrowany na treści karty, bez rozpraszaczy z HUD czy Action Grid w tle.

## Player Fantasy

Gracz czyta sytuację, czuje wagę wyboru pod palcem podczas swipe (drag preview reaguje na ruch), i decyduje — to jest najbardziej fizyczny, namacalny moment w grze, mocniej osadzony w ciele niż tap na przycisk akcji. Pod tą warstwą leży infrastruktura uniform-entrance i blokowania UI, niewidoczna dla gracza, ale gwarantująca, że ten moment nigdy nie jest przerywany ani zdradzany wizualnie (brak kodowania moralnego — gracz musi czuć ciężar decyzji przez treść, nie przez kolor przycisku).

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents not consulted — Lean mode. Review manually before production.*

### Core Rules

This GDD resolves the **commitment threshold** Open Question left by Card Content Database.

**Modal layout:**
1. Category icon (sponsor/drama/hater/neutral) + situation text, centered.
2. Both option labels (left = option_A, right = option_B) visible without dragging, so the player knows what each direction means before gesturing.
3. The card occupies the full screen width, visually and interactively blocking the Resource HUD and Action Grid beneath it.

**Swipe mechanics:**
1. **Drag preview**: the card follows the finger 1:1, with a slight tilt (rotation proportional to X displacement).
2. **Commitment threshold = 30% of screen width** — dragging the card ≥30% of screen width in a direction and releasing confirms that choice; <30% and releasing → the card bounces back to center.
3. While dragging, the option label in the drag direction slightly enlarges (a "this will confirm" signal), the other dims — purely interactive feedback, not moral coding (both labels share an identical neutral base style).

**Entrance and exit:**
4. **Entrance**: slide-in + fade, ~150-200ms, identical for all 12 cards regardless of weight/intensity (per Decision Card System).
5. **Resolution**: cards with `milestone_to_set` get a heavier/longer beat (per Card Content Database) — this applies to the phase *after* the choice is confirmed, not the swipe gesture itself.
6. After resolution, the card screen closes (fade-out), Resource HUD and Action Grid return to full interactivity.
7. **Bounce-back is interruptible**: if the player touches the card again while a bounce-back tween is still playing, the tween cancels immediately and the state transitions straight to `dragging` — no waiting for the tween to finish.
8. **Interruption reset is instant, not animated**: if the gesture is interrupted (app backgrounded, incoming call) while `dragging`, position/rotation reset to (0,0)/0° immediately on resume — no bounce-back tween plays, consistent with "no partial state persisted."

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `hidden` | No card on screen | → `entering` when Decision Card System enters `presenting` |
| `entering` | Entrance animation (150-200ms) | → `awaiting_swipe` once the animation completes |
| `awaiting_swipe` | Card static, waiting for a gesture | → `dragging` when the player starts dragging |
| `dragging` | Card tracks the finger, labels react | → `awaiting_swipe` (bounce-back, <30%) or `resolving` (≥30% + release) |
| `resolving` | Resolution beat (normal or heavier for milestone) | → `hidden` once complete, HUD/Grid unblocked |

### Interactions with Other Systems

- **Decision Card System** (hard, read+write) → reads `presenting`/`resolving` state and the chosen card's content; sends the player's choice (option_A/option_B) as input
- **Card Content Database** (hard, read) → reads text, category icons, option labels to display
- **Resource HUD / Action Grid (Action UI)** (peer, blocked) → become non-interactive whenever Card UI is in any state other than `hidden`

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

This GDD has no original game-design math — display-derivation rules only, same tier as Action UI.

**Drag rotation** is defined as:

`rotation_degrees = clamp(drag_x / half_screen_width, -1.0, 1.0) × max_tilt_degrees`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Drag displacement | drag_x | float | unbounded (typically -screen_width to +screen_width) | Horizontal finger displacement from drag start, px |
| Half screen width | half_screen_width | float | >0 | screen_width / 2 — normalizes displacement to ±1 at edge-to-edge drag |
| Max tilt | max_tilt_degrees | float (tuning) | 8–15° | Max card rotation at full-width drag |
| Output rotation | rotation_degrees | float | [-max_tilt_degrees, +max_tilt_degrees] | Applied to the card node |

**Example:** drag_x=200px, half_screen_width=360px (720px screen), max_tilt_degrees=12° → clamp(200/360,-1,1)=0.556 → rotation=6.67°.

**Commitment check** is defined as (distance OR velocity, Tinder-style):

`is_committed = (abs(drag_x_at_release) >= commit_threshold_ratio × screen_width) OR (abs(release_velocity) >= flick_velocity_threshold)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Displacement at release | drag_x_at_release | float | unbounded | Horizontal displacement when finger lifts |
| Threshold ratio | commit_threshold_ratio | float (tuning) | 0.30 (0.0–1.0) | Fraction of screen width needed to confirm by distance |
| Screen width | screen_width | float | device-dependent (px) | Current viewport width |
| Release velocity | release_velocity | float | unbounded (px/s) | Finger velocity at the moment of release |
| Flick threshold | flick_velocity_threshold | float (tuning) | 800 px/s (starting value) | Minimum velocity to confirm a fast, short swipe regardless of distance |
| Result | is_committed | bool | {true, false} | Confirms the choice vs. bounce-back |

**Rationale:** 30% of screen width is comparable to Tinder's ~40-50% of *card* width, since this game's cards occupy near-full screen width — slightly more lenient, fitting a satirical idle game favoring frequent, low-friction decision throughput over deliberation tension. The velocity OR-clause catches fast short flicks that "feel" confirmed but would miss a pure-distance check.

**Bounce-back tween (prose rule, no branching/clamping — table not needed):** when `is_committed = false`, the card tweens back to position (0,0) and rotation 0°, ease-out, over 150ms — matching the entrance animation's timing for visual consistency.

**Resolution beat intensity** is purely data-driven (the milestone-card heavier/longer beat flag comes from Card Content Database's schema, not computed from any in-screen state) — no formula needed, just a reference to that dependency.

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If the player drags past the screen edge** (`drag_x` exceeds `screen_width`): `rotation_degrees` clamps to `max_tilt_degrees` (formula already handles this) — the card stops rotating further but may visually exit the viewport; acceptable since the gesture results in `is_committed=true` well before this point.
- **If the player taps the card without dragging** (tap, not swipe): `drag_x_at_release≈0`, `release_velocity≈0` → `is_committed=false` → bounce-back (no effect) — tap is not an alternative choice method in MVP.
- **If multitouch occurs** (a second finger touches the screen while dragging): only the first active touch is tracked; the second is ignored — prevents undefined behavior from two simultaneous gestures.
- **If the gesture is interrupted** (e.g., incoming call, app backgrounded mid-`dragging`): the card returns to `awaiting_swipe` (treated as a sub-threshold release) — no partial state is persisted.
- **If two cards could appear "simultaneously"**: not applicable — Decision Card System guarantees only one card in `presenting` at a time (single-concurrency, per its Core Rules).

## Dependencies

**Upstream (this system depends on):**
- **Decision Card System** (hard) — state machine, chosen card data, choice input.
- **Card Content Database** (hard) — card text, category icons, option labels.

**Peer (blocked while this UI is active):**
- **Action UI** (Resource HUD, Action Grid) — non-interactive whenever Card UI is in any state other than `hidden`.

**Downstream (depends on this system):**
- **Main Navigation/Screen Flow** (hard, Vertical Slice, undesigned) — will integrate this screen into broader app navigation.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `commit_threshold_ratio` | 0.30 | 0.20–0.50 | Too low: accidental confirms from small drags. Too high: feels sticky/unresponsive |
| `flick_velocity_threshold` | 800 px/s | 500–1200 px/s | Too low: any quick tap-drag confirms unintentionally. Too high: defeats the purpose of the flick escape clause |
| `max_tilt_degrees` | 12° | 8–15° | Too low: drag feels flat/lifeless. Too high: card rotation feels exaggerated/silly |
| Entrance/bounce-back duration | 150-200ms | 100–300ms | Too fast: feels like a glitch. Too slow: feels sluggish, delays gameplay |

**Knob interaction:** `commit_threshold_ratio` and `flick_velocity_threshold` together define the total "ease of confirming" — tuning one without considering the other can make the OR-condition redundant (if one is too lenient, the other never matters).

## Visual/Audio Requirements

> *Specialist consulted: `art-director` — category is "UI systems," mandatory for Visual/Audio. Most requirements already specified by Card Content Database (resolution, icons, no moral color-coding) and Decision Card System (uniform entrance) — this section covers only the drag-feedback gap.*

- **Label feedback during drag:** the option label in the drag direction slightly enlarges, the other dims — purely interactive, neutral base style shared by both labels (no good/bad coding).
- **Edge vignette (additional, art-director recommended):** a soft, neutral-tint glow on whichever screen edge the card approaches during drag, opacity scaling 0→100% as drag nears the commit threshold — identical color on both sides, only *position* (not hue) tracks drag direction. Gives peripheral commit-confidence feedback since players' eyes are on card center, not corner labels, during the gesture.
- Resolution beat, entrance animation, category icons, and moral-neutrality constraints are owned by Card Content Database and Decision Card System — not duplicated here.

📌 **Asset Spec** — once the art bible is approved, run `/asset-spec system:card-ui`.

## UI Requirements

- The card must block other UI interactions (HUD, Action Grid) for its entire on-screen duration — per the requirement already declared in Card Content Database.
- The swipe gesture must work across any Android screen size — `screen_width` in the formulas is read dynamically, never hardcoded.
- Drag preview must update smoothly (every frame), not throttled, for consistency with the rest of the game (Action UI's progress bar also updates every frame).

> 📌 **UX Flag — Card UI**: This screen has real UI requirements. In Phase 4, run `/ux-design` for `design/ux/decision-card.md` — already flagged in Card Content Database; this entry confirms it.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**State transitions:**
- **GIVEN** `hidden`, **WHEN** a card is triggered, **THEN** → `entering` (150-200ms) → `awaiting_swipe`.
- **GIVEN** `awaiting_swipe`, **WHEN** the player touches and moves beyond drag-start threshold, **THEN** → `dragging`.
- **GIVEN** `dragging`, **WHEN** released with neither commitment condition met, **THEN** → `awaiting_swipe` via bounce-back.
- **GIVEN** `dragging`, **WHEN** released with ≥1 commitment condition met, **THEN** → `resolving` → `hidden`.
- **GIVEN** any non-`hidden` state, **WHEN** the player taps Resource HUD/Action Grid, **THEN** input ignored, no Action UI change.
- **GIVEN** state just became `hidden`, **WHEN** the player interacts with Action UI, **THEN** processed normally.

**Rotation formula:**
- **GIVEN** drag_x=0, **THEN** rotation_degrees=0.
- **GIVEN** half_screen_width=540px, drag_x=270px, **THEN** rotation=6° (linear).
- **GIVEN** drag_x=540px (ratio=1.0), **THEN** rotation=12° (at clamp boundary).
- **GIVEN** drag_x=800px (past edge), **THEN** rotation=12° (clamped, not over-rotated).
- **GIVEN** drag_x=-540px, **THEN** rotation=-12°; **GIVEN** drag_x=-900px, **THEN** still -12° (clamped).

**Commitment formula:**
- **GIVEN** screen_width=1080px, drag_x_at_release=324px (=0.30×1080, exact), velocity=0, **THEN** is_committed=true (inclusive boundary).
- **GIVEN** drag_x_at_release=323px, velocity=0, **THEN** is_committed=false.
- **GIVEN** drag_x_at_release=50px, velocity=800px/s (exact), **THEN** is_committed=true (velocity alone suffices).
- **GIVEN** velocity=799px/s, drag_x_at_release=50px, **THEN** is_committed=false.
- **GIVEN** drag_x_at_release=400px, velocity=100px/s, **THEN** is_committed=true (OR — distance alone suffices).
- **GIVEN** drag_x_at_release=100px, velocity=200px/s, **THEN** is_committed=false (neither met).
- **GIVEN** drag_x_at_release=-400px, velocity=0, **THEN** is_committed=true (abs() applied, direction-agnostic).
- **GIVEN** velocity=-850px/s, drag_x_at_release=50px, **THEN** is_committed=true (abs() applied to velocity).

**Bounce-back behavior:**
- **GIVEN** dragging at nonzero position/rotation, **WHEN** bounce-back triggers, **THEN** tweens to (0,0)/0°, 150ms, ease-out.
- **GIVEN** a bounce-back tween in progress, **WHEN** the player touches the card again, **THEN** the tween cancels immediately, state → `dragging` (per Core Rules rule 7).

**Defined edge cases:**
- **GIVEN** drag_x_at_release=1500px on a 1080px screen, **THEN** rotation clamped to ±12°, is_committed=true (distance condition met).
- **GIVEN** a tap without drag movement, **THEN** is_committed=false, bounce-back (no alternate tap-resolve path).
- **GIVEN** `dragging` tracking touch A, **WHEN** a second touch B begins, **THEN** B is ignored entirely, A continues normally.
- **GIVEN** touch A released while B is active, **THEN** release evaluated using A's data only; B does not become tracked afterward.
- **GIVEN** `dragging`, **WHEN** the app is backgrounded/interrupted, **THEN** on resume state is `awaiting_swipe`, position/rotation reset to (0,0)/0° instantly, no tween (per Core Rules rule 8).

**Not testable against this GDD alone:**
- Whether a new card-trigger is suppressed while Card UI is non-`hidden` — depends on Decision Card System's single-concurrency guarantee, not this GDD.
- Exact resolution beat duration for the `resolving` state — intensity is data-driven from Card Content Database; this GDD doesn't define a fallback duration.
- The triggering event/source for "a card is triggered" (AC for entering) — depends on undesigned Main Navigation/Screen Flow or the calling system's contract.

## Open Questions

- **Exact resolution beat duration** — Card Content Database declares "heavier/longer" but gives no concrete ms value; this GDD defines no fallback. *Owner: revise Card Content Database or `/ux-design`. Target: Pre-Production.*
- **Touch-tracking reset when a second touch remains active after the first releases** — undefined behavior for this rare multitouch edge case. *Owner: revise this GDD. Target: before `/vertical-slice`.*
