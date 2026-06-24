## Interaction test for ActionGrid (Story 003, Action UI epic). Uses
## GdUnit4's scene_runner() to instantiate the real scene headlessly and
## assert on button state/labels and ActionSystem interaction -- same
## evidence approach as Story 002's ResourceHud, the standing method for
## all UI stories in this project (see docs/tech-debt-register.md, Story
## 002 entry).
##
## ActionSystem state is reset per before_test()/after_test() to guarantee
## idle state at the start of each test, since start_action() is a
## single-concurrency gate.
extends GdUnitTestSuite

func before_test() -> void:
	# Force idle: if a prior test left an action running, resolve it before
	# this test begins. ActionSystem has no public "force idle" seam, so
	# directly clear current_action_id -- acceptable here since this is test
	# setup, not production code touching another system's internals.
	ActionSystem.current_action_id = &""

func after_test() -> void:
	ActionSystem.current_action_id = &""

## AC: exactly 6 slots, 3 unlocked + 3 locked.
func test_action_grid_renders_six_slots_three_unlocked_three_locked() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	var unlocked_count: int = 0
	var locked_count: int = 0
	for i in range(1, 7):
		var button: Button = grid.find_child("Slot%dButton" % i) as Button
		if button.disabled:
			locked_count += 1
		else:
			unlocked_count += 1

	assert_int(unlocked_count).is_equal(3)
	assert_int(locked_count).is_equal(3)

## AC: locked slot shows a generic lock, no number (unlock_threshold is null
## for all 3 placeholder locked slots in this story's scope).
func test_locked_slots_show_generic_lock_with_no_number() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	for i in range(4, 7):
		var button: Button = grid.find_child("Slot%dButton" % i) as Button
		assert_str(button.text).is_equal("🔒")

## AC: idle state -- tapping an unlocked button calls ActionSystem.start_action()
## and the action actually starts (current_action_id becomes non-empty).
func test_tapping_unlocked_button_starts_the_action() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var slot1: Button = runner.scene().find_child("Slot1Button") as Button

	slot1.pressed.emit()

	assert_str(String(ActionSystem.current_action_id)).is_equal("nagraj_vloga")

## AC: idle state -- tapping a locked slot is a no-op (it has no pressed
## connection at all, so emitting pressed on it changes nothing).
func test_tapping_locked_slot_is_a_noop() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var slot4: Button = runner.scene().find_child("Slot4Button") as Button

	slot4.pressed.emit()

	assert_str(String(ActionSystem.current_action_id)).is_equal("")

## AC: running state -- starting an action disables all 6 buttons immediately.
func test_starting_an_action_disables_all_six_buttons() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	var slot1: Button = grid.find_child("Slot1Button") as Button

	slot1.pressed.emit()

	for i in range(1, 7):
		var button: Button = grid.find_child("Slot%dButton" % i) as Button
		assert_bool(button.disabled).is_true()

## AC: running->resolved->idle transition re-enables the 3 unlocked buttons,
## but the 3 locked slots stay disabled.
func test_action_completed_reenables_unlocked_but_not_locked_slots() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	var slot1: Button = grid.find_child("Slot1Button") as Button
	slot1.pressed.emit()

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 5.0, &"Cringe": 2.0, &"Morale": 0.0})

	for i in range(1, 4):
		assert_bool((grid.find_child("Slot%dButton" % i) as Button).disabled).is_false()
	for i in range(4, 7):
		assert_bool((grid.find_child("Slot%dButton" % i) as Button).disabled).is_true()

## AC: button anatomy -- name, duration, and reward values with explicit
## sign prefixes, formatted via ActionUIFormatting.format_number().
func test_button_label_shows_name_duration_and_signed_rewards() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var slot2: Button = runner.scene().find_child("Slot2Button") as Button

	# zrob_drame: 9s, Reach +10, Cringe +20, Morale -3 (per ActionSystem.ACTION_REWARDS)
	assert_str(slot2.text).is_equal("Zrób dramę\n9s — +10Z, +20C, -3M")

## ActionScreen root scene instantiates ActionGrid as a sibling of ResourceHud.
func test_action_screen_root_instantiates_action_grid_zone() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_screen.tscn")
	var root: Node = runner.scene()
	var grid: Node = root.find_child("ActionGrid", true, false)
	var hud: Node = root.find_child("ResourceHud", true, false)

	assert_object(grid).is_not_null()
	assert_object(hud).is_not_null()

## AC (coverage gap closed, flagged by code review): an action name exceeding
## button width truncates with an ellipsis, button dimensions unchanged.
## Headless testing cannot inspect actual rendered pixels, so this test
## verifies the configuration that produces that behavior (clip_text +
## OVERRUN_TRIM_ELLIPSIS + a fixed custom_minimum_size) is correctly set on
## every slot button -- the actual glyph-level truncation is then a Godot
## TextServer guarantee, not something re-verified here. button.text itself
## is never mutated by clip_text (it's a rendering-only clip), so dimension
## stability is implied by custom_minimum_size never changing post-_ready().
func test_all_slot_buttons_configured_for_ellipsis_truncation_with_stable_size() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	for i in range(1, 7):
		var button: Button = grid.find_child("Slot%dButton" % i) as Button
		assert_bool(button.clip_text).is_true()
		assert_int(button.text_overrun_behavior).is_equal(TextServer.OVERRUN_TRIM_ELLIPSIS)
		assert_vector(button.custom_minimum_size).is_equal(Vector2(160, 100))

## AC (coverage gap closed, flagged by code review): start_action() returning
## false (e.g. an action already running) must not disable buttons a second
## time or error -- the pressed handler's `if started:` guard must hold.
func test_pressed_handler_does_not_disable_buttons_when_start_action_rejects() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	var slot1: Button = grid.find_child("Slot1Button") as Button
	var slot2: Button = grid.find_child("Slot2Button") as Button

	slot1.pressed.emit()  # starts nagraj_vloga, current_action_id now non-empty
	assert_bool(slot2.disabled).is_true()  # already disabled by the first start

	# Directly invoke the handler again (simulating a stale/race button press)
	# while an action is already running -- start_action() must return false,
	# and the handler must not error or change state further.
	runner.invoke("_on_unlocked_button_pressed", &"zrob_drame")

	assert_str(String(ActionSystem.current_action_id)).is_equal("nagraj_vloga")
	assert_bool(slot2.disabled).is_true()
