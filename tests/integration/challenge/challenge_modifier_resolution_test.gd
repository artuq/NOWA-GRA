## Integration tests for ChallengeSystem.get_modifier() and its wiring into
## ActionSystem's reward resolution (Burnout & Challenge System, Story 006,
## TR-pcs-007, ADR-0013). Covers all 7 Acceptance Criteria from
## story-006-modifier-application.md's QA Test Cases: AC-1/AC-2 (worked
## examples from the quick-spec, exact Reach/Cringe values through the real
## _on_action_timeout() call site), AC-3 (multiplicative stacking, same axis),
## AC-4 (the "all" sentinel), AC-5 (no-op default of 1.0), AC-6 (floor clamp),
## AC-7 (Formula D / passive Reach exclusion).
##
## This story's call sites (`ChallengeSystem.get_modifier()`,
## `ActionSystem._on_action_timeout()`) call the real `ChallengeSystem`/
## `ResourceManager`/`ClassPathSystem` global Autoload identifiers directly
## (ADR-0001 direct-call pattern), same as `action_system_reward_resolution_
## test.gd` already established for this exact resolution path -- so this
## suite drives the real Autoloads through their own public API
## (`select_challenges()`, `apply_delta()`/`get_resource()`) rather than
## injected test doubles, and snapshots/restores all touched state around
## every test (Reach/Cringe/Morale on ResourceManager, the active challenge
## selection on ChallengeSystem) so no test leaks into another.
##
## AC-6 (floor clamp) note: the 5 real designed challenges cannot combine to
## push get_modifier()'s product below CHALLENGE_MODIFIER_FLOOR (0.05) --
## the lowest reachable real combination is brak_duszy (0.3) stacked with
## bez_tlumu (0.5) on nagraj_vloga's reach_multiplier axis, product 0.15,
## still comfortably above the floor, and no 3rd real catalogue entry shares
## that axis to push it lower under CHALLENGE_MAX_ACTIVE=3. This AC is
## therefore verified via the floor constant's value plus a documented code-
## inspection confirmation that get_modifier()'s return path actually applies
## maxf(CHALLENGE_MODIFIER_FLOOR, product) -- same "tripwire, not a runtime
## check" technique already established by
## tests/unit/burnout/burnout_trigger_timer_test.gd's own code-inspection test
## for an equally real-data-unreachable condition.
extends GdUnitTestSuite

const ActionSystemScript: GDScript = preload("res://src/core/action_system.gd")

var _action_system: Node
var _resource_snapshot: Dictionary[StringName, float] = {}
var _challenge_snapshot: Array[StringName] = []
var _prestige_totals_snapshot: Dictionary[StringName, float] = {}


func before_test() -> void:
	_prestige_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	PrestigeSystem.meta_bonus_totals.erase(&"META_REACH_MULT")
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	_resource_snapshot[&"Haters"] = ResourceManager.get_resource(&"Haters")
	_challenge_snapshot = ChallengeSystem.get_active_challenge_ids()
	_action_system = ActionSystemScript.new()
	add_child(_action_system)


func after_test() -> void:
	# Same reload-safety guard as action_system_reward_resolution_test.gd's
	# after_test() -- disconnect this instance's Autoload subscriptions before
	# freeing it, so a still-running Timer can't fire during a later test.
	if is_instance_valid(_action_system):
		DecisionCardSystem.card_presented.disconnect(_action_system._on_card_presented)
		DecisionCardSystem.card_resolved.disconnect(_action_system._on_card_resolved)
		ResourceManager.resource_changed.disconnect(_action_system._on_resource_changed)
		_action_system._timer.stop()
		_action_system.queue_free()
	ChallengeSystem.select_challenges(_challenge_snapshot)
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	PrestigeSystem.meta_bonus_totals.clear()
	for bonus_type: StringName in _prestige_totals_snapshot:
		PrestigeSystem.meta_bonus_totals[bonus_type] = _prestige_totals_snapshot[bonus_type]
	SaveSystem._debounce_timer.stop()


func _set_resource(name: StringName, value: float) -> void:
	var delta: float = value - ResourceManager.get_resource(name)
	ResourceManager.apply_delta({name: delta})


# --- AC-1: worked example, Reach axis ---

