## Unit tests for FeedbackMath (Juice/Feedback Story 001, TR-juice-001/003/004).
## Covers all 8 QA test cases embedded in the story file: the GDD's worked
## magnitude example, bounded linear ratios, unbounded log clamp, max-not-sum,
## zero-delta lowest-tier guarantees, sign-invariance (the no-valence-coding
## central guarantee — a registry forbidden pattern), tier boundaries at
## 0.3/0.7, and a deterministic fuzz clamp sweep (value grid, no RNG, per
## coding-standards.md determinism rules).
##
## FeedbackMath is a stateless static utility — no instance, no setup/teardown
## state, every test is a pure function call.
extends GdUnitTestSuite

## Preloaded (not the bare class_name) so the suite parses even before the
## editor has rescanned the global class cache — headless CI/CLI safety.
const FeedbackMath: GDScript = preload("res://src/ui/feedback_math.gd")


# --- AC-1: GDD worked example ---

func test_gdd_worked_example_returns_0_646() -> void:
	var deltas: Dictionary = {&"Cringe": 20.0, &"Morale": -3.0, &"Reach": 10.0}
	assert_float(FeedbackMath.magnitude(deltas)).is_equal_approx(0.646, 0.001)


func test_gdd_worked_example_individual_contributions() -> void:
	assert_float(FeedbackMath.magnitude({&"Cringe": 20.0})).is_equal_approx(0.571, 0.001)
	assert_float(FeedbackMath.magnitude({&"Morale": -3.0})).is_equal_approx(0.100, 0.001)
	assert_float(FeedbackMath.magnitude({&"Reach": 10.0})).is_equal_approx(0.646, 0.001)


# --- AC-2: bounded linear ratio ---

func test_bounded_cringe_full_norm_is_1() -> void:
	assert_float(FeedbackMath.magnitude({&"Cringe": 35.0})).is_equal_approx(1.0, 0.0001)


func test_bounded_cringe_half_norm_is_0_5() -> void:
	assert_float(FeedbackMath.magnitude({&"Cringe": 17.5})).is_equal_approx(0.5, 0.0001)


func test_bounded_morale_full_norm_is_1() -> void:
	assert_float(FeedbackMath.magnitude({&"Morale": 30.0})).is_equal_approx(1.0, 0.0001)


func test_bounded_over_norm_clamps_to_1() -> void:
	assert_float(FeedbackMath.magnitude({&"Cringe": 70.0})).is_equal_approx(1.0, 0.0001)


# --- AC-3: unbounded log clamp ---

func test_unbounded_reach_at_z_norm_ref_is_exactly_1() -> void:
	# log(1+40)/log(1+40) == 1.0 exactly.
	assert_float(FeedbackMath.magnitude({&"Reach": 40.0})).is_equal_approx(1.0, 0.0001)


func test_unbounded_huge_delta_clamps_to_1() -> void:
	assert_float(FeedbackMath.magnitude({&"Reach": 100000.0})).is_equal_approx(1.0, 0.0001)


# --- AC-4: max, not sum ---

func test_magnitude_is_max_of_contributions_not_sum() -> void:
	# Cringe 17.5 -> 0.5; Morale 15 -> 0.5. Sum would be 1.0; max must be 0.5.
	var deltas: Dictionary = {&"Cringe": 17.5, &"Morale": 15.0}
	assert_float(FeedbackMath.magnitude(deltas)).is_equal_approx(0.5, 0.0001)


# --- AC-5: zero deltas -> lowest tier still defined ---

func test_empty_deltas_magnitude_is_0() -> void:
	assert_float(FeedbackMath.magnitude({})).is_equal_approx(0.0, 0.0001)


func test_zero_delta_magnitude_is_0() -> void:
	assert_float(FeedbackMath.magnitude({&"Reach": 0.0})).is_equal_approx(0.0, 0.0001)


func test_zero_magnitude_lowest_tier_effects_still_defined() -> void:
	# TR-juice-004: never silently skipped — pulse still >= 1.02, one stinger
	# layer, but no shake (shake's absence at low tier IS the spec).
	assert_float(FeedbackMath.pulse_scale(0.0)).is_greater_equal(1.02)
	assert_float(FeedbackMath.shake_amplitude_px(0.0)).is_equal_approx(0.0, 0.0001)
	var params: Dictionary = FeedbackMath.stinger_params(0.0)
	assert_int(params["layers"]).is_equal(1)
	assert_float(params["tail_sec"]).is_equal_approx(0.08, 0.0001)
	assert_float(params["saturation"]).is_equal_approx(0.0, 0.0001)


# --- AC-6: sign-invariance (no-valence-coding, TR-juice-003) ---

