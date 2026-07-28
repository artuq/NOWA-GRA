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


## AC: the destructive confirm layer is never visible on entry.
func test_confirm_panel_hidden_initially() -> void:
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	assert_bool((s.find_child("ConfirmPanel", true, false) as Control).visible).is_false()


## AC: all four buttons are wired to their handlers at _ready.
func test_buttons_wired() -> void:
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	assert_bool((s.find_child("ContinueButton", true, false) as Button).pressed.is_connected(s._on_continue_pressed)).is_true()
	assert_bool((s.find_child("NewGameButton", true, false) as Button).pressed.is_connected(s._on_new_game_pressed)).is_true()
	assert_bool((s.find_child("ConfirmDeleteButton", true, false) as Button).pressed.is_connected(s._on_confirm_delete_pressed)).is_true()
	assert_bool((s.find_child("ConfirmCancelButton", true, false) as Button).pressed.is_connected(s._on_confirm_cancel_pressed)).is_true()


## AC: Continue requests exactly one swap to the boot scene (single-fire guard
## holds across repeated taps) and never touches the save file.
func test_continue_requests_boot_scene_once() -> void:
	SaveSystem.save_now()
	var save_text_before: String = FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)
	var runner: GdUnitSceneRunner = scene_runner(START_SCENE)
	var s: Control = runner.scene()
	s.boot_scene_path = START_SCENE  # harmless valid target
	var routed: Array[String] = []
	s.scene_swap_requested.connect(func(path: String) -> void: routed.append(path))

	s._on_continue_pressed()
	s._on_continue_pressed()  # second tap: guarded no-op

	assert_array(routed).contains_exactly([START_SCENE])
	assert_str(FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)).is_equal(save_text_before)
	assert_bool(FileAccess.file_exists(SaveSystem.BACKUP_PATH)).is_false()


## AC: New Game shows the confirm layer; Cancel hides it again without any
## swap or save mutation.
func test_new_game_confirm_then_cancel_is_a_noop() -> void:
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
