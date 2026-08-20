extends GdUnitTestSuite

const BASE_CONTEXT: Dictionary = {
	"Reach": 100.0,
	"Cringe": 50.0,
	"Haters": 20.0,
	"Morale": 80.0,
	"Sponsors": 3.0,
	"shield_seconds": 0,
	"shield_buffer": 3,
	"base_buffer": 3,
	"haters_multiplier": 1.0,
	"meta_haters_resist": 0.0,
	"assistant_multiplier": 1.0,
	"morale_drain_multiplier": 1.0,
	"morale_floor": 0.0,
	"sponsor_income_multiplier": 1.0,
	"meta_sponsor_bonus": 0.0,
}

var _resources_before: Dictionary = {}
var _algorithm_before: Dictionary = {}


func before_test() -> void:
	_resources_before = ResourceManager.serialize_state()
	_algorithm_before = AlgorithmContractSystem.serialize_state()
	AlgorithmContractSystem.reset_for_new_game()


func after_test() -> void:
	ResourceManager.restore_state(_resources_before)
	AlgorithmContractSystem.restore_state(_algorithm_before)
	for child: Node in SaveSystem.get_children():
		if child is Timer:
			(child as Timer).stop()


func test_drama_is_neutral_simulation_with_exact_haters_rate_multiplier() -> void:
	var neutral: Dictionary = OfflineProgressSystem.simulate_from_context(BASE_CONTEXT, 3600)
	var drama: Dictionary = OfflineProgressSystem.simulate_contract_from_context(
		BASE_CONTEXT, 3600, AlgorithmContractSystem.get_contract_definition(&"drama")
	)
	var neutral_growth: float = float(neutral["final"]["Haters"]) - BASE_CONTEXT["Haters"]
	var drama_growth: float = float(drama["final"]["Haters"]) - BASE_CONTEXT["Haters"]
	assert_float(drama_growth).is_equal_approx(neutral_growth * 1.5, 0.001)


func test_business_pauses_reach_and_haters_and_keeps_fixed_point_carry() -> void:
	var business: Dictionary = OfflineProgressSystem.simulate_contract_from_context(
		BASE_CONTEXT, 3600, AlgorithmContractSystem.get_contract_definition(&"business"), 0
	)
	assert_float(business["final"]["Reach"]).is_equal_approx(100.0, 0.001)
	assert_float(business["final"]["Haters"]).is_equal_approx(20.0, 0.001)
	assert_float(business["final"]["Sponsors"]).is_equal_approx(4.0, 0.001)
	assert_int(business["business_remainder_units"]).is_equal(500)
	assert_float(business["final"]["Morale"]).is_less(80.0)


func test_detox_clamps_haters_and_morale_and_produces_no_reach() -> void:
	var detox: Dictionary = OfflineProgressSystem.simulate_contract_from_context(
		BASE_CONTEXT, 7200, AlgorithmContractSystem.get_contract_definition(&"detox")
	)
	assert_float(detox["final"]["Haters"]).is_equal_approx(0.0, 0.001)
	assert_float(detox["final"]["Morale"]).is_equal_approx(100.0, 0.001)
	assert_float(detox["final"]["Reach"]).is_equal_approx(100.0, 0.001)


func test_short_absence_does_not_consume_armed_contract() -> void:
	assert_bool(AlgorithmContractSystem.arm_contract(&"drama")).is_true()
	assert_dict(AlgorithmContractSystem.stage_return(299, BASE_CONTEXT)).is_empty()
	assert_that(AlgorithmContractSystem.get_armed_contract_id()).is_equal(&"drama")
	assert_int(AlgorithmContractSystem.contract_credits).is_equal(0)


