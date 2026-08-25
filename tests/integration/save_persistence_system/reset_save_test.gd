## Tests for SaveSystem.reset_save() (New Game, BUG-005) and the
## BootController routing predicates it pairs with. Runs against the isolated
## test save paths (save.test.json / save.test.backup.json — repointed in
## SaveSystem._init for GdUnit processes); files are removed around each test
## so no state leaks in either direction.
extends GdUnitTestSuite


func before_test() -> void:
	SaveSystem._debounce_timer.stop()
	SaveSystem._max_dirty_timer.stop()
	SaveSystem._reset_runtime_for_new_game()
	_remove_save_files()


func after_test() -> void:
	SaveSystem._debounce_timer.stop()
	SaveSystem._max_dirty_timer.stop()
	SaveSystem._reset_runtime_for_new_game()
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


## Regression: changing back to boot.tscn does not reconstruct Autoloads.
## New Game must therefore clear the live singleton state as well as disk.
func test_reset_clears_live_progress_and_ephemeral_gameplay_state() -> void:
	ResourceManager.apply_delta({
		&"Reach": 1234.0,
		&"Cringe": 70.0,
		&"Haters": 222.0,
		&"Morale": -55.0,
		&"Sponsors": 25.0,
	})
	HistoryFlagManager.set_milestone(&"test.unlocked")
	HistoryFlagManager.set_milestone(ActionUnlocks.SLOT_6_MILESTONE_RISKY)
	HistoryFlagManager.increment_counter(&"risky_choices_count", 12)
	ClassPathSystem.restore_state({
		"affiliation": {"pato_streamer": 60.0},
		"card_contribution": {"pato_streamer": 60.0},
		"current_tier": {"pato_streamer": 3},
		"active_path": "pato_streamer",
	})
	PrestigeSystem.restore_state({
		"era_count": 4,
		"meta_bonus_totals": {"META_REACH_MULT": 0.5},
	})
	PrestigeSystem._deferred_this_era = true
	StaffSystem.restore_state({"staff_count": {"assistant": 3}})
	ChallengeSystem.restore_state({"_active_challenge_ids": ["bez_tlumu"]})
	BurnoutSystem._cringe_sustained_seconds = 250.0
	BurnoutSystem._card_pending = true
	OfflineProgressSystem.last_simulation_result = {"total_Z_gained": 99.0}
	OnboardingGate.mark_skill_challenge_intro_seen(&"feed_sprint_challenge")
	OnboardingGate.mark_showcase_card_seen(&"brand_deal_choice")
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem._presented_card = {"id": "stale_card"}
	DecisionCardSystem._priority_card_pending = true
	assert_bool(ActionSystem.start_action(&"nagraj_vloga")).is_true()
	assert_bool(ActionSystem.start_action(&"zrob_drame")).is_true()

	assert_bool(SaveSystem.reset_save()).is_true()

	assert_float(ResourceManager.get_resource(&"Reach")).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Haters")).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal(100.0)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal(0.0)
	assert_bool(HistoryFlagManager.has_milestone(&"test.unlocked")).is_false()
	assert_int(HistoryFlagManager.get_counter(&"risky_choices_count")).is_equal(0)
	assert_array(ActionUnlocks.unlocked_slots(
		HistoryFlagManager.get_counter(&"risky_choices_count"),
		HistoryFlagManager.get_counter(&"safe_choices_count"),
		HistoryFlagManager.has_milestone(ActionUnlocks.SLOT_6_MILESTONE_RISKY),
		HistoryFlagManager.has_milestone(ActionUnlocks.SLOT_6_MILESTONE_SAFE),
	)).contains_exactly([false, false, false])
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(0)
	assert_str(String(ClassPathSystem.get_active_path())).is_empty()
	assert_int(PrestigeSystem.get_era_count()).is_equal(0)
	assert_bool(PrestigeSystem.has_deferred_this_era()).is_false()
	assert_int(StaffSystem.get_staff_count(&"assistant")).is_equal(0)
	assert_array(ChallengeSystem.get_active_challenge_ids()).is_empty()
	assert_float(BurnoutSystem._cringe_sustained_seconds).is_equal(0.0)
	assert_bool(BurnoutSystem._card_pending).is_false()
	assert_bool(OfflineProgressSystem.last_simulation_result.is_empty()).is_true()
	assert_bool(OnboardingGate.has_seen_skill_challenge(&"feed_sprint_challenge")).is_false()
	assert_bool(OnboardingGate.has_seen_showcase_card(&"brand_deal_choice")).is_false()
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.COOLDOWN)
	assert_bool(DecisionCardSystem._presented_card.is_empty()).is_true()
	assert_bool(DecisionCardSystem._priority_card_pending).is_false()
	assert_str(String(ActionSystem.current_action_id)).is_empty()
	assert_int(ActionSystem.get_queue_size()).is_equal(0)


