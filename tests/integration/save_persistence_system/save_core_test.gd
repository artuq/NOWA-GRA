## Integration tests for SaveSystem's core save/load mechanics (Story 001,
## TR-save-001/002/003). Covers state transitions, atomic write +
## schema_version + corruption/mismatch fallback, and save/load round-trip
## correctness for ResourceManager + HistoryFlagManager (the only two real
## peer systems — Decision Card System doesn't exist yet, so its placeholder
## is written but never round-trip tested, per the story's explicit scope
## amendment from the QL-STORY-READY gate).
##
## SaveSystem is normally an Autoload singleton, but for test isolation each
## test instantiates a fresh instance directly from the script (matching this
## codebase's established Story 001/002 precedent for other Autoloads).
## UNLIKE those modules, SaveSystem's _ready() reaches out to the REAL
## ResourceManager/HistoryFlagManager Autoload singletons (there is only one
## of each in the running engine — GDScript Autoloads cannot be instantiated
## fresh) and to the REAL filesystem (user://save.json / user://save.tmp).
## Test isolation here means: back up and restore the real save files around
## every test, and use restore_state()'s ability to set any value (including
## reverting a counter downward, which bypasses increment_counter()'s
## monotonic guard by design — restore_state() is a boot-time bulk loader,
## not a gameplay mutation) to put HistoryFlagManager's test-only counter
## back to its pre-test value afterward.
##
## HistoryFlagManager's MILESTONES cannot be unset by any API, including
## restore_state() (it only ever sets true, matching the module's permanent-
## history design) — this suite uses one dedicated, clearly-scoped test-only
## milestone name (`test.save_persistence_core.fixture`) that no production
## code will ever check, and accepts that it remains permanently set after
## the first test run. This is consistent with HistoryFlagManager's
## documented immutability, not a test-isolation bug.
extends GdUnitTestSuite

const SaveSystemScript: GDScript = preload("res://src/core/save_system.gd")

const _TEST_MILESTONE: StringName = &"test.save_persistence_core.fixture"
const _TEST_COUNTER: StringName = &"test_save_persistence_core_counter"

var _resource_snapshot: Dictionary[StringName, float] = {}
var _counter_snapshot: int = 0
var _save_systems: Array[Node] = []

var _had_save_file: bool = false
var _save_file_backup: String = ""
var _had_temp_file: bool = false
var _temp_file_backup: String = ""


func before_test() -> void:
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Haters"] = ResourceManager.get_resource(&"Haters")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	_resource_snapshot[&"Sponsors"] = ResourceManager.get_resource(&"Sponsors")
	_counter_snapshot = HistoryFlagManager.get_counter(_TEST_COUNTER)
	_save_systems = []

	# Back up any real save file from outside this test run, then clear the
	# slate so every test starts from a known "no save file" state.
	_had_save_file = FileAccess.file_exists("user://save.json")
	if _had_save_file:
		var existing: FileAccess = FileAccess.open("user://save.json", FileAccess.READ)
		_save_file_backup = existing.get_as_text()
		existing.close()
		DirAccess.remove_absolute("user://save.json")
	_had_temp_file = FileAccess.file_exists("user://save.tmp")
	if _had_temp_file:
		var existing_temp: FileAccess = FileAccess.open("user://save.tmp", FileAccess.READ)
		_temp_file_backup = existing_temp.get_as_text()
		existing_temp.close()
		DirAccess.remove_absolute("user://save.tmp")


func after_test() -> void:
	for instance: Node in _save_systems:
		if is_instance_valid(instance):
			instance.queue_free()

	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	HistoryFlagManager.restore_state({"counters": {String(_TEST_COUNTER): _counter_snapshot}})

	if FileAccess.file_exists("user://save.json"):
		DirAccess.remove_absolute("user://save.json")
	if _had_save_file:
		var restored: FileAccess = FileAccess.open("user://save.json", FileAccess.WRITE)
		restored.store_string(_save_file_backup)
		restored.close()
	if FileAccess.file_exists("user://save.tmp"):
		DirAccess.remove_absolute("user://save.tmp")
	if _had_temp_file:
		var restored_temp: FileAccess = FileAccess.open("user://save.tmp", FileAccess.WRITE)
		restored_temp.store_string(_temp_file_backup)
		restored_temp.close()

	# The apply_delta() restore above marks the real SaveSystem dirty
	# (2026-06-29 fix). Stop its debounce timer LAST, after the on-disk
	# save.json/save.tmp backup/restore above, so a delayed save_now() can't
	# fire later in the suite and overwrite the just-restored backup with
	# live test state. See cooldown_pool_test.gd.
	SaveSystem._debounce_timer.stop()


