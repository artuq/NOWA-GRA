## Interaction tests for StartScreen (BUG-005 fix): the Continue / New Game
## gate. boot_scene_path is retargeted at the start screen scene itself
## (harmless, exists) so the real change_scene_to_file call never boots the
## actual game inside the test process — same pattern as
## offline_report_screen_test.gd's main_scene_path retarget.
##
## SaveSystem's test isolation (save.test.json / save.test.backup.json) is
## active for the whole run; this suite additionally removes both files around
## each test so it neither depends on nor leaks save-file state.
extends GdUnitTestSuite

const START_SCENE: String = "res://scenes/start_screen/start_screen.tscn"

var _language_preference_snapshot: StringName
var _language_confirmed_snapshot: bool
var _locale_snapshot: String


func before_test() -> void:
	_language_preference_snapshot = SettingsSystem.language_preference
	_language_confirmed_snapshot = SettingsSystem.language_choice_confirmed
	_locale_snapshot = TranslationServer.get_locale()
	SettingsSystem.language_preference = SettingsSystem.LANGUAGE_SYSTEM
	SettingsSystem.language_choice_confirmed = false
	SaveSystem._debounce_timer.stop()
	_remove_save_files()


func after_test() -> void:
	SettingsSystem.language_preference = _language_preference_snapshot
	SettingsSystem.language_choice_confirmed = _language_confirmed_snapshot
	TranslationServer.set_locale(_locale_snapshot)
	SaveSystem._debounce_timer.stop()
	_remove_save_files()


func _remove_save_files() -> void:
	for path: String in [SaveSystem.SAVE_PATH, SaveSystem.BACKUP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## AC: the destructive confirm layer is never visible on entry.
func test_confirm_panel_hidden_initially() -> void:
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	assert_bool((s.find_child("ConfirmPanel", true, false) as Control).visible).is_false()


## AC: navigation, language, and destructive-confirm buttons are all wired.
func test_buttons_wired() -> void:
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	assert_bool((s.find_child("ContinueButton", true, false) as Button).pressed.is_connected(s._on_continue_pressed)).is_true()
	assert_bool((s.find_child("NewGameButton", true, false) as Button).pressed.is_connected(s._on_new_game_pressed)).is_true()
	assert_bool((s.find_child("ConfirmDeleteButton", true, false) as Button).pressed.is_connected(s._on_confirm_delete_pressed)).is_true()
	assert_bool((s.find_child("ConfirmCancelButton", true, false) as Button).pressed.is_connected(s._on_confirm_cancel_pressed)).is_true()
	assert_bool((s.find_child("EnglishButton", true, false) as Button).pressed.is_connected(s._on_language_pressed.bind(SettingsSystem.LANGUAGE_EN))).is_true()
	assert_bool((s.find_child("PolishButton", true, false) as Button).pressed.is_connected(s._on_language_pressed.bind(SettingsSystem.LANGUAGE_PL))).is_true()


func test_fresh_install_requires_explicit_language_choice() -> void:
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	var continue_button: Button = s.find_child("ContinueButton", true, false) as Button

	assert_bool(continue_button.disabled).is_true()
	assert_bool((s.find_child("NewGameButton", true, false) as Button).visible).is_false()

	s._on_language_pressed(SettingsSystem.LANGUAGE_EN)

	assert_bool(SettingsSystem.language_choice_confirmed).is_true()
	assert_str(String(SettingsSystem.language_preference)).is_equal("en")
	assert_str(TranslationServer.get_locale()).is_equal("en")
	assert_bool(continue_button.disabled).is_false()


## AC: Continue requests exactly one swap to the boot scene (single-fire guard
## holds across repeated taps) without changing career or settings state.
func test_continue_requests_boot_scene_once() -> void:
	SettingsSystem.set_language_preference(SettingsSystem.LANGUAGE_EN)
	SaveSystem.save_now()
	var save_before: Dictionary = SaveSystem.load_save()
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	s.boot_scene_path = START_SCENE  # harmless valid target
	var routed: Array[String] = []
	s.scene_swap_requested.connect(func(path: String) -> void: routed.append(path))

	s._on_continue_pressed()
	s._on_continue_pressed()  # second tap: guarded no-op

	assert_array(routed).contains_exactly([START_SCENE])
	var save_after: Dictionary = SaveSystem.load_save()
	# A scene transition may flush a pending save and refresh only its clock.
	save_before.erase("last_saved_at")
	save_after.erase("last_saved_at")
	assert_dict(save_after).is_equal(save_before)
	assert_bool(FileAccess.file_exists(SaveSystem.BACKUP_PATH)).is_false()


func test_fresh_continue_persists_settings_without_creating_career() -> void:
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	s.boot_scene_path = START_SCENE
	s._on_language_pressed(SettingsSystem.LANGUAGE_PL)

	s._on_continue_pressed()

	var written: Dictionary = SaveSystem.load_save()
	assert_bool(BootController.has_progress(written)).is_false()
	assert_str(String(written["settings"]["language_preference"])).is_equal("pl")
	assert_bool(bool(written["settings"]["language_choice_confirmed"])).is_true()


## AC: New Game shows the confirm layer; Cancel hides it again without any
## swap or save mutation.
func test_new_game_confirm_then_cancel_is_a_noop() -> void:
	SettingsSystem.set_language_preference(SettingsSystem.LANGUAGE_EN)
	SaveSystem.save_now()
	var save_text_before: String = FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	s.boot_scene_path = START_SCENE
	var routed: Array[String] = []
	s.scene_swap_requested.connect(func(path: String) -> void: routed.append(path))
	var confirm: Control = s.find_child("ConfirmPanel", true, false)

	s._on_new_game_pressed()
	assert_bool(confirm.visible).is_true()
	s._on_confirm_cancel_pressed()
	assert_bool(confirm.visible).is_false()

	assert_array(routed).is_empty()
	assert_str(FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)).is_equal(save_text_before)


## AC: confirmed delete backs up the old save, leaves a fresh no-progress save
## behind (BootController.has_progress() == false), and requests the reboot.
func test_confirm_delete_resets_save_and_reboots() -> void:
	SettingsSystem.set_language_preference(SettingsSystem.LANGUAGE_EN)
	SaveSystem.save_now()
	var old_save_text: String = FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	s.boot_scene_path = START_SCENE
	var routed: Array[String] = []
	s.scene_swap_requested.connect(func(path: String) -> void: routed.append(path))

	s._on_new_game_pressed()
	s._on_confirm_delete_pressed()

	assert_array(routed).contains_exactly([START_SCENE])
	assert_str(FileAccess.get_file_as_string(SaveSystem.BACKUP_PATH)).is_equal(old_save_text)
	var fresh: Dictionary = SaveSystem.load_save()
	assert_bool(BootController.has_progress(fresh)).is_false()
	assert_bool(fresh.has("settings")).is_true()