## A failed fresh-save write must not report success or destroy the live
## career; StartScreen uses this return value to decide whether to reboot.
func test_reset_write_failure_keeps_live_progress() -> void:
	ResourceManager.apply_delta({&"Reach": 321.0})
	HistoryFlagManager.set_milestone(&"test.keep_on_write_failure")
	SaveSystem.save_now()
	var saved_text: String = FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)
	ResourceManager.apply_delta({&"Reach": 7.0})
	var reach_before_reset: float = ResourceManager.get_resource(&"Reach")
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()
	assert_bool(SaveSystem._max_dirty_timer.is_stopped()).is_false()
	var original_temp_path: String = SaveSystem.TEMP_PATH
	SaveSystem.TEMP_PATH = "user://missing-reset-parent/save.tmp"
	var succeeded: Array[bool] = [true]

	assert_error(func() -> void:
		succeeded[0] = SaveSystem.reset_save()
	).is_push_error(any_string())
	SaveSystem.TEMP_PATH = original_temp_path

	assert_bool(succeeded[0]).is_false()
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal(reach_before_reset)
	assert_bool(HistoryFlagManager.has_milestone(&"test.keep_on_write_failure")).is_true()
	assert_str(FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)).is_equal(saved_text)
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()
	assert_bool(SaveSystem._max_dirty_timer.is_stopped()).is_false()
	assert_float(SaveSystem._debounce_timer.wait_time).is_equal(SaveSystem._DEBOUNCE_INTERVAL_SEC)
	assert_float(SaveSystem._max_dirty_timer.wait_time).is_equal(SaveSystem._MAX_DIRTY_AGE_SEC)


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


## AC: the start-screen routing truth table — existing careers always receive
## the gate once per process; a fresh install receives it only until an
## explicit language choice has been persisted.
func test_should_show_start_screen_truth_table() -> void:
	var with_progress: Dictionary = {"schema_version": 1, "resources": {}}
	var fresh_confirmed: Dictionary = {
		"settings": {"language_choice_confirmed": true},
	}
	assert_bool(BootController.should_show_start_screen(with_progress, false)).is_true()
	assert_bool(BootController.should_show_start_screen(with_progress, true)).is_false()
	assert_bool(BootController.should_show_start_screen({}, false)).is_true()
	assert_bool(BootController.should_show_start_screen({}, true)).is_false()
	assert_bool(BootController.should_show_start_screen(fresh_confirmed, false)).is_false()


func test_save_settings_only_does_not_create_progress() -> void:
	SettingsSystem.set_language_preference(SettingsSystem.LANGUAGE_EN)

	assert_bool(SaveSystem.save_settings_only()).is_true()

	var data: Dictionary = SaveSystem.load_save()
	assert_bool(BootController.has_progress(data)).is_false()
	assert_bool(data.has("settings")).is_true()
	assert_bool(bool(data["settings"].get("language_choice_confirmed", false))).is_true()
