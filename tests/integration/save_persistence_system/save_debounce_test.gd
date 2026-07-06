## Integration tests for SaveSystem's debounce/coalescing and mobile
## lifecycle flush (Story 002, TR-save-001). Covers all 6 acceptance
## criteria: single isolated trigger, two-trigger coalescing (trailing-edge),
## trailing-edge reflecting latest state, timer reset near a boundary,
## no-triggers-no-write, and the mobile lifecycle flush (plus its no-pending
## no-op edge case).
##
## Per the story's Implementation Notes, debounce timing is driven by the
## real `Timer` for short, bounded real-time waits rather than faking
## `time_left` (read-only in Godot 4.6.x, already-logged tech debt from
## ActionSystem's Story 001). To keep this suite fast and non-flaky, each
## test overrides `_debounce_timer.wait_time` to [constant _TEST_INTERVAL_SEC]
## (0.3s) immediately after instantiation — the mechanism under test is the
## restart-on-call/coalescing algorithm, not the literal 2-second production
## value, so a shorter interval exercises the same logic deterministically.
##
## SaveSystem reaches the real ResourceManager/HistoryFlagManager Autoloads
## and the real filesystem — see save_core_test.gd's header for the full
## isolation rationale (file backup/restore, restore_state() reverting
## counters). This suite only touches ResourceManager's Reach value, so its
## isolation needs are simpler.
extends GdUnitTestSuite

const SaveSystemScript: GDScript = preload("res://src/core/save_system.gd")

const _TEST_INTERVAL_SEC: float = 0.3

var _resource_snapshot: Dictionary[StringName, float] = {}
var _save_systems: Array[Node] = []

var _had_save_file: bool = false
var _save_file_backup: String = ""
var _had_temp_file: bool = false
var _temp_file_backup: String = ""


func before_test() -> void:
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_save_systems = []

	_had_save_file = FileAccess.file_exists(SaveSystemScript.SAVE_PATH)
	if _had_save_file:
		var existing: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.READ)
		_save_file_backup = existing.get_as_text()
		existing.close()
		DirAccess.remove_absolute(SaveSystemScript.SAVE_PATH)
	_had_temp_file = FileAccess.file_exists(SaveSystemScript.TEMP_PATH)
	if _had_temp_file:
		var existing_temp: FileAccess = FileAccess.open(SaveSystemScript.TEMP_PATH, FileAccess.READ)
		_temp_file_backup = existing_temp.get_as_text()
		existing_temp.close()
		DirAccess.remove_absolute(SaveSystemScript.TEMP_PATH)


func after_test() -> void:
	for instance: Node in _save_systems:
		if is_instance_valid(instance):
			instance.queue_free()

	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)

	if FileAccess.file_exists(SaveSystemScript.SAVE_PATH):
		DirAccess.remove_absolute(SaveSystemScript.SAVE_PATH)
	if _had_save_file:
		var restored: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.WRITE)
		restored.store_string(_save_file_backup)
		restored.close()
	if FileAccess.file_exists(SaveSystemScript.TEMP_PATH):
		DirAccess.remove_absolute(SaveSystemScript.TEMP_PATH)
	if _had_temp_file:
		var restored_temp: FileAccess = FileAccess.open(SaveSystemScript.TEMP_PATH, FileAccess.WRITE)
		restored_temp.store_string(_temp_file_backup)
		restored_temp.close()


## Instantiates a fresh SaveSystem, adds it to the tree, and overrides its
## debounce interval to [constant _TEST_INTERVAL_SEC] for fast, bounded
## tests. Tracked for automatic cleanup in after_test().
func _new_save_system() -> Node:
	var instance: Node = SaveSystemScript.new()
	add_child(instance)
	instance._debounce_timer.wait_time = _TEST_INTERVAL_SEC
	_save_systems.append(instance)
	return instance


func _read_save_file() -> Dictionary:
	var file: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed


## AC-1: ready and idle, one mark_dirty() call, nothing else for the debounce
## interval -> exactly one save written.
func test_single_isolated_trigger_writes_exactly_one_save() -> void:
	var save_system: Node = _new_save_system()
	var save_count: Array = [0]
	save_system._debounce_timer.timeout.connect(func() -> void: save_count[0] += 1)
	var interval: float = save_system._debounce_timer.wait_time

	save_system.mark_dirty()
	await get_tree().create_timer(interval + 0.1).timeout

	assert_int(save_count[0]).is_equal(1)


