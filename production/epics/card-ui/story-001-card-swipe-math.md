# Story 001: Card Swipe Math

> **Epic**: Card UI
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-26

## Context

**GDD**: `design/gdd/card-ui.md`
**Requirement**: `TR-cui-001` — Swipe/drag modal card presentation with commitment threshold (this story implements the math half of it)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008: Card UI modal, swipe gesture, DecisionCardSystem integration
**ADR Decision Summary**: Swipe rotation + commitment-threshold formulas are extracted into a stateless `CardSwipeMath` static utility class (`res://src/ui/card_swipe_math.gd`, `class_name CardSwipeMath`) so they're headlessly unit-testable against the GDD's exact numeric ACs — same precedent as `ResourceFormulas` / `ActionUIFormatting`. The gesture state machine and tweens are NOT here (Story 003).

**Engine**: Godot 4.6.3 | **Risk**: LOW — pure GDScript math (`clamp`, `absf`), no engine-specific API
**Engine Notes**: None — no post-cutoff APIs.

**Control Manifest Rules (this layer — Presentation)**:
- Required: PascalCase `class_name` (`CardSwipeMath`), snake_case file name; stateless static utility (no instance vars, ever — same invariant as `ResourceFormulas`/`ActionUIFormatting`)
- Forbidden: any scene/Autoload dependency in this class — it must be pure functions of its arguments
- Guardrail: O(1) per call, negligible even if called per input event during a drag

---

## Acceptance Criteria

*From GDD `design/gdd/card-ui.md`'s Formulas + Acceptance Criteria sections, scoped to this story:*

**Rotation formula** — `rotation_degrees(drag_x, half_screen_width) = clamp(drag_x / half_screen_width, -1.0, 1.0) * MAX_TILT` (MAX_TILT = 12.0°):
- [ ] drag_x=0 → 0°
- [ ] drag_x=270, half_screen_width=540 → 6° (linear, mid-range)
- [ ] drag_x=540, half_screen_width=540 (ratio=1.0) → 12° (clamp boundary)
- [ ] drag_x=800, half_screen_width=540 (past edge) → 12° (clamped, not over-rotated)
- [ ] drag_x=-540 → -12°; drag_x=-900 → still -12° (clamped, symmetric)

**Commitment formula** — `is_committed(drag_x_at_release, velocity, screen_width) = absf(drag_x_at_release) >= 0.30 * screen_width OR absf(velocity) >= 800.0`:
- [ ] drag_x_at_release=324, velocity=0, screen_width=1080 (=0.30×1080 exactly) → true (inclusive boundary)
- [ ] drag_x_at_release=323, velocity=0, screen_width=1080 → false
- [ ] drag_x_at_release=50, velocity=800 → true (velocity alone suffices, exact boundary)
- [ ] drag_x_at_release=50, velocity=799 → false
- [ ] drag_x_at_release=400, velocity=100, screen_width=1080 → true (distance alone suffices)
- [ ] drag_x_at_release=100, velocity=200, screen_width=1080 → false (neither met)
- [ ] drag_x_at_release=-400, velocity=0, screen_width=1080 → true (absf applied, direction-agnostic)
- [ ] velocity=-850, drag_x_at_release=50 → true (absf applied to velocity)

---

## Implementation Notes

*Derived from ADR-0008's Decision §3:*

Create `res://src/ui/card_swipe_math.gd`, `class_name CardSwipeMath`, `extends RefCounted`, stateless — exactly the shape of `src/ui/action_ui_formatting.gd`. Two static functions plus the tuning constants:

```gdscript
class_name CardSwipeMath
extends RefCounted

## Max card tilt at full-width drag (GDD tuning knob: 8-15°; locked at 12).
const MAX_TILT_DEGREES: float = 12.0
## Fraction of screen width needed to confirm by distance (GDD tuning: 0.30).
const COMMIT_THRESHOLD_RATIO: float = 0.30
## Minimum release velocity (px/s) to confirm a fast short flick (GDD: 800).
const FLICK_VELOCITY_THRESHOLD: float = 800.0

static func rotation_degrees(drag_x: float, half_screen_width: float) -> float:
    var ratio: float = clampf(drag_x / half_screen_width, -1.0, 1.0)
    return ratio * MAX_TILT_DEGREES

static func is_committed(drag_x_at_release: float, velocity: float, screen_width: float) -> bool:
    var by_distance: bool = absf(drag_x_at_release) >= COMMIT_THRESHOLD_RATIO * screen_width
    var by_velocity: bool = absf(velocity) >= FLICK_VELOCITY_THRESHOLD
    return by_distance or by_velocity
```

Note: `half_screen_width > 0` is the caller's contract (a real screen always has positive width); do not add a divide-by-zero guard for a value that cannot legitimately be 0 in this context — same trust-the-caller stance as the other formula utilities. The commitment check's boundaries are **inclusive** (`>=`), per the GDD's exact-boundary ACs (324px and 800px/s both confirm).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 (Card Screen Modal): the modal scene, content display, DecisionCardSystem wiring — none of which this pure-math class touches
- Story 003 (Swipe Gesture): the gesture state machine, drag tracking, tweens, and the actual calls into these functions during a live drag — this story only provides the functions

---

## QA Test Cases

*Automated unit-test specs, derived directly from the GDD's exact numeric ACs.*

- **AC: rotation formula**
  - Given: each (drag_x, half_screen_width) pair from the ACs above
  - When: `CardSwipeMath.rotation_degrees(drag_x, half_screen_width)` is called
  - Then: result equals the listed degree value (±0.01)
  - Edge cases: the clamp boundaries (ratio exactly ±1.0 → ±12°) and past-edge over-drag (800/540 and -900/540 both clamp) are the critical assertions

- **AC: commitment formula**
  - Given: each (drag_x_at_release, velocity, screen_width) triple from the ACs above
  - When: `CardSwipeMath.is_committed(...)` is called
  - Then: result equals the listed bool
  - Edge cases: the exact inclusive boundaries (324px = 30% of 1080 → true; 323 → false; 800px/s → true; 799 → false) are the highest-risk off-by-one cases; the absf cases (negative distance, negative velocity) must confirm direction-agnosticism

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/card_ui/card_swipe_math_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 003 (Swipe Gesture Interaction) — calls these functions during a live drag