## Instantiates a fresh SaveSystem and adds it to the tree (triggers
## _ready() -> load_save() + restore_state() on the real peer Autoloads).
## Tracked for automatic cleanup in after_test().
func _new_save_system() -> Node:
	var instance: Node = SaveSystemScript.new()
	add_child(instance)
	_save_systems.append(instance)
	return instance


## AC-1 / AC-9: no save file -> uninitialized -> loading -> ready;
## restore_state({}) is a true no-op, leaving ResourceManager exactly as it
## already was (the "default" being preserved, not reset to hardcoded zeros
## -- this suite runs inside a shared engine process where the absolute
## baseline may not be zero).
func test_no_save_file_reaches_ready_with_unchanged_defaults() -> void:
	var before_reach: float = ResourceManager.get_resource(&"Reach")

	var save_system: Node = _new_save_system()

	assert_int(save_system.state).is_equal(SaveSystemScript.State.READY)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(before_reach, 0.0001)


## AC-2: a valid, schema-matching save file exists -> loading it restores
## ResourceManager/HistoryFlagManager to match the file exactly.
func test_load_with_valid_save_file_restores_matching_state() -> void:
	var writer: Node = _new_save_system()
	ResourceManager.apply_delta({&"Reach": 42.0 - ResourceManager.get_resource(&"Reach")})
	HistoryFlagManager.restore_state({"counters": {String(_TEST_COUNTER): 7}})
	writer.save_now()

	# Change live state so the next load has something real to restore.
	ResourceManager.apply_delta({&"Reach": 0.0 - ResourceManager.get_resource(&"Reach")})
	HistoryFlagManager.restore_state({"counters": {String(_TEST_COUNTER): 0}})

	var reader: Node = _new_save_system()

	assert_int(reader.state).is_equal(SaveSystemScript.State.READY)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(42.0, 0.0001)
	assert_int(HistoryFlagManager.get_counter(_TEST_COUNTER)).is_equal(7)


## AC-3: calling save_now() from ready leaves state at ready (the write is
## synchronous -- there is no separate frame where SAVING is externally
## observable, so this confirms the call never leaves state stuck anywhere
## else, which is the testable substance of this criterion).
func test_save_now_returns_to_ready() -> void:
	var save_system: Node = _new_save_system()
	assert_int(save_system.state).is_equal(SaveSystemScript.State.READY)

	save_system.save_now()

	assert_int(save_system.state).is_equal(SaveSystemScript.State.READY)


## AC-4: once loaded this session, repeated save-triggering events never
## re-enter LOADING -- only ready<->saving.
func test_repeated_saves_never_reenter_loading() -> void:
	var save_system: Node = _new_save_system()

	save_system.save_now()
	save_system.save_now()
	save_system.save_now()

	assert_int(save_system.state).is_equal(SaveSystemScript.State.READY)


