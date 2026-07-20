## Unit tests for ChallengeSystem's catalogue fidelity, selection storage, and
## restore_state()/serialize_state() pair (Burnout & Challenge System, Story
## 005, TR-pcs-007, ADR-0013). Covers all 5 Acceptance Criteria from
## story-005-challenge-catalogue-storage.md's QA Test Cases:
## AC-1 (catalogue fidelity), AC-2 (selection storage), AC-3 (max-active cap
## rejection), AC-4 (round-trip persistence, order preserved), AC-5
## (missing-key default).
##
## ChallengeSystem is normally an Autoload singleton, but for test isolation
## each test instantiates a fresh instance directly from the script (never
## added to the scene tree) -- same "drive the method directly, not the
## engine loop" technique tests/unit/burnout/burnout_persistence_test.gd
## already established. None of this suite's methods touch signals, the
## scene tree, or any other Autoload, so no setup/teardown beyond a fresh
## instance per test is needed.
extends GdUnitTestSuite

const ChallengeSystemScript: GDScript = preload("res://src/core/challenge_system.gd")

var _cs: Node


func before_test() -> void:
	_cs = ChallengeSystemScript.new()


func after_test() -> void:
	if is_instance_valid(_cs):
		_cs.free()


# --- AC-1: catalogue fidelity ---

func test_ac1_brak_duszy_matches_quick_spec_table_exactly() -> void:
	var data: Dictionary = _cs.get_challenge_data(&"brak_duszy")

	assert_that(data["modifier_type"]).is_equal(&"reach_multiplier")
	assert_float(data["modifier_value"]).is_equal_approx(0.3, 0.0001)
	assert_array(data["applies_to"]).is_equal([&"nagraj_vloga"])
	assert_float(data["meta_bonus_multiplier"]).is_equal_approx(2.0, 0.0001)


func test_ac1_drama_bez_granic_matches_quick_spec_table_exactly() -> void:
	var data: Dictionary = _cs.get_challenge_data(&"drama_bez_granic")

	assert_that(data["modifier_type"]).is_equal(&"cringe_multiplier")
	assert_float(data["modifier_value"]).is_equal_approx(2.0, 0.0001)
	assert_array(data["applies_to"]).is_equal([&"zrob_drame"])
	assert_float(data["meta_bonus_multiplier"]).is_equal_approx(2.5, 0.0001)


func test_ac1_przepros_na_niby_matches_quick_spec_table_exactly() -> void:
	var data: Dictionary = _cs.get_challenge_data(&"przepros_na_niby")

	assert_that(data["modifier_type"]).is_equal(&"cringe_multiplier")
	assert_float(data["modifier_value"]).is_equal_approx(0.3, 0.0001)
	assert_array(data["applies_to"]).is_equal([&"przepros_w_internecie"])
	assert_float(data["meta_bonus_multiplier"]).is_equal_approx(1.8, 0.0001)


## bez_tlumu's applies_to is the literal String "all", not an array -- distinct
## from the other 4 challenges, per the quick-spec's own table row.
func test_ac1_bez_tlumu_matches_quick_spec_table_exactly_including_all_applies_to() -> void:
	var data: Dictionary = _cs.get_challenge_data(&"bez_tlumu")

	assert_that(data["modifier_type"]).is_equal(&"reach_multiplier")
	assert_float(data["modifier_value"]).is_equal_approx(0.5, 0.0001)
	assert_str(data["applies_to"]).is_equal("all")
	assert_float(data["meta_bonus_multiplier"]).is_equal_approx(3.0, 0.0001)


func test_ac1_wypalony_ale_core_matches_quick_spec_table_exactly() -> void:
	var data: Dictionary = _cs.get_challenge_data(&"wypalony_ale_core")

	assert_that(data["modifier_type"]).is_equal(&"morale_multiplier")
	assert_float(data["modifier_value"]).is_equal_approx(0.6, 0.0001)
	assert_array(data["applies_to"]).is_equal([&"przepros_w_internecie"])
	assert_float(data["meta_bonus_multiplier"]).is_equal_approx(2.0, 0.0001)


func test_ac1_unknown_challenge_id_returns_empty_dictionary() -> void:
	var data: Dictionary = _cs.get_challenge_data(&"not_a_real_challenge")

	assert_dict(data).is_empty()


# --- AC-2: selection storage ---

func test_ac2_select_challenges_stores_exact_ids_and_returns_true() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"bez_tlumu"]
	var result: bool = _cs.select_challenges(ids)

	assert_bool(result).is_true()
	assert_array(_cs.get_active_challenge_ids()).is_equal([&"brak_duszy", &"bez_tlumu"])


func test_ac2_select_challenges_empty_array_is_a_valid_normal_run_selection() -> void:
	var ids: Array[StringName] = []
	var result: bool = _cs.select_challenges(ids)

	assert_bool(result).is_true()
	assert_array(_cs.get_active_challenge_ids()).is_empty()


# --- AC-3: max-active cap rejection ---

func test_ac3_selecting_more_than_max_active_is_rejected() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"drama_bez_granic", &"przepros_na_niby", &"bez_tlumu"]
	var result: bool = _cs.select_challenges(ids)

	assert_bool(result).is_false()


## Edge case (QA Test Cases AC-3): a rejected over-cap selection must not
## partially update _active_challenge_ids -- the prior selection stays intact.
func test_ac3_rejected_selection_leaves_prior_selection_unchanged() -> void:
	var prior_ids: Array[StringName] = [&"brak_duszy"]
	_cs.select_challenges(prior_ids)

	var over_cap_ids: Array[StringName] = [&"brak_duszy", &"drama_bez_granic", &"przepros_na_niby", &"bez_tlumu"]
	var result: bool = _cs.select_challenges(over_cap_ids)

	assert_bool(result).is_false()
	assert_array(_cs.get_active_challenge_ids()).is_equal([&"brak_duszy"])


func test_ac3_selecting_exactly_max_active_is_accepted() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"drama_bez_granic", &"przepros_na_niby"]
	var result: bool = _cs.select_challenges(ids)

	assert_bool(result).is_true()
	assert_int(_cs.get_active_challenge_ids().size()).is_equal(3)


# --- AC-4: round-trip persistence, order preserved ---

func test_ac4_round_trip_preserves_ids_and_order_on_fresh_instance() -> void:
	var ids: Array[StringName] = [&"drama_bez_granic", &"przepros_na_niby"]
	_cs.select_challenges(ids)

	var saved: Dictionary = _cs.serialize_state()

	var fresh: Node = ChallengeSystemScript.new()
	fresh.restore_state(saved)

	assert_array(fresh.get_active_challenge_ids()).is_equal([&"drama_bez_granic", &"przepros_na_niby"])
	fresh.free()


# --- AC-5: missing-key default ---

func test_ac5_restore_state_empty_dictionary_defaults_to_empty_array() -> void:
	_cs.restore_state({})

	assert_array(_cs.get_active_challenge_ids()).is_empty()


## Edge case: restore_state() must clear any pre-existing selection before
## applying the input, not merge/append onto it.
func test_ac5_restore_state_replaces_not_appends_to_existing_selection() -> void:
	var ids: Array[StringName] = [&"brak_duszy"]
	_cs.select_challenges(ids)

	_cs.restore_state({"_active_challenge_ids": ["bez_tlumu"]})

	assert_array(_cs.get_active_challenge_ids()).is_equal([&"bez_tlumu"])
