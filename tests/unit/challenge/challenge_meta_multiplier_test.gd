## Unit tests for ChallengeSystem.get_combined_meta_multiplier() (Burnout &
## Challenge System, Story 007, TR-pcs-007, ADR-0013). Isolates the pure
## catalogue-product logic from PrestigeSystem's wiring -- Story 007's own
## integration suite (tests/integration/prestige/prestige_challenge_
## multiplier_wiring_test.gd) already proves the real on_burnout_accepted()
## call site uses this getter's return value correctly at 0 and 2 active
## challenges, but never exercised the single-challenge case in isolation
## (code-review finding, 2026-07-20).
##
## Unlike its sibling get_modifier() (Story 006), this getter has NO
## CHALLENGE_MODIFIER_FLOOR-style clamp -- confirmed correct, not an
## oversight: get_modifier() protects a single reward axis from being zeroed
## by a misconfigured entry, while this getter feeds a GRANT multiplier
## (PrestigeFormulas.grant_magnitude()'s pow(challenge_mult, ...) term) that
## is meant to scale up, never down toward zero, by design (every real
## catalogue entry's meta_bonus_multiplier is > 1.0).
##
## Same "instantiate a fresh instance, never add_child()" technique
## challenge_selection_storage_test.gd (Story 005) already established for
## this exact class.
extends GdUnitTestSuite

const ChallengeSystemScript: GDScript = preload("res://src/core/challenge_system.gd")

var _cs: Node


func before_test() -> void:
	_cs = ChallengeSystemScript.new()


func after_test() -> void:
	if is_instance_valid(_cs):
		_cs.free()


func test_no_active_challenges_returns_one() -> void:
	var ids: Array[StringName] = []
	_cs.select_challenges(ids)

	assert_float(_cs.get_combined_meta_multiplier()).is_equal_approx(1.0, 0.0001)


## The gap the code review flagged: only 0- and 2-challenge cases were
## previously exercised (via the integration suite), never exactly one.
func test_single_active_challenge_returns_its_own_meta_bonus_multiplier() -> void:
	var ids: Array[StringName] = [&"brak_duszy"]
	_cs.select_challenges(ids)

	assert_float(_cs.get_combined_meta_multiplier()).is_equal_approx(2.0, 0.0001)


func test_two_active_challenges_multiply_not_add() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"drama_bez_granic"]
	_cs.select_challenges(ids)

	# 2.0 * 2.5 = 5.0, not 4.5 (which addition would produce) -- same
	# worked example story-007-meta-multiplier-pull.md's own AC-2 uses.
	assert_float(_cs.get_combined_meta_multiplier()).is_equal_approx(5.0, 0.0001)


## All 5 real catalogue entries active simultaneously would exceed
## CHALLENGE_MAX_ACTIVE (3) via select_challenges()'s own cap -- this test
## instead directly restores 3 ids to confirm the product keeps compounding
## correctly past 2 factors, not just a 2-factor special case.
func test_three_active_challenges_compound_multiplicatively() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"drama_bez_granic", &"przepros_na_niby"]
	_cs.select_challenges(ids)

	# 2.0 * 2.5 * 1.8 = 9.0
	assert_float(_cs.get_combined_meta_multiplier()).is_equal_approx(9.0, 0.0001)