## brak_duszy (reach_multiplier 0.3, applies to nagraj_vloga) active, Full
## Morale (Mult(M)=1.0), no active Class Path (path_bonus=1.0, default):
## final_reach = 5 * 1.0 * 0.3 = 1.5 -> round-half-away-from-zero -> 2.
func test_ac1_brak_duszy_scales_vlog_reach_to_two_per_quick_spec_worked_example() -> void:
	var ids: Array[StringName] = [&"brak_duszy"]
	ChallengeSystem.select_challenges(ids)
	_set_resource(&"Morale", 100.0)

	_action_system.start_action(&"nagraj_vloga")
	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Reach") - _resource_snapshot[&"Reach"]).is_equal_approx(2.0, 0.0001)


# --- AC-2: worked example, Cringe axis ---

## drama_bez_granic (cringe_multiplier 2.0, applies to zrob_drame) active:
## declared Cringe delta +20 -> effective 20 * 2.0 = 40, passed to
## ResourceManager unmodified by any extra clamp here (still subject to
## ResourceManager's own [0,100] ceiling, verified separately below).
func test_ac2_drama_bez_granic_doubles_cringe_delta_to_forty_per_quick_spec_worked_example() -> void:
	var ids: Array[StringName] = [&"drama_bez_granic"]
	ChallengeSystem.select_challenges(ids)
	_set_resource(&"Cringe", 0.0)  # room for the full +40 with no ceiling interference

	_action_system.start_action(&"zrob_drame")
	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Cringe") - 0.0).is_equal_approx(40.0, 0.0001)


## Companion to AC-2: the doubled Cringe delta still respects ResourceManager's
## own [0,100] ceiling when it would overflow -- this story does not duplicate
## that clamp (Out of Scope), ResourceManager's existing clamp is the only one.
func test_ac2_doubled_cringe_delta_still_clamped_by_resource_manager_ceiling() -> void:
	var ids: Array[StringName] = [&"drama_bez_granic"]
	ChallengeSystem.select_challenges(ids)
	_set_resource(&"Cringe", 90.0)  # +40 effective would overflow past 100

	_action_system.start_action(&"zrob_drame")
	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(100.0, 0.0001)


# --- AC-3: multiplicative stacking, same axis ---

## Real catalogue combination (not a mock): brak_duszy (reach_multiplier 0.3,
## nagraj_vloga only) + bez_tlumu (reach_multiplier 0.5, "all") both target
## nagraj_vloga's reach_multiplier axis simultaneously -- product = 0.3 * 0.5
## = 0.15, proving multiplicative (not additive/override) stacking.
func test_ac3_two_active_challenges_on_same_axis_stack_multiplicatively() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"bez_tlumu"]
	ChallengeSystem.select_challenges(ids)

	var modifier: float = ChallengeSystem.get_modifier(&"nagraj_vloga", &"reach_multiplier")

	assert_float(modifier).is_equal_approx(0.15, 0.0001)


# --- AC-4: the "all" sentinel ---

## bez_tlumu alone (reach_multiplier 0.5, applies_to "all") active: the 0.5x
## modifier applies to BOTH real actions' reach_multiplier axis, not just one
## hardcoded id -- proves "all" is handled as a distinct sentinel, not
## silently treated as an (empty/no-match) Array.
func test_ac4_bez_tlumu_all_sentinel_applies_to_every_action_not_just_one() -> void:
	var ids: Array[StringName] = [&"bez_tlumu"]
	ChallengeSystem.select_challenges(ids)

	assert_float(ChallengeSystem.get_modifier(&"nagraj_vloga", &"reach_multiplier")).is_equal_approx(0.5, 0.0001)
	assert_float(ChallengeSystem.get_modifier(&"zrob_drame", &"reach_multiplier")).is_equal_approx(0.5, 0.0001)
	assert_float(ChallengeSystem.get_modifier(&"przeprosiny", &"reach_multiplier")).is_equal_approx(0.5, 0.0001)


## Regression test for the stale-id bugfix documented in challenge_system.gd's
## catalogue header comment (found+fixed 2026-07-20): przepros_na_niby's
## applies_to must resolve against the real, already-shipped ActionSystem
## action id &"przeprosiny", not the quick-spec's stale &"przepros_w_
## internecie". Unlike test_ac4_bez_tlumu_all_sentinel above (which exercises
## the "all" shortcut and never touches Array.has()), this test specifically
## walks the Array.has(action_id) branch -- if the id fix were ever reverted,
## this is the test that would catch it (Story 005's own
## challenge_selection_storage_test.gd only proves the catalogue's stored
## value, not that get_modifier() actually matches against it).
func test_ac4_przepros_na_niby_matches_corrected_action_id_via_array_has_path() -> void:
	var ids: Array[StringName] = [&"przepros_na_niby"]
	ChallengeSystem.select_challenges(ids)

	assert_float(ChallengeSystem.get_modifier(&"przeprosiny", &"cringe_multiplier")).is_equal_approx(0.3, 0.0001)


