## Integration contracts for the ActionScreen-scoped live ambient resource
## ticker. The suite drives `_process()` directly so accumulator behavior is
## deterministic and never depends on wall-clock frame timing.
extends GdUnitTestSuite

const TICKER_SCRIPT: GDScript = preload("res://src/core/live_resource_ticker.gd")
const STEP_SCRIPT: GDScript = preload("res://src/core/resource_simulation_step.gd")
const ACTION_SCREEN: PackedScene = preload("res://scenes/action_screen/action_screen.tscn")
const EPSILON: float = 0.000001

var _resource_snapshot: Dictionary[StringName, float] = {}
var _shield_snapshot: float = 0.0
var _class_path_snapshot: Dictionary = {}
var _staff_snapshot: Dictionary = {}
var _challenge_snapshot: Array[StringName] = []
var _prestige_snapshot: Dictionary[StringName, float] = {}


func before_test() -> void:
	for key: StringName in [&"Reach", &"Cringe", &"Haters", &"Morale", &"Sponsors"]:
		_resource_snapshot[key] = ResourceManager.get_resource(key)
	_shield_snapshot = ResourceManager.get_shield_remaining_seconds()
	_class_path_snapshot = ClassPathSystem.serialize_state()
	_staff_snapshot = StaffSystem.serialize_state()
	_challenge_snapshot = ChallengeSystem.get_active_challenge_ids()
	_prestige_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()

	ClassPathSystem.restore_state({})
	StaffSystem.restore_state({})
	var no_challenges: Array[StringName] = []
	ChallengeSystem.select_challenges(no_challenges)
	PrestigeSystem.meta_bonus_totals.clear()
	ResourceManager.restore_state({"shield_remaining_seconds": 0.0})
	_stop_save_timers()


func after_test() -> void:
	ClassPathSystem.restore_state(_class_path_snapshot)
	StaffSystem.restore_state(_staff_snapshot)
	ChallengeSystem.select_challenges(_challenge_snapshot)
	PrestigeSystem.meta_bonus_totals.clear()
	for bonus_type: StringName in _prestige_snapshot:
		PrestigeSystem.meta_bonus_totals[bonus_type] = _prestige_snapshot[bonus_type]

	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	ResourceManager.restore_state({"shield_remaining_seconds": _shield_snapshot})
	_stop_save_timers()


func _stop_save_timers() -> void:
	SaveSystem._debounce_timer.stop()
	# Package 2 adds a hard maximum dirty-age timer. Property discovery keeps
	# this test file loadable during the red phase before that field exists.
	for property: Dictionary in SaveSystem.get_property_list():
		if property["name"] == &"_max_dirty_timer":
			var max_dirty_timer: Timer = SaveSystem.get("_max_dirty_timer") as Timer
			if max_dirty_timer != null:
				max_dirty_timer.stop()
			return


func _set_resources(cringe: float, haters: float, morale: float, reach: float = 0.0) -> void:
	ResourceManager.apply_delta({
		&"Cringe": cringe - ResourceManager.get_resource(&"Cringe"),
		&"Haters": haters - ResourceManager.get_resource(&"Haters"),
		&"Morale": morale - ResourceManager.get_resource(&"Morale"),
		&"Reach": reach - ResourceManager.get_resource(&"Reach"),
	})
	_stop_save_timers()


func _progress_snapshot() -> Dictionary:
	return {
		"Reach": ResourceManager.get_resource(&"Reach"),
		"Haters": ResourceManager.get_resource(&"Haters"),
		"Morale": ResourceManager.get_resource(&"Morale"),
	}


func _neutral_expected_after_steps(step_count: int) -> Dictionary:
	var haters: float = ResourceManager.get_resource(&"Haters")
	var morale: float = ResourceManager.get_resource(&"Morale")
	var reach: float = ResourceManager.get_resource(&"Reach")
	var cringe: float = ResourceManager.get_resource(&"Cringe")
	for _step_index: int in step_count:
		var step: Dictionary = STEP_SCRIPT.compute(
			cringe,
			haters,
			morale,
			1.0,
			ResourceFormulas.M_BUFFER,
			1.0,
			0.0,
			1.0,
			0.0,
			1.0
		)
		haters = step["final_H"]
		morale = step["final_M"]
		reach += step["reach_gained"]
	return {"Reach": reach, "Haters": haters, "Morale": morale}


func _assert_progress_matches(actual: Dictionary, expected: Dictionary) -> void:
	assert_float(actual["Reach"]).is_equal_approx(expected["Reach"], EPSILON)
	assert_float(actual["Haters"]).is_equal_approx(expected["Haters"], EPSILON)
	assert_float(actual["Morale"]).is_equal_approx(expected["Morale"], EPSILON)


## Fractional frame deltas accumulate without mutating resources until one
## complete one-second simulation quantum exists.
func test_fractional_deltas_point_four_plus_point_six_apply_exactly_one_tick() -> void:
	_set_resources(50.0, 10.0, 80.0, 5.0)
	var before: Dictionary = _progress_snapshot()
	var expected: Dictionary = _neutral_expected_after_steps(1)
	var ticker: Node = TICKER_SCRIPT.new()

	ticker._process(0.4)
	_assert_progress_matches(_progress_snapshot(), before)

	ticker._process(0.6)
	_assert_progress_matches(_progress_snapshot(), expected)
	ticker.free()


