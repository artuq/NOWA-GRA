## Tests for SaveSystem.reset_save() (New Game, BUG-005) and the
## BootController routing predicates it pairs with. Runs against the isolated
## test save paths (save.test.json / save.test.backup.json — repointed in
## SaveSystem._init for GdUnit processes); files are removed around each test
## so no state leaks in either direction.
extends GdUnitTestSuite


func before_test() -> void:
	SaveSystem._debounce_timer.stop()
	_remove_save_files()


func after_test() -> void:
	SaveSystem._debounce_timer.stop()
	_remove_save_files()


func _remove_save_files() -> void:
	for path: String in [SaveSystem.SAVE_PATH, SaveSystem.BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## AC: the pre-reset save lands byte-identical in BACKUP_PATH.
func test_reset_backs_up_previous_save() -> void:
	SaveSystem.save_now()
	var old_text: String = FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)

	assert_bool(SaveSystem.reset_save()).is_true()

	assert_str(FileAccess.get_file_as_string(SaveSystem.BACKUP_PATH)).is_equal(old_text)


## AC: the fresh save keeps ONLY settings (accessibility survives the wipe) —
## no resources/history/prestige blocks, schema version current.
func test_reset_preserves_settings_and_nothing_else() -> void:
	SaveSystem.save_now()

	assert_bool(SaveSystem.reset_save()).is_true()

	var fresh: Dictionary = SaveSystem.load_save()
	assert_int(int(fresh.get("schema_version", -1))).is_equal(SaveSystem.SCHEMA_VERSION)
	assert_bool(fresh.has("settings")).is_true()
	var settings: Dictionary = fresh.get("settings", {})
	assert_bool(bool(settings.get("reduce_motion", not SettingsSystem.reduce_motion))).is_equal(SettingsSystem.reduce_motion)
	for progression_key: String in ["resources", "history_flags", "class_path", "prestige", "onboarding", "decision_card_state"]:
		assert_bool(fresh.has(progression_key)).is_false()


## AC: reset with no existing save still succeeds (no backup created — there
## was nothing to back up) and writes the fresh settings-only save.
func test_reset_without_existing_save_writes_fresh() -> void:
	assert_bool(SaveSystem.reset_save()).is_true()

	assert_bool(FileAccess.file_exists(SaveSystem.BACKUP_PATH)).is_false()
	assert_bool(SaveSystem.load_save().has("settings")).is_true()


## AC: has_progress() keys on the "resources" block — {} (first session) and
## the post-reset settings-only save both read as no-progress; any real
## save_now() snapshot reads as progress.
func test_has_progress_semantics() -> void:
	assert_bool(BootController.has_progress({})).is_false()

	SaveSystem.reset_save()
	assert_bool(BootController.has_progress(SaveSystem.load_save())).is_false()

	SaveSystem.save_now()
	assert_bool(BootController.has_progress(SaveSystem.load_save())).is_true()


## AC: the start-screen routing truth table — shown exactly when progress
## exists AND it hasn't been offered yet this session.
func test_should_show_start_screen_truth_table() -> void:
	var with_progress: Dictionary = {"schema_version": 1, "resources": {}}
	assert_bool(BootController.should_show_start_screen(with_progress, false)).is_true()
	assert_bool(BootController.should_show_start_screen(with_progress, true)).is_false()
	assert_bool(BootController.should_show_start_screen({}, false)).is_false()
	assert_bool(BootController.should_show_start_screen({}, true)).is_false()