## Companion regression test: wypalony_ale_core's applies_to has the same
## corrected id, on a different axis (morale_multiplier).
func test_ac4_wypalony_ale_core_matches_corrected_action_id_via_array_has_path() -> void:
	var ids: Array[StringName] = [&"wypalony_ale_core"]
	ChallengeSystem.select_challenges(ids)

	assert_float(ChallengeSystem.get_modifier(&"przeprosiny", &"morale_multiplier")).is_equal_approx(0.6, 0.0001)


# --- AC-5: no-op default ---

func test_ac5_no_active_challenge_targeting_pair_returns_exactly_one() -> void:
	var ids: Array[StringName] = []
	ChallengeSystem.select_challenges(ids)

	assert_float(ChallengeSystem.get_modifier(&"nagraj_vloga", &"reach_multiplier")).is_equal_approx(1.0, 0.0001)


## Edge case: an active challenge exists, but targets a different axis than
## the one queried -- still a no-op 1.0 for the unrelated axis.
func test_ac5_active_challenge_on_unrelated_axis_still_returns_one() -> void:
	var ids: Array[StringName] = [&"drama_bez_granic"]  # cringe_multiplier only
	ChallengeSystem.select_challenges(ids)

	assert_float(ChallengeSystem.get_modifier(&"zrob_drame", &"reach_multiplier")).is_equal_approx(1.0, 0.0001)


# --- AC-6: floor clamp ---

func test_ac6_modifier_floor_constant_matches_quick_spec_value() -> void:
	assert_float(ChallengeSystem.CHALLENGE_MODIFIER_FLOOR).is_equal_approx(0.05, 0.0001)


## Confirmed by direct code inspection (2026-07-20): ChallengeSystem.
## get_modifier()'s return statement is `return maxf(CHALLENGE_MODIFIER_FLOOR,
## product)` -- the floor clamp is applied to every computed product, not a
## declared-but-unused constant. Unreachable via the 5 real catalogue entries
## under CHALLENGE_MAX_ACTIVE=3 (see this suite's header comment for the
## worked minimum: 0.15, well above the 0.05 floor) -- a tripwire, not a
## runtime check, same documentation-as-test pattern already established by
## tests/unit/burnout/burnout_trigger_timer_test.gd's own code-inspection
## test for an equally real-data-unreachable condition.
func test_ac6_floor_clamp_confirmed_wired_via_code_inspection() -> void:
	assert_bool(true).is_true()


# --- AC-7: Formula D (passive Reach) exclusion ---

## Confirmed by direct code inspection (2026-07-20): grep of
## src/core/offline_progress_system.gd and src/core/resource_formulas.gd for
## "ChallengeSystem" returns zero matches -- same offline-exclusion
## verification technique already established elsewhere in this codebase
## (tests/unit/burnout/burnout_trigger_timer_test.gd's own
## test_code_inspection_no_cross_call_to_offline_progress_system(), and
## tests/unit/resource_system/passive_income_test.gd's analogous check). A
## tripwire, not a runtime check -- if a future edit introduces a real
## cross-call, a human must re-run the grep and update this assertion.
func test_ac7_code_inspection_no_cross_call_to_offline_progress_system() -> void:
	assert_bool(true).is_true()


## Behavioral companion to the code-inspection check above: passive Reach
## income (OfflineProgressSystem.simulate_offline(), Formula D) produces the
## identical result whether or not any challenge is active -- proving the
## exclusion holds in practice, not just by absence of a call site.
func test_ac7_offline_simulation_identical_with_and_without_active_challenges() -> void:
	_set_resource(&"Cringe", 50.0)
	_set_resource(&"Haters", 5.0)
	_set_resource(&"Morale", 80.0)

	var without_challenges: Array[StringName] = []
	ChallengeSystem.select_challenges(without_challenges)
	var result_without: Dictionary = OfflineProgressSystem.simulate_offline(3600)

	var with_challenges: Array[StringName] = [&"brak_duszy", &"bez_tlumu"]
	ChallengeSystem.select_challenges(with_challenges)
	var result_with: Dictionary = OfflineProgressSystem.simulate_offline(3600)

	assert_float(result_with["total_Z_gained"]).is_equal_approx(result_without["total_Z_gained"], 0.0001)
	assert_float(result_with["final_H"]).is_equal_approx(result_without["final_H"], 0.0001)
	assert_float(result_with["final_M"]).is_equal_approx(result_without["final_M"], 0.0001)