## AC-2: a trigger has fired and the timer is running, a second trigger
## fires partway through -> only one save is written, timed from the
## *second* (latest) trigger, not the first.
func test_two_triggers_within_window_coalesce_into_one_save() -> void:
	var save_system: Node = _new_save_system()
	var save_count: Array = [0]
	save_system._debounce_timer.timeout.connect(func() -> void: save_count[0] += 1)
	var interval: float = save_system._debounce_timer.wait_time

	save_system.mark_dirty()
	await get_tree().create_timer(interval * 0.5).timeout
	save_system.mark_dirty()
	await get_tree().create_timer(interval + 0.1).timeout

	assert_int(save_count[0]).is_equal(1)


## AC-3: multiple triggers within one window leave ResourceManager in
## different states -> the trailing-edge save reflects the state at the
## *last* trigger, not an earlier one.
func test_trailing_edge_save_reflects_latest_state() -> void:
	var save_system: Node = _new_save_system()
	var interval: float = save_system._debounce_timer.wait_time

	ResourceManager.apply_delta({&"Reach": 11.0 - ResourceManager.get_resource(&"Reach")})
	save_system.mark_dirty()
	await get_tree().create_timer(interval * 0.5).timeout
	ResourceManager.apply_delta({&"Reach": 22.0 - ResourceManager.get_resource(&"Reach")})
	save_system.mark_dirty()
	await get_tree().create_timer(interval + 0.1).timeout

	var parsed: Dictionary = _read_save_file()
	assert_float(float(parsed["resources"]["Reach"])).is_equal_approx(22.0, 0.0001)


## AC-4: the debounce timer is near the end of its window, a new trigger
## fires at that moment -> the timer resets to 0; no save fires on the
## original schedule, and the save that does fire is timed from this newest
## trigger.
func test_timer_resets_near_boundary_save_fires_after_newest_trigger() -> void:
	var save_system: Node = _new_save_system()
	var save_count: Array = [0]
	save_system._debounce_timer.timeout.connect(func() -> void: save_count[0] += 1)
	var interval: float = save_system._debounce_timer.wait_time

	save_system.mark_dirty()
	await get_tree().create_timer(interval * 0.95).timeout
	save_system.mark_dirty()

	# Shortly after the ORIGINAL window would have elapsed, confirm no save
	# has fired yet -- it was reset, not allowed to complete on the old
	# schedule.
	await get_tree().create_timer(interval * 0.15).timeout
	assert_int(save_count[0]).is_equal(0)

	# Wait out the remainder of the NEW window.
	await get_tree().create_timer(interval).timeout
	assert_int(save_count[0]).is_equal(1)


## AC-5: ready with no triggers -> no write occurs, regardless of elapsed
## time.
func test_no_triggers_no_write() -> void:
	var save_system: Node = _new_save_system()
	var save_count: Array = [0]
	save_system._debounce_timer.timeout.connect(func() -> void: save_count[0] += 1)
	var interval: float = save_system._debounce_timer.wait_time

	await get_tree().create_timer(interval + 0.1).timeout

	assert_int(save_count[0]).is_equal(0)
	assert_bool(FileAccess.file_exists(SaveSystemScript.SAVE_PATH)).is_false()
	assert_int(save_system.state).is_equal(SaveSystemScript.State.READY)


## AC-6: a debounced save is pending (timer running) when the OS signals
## backgrounding -> the save fires immediately, bypassing the remaining
## debounce window. Simulated via direct _notification() invocation per the
## story's Implementation Notes (headless test cannot trigger a real OS
## lifecycle event).
func test_mobile_lifecycle_flush_fires_pending_save_immediately() -> void:
	var save_system: Node = _new_save_system()
	ResourceManager.apply_delta({&"Reach": 50.0 - ResourceManager.get_resource(&"Reach")})
	save_system.mark_dirty()

	save_system._notification(NOTIFICATION_APPLICATION_PAUSED)

	assert_bool(FileAccess.file_exists(SaveSystemScript.SAVE_PATH)).is_true()
	var parsed: Dictionary = _read_save_file()
	assert_float(float(parsed["resources"]["Reach"])).is_equal_approx(50.0, 0.0001)


## AC-6 edge case: backgrounding with NO pending save must not trigger a
## spurious write.
func test_mobile_lifecycle_flush_with_no_pending_save_is_noop() -> void:
	var save_system: Node = _new_save_system()

	save_system._notification(NOTIFICATION_APPLICATION_PAUSED)

	assert_bool(FileAccess.file_exists(SaveSystemScript.SAVE_PATH)).is_false()


## Smoke test (not itself an AC): locks the real production debounce
## interval at exactly 2.0s, per the Tuning Knob default in
## save-persistence-system.md. Every other test in this suite overrides
## _debounce_timer.wait_time for speed; this is the one place the literal
## constant is checked, so an accidental edit (e.g. to 0.2) doesn't slip
## through unnoticed.
func test_production_debounce_interval_constant_is_two_seconds() -> void:
	assert_float(SaveSystemScript._DEBOUNCE_INTERVAL_SEC).is_equal_approx(2.0, 0.0001)
