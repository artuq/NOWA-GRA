## Unit tests for OfflineProgressSystem.simulate_offline() (Story 001,
## TR-off-001/ADR-0006). Covers cap behavior, stepped H/M/Z evolution against
## the GDD's worked example, Cringe constancy, and the defined edge cases.
##
## simulate_offline() reads ResourceManager's current Cringe/Haters/Morale at
## call time and does not write back -- each test snapshots and restores
## ResourceManager state so cases don't leak into each other, same pattern as
## the Resource System epic's formula tests.
extends GdUnitTestSuite

var _resource_snapshot: Dictionary[StringName, float] = {}

func before_test() -> void:
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Haters"] = ResourceManager.get_resource(&"Haters")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")

func after_test() -> void:
	# See cooldown_pool_test.gd's after_test() comment: stop the real
	# SaveSystem's debounce timer (armed by apply_delta below) so a delayed
	# save_now() can't fire mid-suite.
	SaveSystem._debounce_timer.stop()
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	SaveSystem._debounce_timer.stop()  # the restore above re-arms it

func _set_resources(cringe: float, haters: float, morale: float) -> void:
	var delta: Dictionary[StringName, float] = {
		&"Cringe": cringe - ResourceManager.get_resource(&"Cringe"),
		&"Haters": haters - ResourceManager.get_resource(&"Haters"),
		&"Morale": morale - ResourceManager.get_resource(&"Morale"),
	}
	ResourceManager.apply_delta(delta)

