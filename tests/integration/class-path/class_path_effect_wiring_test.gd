## Integration tests for the tier-fill effect wiring (2026-07-28): the real
## ActionSystem / DecisionCardSystem / ResourceManager / OfflineProgressSystem
## Autoloads pulling the real ClassPathSystem Autoload's effect getters.
##
## Technique: the AUTOLOAD ClassPathSystem's private state is set directly
## (active path + tier) and fully restored in after_test() — same
## direct-private-field convention the unit suites use on detached instances,
## applied to the singleton because the consumers under test read the
## singleton, not an injected instance. Resources are snapshotted/restored
## around every test (boot_flow_test pattern).
extends GdUnitTestSuite

var _reach_before: float
var _haters_before: float
var _morale_before: float
var _cringe_before: float
var _sponsors_before: float
var _prestige_totals_snapshot: Dictionary[StringName, float] = {}


func before_test() -> void:
	SaveSystem._debounce_timer.stop()
	_prestige_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	PrestigeSystem.meta_bonus_totals.clear()
	_reach_before = ResourceManager.get_resource(&"Reach")
	_haters_before = ResourceManager.get_resource(&"Haters")
	_morale_before = ResourceManager.get_resource(&"Morale")
	_cringe_before = ResourceManager.get_resource(&"Cringe")
	_sponsors_before = ResourceManager.get_resource(&"Sponsors")


func after_test() -> void:
	_clear_path_state()
	PrestigeSystem.meta_bonus_totals.clear()
	for bonus_type: StringName in _prestige_totals_snapshot:
		PrestigeSystem.meta_bonus_totals[bonus_type] = _prestige_totals_snapshot[bonus_type]
	ResourceManager.apply_delta({
		&"Reach": _reach_before - ResourceManager.get_resource(&"Reach"),
		&"Haters": _haters_before - ResourceManager.get_resource(&"Haters"),
		&"Morale": _morale_before - ResourceManager.get_resource(&"Morale"),
		&"Cringe": _cringe_before - ResourceManager.get_resource(&"Cringe"),
		&"Sponsors": _sponsors_before - ResourceManager.get_resource(&"Sponsors"),
	})
	SaveSystem._debounce_timer.stop()


func _set_path_state(path_id: StringName, tier: int) -> void:
	ClassPathSystem._active_path = path_id
	ClassPathSystem._current_tier[path_id] = tier


func _clear_path_state() -> void:
	ClassPathSystem._active_path = &""
	ClassPathSystem._current_tier.clear()
	ClassPathSystem._affiliation.clear()


## AC: T4 duration cut arms the real Timer with the multiplied wait_time.
func test_duration_cut_applied_at_start() -> void:
	_set_path_state(&"pato_streamer", 4)
	assert_bool(ActionSystem.start_action(&"zrob_drame")).is_true()
	assert_float(ActionSystem.get_current_duration()).is_equal_approx(9.0 * (2.0 / 3.0), 0.001)
	# Cleanup: resolve immediately so no action is left running.
	ActionSystem._timer.stop()
	ActionSystem._on_action_timeout()


## AC: T3 interlock — drama completion at pato T3 also yields +1 Sponsor,
## carried in both apply_delta and the action_completed payload.
func test_secondary_yield_merged_into_completion() -> void:
	_set_path_state(&"pato_streamer", 3)
	var sponsors_before: float = ResourceManager.get_resource(&"Sponsors")
	var captured: Array[Dictionary] = []
	var handler: Callable = func(_id: StringName, rewards: Dictionary) -> void: captured.append(rewards)
	ActionSystem.action_completed.connect(handler)
	assert_bool(ActionSystem.start_action(&"zrob_drame")).is_true()
	ActionSystem._timer.stop()
	ActionSystem._on_action_timeout()
	ActionSystem.action_completed.disconnect(handler)
	assert_float(ResourceManager.get_resource(&"Sponsors") - sponsors_before).is_equal_approx(1.0, 0.0001)
	assert_int(captured.size()).is_equal(1)
	assert_float(captured[0].get(&"Sponsors", 0.0)).is_equal_approx(1.0, 0.0001)