## A frame hitch consumes every whole quantum and retains the fractional
## remainder: 3.2 seconds means three ticks now, then +0.8 completes tick 4.
func test_hitch_of_three_point_two_seconds_applies_three_ticks_and_keeps_remainder() -> void:
	_set_resources(65.0, 9.5, 72.0, 2.25)
	var expected_after_three: Dictionary = _neutral_expected_after_steps(3)
	var expected_after_four: Dictionary = _neutral_expected_after_steps(4)
	var ticker: Node = TICKER_SCRIPT.new()

	ticker._process(3.2)
	_assert_progress_matches(_progress_snapshot(), expected_after_three)

	ticker._process(0.8)
	_assert_progress_matches(_progress_snapshot(), expected_after_four)
	ticker.free()


## Live progression pulls all three intended growth sources and the active
## path's drain/floor effects: Class Path, Troll staff and permanent Haters
## resistance. The pure shared step is the integration oracle.
func test_live_tick_includes_class_path_troll_and_meta_haters_resistance() -> void:
	ClassPathSystem._active_path = &"ekspert_niszowy"
	ClassPathSystem._current_tier[&"ekspert_niszowy"] = 5
	StaffSystem._staff_count[&"troll"] = 4
	PrestigeSystem.meta_bonus_totals[&"META_HATERS_RESIST"] = 0.20
	_set_resources(80.0, 12.0, 80.0, 0.0)

	assert_float(ClassPathSystem.get_haters_growth_multiplier()).is_equal_approx(0.5, EPSILON)
	assert_float(ClassPathSystem.get_morale_drain_multiplier()).is_equal_approx(0.8, EPSILON)
	assert_float(ClassPathSystem.get_morale_floor()).is_equal_approx(40.0, EPSILON)
	assert_float(StaffSystem.get_haters_multiplier()).is_greater(1.0)
	var expected: Dictionary = STEP_SCRIPT.compute(
		ResourceManager.get_resource(&"Cringe"),
		ResourceManager.get_resource(&"Haters"),
		ResourceManager.get_resource(&"Morale"),
		1.0,
		ResourceManager.get_shield_effective_buffer(),
		ClassPathSystem.get_haters_growth_multiplier() * StaffSystem.get_haters_multiplier(),
		PrestigeSystem.get_meta_bonus_total(&"META_HATERS_RESIST"),
		ClassPathSystem.get_morale_drain_multiplier(),
		ClassPathSystem.get_morale_floor(),
		1.0
	)
	var reach_before: float = ResourceManager.get_resource(&"Reach")
	var ticker: Node = TICKER_SCRIPT.new()

	ticker._process(1.0)

	assert_float(ResourceManager.get_resource(&"Haters")).is_equal_approx(expected["final_H"], EPSILON)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(expected["final_M"], EPSILON)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(
		reach_before + float(expected["reach_gained"]), EPSILON
	)
	ticker.free()


## Assistant is explicitly offline-only; Challenge reward modifiers and
## META_REACH_MULT are action-reward axes. None may leak into Formula D's
## ambient live Reach. A non-neutral fixture must remain byte-for-byte equal
## to the neutral live result.
func test_live_tick_excludes_assistant_challenge_and_meta_reach_multipliers() -> void:
	_set_resources(55.0, 8.0, 75.0, 3.0)
	var baseline_ticker: Node = TICKER_SCRIPT.new()
	baseline_ticker._process(1.0)
	var baseline: Dictionary = _progress_snapshot()
	baseline_ticker.free()

	_set_resources(55.0, 8.0, 75.0, 3.0)
	StaffSystem._staff_count[&"assistant"] = 5
	var active_challenges: Array[StringName] = [&"bez_tlumu", &"wypalony_ale_core"]
	ChallengeSystem.select_challenges(active_challenges)
	PrestigeSystem.meta_bonus_totals[&"META_REACH_MULT"] = 0.50
	assert_float(StaffSystem.get_offline_rate_multiplier()).is_greater(1.0)
	assert_float(ChallengeSystem.get_modifier(&"nagraj_vloga", &"reach_multiplier")).is_less(1.0)
	assert_float(ChallengeSystem.get_modifier(&"przeprosiny", &"morale_multiplier")).is_less(1.0)
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")).is_greater(0.0)
	var excluded_ticker: Node = TICKER_SCRIPT.new()

	excluded_ticker._process(1.0)

	_assert_progress_matches(_progress_snapshot(), baseline)
	excluded_ticker.free()


## Lifecycle contract: the ticker is a direct child of ActionScreen, not a
## global Autoload that continues advancing during boot/report/other scenes.
func test_ticker_is_direct_action_screen_child_and_not_an_autoload() -> void:
	var runner: GdUnitSceneRunner = scene_runner(ACTION_SCREEN.resource_path)
	var action_screen: Node = runner.scene()
	var ticker: Node = action_screen.get_node_or_null("LiveResourceTicker")

	assert_object(ticker).is_not_null()
	assert_object(ticker.get_parent()).is_same(action_screen)
	assert_bool(ProjectSettings.has_setting("autoload/LiveResourceTicker")).is_false()