## AC: zero-duration edge case -- no gain, no error, returns immediately.
func test_zero_elapsed_seconds_produces_zero_gain() -> void:
	_set_resources(50.0, 5.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(0)

	assert_float(result["total_Z_gained"]).is_equal_approx(0.0, 0.0001)
	assert_float(result["final_H"]).is_equal_approx(5.0, 0.0001)
	assert_float(result["final_M"]).is_equal_approx(80.0, 0.0001)
	assert_bool(result["capped"]).is_false()

## AC: cap boundary is inclusive -- exactly 86400s runs all 1440 steps, not capped.
func test_elapsed_at_cap_boundary_is_not_capped() -> void:
	_set_resources(50.0, 5.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(86400)

	assert_bool(result["capped"]).is_false()

## AC: one second past the cap boundary -- capped, and produces the same
## result as a standalone 86400s run (deterministic, reproducible).
func test_elapsed_one_second_past_cap_matches_capped_run() -> void:
	_set_resources(50.0, 5.0, 80.0)
	var capped_result: Dictionary = OfflineProgressSystem.simulate_offline(86400)

	_set_resources(50.0, 5.0, 80.0)
	var over_result: Dictionary = OfflineProgressSystem.simulate_offline(86401)

	assert_bool(over_result["capped"]).is_true()
	assert_float(over_result["final_H"]).is_equal_approx(capped_result["final_H"], 0.0001)
	assert_float(over_result["final_M"]).is_equal_approx(capped_result["final_M"], 0.0001)
	assert_float(over_result["total_Z_gained"]).is_equal_approx(capped_result["total_Z_gained"], 0.0001)

## AC: well past the cap (200,000s) -- still capped, same bounded result.
func test_elapsed_far_past_cap_is_capped() -> void:
	_set_resources(50.0, 5.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(200000)

	assert_bool(result["capped"]).is_true()

## AC: a partial final step (90s = 1.5 steps) is handled correctly -- the
## second step uses dt=30, not a full dt=60. Verified indirectly: H growth
## over 90s must be strictly less than 2x a single 60s step's growth and
## strictly more than 1x (since 90s = 1 full step + a half step).
func test_partial_final_step_is_handled() -> void:
	_set_resources(50.0, 0.0, 100.0)
	var one_step: Dictionary = OfflineProgressSystem.simulate_offline(60)

	_set_resources(50.0, 0.0, 100.0)
	var one_and_half_steps: Dictionary = OfflineProgressSystem.simulate_offline(90)

	var growth_per_step: float = one_step["final_H"]
	assert_float(one_and_half_steps["final_H"]).is_greater(growth_per_step)
	assert_float(one_and_half_steps["final_H"]).is_less(growth_per_step * 2.0)

## AC: Cringe constancy -- the fixed Cringe value used in step 1 is the same
## value used in the final step (no Cringe drift across a 24h simulation).
## Verified indirectly via the GDD's worked example: H grows linearly under a
## constant H_rate(Cringe), so a non-constant Cringe would produce a
## final_H that deviates from the linear-growth prediction.
func test_cringe_held_constant_across_full_simulation() -> void:
	_set_resources(50.0, 5.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(86400)

	var expected_h_rate: float = ResourceFormulas.haters_growth_rate(50.0)
	var expected_final_h: float = 5.0 + expected_h_rate * 1440.0
	assert_float(result["final_H"]).is_equal_approx(expected_final_h, expected_final_h * 0.02)

## AC: worked example -- Cringe=50, H0=5, M0=80%, 24h offline.
## GDD expects final_H≈394 (±2%), final_M≈0% (±1pp), total_Z_gained within
## 28,000-29,000.
func test_worked_example_matches_gdd_expected_values() -> void:
	_set_resources(50.0, 5.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(86400)

	assert_float(result["final_H"]).is_equal_approx(394.0, 394.0 * 0.02)
	assert_float(result["final_M"]).is_between(0.0, 1.0)
	assert_float(result["total_Z_gained"]).is_between(28000.0, 29000.0)

## AC: H0=0 -- still increases per the same formula, no special-case branch,
## no division-by-zero/NaN/negative outputs anywhere.
func test_zero_starting_haters_produces_finite_nonnegative_growth() -> void:
	_set_resources(50.0, 0.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(86400)

	assert_float(result["final_H"]).is_greater(0.0)
	assert_bool(is_nan(result["final_H"])).is_false()
	assert_bool(is_nan(result["final_M"])).is_false()
	assert_bool(is_nan(result["total_Z_gained"])).is_false()
	assert_float(result["final_M"]).is_greater_equal(0.0)
	assert_float(result["total_Z_gained"]).is_greater_equal(0.0)

## AC: Morale floors at 0 and stays there -- once M reaches 0 before the
## final step, Mult(M)=0.5x applies for all remaining steps (intentional,
## not a bug). Verified by confirming final_M is exactly 0, not negative.
func test_morale_floors_at_zero_when_drain_exceeds_remaining_morale() -> void:
	_set_resources(100.0, 500.0, 10.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(86400)

	assert_float(result["final_M"]).is_equal_approx(0.0, 0.0001)

## AC: M0=0% at start -- Mult(M)=0.5x from step 1 onward. Verified indirectly:
## total_Z_gained for an M0=0 run must be exactly half of an otherwise-identical
## M0=100 run that never drains (held via a Haters count too low to drain Morale).
func test_zero_starting_morale_applies_critical_multiplier_from_first_step() -> void:
	_set_resources(0.0, 1.0, 0.0)
	var critical_result: Dictionary = OfflineProgressSystem.simulate_offline(60)

	_set_resources(0.0, 1.0, 100.0)
	var full_result: Dictionary = OfflineProgressSystem.simulate_offline(60)

	# Haters count (1) is below M_BUFFER (3), so Morale never drains in either
	# run -- the only difference between the two is the starting multiplier
	# band (Critical 0.5x vs Full 1.0x), isolating the AC under test.
	assert_float(critical_result["total_Z_gained"]).is_equal_approx(full_result["total_Z_gained"] * 0.5, 0.001)

## AC: a single step's Z calculation must use the POST-update H and M, not
## the step's starting values -- the fixed H-then-M-then-Mult-then-Z order is
## not optional. Verified by computing the step by hand under both orderings
## and confirming the implementation matches only the correct (post-update)
## one. Chosen inputs (H0=10, well above M_BUFFER=3) guarantee a nonzero
## M_drain, so the two orderings produce numerically different Z values.
func test_single_step_uses_post_update_h_and_m_for_zasiegi() -> void:
	var cringe: float = 50.0
	var h0: float = 10.0
	var m0: float = 80.0
	_set_resources(cringe, h0, m0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(60)

	var h_rate: float = ResourceFormulas.haters_growth_rate(cringe)
	var h1: float = h0 + h_rate * 1.0
	var m_drain: float = ResourceFormulas.morale_drain_rate(int(h1))
	var m1: float = max(0.0, m0 - m_drain * 1.0)
	var mult_post_update: float = ResourceFormulas.action_effectiveness_multiplier(m1)
	var z_correct_order: float = ResourceFormulas.passive_zasiegi_income(h1, mult_post_update, 60.0)

	var mult_pre_update: float = ResourceFormulas.action_effectiveness_multiplier(m0)
	var z_wrong_order: float = ResourceFormulas.passive_zasiegi_income(h0, mult_pre_update, 60.0)

	# Sanity check: the two orderings must actually differ for this test to
	# prove anything -- otherwise a reordering bug could pass silently.
	assert_float(z_correct_order).is_not_equal(z_wrong_order)
	assert_float(result["total_Z_gained"]).is_equal_approx(z_correct_order, 0.0001)

## AC: while H is at or below M_BUFFER (3), Morale does not drain for that
## step -- the buffer threshold itself, not just an incidental low-H case.
## Single-step window: H0=3 grows by under 0.3 over one 60s step (Cringe=50 ->
## H_rate~0.27/min), so post-update H (~3.27, truncated to 3 by int()) stays
## at the buffer for this one step -- a longer run would let H grow past the
## buffer and start draining, which is a separate, already-covered case.
func test_morale_does_not_drain_while_haters_at_or_below_buffer() -> void:
	_set_resources(50.0, 3.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(60)

	assert_float(result["final_M"]).is_equal_approx(80.0, 0.0001)

## Observable side effect: last_simulation_result is set to the same
## Dictionary returned by the call -- documented contract for a future
## Offline Report Screen (ADR-0003), read-once and never serialized.
func test_last_simulation_result_is_set_after_call() -> void:
	_set_resources(50.0, 5.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(600)

	assert_dict(OfflineProgressSystem.last_simulation_result).is_equal(result)

## Smallest nonzero duration (Δt=1s) -- a single partial step, dt_minutes
## far below 1.0, must still produce finite, non-negative, non-NaN output.
func test_one_second_elapsed_produces_finite_output() -> void:
	_set_resources(50.0, 5.0, 80.0)

	var result: Dictionary = OfflineProgressSystem.simulate_offline(1)

	assert_bool(result["capped"]).is_false()
	assert_bool(is_nan(result["final_H"])).is_false()
	assert_float(result["final_H"]).is_greater_equal(5.0)
	assert_float(result["total_Z_gained"]).is_greater_equal(0.0)
