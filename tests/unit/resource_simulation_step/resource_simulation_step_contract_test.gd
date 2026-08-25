## Contract tests for the pure ResourceSimulationStep shared by live and
## offline resource progression. These tests deliberately use the shipped
## formula helpers as the oracle: the step owns sequencing and integration,
## not a second copy of the balance math.
extends GdUnitTestSuite

const STEP_SCRIPT: GDScript = preload("res://src/core/resource_simulation_step.gd")
const EPSILON: float = 0.000001


func _compute(
		cringe: float,
		haters: float,
		morale: float,
		elapsed_seconds: float,
		effective_buffer: int = ResourceFormulas.M_BUFFER,
		haters_multiplier: float = 1.0,
		meta_haters_resist: float = 0.0,
		morale_drain_multiplier: float = 1.0,
		morale_floor: float = 0.0,
		passive_income_multiplier: float = 1.0) -> Dictionary:
	return STEP_SCRIPT.compute(
		cringe,
		haters,
		morale,
		elapsed_seconds,
		effective_buffer,
		haters_multiplier,
		meta_haters_resist,
		morale_drain_multiplier,
		morale_floor,
		passive_income_multiplier
	)


## The order is a gameplay contract, not an implementation detail: Reach is
## calculated from post-growth Haters and the multiplier band selected from
## post-drain Morale.
func test_step_orders_haters_then_morale_then_multiplier_then_reach() -> void:
	var cringe: float = 50.0
	var haters_before: float = 10.0
	var morale_before: float = 40.1
	var elapsed_seconds: float = 60.0

	var result: Dictionary = _compute(cringe, haters_before, morale_before, elapsed_seconds)

	var expected_haters: float = haters_before + ResourceFormulas.haters_growth_rate(cringe)
	var expected_drain: float = ResourceFormulas.morale_drain_rate(int(expected_haters))
	var expected_morale: float = maxf(0.0, morale_before - expected_drain)
	var expected_multiplier: float = ResourceFormulas.action_effectiveness_multiplier(expected_morale)
	var expected_reach: float = ResourceFormulas.passive_zasiegi_income(
		expected_haters, expected_multiplier, elapsed_seconds
	)
	var pre_update_reach: float = ResourceFormulas.passive_zasiegi_income(
		haters_before,
		ResourceFormulas.action_effectiveness_multiplier(morale_before),
		elapsed_seconds
	)

	assert_float(expected_multiplier).is_equal_approx(0.75, EPSILON)
	assert_float(expected_reach).is_not_equal(pre_update_reach)
	assert_float(result["final_H"]).is_equal_approx(expected_haters, EPSILON)
	assert_float(result["final_M"]).is_equal_approx(expected_morale, EPSILON)
	assert_float(result["reach_gained"]).is_equal_approx(expected_reach, EPSILON)


## Ambient progression remains float-based end to end. Resource display may
## round later, but the simulation step must preserve fractional Haters,
## Morale and Reach so one-second live ticks do not leak value over time.
func test_step_preserves_fractional_values_without_rounding() -> void:
	var cringe: float = 33.0
	var haters_before: float = 7.75
	var morale_before: float = 63.25
	var elapsed_seconds: float = 17.5

	var result: Dictionary = _compute(cringe, haters_before, morale_before, elapsed_seconds)
	var elapsed_minutes: float = elapsed_seconds / 60.0
	var expected_haters: float = haters_before \
		+ ResourceFormulas.haters_growth_rate(cringe) * elapsed_minutes
	var expected_drain: float = ResourceFormulas.morale_drain_rate(int(expected_haters)) \
		* elapsed_minutes
	var expected_morale: float = maxf(0.0, morale_before - expected_drain)
	var expected_reach: float = ResourceFormulas.passive_zasiegi_income(
		expected_haters,
		ResourceFormulas.action_effectiveness_multiplier(expected_morale),
		elapsed_seconds
	)

	assert_float(result["final_H"]).is_equal_approx(expected_haters, EPSILON)
	assert_float(result["final_M"]).is_equal_approx(expected_morale, EPSILON)
	assert_float(result["reach_gained"]).is_equal_approx(expected_reach, EPSILON)
	assert_float(result["final_H"]).is_not_equal(roundf(result["final_H"]))
	assert_float(result["final_M"]).is_not_equal(roundf(result["final_M"]))
	assert_float(result["reach_gained"]).is_not_equal(roundf(result["reach_gained"]))


## An ambient floor blocks downward drain from crossing it, but never grants
## free Morale when the player is already below the floor at step start.
func test_morale_floor_never_raises_morale_already_below_it() -> void:
	var morale_before: float = 20.0
	var result: Dictionary = _compute(
		100.0,
		100.0,
		morale_before,
		60.0,
		ResourceFormulas.M_BUFFER,
		1.0,
		0.0,
		1.0,
		40.0
	)

	assert_float(result["final_M"]).is_equal_approx(morale_before, EPSILON)


## Included growth/drain/income factors compose multiplicatively inside the
## pure step and are applied to their own axes only.
func test_step_composes_explicit_growth_drain_and_income_factors() -> void:
	var cringe: float = 80.0
	var haters_before: float = 12.0
	var morale_before: float = 80.0
	var elapsed_seconds: float = 60.0
	var haters_multiplier: float = 0.5 * 1.75
	var meta_haters_resist: float = 0.20
	var morale_drain_multiplier: float = 0.8
	var passive_income_multiplier: float = 1.4

	var result: Dictionary = _compute(
		cringe,
		haters_before,
		morale_before,
		elapsed_seconds,
		ResourceFormulas.M_BUFFER,
		haters_multiplier,
		meta_haters_resist,
		morale_drain_multiplier,
		0.0,
		passive_income_multiplier
	)
	var expected_rate: float = PrestigeFormulas.haters_rate_final(
		ResourceFormulas.haters_growth_rate(cringe), meta_haters_resist
	) * haters_multiplier
	var expected_haters: float = haters_before + expected_rate
	var expected_morale: float = morale_before \
		- ResourceFormulas.morale_drain_rate(int(expected_haters)) * morale_drain_multiplier
	var expected_reach: float = ResourceFormulas.passive_zasiegi_income(
		expected_haters,
		ResourceFormulas.action_effectiveness_multiplier(expected_morale),
		elapsed_seconds
	) * passive_income_multiplier

	assert_float(result["final_H"]).is_equal_approx(expected_haters, EPSILON)
	assert_float(result["final_M"]).is_equal_approx(expected_morale, EPSILON)
	assert_float(result["reach_gained"]).is_equal_approx(expected_reach, EPSILON)