## AC-5: ResourceManager snapshot round-trips exactly through save+reload.
func test_resource_snapshot_round_trips_exactly() -> void:
	var writer: Node = _new_save_system()
	ResourceManager.apply_delta({
		&"Reach": 15.0 - ResourceManager.get_resource(&"Reach"),
		&"Cringe": 30.0 - ResourceManager.get_resource(&"Cringe"),
	})
	writer.save_now()

	ResourceManager.apply_delta({
		&"Reach": 0.0 - ResourceManager.get_resource(&"Reach"),
		&"Cringe": 0.0 - ResourceManager.get_resource(&"Cringe"),
	})

	_new_save_system()

	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(15.0, 0.0001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(30.0, 0.0001)


## AC-6: HistoryFlagManager milestones/counters round-trip exactly.
func test_history_flag_round_trips_exactly() -> void:
	var writer: Node = _new_save_system()
	HistoryFlagManager.set_milestone(_TEST_MILESTONE)
	HistoryFlagManager.restore_state({"counters": {String(_TEST_COUNTER): 9}})
	writer.save_now()

	HistoryFlagManager.restore_state({"counters": {String(_TEST_COUNTER): 0}})

	_new_save_system()

	assert_bool(HistoryFlagManager.has_milestone(_TEST_MILESTONE)).is_true()
	assert_int(HistoryFlagManager.get_counter(_TEST_COUNTER)).is_equal(9)


## AC-7: a second save after further changes is a complete, independent
## snapshot -- loading it reflects only the latest state, never the prior
## save's value.
func test_second_save_is_independent_snapshot() -> void:
	var writer: Node = _new_save_system()
	ResourceManager.apply_delta({&"Reach": 10.0 - ResourceManager.get_resource(&"Reach")})
	writer.save_now()

	ResourceManager.apply_delta({&"Reach": 99.0 - ResourceManager.get_resource(&"Reach")})
	writer.save_now()

	ResourceManager.apply_delta({&"Reach": 0.0 - ResourceManager.get_resource(&"Reach")})

	_new_save_system()

	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(99.0, 0.0001)


## AC-8: every save contains a correct schema_version and a last_saved_at
## matching that write's time.
func test_save_file_contains_correct_schema_version_and_timestamp() -> void:
	var before_time: float = Time.get_unix_time_from_system()
	var save_system: Node = _new_save_system()

	save_system.save_now()

	var file: FileAccess = FileAccess.open("user://save.json", FileAccess.READ)
	var parsed: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var after_time: float = Time.get_unix_time_from_system()

	assert_int(int(parsed["schema_version"])).is_equal(SaveSystemScript.SCHEMA_VERSION)
	assert_float(float(parsed["last_saved_at"])).is_greater_equal(before_time)
	assert_float(float(parsed["last_saved_at"])).is_less_equal(after_time)


## AC-10: a corrupted/unparseable save file falls back to defaults, no crash.
func test_corrupted_save_file_falls_back_to_defaults_no_crash() -> void:
	var file: FileAccess = FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string("{ this is not valid JSON")
	file.close()

	var save_system: Node = _new_save_system()

	assert_int(save_system.state).is_equal(SaveSystemScript.State.READY)


## AC-11: a write killed before the atomic rename leaves the previous,
## complete save intact -- simulated via file-system state, not a literal
## process kill (per Sprint 3 risk register).
func test_kill_before_rename_leaves_previous_save_intact() -> void:
	var writer: Node = _new_save_system()
	ResourceManager.apply_delta({&"Reach": 55.0 - ResourceManager.get_resource(&"Reach")})
	writer.save_now()

	# Simulate a kill mid-write: write a different snapshot to TEMP_PATH only,
	# intentionally never renaming it.
	var temp_data: Dictionary = {"schema_version": SaveSystemScript.SCHEMA_VERSION, "resources": {"Reach": 999.0}}
	var temp_file: FileAccess = FileAccess.open("user://save.tmp", FileAccess.WRITE)
	temp_file.store_string(JSON.stringify(temp_data))
	temp_file.close()

	ResourceManager.apply_delta({&"Reach": 0.0 - ResourceManager.get_resource(&"Reach")})
	_new_save_system()

	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(55.0, 0.0001)


## AC-12: a completed rename leaves the file reflecting the full new
## snapshot, with no remnant temp file.
func test_completed_rename_leaves_full_new_snapshot_no_temp_remnant() -> void:
	var save_system: Node = _new_save_system()

	save_system.save_now()

	assert_bool(FileAccess.file_exists("user://save.tmp")).is_false()
	assert_bool(FileAccess.file_exists("user://save.json")).is_true()


## AC-13: a schema_version mismatch in an otherwise valid file is discarded
## -- defaults initialize, ready reached, no partial migration attempted.
func test_schema_version_mismatch_falls_back_to_defaults_no_migration() -> void:
	var mismatched: Dictionary = {"schema_version": 999, "resources": {"Reach": 12345.0}}
	var file: FileAccess = FileAccess.open("user://save.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(mismatched))
	file.close()
	var before_reach: float = ResourceManager.get_resource(&"Reach")

	var save_system: Node = _new_save_system()

	assert_int(save_system.state).is_equal(SaveSystemScript.State.READY)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(before_reach, 0.0001)


## AC-14: a stray leftover .tmp file from an interrupted prior operation is
## never loaded -- only the final renamed .json file is read.
func test_stray_temp_file_is_never_loaded() -> void:
	var writer: Node = _new_save_system()
	ResourceManager.apply_delta({&"Reach": 33.0 - ResourceManager.get_resource(&"Reach")})
	writer.save_now()

	# Leave a stray .tmp file with DIFFERENT content than the real .json.
	var stray_data: Dictionary = {"schema_version": SaveSystemScript.SCHEMA_VERSION, "resources": {"Reach": 777.0}}
	var stray_file: FileAccess = FileAccess.open("user://save.tmp", FileAccess.WRITE)
	stray_file.store_string(JSON.stringify(stray_data))
	stray_file.close()

	ResourceManager.apply_delta({&"Reach": 0.0 - ResourceManager.get_resource(&"Reach")})
	_new_save_system()

	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(33.0, 0.0001)
