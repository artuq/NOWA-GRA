## Integration tests for StaffSystem against the real Autoloads it touches:
## hiring against ResourceManager's Sponsors, the three pull-model consumers
## (DecisionCardSystem sponsor income, OfflineProgressSystem assistant/troll),
## era reset from PrestigeSystem's sweep, and the save/boot round-trip that
## has been a repeated blocking bug in this project's history.
extends GdUnitTestSuite

var _sponsors_before: float
var _reach_before: float
var _cringe_before: float
var _haters_before: float
var _morale_before: float
var _prestige_totals_snapshot: Dictionary[StringName, float] = {}


func before_test() -> void:
	SaveSystem._debounce_timer.stop()
	_prestige_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	PrestigeSystem.meta_bonus_totals.clear()
	_sponsors_before = ResourceManager.get_resource(&"Sponsors")
	_reach_before = ResourceManager.get_resource(&"Reach")
	_cringe_before = ResourceManager.get_resource(&"Cringe")
	_haters_before = ResourceManager.get_resource(&"Haters")
	_morale_before = ResourceManager.get_resource(&"Morale")
	StaffSystem.reset_era_state()


func after_test() -> void:
	StaffSystem.reset_era_state()
	PrestigeSystem.meta_bonus_totals.clear()
	for bonus_type: StringName in _prestige_totals_snapshot:
		PrestigeSystem.meta_bonus_totals[bonus_type] = _prestige_totals_snapshot[bonus_type]
	ResourceManager.apply_delta({
		&"Sponsors": _sponsors_before - ResourceManager.get_resource(&"Sponsors"),
		&"Reach": _reach_before - ResourceManager.get_resource(&"Reach"),
		&"Cringe": _cringe_before - ResourceManager.get_resource(&"Cringe"),
		&"Haters": _haters_before - ResourceManager.get_resource(&"Haters"),
		&"Morale": _morale_before - ResourceManager.get_resource(&"Morale"),
	})
	SaveSystem._debounce_timer.stop()


func _set_sponsors(value: float) -> void:
	ResourceManager.apply_delta({&"Sponsors": value - ResourceManager.get_resource(&"Sponsors")})


## AC: a hire deducts exactly the F2 cost and increments the count; the next
## cost escalates. Unaffordable hires reject with zero side effects.
func test_hire_deducts_cost_and_escalates() -> void:
	_set_sponsors(20.0)
	assert_int(StaffSystem.get_next_hire_cost(&"troll")).is_equal(4)

	assert_bool(StaffSystem.hire(&"troll")).is_true()

	assert_int(StaffSystem.get_staff_count(&"troll")).is_equal(1)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(16.0, 0.0001)
	assert_int(StaffSystem.get_next_hire_cost(&"troll")).is_equal(7)

	# Unaffordable: no deduction, no count change, clean false.
	_set_sponsors(2.0)
	assert_bool(StaffSystem.hire(&"troll")).is_false()
	assert_int(StaffSystem.get_staff_count(&"troll")).is_equal(1)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(2.0, 0.0001)


## AC: unknown role rejects cleanly, spends nothing.
func test_unknown_role_rejected() -> void:
	_set_sponsors(1000.0)
	assert_bool(StaffSystem.hire(&"ceo")).is_false()
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(1000.0, 0.0001)


## AC (F3b): Sponsor Managers scale the Sponsors AMOUNT a card grants.
## Synthetic neutral card so no counters/affiliation move.
func test_sponsor_manager_scales_card_income() -> void:
	_set_sponsors(500.0)
	assert_bool(StaffSystem.hire(&"sponsor_manager")).is_true()
	var expected_mult: float = StaffSystem.get_sponsor_multiplier()
	assert_float(expected_mult).is_greater(1.0)

	var sponsors_before: float = ResourceManager.get_resource(&"Sponsors")
	DecisionCardSystem._presented_card = {
		"id": "test_staff_sponsor_card",
		"path_tag": "",
		"options": [
			{"label": "Take", "resolution_reaction": "", "resource_deltas": {&"Sponsors": 10.0}, "counter_increments": {}},
		],
	}
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.resolve_choice(0)

	var gained: float = ResourceManager.get_resource(&"Sponsors") - sponsors_before
	assert_float(gained).is_equal_approx(roundf(10.0 * expected_mult), 0.0001)


## AC (Core Rule 6): Assistants raise offline income; (F3) Trolls raise
## offline Haters growth. Same inputs, staff off vs on.
func test_offline_multipliers_applied() -> void:
	ResourceManager.apply_delta({&"Cringe": 50.0 - ResourceManager.get_resource(&"Cringe")})
	var h0: float = ResourceManager.get_resource(&"Haters")
	var baseline: Dictionary = OfflineProgressSystem.simulate_offline(3600)

	_set_sponsors(500.0)
	assert_bool(StaffSystem.hire(&"assistant")).is_true()
	assert_bool(StaffSystem.hire(&"troll")).is_true()
	var with_staff: Dictionary = OfflineProgressSystem.simulate_offline(3600)

	assert_float(with_staff["total_Z_gained"]).is_greater(baseline["total_Z_gained"])
	assert_float(with_staff["final_H"] - h0).is_greater(baseline["final_H"] - h0)
	OfflineProgressSystem.last_simulation_result = {}


## AC (Core Rule 2): era reset clears every count — staff is part of what the
## burnout costs.
func test_era_reset_clears_all_counts() -> void:
	_set_sponsors(500.0)
	StaffSystem.hire(&"troll")
	StaffSystem.hire(&"assistant")

	StaffSystem.reset_era_state()

	for role: StringName in StaffSystem.ROLES:
		assert_int(StaffSystem.get_staff_count(role)).is_equal(0)
	assert_float(StaffSystem.get_sponsor_multiplier()).is_equal_approx(1.0, 0.0001)


## AC: counts round-trip through a REAL save_now() -> restore_state() cycle.
## This is the exact wiring gap that shipped broken three times in this
## project (ClassPath, Prestige, and the investment split), so it is asserted
## against SaveSystem's real serialize path, not StaffSystem's in isolation.
func test_counts_survive_save_and_restore() -> void:
	_set_sponsors(500.0)
	StaffSystem.hire(&"troll")
	StaffSystem.hire(&"troll")
	StaffSystem.hire(&"sponsor_manager")

	SaveSystem.save_now()
	StaffSystem.reset_era_state()
	assert_int(StaffSystem.get_staff_count(&"troll")).is_equal(0)

	var data: Dictionary = SaveSystem.load_save()
	assert_bool(data.has("staff")).is_true()
	StaffSystem.restore_state(data["staff"])

	assert_int(StaffSystem.get_staff_count(&"troll")).is_equal(2)
	assert_int(StaffSystem.get_staff_count(&"sponsor_manager")).is_equal(1)
	assert_int(StaffSystem.get_staff_count(&"assistant")).is_equal(0)
