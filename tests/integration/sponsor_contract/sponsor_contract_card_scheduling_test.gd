extends GdUnitTestSuite

const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

var _contract_snapshot: Dictionary
var _onboarding_phase_snapshot: int
var _instances: Array[Node] = []


func before_test() -> void:
	_contract_snapshot = SponsorContractSystem.serialize_state()
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL


func after_test() -> void:
	SponsorContractSystem.restore_state(_contract_snapshot)
	OnboardingGate.phase = _onboarding_phase_snapshot
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.queue_free()


func _new_dcs() -> Node:
	var dcs: Node = DecisionCardSystemScript.new()
	add_child(dcs)
	_instances.append(dcs)
	return dcs


func test_due_contract_card_preempts_normal_weighted_pool() -> void:
	SponsorContractSystem.restore_state({"state": "fallout_due", "opening_choice": "a", "actions_completed": 4})
	var dcs: Node = _new_dcs()
	dcs.state = DecisionCardSystemScript.State.CHECKING
	dcs._check_pool()
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)
	assert_str(dcs._presented_card["id"]).is_equal("sponsor_contract_mega_fallout")


func test_never_trigger_contract_cards_do_not_leak_into_normal_pool() -> void:
	SponsorContractSystem.reset_for_new_game()
	var dcs: Node = _new_dcs()
	var ids: Array[String] = []
	for card: Dictionary in dcs._build_eligible_pool():
		ids.append(String(card["id"]))
	assert_bool(ids.has("sponsor_contract_mega_fallout")).is_false()
	assert_bool(ids.has("sponsor_contract_indie_fallout")).is_false()
	assert_bool(ids.has("sponsor_contract_finale")).is_false()


func test_test_override_remains_isolated_from_runtime_contract_schedule() -> void:
	SponsorContractSystem.restore_state({"state": "finale_due", "opening_choice": "b", "actions_completed": 2})
	var dcs: Node = _new_dcs()
	var synthetic: Dictionary = {
		"id": "synthetic", "trigger_condition": "always", "text": "",
		"options": [
			{"id": "a", "label": "", "resource_deltas": {}, "counter_increments": {}},
			{"id": "b", "label": "", "resource_deltas": {}, "counter_increments": {}},
		],
	}
	var override: Array[Dictionary] = [synthetic]
	dcs.state = DecisionCardSystemScript.State.CHECKING
	dcs._check_pool(override)
	assert_str(dcs._presented_card["id"]).is_equal("synthetic")
