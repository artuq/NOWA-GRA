## Interaction tests for BootController (Story 003, Offline Report Screen epic).
## Drives boot_with(data, elapsed_seconds) directly with explicit inputs (the
## class's test seam, see boot_controller.gd doc comment) -- avoids mocking the
## system clock or a real save file for deterministic boundary testing.
##
## ResourceManager/OfflineProgressSystem are Autoloads; their mutable state is
## snapshotted and restored around each test so boot_with's writes don't leak.
## Story type: Integration. Evidence: this file. Gate: BLOCKING.
extends GdUnitTestSuite

var _reach_before: float
var _haters_before: float
var _morale_before: float
var _shield_before: float


func _stop_save_timers() -> void:
	for child: Node in SaveSystem.get_children():
		if child is Timer:
			(child as Timer).stop()


func _saved_resources_with_shield(remaining_seconds: float) -> Dictionary:
	var resources: Dictionary = ResourceManager.serialize_state()
	resources["shield_remaining_seconds"] = remaining_seconds
	return resources

func before_test() -> void:
	# boot_with() calls the real ResourceManager.apply_delta(), which (since the
	# mark_dirty wiring fix, 2026-06-29) starts SaveSystem's real debounce timer.
	# Stopping it before/after every test prevents it from firing mid-suite and
	# writing a real user://save.json with test data -- a real, observed bug:
	# an unstopped timer here polluted card_resolution_test.gd's milestone
	# assertions in a later, unrelated test file via a stale on-disk save.
	_stop_save_timers()
	_reach_before = ResourceManager.get_resource(&"Reach")
	_haters_before = ResourceManager.get_resource(&"Haters")
	_morale_before = ResourceManager.get_resource(&"Morale")
	_shield_before = ResourceManager.get_shield_remaining_seconds()

func after_test() -> void:
	_stop_save_timers()
	ResourceManager.apply_delta({
		&"Reach": _reach_before - ResourceManager.get_resource(&"Reach"),
		&"Haters": _haters_before - ResourceManager.get_resource(&"Haters"),
		&"Morale": _morale_before - ResourceManager.get_resource(&"Morale"),
	})
	ResourceManager._shield_remaining_seconds = _shield_before
	_stop_save_timers()  # the restore above re-triggers mark_dirty
	OfflineProgressSystem.last_simulation_result = {}

## AC: elapsed=300 (threshold, inclusive) routes to the Offline Report Screen.
func test_threshold_inclusive_routes_to_report() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var routed: Array[String] = []
	bc.route_requested.connect(func(path: String) -> void: routed.append(path))

	bc.boot_with({}, 300)

	assert_array(routed).contains_exactly([BootController.OFFLINE_REPORT_SCENE])
	bc.queue_free()

## AC: elapsed=299 (one under) routes straight to main, no report.
func test_below_threshold_routes_to_main() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var routed: Array[String] = []
	bc.route_requested.connect(func(path: String) -> void: routed.append(path))

	bc.boot_with({}, 299)

	assert_array(routed).contains_exactly([BootController.MAIN_SCENE])
	bc.queue_free()

## AC: elapsed=0 (first session / no prior save) routes to main directly.
func test_zero_elapsed_routes_to_main() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var routed: Array[String] = []
	bc.route_requested.connect(func(path: String) -> void: routed.append(path))

	bc.boot_with({}, 0)

	assert_array(routed).contains_exactly([BootController.MAIN_SCENE])
	bc.queue_free()

## AC: the transient payload carries the sim result plus elapsed_seconds, h0, m0
## -- captured BEFORE the sim result is applied, so the deltas are true.
func test_transient_payload_has_baselines_and_elapsed() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var h0: float = ResourceManager.get_resource(&"Haters")
	var m0: float = ResourceManager.get_resource(&"Morale")

	bc.boot_with({}, 600)

	var r: Dictionary = OfflineProgressSystem.last_simulation_result
	assert_int(r.get("elapsed_seconds")).is_equal(600)
	assert_float(r.get("h0")).is_equal_approx(h0, 0.0001)
	assert_float(r.get("m0")).is_equal_approx(m0, 0.0001)
	assert_bool(r.has("final_H")).is_true()
	assert_bool(r.has("total_Z_gained")).is_true()
	bc.queue_free()