## AC: biznesmen T5 — negative action Morale costs zeroed (drama's -3 becomes
## 0), positive Morale rewards untouched.
func test_morale_cost_immunity_at_biznesmen_t5() -> void:
	_set_path_state(&"biznesmen_contentu", 5)
	var morale_before: float = ResourceManager.get_resource(&"Morale")
	assert_bool(ActionSystem.start_action(&"zrob_drame")).is_true()
	ActionSystem._timer.stop()
	ActionSystem._on_action_timeout()
	# Drama's base Morale is -3; with cost immunity the applied Morale delta
	# is 0 — Morale unchanged (no other Morale source in this resolution).
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(morale_before, 0.0001)


## AC: pato T5 — positive Cringe gains scale ×1.5 (drama 20 -> 30).
func test_cringe_gain_scaled_at_pato_t5() -> void:
	_set_path_state(&"pato_streamer", 5)
	var cringe_before: float = ResourceManager.get_resource(&"Cringe")
	assert_bool(ActionSystem.start_action(&"zrob_drame")).is_true()
	ActionSystem._timer.stop()
	ActionSystem._on_action_timeout()
	var gained: float = ResourceManager.get_resource(&"Cringe") - cringe_before
	# 20 * 1.5 = 30 — unless the 0..100 clamp truncated (start too high);
	# guard the precondition instead of silently passing.
	assert_float(cringe_before).is_less(70.0)
	assert_float(gained).is_equal_approx(30.0, 0.0001)


## AC: sponsor income multiplier scales positive Sponsors card rewards at
## the DecisionCardSystem site (guru T5 ×2: +3 -> +6). Synthetic neutral
## card (path_tag "", no counter increments) so resolving it pollutes no
## HistoryFlagManager counters and triggers no affiliation recalculation.
func test_card_sponsor_income_scaled() -> void:
	_set_path_state(&"guru_celebryta", 5)
	var sponsors_before: float = ResourceManager.get_resource(&"Sponsors")
	DecisionCardSystem._presented_card = {
		"id": "test_sponsor_income_card",
		"path_tag": "",
		"options": [
			{"label": "Take it", "resolution_reaction": "", "resource_deltas": {&"Sponsors": 3.0}, "counter_increments": {}},
		],
	}
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.resolve_choice(0)
	assert_float(ResourceManager.get_resource(&"Sponsors") - sponsors_before).is_equal_approx(6.0, 0.0001)


## AC: offline sim applies ekspert T5's haters ×0.5 and the Morale drain
## floor at 40 — identical inputs, path on vs off. Cringe is parked at a
## value with guaranteed nonzero haters growth first.
func test_offline_ekspert_t5_ambient_shield() -> void:
	var elapsed: int = 3600
	ResourceManager.apply_delta({&"Cringe": 50.0 - ResourceManager.get_resource(&"Cringe")})
	# Park Morale at 100 so the floor assertion below is meaningful (the
	# floor never lifts a Morale already under 40 — deliberate semantics).
	ResourceManager.apply_delta({&"Morale": 100.0 - ResourceManager.get_resource(&"Morale")})
	var h0: float = ResourceManager.get_resource(&"Haters")
	_clear_path_state()
	var baseline: Dictionary = OfflineProgressSystem.simulate_offline(elapsed)
	_set_path_state(&"ekspert_niszowy", 5)
	var with_path: Dictionary = OfflineProgressSystem.simulate_offline(elapsed)
	var baseline_growth: float = baseline["final_H"] - h0
	var path_growth: float = with_path["final_H"] - h0
	assert_float(baseline_growth).is_greater(0.0)
	assert_float(path_growth).is_equal_approx(baseline_growth * 0.5, maxf(0.01, baseline_growth * 0.01))
	# Floor: with the path active, Morale never ends below 40 (baseline may).
	assert_float(with_path["final_M"]).is_greater_equal(40.0)
	OfflineProgressSystem.last_simulation_result = {}