func test_magnitude_is_sign_invariant() -> void:
	var grid: Array[Dictionary] = [
		{&"Cringe": 20.0},
		{&"Morale": 12.5},
		{&"Reach": 180.0},
		{&"Sponsors": 3.0},
		{&"Haters": 7.0},
		{&"Cringe": 35.0, &"Morale": 30.0, &"Reach": 220.0},
		{&"Cringe": 0.5, &"Reach": 1.0},
	]
	for deltas: Dictionary in grid:
		var negated: Dictionary = {}
		for key in deltas:
			negated[key] = -float(deltas[key])
		assert_float(FeedbackMath.magnitude(negated)).is_equal(FeedbackMath.magnitude(deltas))


func test_mixed_signs_equal_all_positive() -> void:
	var mixed: Dictionary = {&"Cringe": 20.0, &"Morale": -3.0, &"Reach": -10.0}
	var positive: Dictionary = {&"Cringe": 20.0, &"Morale": 3.0, &"Reach": 10.0}
	assert_float(FeedbackMath.magnitude(mixed)).is_equal(FeedbackMath.magnitude(positive))


# --- AC-7: tier boundaries ---

func test_shake_amplitude_tiers() -> void:
	# Values retuned 2026-07-06 (feel-test: 2-4/8px invisible under the pulse).
	assert_float(FeedbackMath.shake_amplitude_px(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(FeedbackMath.shake_amplitude_px(0.29)).is_equal_approx(0.0, 0.0001)
	assert_float(FeedbackMath.shake_amplitude_px(0.3)).is_equal_approx(6.0, 0.0001)  # mid tier floor (inclusive)
	assert_float(FeedbackMath.shake_amplitude_px(0.69)).is_less_equal(8.0)
	assert_float(FeedbackMath.shake_amplitude_px(0.7)).is_equal_approx(8.0, 0.0001)  # high tier floor
	assert_float(FeedbackMath.shake_amplitude_px(1.0)).is_equal_approx(12.0, 0.0001)  # cap


func test_shake_duration_tiers() -> void:
	assert_float(FeedbackMath.shake_duration_sec(0.29)).is_equal_approx(0.0, 0.0001)
	assert_float(FeedbackMath.shake_duration_sec(0.69)).is_less_equal(0.35)
	assert_float(FeedbackMath.shake_duration_sec(1.0)).is_equal_approx(0.40, 0.0001)  # cap


func test_pulse_scale_tier_ranges_and_monotonicity() -> void:
	# Range checks at tier edges per the story AC.
	assert_float(FeedbackMath.pulse_scale(0.0)).is_equal_approx(1.02, 0.0001)
	assert_float(FeedbackMath.pulse_scale(0.29)).is_less_equal(1.05)
	assert_float(FeedbackMath.pulse_scale(0.7)).is_equal_approx(1.10, 0.0001)
	assert_float(FeedbackMath.pulse_scale(1.0)).is_equal_approx(1.15, 0.0001)
	# Monotonically non-decreasing across a fine grid.
	var previous: float = 0.0
	for i in 101:
		var value: float = FeedbackMath.pulse_scale(float(i) / 100.0)
		assert_float(value).is_greater_equal(previous)
		previous = value


func test_stinger_layer_tiers() -> void:
	assert_int(FeedbackMath.stinger_params(0.29)["layers"]).is_equal(1)
	assert_int(FeedbackMath.stinger_params(0.3)["layers"]).is_equal(2)
	assert_int(FeedbackMath.stinger_params(0.69)["layers"]).is_equal(2)
	assert_int(FeedbackMath.stinger_params(0.7)["layers"]).is_equal(3)
	assert_int(FeedbackMath.stinger_params(1.0)["layers"]).is_equal(3)


# --- AC-8: deterministic fuzz clamp sweep ---

func test_fuzz_clamp_sweep_magnitude_always_in_unit_range() -> void:
	# Deterministic value grid (no RNG, per coding-standards.md): extreme and
	# tiny values across known keys, unknown keys, and mixed dictionaries.
	var values: Array[float] = [-1000000.0, -35.0, -0.001, 0.0, 0.001, 17.5, 40.0, 999.0, 1000000.0]
	var keys: Array[StringName] = [&"Cringe", &"Morale", &"Reach", &"Sponsors", &"Haters", &"FutureUnknownResource"]
	for key: StringName in keys:
		for value: float in values:
			var m: float = FeedbackMath.magnitude({key: value})
			assert_float(m).is_greater_equal(0.0)
			assert_float(m).is_less_equal(1.0)
	# Mixed extreme dictionary.
	var extreme: Dictionary = {&"Cringe": -1000000.0, &"Reach": 1000000.0, &"FutureUnknownResource": 42.0}
	var extreme_m: float = FeedbackMath.magnitude(extreme)
	assert_float(extreme_m).is_equal_approx(1.0, 0.0001)


func test_unknown_resource_key_treated_as_unbounded_never_crashes() -> void:
	# log(1+40)/log(1+40) == 1.0 — unknown key uses the unbounded formula.
	assert_float(FeedbackMath.magnitude({&"FutureUnknownResource": 40.0})).is_equal_approx(1.0, 0.0001)
