## Integration coverage for Prestige Formula F3 application points.
##
## The pure formulas already have unit coverage; this suite proves the real
## gameplay consumers pull the persisted PrestigeSystem totals at resolution
## time. Every singleton touched here is snapshotted and restored so a real
## player save cannot alter the expected values or be altered by the suite.
extends GdUnitTestSuite

const ActionSystemScript: GDScript = preload("res://src/core/action_system.gd")
const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

var _action_system: Node
var _resource_snapshot: Dictionary[StringName, float] = {}
var _prestige_totals_snapshot: Dictionary[StringName, float] = {}
var _class_path_snapshot: Dictionary = {}
var _challenge_snapshot: Dictionary = {}
var _staff_snapshot: Dictionary = {}


func before_test() -> void:
	SaveSystem._debounce_timer.stop()
	for key: StringName in [&"Reach", &"Cringe", &"Haters", &"Morale", &"Sponsors"]:
		_resource_snapshot[key] = ResourceManager.get_resource(key)
	_prestige_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	_class_path_snapshot = ClassPathSystem.serialize_state()
	_challenge_snapshot = ChallengeSystem.serialize_state()
	_staff_snapshot = StaffSystem.serialize_state()

	PrestigeSystem.meta_bonus_totals.clear()
	ClassPathSystem.restore_state({})
	ChallengeSystem.restore_state({})
	StaffSystem.restore_state({})

	_action_system = ActionSystemScript.new()
	add_child(_action_system)


func after_test() -> void:
	if is_instance_valid(_action_system):
		DecisionCardSystem.card_presented.disconnect(_action_system._on_card_presented)
		DecisionCardSystem.card_resolved.disconnect(_action_system._on_card_resolved)
		ResourceManager.resource_changed.disconnect(_action_system._on_resource_changed)
		_action_system._timer.stop()
		_action_system.queue_free()

	PrestigeSystem.meta_bonus_totals.clear()
	for bonus_type: StringName in _prestige_totals_snapshot:
		PrestigeSystem.meta_bonus_totals[bonus_type] = _prestige_totals_snapshot[bonus_type]
	ClassPathSystem.restore_state(_class_path_snapshot)
	ChallengeSystem.restore_state(_challenge_snapshot)
	StaffSystem.restore_state(_staff_snapshot)

	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	OfflineProgressSystem.last_simulation_result = {}
	SaveSystem._debounce_timer.stop()


func _set_resource(name: StringName, value: float) -> void:
	ResourceManager.apply_delta({name: value - ResourceManager.get_resource(name)})


## F3a: a permanent +50% Reach total is pulled by the real action resolution.
## Base 10 at full Morale with neutral path/challenge becomes 15.
func test_meta_reach_multiplier_applies_to_action_reward() -> void:
	_set_resource(&"Morale", 100.0)
	PrestigeSystem.meta_bonus_totals[&"META_REACH_MULT"] = 0.50
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	assert_bool(_action_system.start_action(&"zrob_drame")).is_true()
	_action_system._timer.stop()
	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(15.0, 0.0001)


## F3b: positive Sponsors from a card use the permanent multiplier and round
## only once after the complete product. Base 3 × 1.5 = 4.5 -> 5.
func test_meta_sponsor_multiplier_applies_to_positive_card_income() -> void:
	PrestigeSystem.meta_bonus_totals[&"META_SPONSOR_MULT"] = 0.50
	var sponsors_before: float = ResourceManager.get_resource(&"Sponsors")
	var dcs: Node = DecisionCardSystemScript.new()
	dcs._presented_card = {
		"id": "test_meta_sponsor_card",
		"path_tag": "",
		"options": [
			{"label": "Take", "resolution_reaction": "", "resource_deltas": {&"Sponsors": 3.0}, "counter_increments": {}},
		],
	}
	dcs.state = dcs.State.PRESENTING

	dcs.resolve_choice(0)

	assert_float(ResourceManager.get_resource(&"Sponsors") - sponsors_before).is_equal_approx(5.0, 0.0001)
	dcs.free()


## F3b is income-only: a card cost remains unchanged even with a maxed bonus.
func test_meta_sponsor_multiplier_does_not_scale_card_cost() -> void:
	PrestigeSystem.meta_bonus_totals[&"META_SPONSOR_MULT"] = 0.50
	_set_resource(&"Sponsors", 10.0)
	var dcs: Node = DecisionCardSystemScript.new()
	dcs._presented_card = {
		"id": "test_meta_sponsor_cost_card",
		"path_tag": "",
		"options": [
			{"label": "Pay", "resolution_reaction": "", "resource_deltas": {&"Sponsors": -3.0}, "counter_increments": {}},
		],
	}
	dcs.state = dcs.State.PRESENTING

	dcs.resolve_choice(0)

	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(7.0, 0.0001)
	dcs.free()


## F3c: the real offline loop snapshots the permanent resistance. With all
## other multipliers neutral, 0.30 resistance yields exactly 0.70× H growth.
func test_meta_haters_resistance_applies_to_offline_growth() -> void:
	_set_resource(&"Cringe", 80.0)
	_set_resource(&"Haters", 0.0)
	_set_resource(&"Morale", 100.0)
	PrestigeSystem.meta_bonus_totals[&"META_HATERS_RESIST"] = 0.0
	var unresisted: Dictionary = OfflineProgressSystem.simulate_offline(3600)

	PrestigeSystem.meta_bonus_totals[&"META_HATERS_RESIST"] = 0.30
	var resisted: Dictionary = OfflineProgressSystem.simulate_offline(3600)

	assert_float(unresisted["final_H"]).is_greater(0.0)
	assert_float(resisted["final_H"]).is_equal_approx(unresisted["final_H"] * 0.70, 0.0001)
