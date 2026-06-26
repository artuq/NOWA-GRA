## Unit tests for CardSwipeMath (Story 001, Card UI epic). Covers the rotation
## and commitment formulas against the GDD's exact numeric acceptance criteria.
## Pure static utility -- no scene tree or Autoload dependency, same pattern as
## ActionUIFormatting / ResourceFormulas.
extends GdUnitTestSuite

## AC: drag_x=0 -> 0 degrees.
func test_rotation_at_zero_drag_is_zero() -> void:
	assert_float(CardSwipeMath.rotation_degrees(0.0, 540.0)).is_equal_approx(0.0, 0.01)

## AC: drag_x=270, half=540 -> 6 degrees (linear mid-range).
func test_rotation_mid_range_is_linear() -> void:
	assert_float(CardSwipeMath.rotation_degrees(270.0, 540.0)).is_equal_approx(6.0, 0.01)

## AC: drag_x=540, half=540 (ratio=1.0) -> 12 degrees (clamp boundary).
func test_rotation_at_full_width_hits_max_tilt() -> void:
	assert_float(CardSwipeMath.rotation_degrees(540.0, 540.0)).is_equal_approx(12.0, 0.01)

## AC: drag_x=800 past the edge -> still 12 degrees (clamped, not over-rotated).
func test_rotation_past_edge_clamps_to_max() -> void:
	assert_float(CardSwipeMath.rotation_degrees(800.0, 540.0)).is_equal_approx(12.0, 0.01)

## AC: negative drag is symmetric and clamps to -12.
func test_rotation_negative_is_symmetric_and_clamped() -> void:
	assert_float(CardSwipeMath.rotation_degrees(-540.0, 540.0)).is_equal_approx(-12.0, 0.01)
	assert_float(CardSwipeMath.rotation_degrees(-900.0, 540.0)).is_equal_approx(-12.0, 0.01)

## AC: 324px at velocity 0 on a 1080 screen (=0.30x1080 exactly) -> committed
## (inclusive boundary).
func test_commitment_at_exact_distance_boundary_is_true() -> void:
	assert_bool(CardSwipeMath.is_committed(324.0, 0.0, 1080.0)).is_true()

## AC: 323px (one px under the boundary) -> not committed.
func test_commitment_one_px_under_distance_boundary_is_false() -> void:
	assert_bool(CardSwipeMath.is_committed(323.0, 0.0, 1080.0)).is_false()

## AC: 50px distance but velocity exactly 800px/s -> committed (velocity alone,
## inclusive boundary).
func test_commitment_at_exact_velocity_boundary_is_true() -> void:
	assert_bool(CardSwipeMath.is_committed(50.0, 800.0, 1080.0)).is_true()

## AC: velocity 799px/s (one under) with small distance -> not committed.
func test_commitment_one_under_velocity_boundary_is_false() -> void:
	assert_bool(CardSwipeMath.is_committed(50.0, 799.0, 1080.0)).is_false()

## AC: 400px distance with low velocity -> committed (distance alone suffices).
func test_commitment_distance_alone_suffices() -> void:
	assert_bool(CardSwipeMath.is_committed(400.0, 100.0, 1080.0)).is_true()

## AC: 100px + 200px/s -> neither condition met -> not committed.
func test_commitment_neither_condition_met_is_false() -> void:
	assert_bool(CardSwipeMath.is_committed(100.0, 200.0, 1080.0)).is_false()

## AC: -400px (left drag) at velocity 0 -> committed (absf applied to distance,
## direction-agnostic).
func test_commitment_negative_distance_is_direction_agnostic() -> void:
	assert_bool(CardSwipeMath.is_committed(-400.0, 0.0, 1080.0)).is_true()

## AC: -850px/s (left flick) with small distance -> committed (absf applied to
## velocity).
func test_commitment_negative_velocity_is_direction_agnostic() -> void:
	assert_bool(CardSwipeMath.is_committed(50.0, -850.0, 1080.0)).is_true()