## AC: the sim result is applied to ResourceManager exactly once via apply_delta
## (Reach increases by total_Z_gained; Haters/Morale move to the sim's finals).
func test_sim_result_applied_to_resource_manager() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	bc.boot_with({}, 600)

	var r: Dictionary = OfflineProgressSystem.last_simulation_result
	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(r["total_Z_gained"], 0.0001)
	assert_float(ResourceManager.get_resource(&"Haters")).is_equal_approx(r["final_H"], 0.0001)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(r["final_M"], 0.0001)
	bc.queue_free()

## AC: restore_state is called on ResourceManager/HistoryFlagManager with the
## CORRECT save-dict sub-keys -- not just "doesn't crash" (code-review finding,
## 2026-06-29): a known Reach value in data["resources"] must actually land in
## ResourceManager after boot_with, proving the right sub-dict was passed (a
## bug passing the wrong key, or the whole `data`, would leave Reach unchanged).
func test_restores_resources_from_the_correct_save_subdict() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var data: Dictionary = {
		"schema_version": 1,
		"last_saved_at": Time.get_unix_time_from_system(),
		"resources": {"Reach": 777.0, "Cringe": 12.0, "Haters": 3.0, "Morale": 60.0, "Sponsors": 1.0},
		"history_flags": {},
		"decision_card_state": {"cooldown_actions_remaining": 0, "resolved_milestone_cards": []},
	}

	bc.boot_with(data, 0)  # elapsed=0 -> no offline sim deltas on top

	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(777.0, 0.0001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(12.0, 0.0001)
	bc.queue_free()

## AC: an empty/first-session save (no "resources"/"history_flags" keys) and the
## decision_card_state stub key both pass through without error -- the modules
## without restore_state (ActionSystem, DecisionCardSystem, OnboardingGate) are
## simply never called, not silently failing.
func test_first_session_empty_save_does_not_crash() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	bc.boot_with({}, 0)
	bc.queue_free()

## AC: existing Action UI structure stays reachable as a regression guard --
## main.tscn hosts action_screen.tscn unchanged at its own path.
func test_main_scene_hosts_action_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/main/main.tscn")
	var root: Node = runner.scene()
	var action_screen: Node = root.find_child("ActionScreen", true, false)
	assert_object(action_screen).is_not_null()
	assert_object(action_screen.find_child("ResourceHud", true, false)).is_not_null()
	assert_object(action_screen.find_child("ActionGrid", true, false)).is_not_null()


## Package 2 AC: boot consumes shield time by the real elapsed duration, not
## merely by the resource simulation step. A short offline gap therefore
## preserves only the unelapsed portion.
func test_boot_consumes_partial_shield_by_actual_elapsed_time() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var data: Dictionary = {
		"resources": _saved_resources_with_shield(300.0),
	}

	bc.boot_with(data, 120)

	assert_float(ResourceManager.get_shield_remaining_seconds()).is_equal_approx(180.0, 0.0001)
	bc.queue_free()


## Package 2 AC: the 24-hour cap limits economy simulation only. Shield is a
## wall-clock duration and must consume the full actual elapsed time even
## when elapsed_seconds exceeds OfflineProgressSystem's cap.
func test_boot_consumes_shield_beyond_offline_simulation_cap_using_actual_elapsed() -> void:
	var bc: BootController = BootController.new()
	add_child(bc)
	var initial_shield: float = float(OfflineProgressSystem.MAX_OFFLINE_CAP_SECONDS + 7200)
	var actual_elapsed: int = OfflineProgressSystem.MAX_OFFLINE_CAP_SECONDS + 3600
	var data: Dictionary = {
		"resources": _saved_resources_with_shield(initial_shield),
	}

	bc.boot_with(data, actual_elapsed)

	assert_bool(OfflineProgressSystem.last_simulation_result["capped"]).is_true()
	assert_float(ResourceManager.get_shield_remaining_seconds()).is_equal_approx(3600.0, 0.0001)
	bc.queue_free()
