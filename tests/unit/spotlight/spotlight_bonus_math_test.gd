extends GdUnitTestSuite

const SpotlightBonusMathScript: GDScript = preload("res://src/core/spotlight_bonus_math.gd")


func test_zero_score_returns_minimum_reward() -> void:
	assert_int(SpotlightBonusMathScript.curved_reward(30.0, 220.0, 0.0, 1.5)).is_equal(30)


func test_perfect_score_returns_maximum_reward() -> void:
	assert_int(SpotlightBonusMathScript.curved_reward(30.0, 220.0, 1.0, 1.5)).is_equal(220)


func test_half_score_uses_declared_curve() -> void:
	var expected: int = roundi(30.0 + 190.0 * pow(0.5, 1.5))
	assert_int(SpotlightBonusMathScript.curved_reward(30.0, 220.0, 0.5, 1.5)).is_equal(expected)


func test_score_is_clamped_at_both_boundaries() -> void:
	assert_int(SpotlightBonusMathScript.curved_reward(30.0, 220.0, -4.0, 1.5)).is_equal(30)
	assert_int(SpotlightBonusMathScript.curved_reward(30.0, 220.0, 4.0, 1.5)).is_equal(220)


func test_non_finite_score_returns_zero() -> void:
	assert_int(SpotlightBonusMathScript.curved_reward(30.0, 220.0, NAN, 1.5)).is_equal(0)


func test_invalid_reward_range_returns_zero() -> void:
	assert_int(SpotlightBonusMathScript.curved_reward(220.0, 30.0, 0.5, 1.5)).is_equal(0)


func test_invalid_exponent_returns_zero() -> void:
	assert_int(SpotlightBonusMathScript.curved_reward(30.0, 220.0, 0.5, 0.0)).is_equal(0)