func test_failed_save_retry_never_applies_staged_result_twice() -> void:
	ResourceManager.restore_state({"Reach": 100.0, "Cringe": 50.0, "Haters": 20.0, "Morale": 80.0, "Sponsors": 3.0})
	assert_bool(AlgorithmContractSystem.arm_contract(&"detox")).is_true()
	assert_dict(AlgorithmContractSystem.stage_return(3600, BASE_CONTEXT)).is_not_empty()
	assert_bool(AlgorithmContractSystem.commit_staged_return(func() -> bool: return false)).is_false()
	var after_first: Dictionary = ResourceManager.serialize_state()
	assert_bool(AlgorithmContractSystem.commit_staged_return(func() -> bool: return false)).is_false()
	assert_dict(ResourceManager.serialize_state()).is_equal(after_first)
	assert_int(AlgorithmContractSystem.contract_credits).is_equal(1)
	assert_bool(AlgorithmContractSystem.commit_staged_return(func() -> bool: return true)).is_true()
	assert_dict(ResourceManager.serialize_state()).is_equal(after_first)


func test_ladder_requires_all_three_gates_and_never_decreases() -> void:
	var ladder: Array[Dictionary] = [
		{"rung": 1, "eras": 0, "mastery": 0, "contracts": 0},
		{"rung": 2, "eras": 1, "mastery": 1, "contracts": 2},
		{"rung": 3, "eras": 2, "mastery": 3, "contracts": 5},
	]
	assert_int(AlgorithmContractSystem.derive_rung(1, 1, 1, ladder)).is_equal(1)
	assert_int(AlgorithmContractSystem.derive_rung(1, 1, 2, ladder)).is_equal(2)
	assert_int(AlgorithmContractSystem.derive_rung(0, 0, 0, ladder, 2)).is_equal(2)


func test_burnout_clears_plan_and_business_carry_but_preserves_empire() -> void:
	AlgorithmContractSystem.arm_contract(&"business")
	AlgorithmContractSystem.business_remainder_units = 777
	AlgorithmContractSystem.contract_credits = 8
	AlgorithmContractSystem.stored_rung = 3
	AlgorithmContractSystem.clear_for_burnout()
	assert_that(AlgorithmContractSystem.get_armed_contract_id()).is_equal(&"")
	assert_int(AlgorithmContractSystem.business_remainder_units).is_equal(0)
	assert_int(AlgorithmContractSystem.contract_credits).is_equal(8)
	assert_int(AlgorithmContractSystem.stored_rung).is_equal(3)


func test_new_game_clears_every_contract_and_empire_field() -> void:
	AlgorithmContractSystem.arm_contract(&"drama")
	AlgorithmContractSystem.business_remainder_units = 500
	AlgorithmContractSystem.contract_credits = 12
	AlgorithmContractSystem.stored_rung = 4
	AlgorithmContractSystem.reset_for_new_game()
	assert_that(AlgorithmContractSystem.get_armed_contract_id()).is_equal(&"")
	assert_int(AlgorithmContractSystem.business_remainder_units).is_equal(0)
	assert_int(AlgorithmContractSystem.contract_credits).is_equal(0)
	assert_int(AlgorithmContractSystem.stored_rung).is_equal(1)


func test_invalid_saved_contract_is_not_replaced_with_current_tuning() -> void:
	AlgorithmContractSystem.restore_state({
		"armed_contract": {"id": "business", "revision": 99, "terms": {"sponsors_per_hour": 999.0}},
		"business_remainder_units": 321,
		"contract_credits": 4,
		"stored_rung": 2,
	})
	assert_that(AlgorithmContractSystem.get_armed_contract_id()).is_equal(&"")
	assert_int(AlgorithmContractSystem.business_remainder_units).is_equal(321)
	assert_int(AlgorithmContractSystem.contract_credits).is_equal(4)
	assert_int(AlgorithmContractSystem.stored_rung).is_equal(2)


func test_contract_time_is_capped_once_at_24_hours() -> void:
	var detox: Dictionary = OfflineProgressSystem.simulate_contract_from_context(
		BASE_CONTEXT, 86401, AlgorithmContractSystem.get_contract_definition(&"detox")
	)
	assert_bool(detox["capped"]).is_true()
	assert_int(detox["counted_seconds"]).is_equal(86400)


func test_negative_clock_delta_clamps_to_zero() -> void:
	assert_int(BootController.compute_elapsed_seconds({"last_saved_at": 2000.0}, 1000.0)).is_equal(0)
