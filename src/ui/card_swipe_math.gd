## CardSwipeMath is a stateless static utility holding Card UI's swipe
## display-math: the drag-rotation curve and the commitment-threshold check.
## Extracted into pure static functions (same precedent as ResourceFormulas /
## ActionUIFormatting) so they're unit-testable against the GDD's exact
## numeric acceptance criteria without a scene tree, per ADR-0008.
##
## Stateless-only invariant: never add instance vars or @export fields -- the
## gesture state machine (drag tracking, tweens, single-touch latch) lives in
## card_screen.gd, NOT here. This class is pure functions of its arguments.
##
## Performance: O(1) per call (a clamp/abs and a comparison), negligible even
## if called per input event during a live drag.
##
## Usage example:
##   var deg: float = CardSwipeMath.rotation_degrees(270.0, 540.0)  # -> 6.0
##   var go: bool = CardSwipeMath.is_committed(324.0, 0.0, 1080.0)  # -> true
class_name CardSwipeMath
extends RefCounted

## Max card tilt (degrees) at a full-width drag. GDD tuning knob: 8-15°,
## locked at 12. The rotation curve clamps the drag ratio to [-1, 1] before
## scaling by this, so output is always within [-MAX_TILT_DEGREES, +MAX_TILT_DEGREES].
const MAX_TILT_DEGREES: float = 12.0

## Fraction of screen width the card must be dragged to confirm by distance
## alone. GDD tuning knob: 0.30.
const COMMIT_THRESHOLD_RATIO: float = 0.30

## Minimum release velocity (px/s) that confirms a fast, short flick
## regardless of distance (the Tinder-style velocity OR-clause). GDD tuning
## knob: 800 px/s starting value.
const FLICK_VELOCITY_THRESHOLD: float = 800.0

## Returns the card's tilt in degrees for a horizontal drag of [param drag_x]
## px, per card-ui.md's rotation formula:
##
##   rotation = clamp(drag_x / half_screen_width, -1.0, 1.0) * MAX_TILT_DEGREES
##
## [param half_screen_width] is screen_width / 2 (>0 by the caller's contract --
## a real viewport always has positive width; this function does not guard
## against 0, trusting the caller, same stance as the other formula utilities).
## Over-dragging past the screen edge is clamped, never over-rotating beyond
## ±MAX_TILT_DEGREES.
##
## Usage example:
##   CardSwipeMath.rotation_degrees(540.0, 540.0)  # -> 12.0 (clamp boundary)
static func rotation_degrees(drag_x: float, half_screen_width: float) -> float:
	var ratio: float = clampf(drag_x / half_screen_width, -1.0, 1.0)
	return ratio * MAX_TILT_DEGREES

## Returns whether a release confirms the choice, per card-ui.md's commitment
## formula (distance OR velocity, Tinder-style):
##
##   is_committed = abs(drag_x_at_release) >= COMMIT_THRESHOLD_RATIO * screen_width
##                  OR abs(velocity) >= FLICK_VELOCITY_THRESHOLD
##
## Both boundaries are INCLUSIVE (>=) per the GDD's exact-boundary ACs: a
## release at exactly 30% of screen width, or at exactly the flick threshold,
## confirms. absf() is applied to both the displacement and the velocity, so
## the check is direction-agnostic (a left drag/flick confirms the same as a
## right one -- the calling gesture code decides which option the direction maps to).
##
## Usage example:
##   CardSwipeMath.is_committed(50.0, 800.0, 1080.0)  # -> true (velocity alone)
static func is_committed(drag_x_at_release: float, velocity: float, screen_width: float) -> bool:
	var by_distance: bool = absf(drag_x_at_release) >= COMMIT_THRESHOLD_RATIO * screen_width
	var by_velocity: bool = absf(velocity) >= FLICK_VELOCITY_THRESHOLD
	return by_distance or by_velocity
