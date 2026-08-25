## Interaction test for RunningActionOverlay (Story 004, Action UI epic).
## Uses GdUnit4's scene_runner() to instantiate the real scene headlessly --
## same evidence approach as Stories 002/003.
##
## ActionSystem state is reset per before_test()/after_test() to guarantee
## idle state, since start_action() is a single-concurrency gate.
extends GdUnitTestSuite

var _class_path_snapshot: Dictionary
var _locale_snapshot: String

func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_class_path_snapshot = ClassPathSystem.serialize_state()
	ClassPathSystem.reset_era_state()
	ActionSystem._timer.stop()
	ActionSystem.current_action_id = &""
	ActionSystem.clear_queue()

func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)
	ActionSystem._timer.stop()
	ActionSystem.current_action_id = &""
	ActionSystem.clear_queue()
	ClassPathSystem.reset_era_state()
	ClassPathSystem.restore_state(_class_path_snapshot)
	SaveSystem._debounce_timer.stop()

## AC (`_process()` discipline, this story's core architectural requirement):
## the overlay must not process while idle, including at scene load --
## verified via simulate_frames() and confirming the progress bar never
## changes from its initial value while idle.
func test_process_disabled_while_idle_including_at_scene_load() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()
	var progress_bar: ProgressBar = overlay.find_child("ProgressBar") as ProgressBar
	var value_before: float = progress_bar.value

	runner.simulate_frames(5)

	assert_float(progress_bar.value).is_equal_approx(value_before, 0.0001)
	assert_bool(overlay.is_processing()).is_false()

## AC: overlay is hidden while idle.
func test_overlay_hidden_while_idle() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()

	assert_bool(overlay.visible).is_false()


## Package 2 regression: this full-screen overlay is presentation-only. Every
## Control in its subtree must ignore pointer input so the ActionGrid and the
## Sponsor Shield control remain tappable while an action is running.
func test_overlay_control_tree_ignores_pointer_input() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Control = runner.scene() as Control
	var pending: Array[Node] = [overlay]

	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is Control:
			assert_int((current as Control).mouse_filter).override_failure_message(
				"%s may intercept taps below the presentation overlay" % current.get_path()
			).is_equal(Control.MOUSE_FILTER_IGNORE)
		pending.append_array(current.get_children())

## AC: action_started makes the overlay visible, enables _process(), and
## shows the action name.
func test_action_started_shows_overlay_and_enables_process() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()

	ActionSystem.start_action(&"zrob_drame")

	assert_bool(overlay.visible).is_true()
	assert_bool(overlay.is_processing()).is_true()
	assert_str((overlay.find_child("ActionNameLabel") as Label).text).is_equal("Make Drama")


func test_runtime_polish_switch_updates_name_without_changing_running_action_id() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()

	ActionSystem.start_action(&"zrob_drame")
	assert_str((overlay.find_child("ActionNameLabel") as Label).text).is_equal("Make Drama")

	TranslationServer.set_locale("pl_PL")
	runner.invoke("_on_language_changed", &"pl", &"pl_PL")

	assert_str((overlay.find_child("ActionNameLabel") as Label).text).is_equal("Zrób dramę")
	assert_that(ActionSystem.current_action_id).is_equal(&"zrob_drame")

## AC: progress bar fill matches ActionSystem.get_progress() while running.
func test_progress_bar_fill_matches_get_progress_while_running() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()
	var progress_bar: ProgressBar = overlay.find_child("ProgressBar") as ProgressBar

	ActionSystem.start_action(&"zrob_drame")
	runner.simulate_frames(1)

	assert_float(progress_bar.value).is_equal_approx(ActionSystem.get_progress(), 0.0001)

## Coverage gap closed (flagged by code review): the remaining-time label was
## never asserted anywhere, despite being an explicit AC alongside the
## progress bar. Invokes _process() directly (rather than simulate_frames())
## for a deterministic single step, avoiding any real-frame-timing variance.
func test_remaining_time_label_shows_a_value_while_running() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()
	var remaining_label: Label = overlay.find_child("RemainingTimeLabel") as Label

	ActionSystem.start_action(&"zrob_drame")
	runner.invoke("_process", 0.0)

	assert_str(remaining_label.text).is_equal("9s")


## Regression: T4 duration bonuses arm a shorter Timer. Remaining time must
## use that effective duration rather than the base ACTION_DURATIONS entry.
func test_remaining_time_uses_effective_duration_after_class_path_bonus() -> void:
	ClassPathSystem._active_path = &"pato_streamer"
	ClassPathSystem._current_tier[&"pato_streamer"] = 4
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()
	var remaining_label: Label = overlay.find_child("RemainingTimeLabel") as Label

	ActionSystem.start_action(&"zrob_drame")
	runner.invoke("_process", 0.0)

	assert_str(remaining_label.text).is_equal("6s")

## Coverage gap closed (flagged by code review): progress bar correctly
## relays near-maximal fill shortly before completion. The exact
## elapsed_time>=duration -> fill_ratio=1 clamp is ActionSystem.get_progress()'s
## own tested contract (action_system_timer_concurrency_test.gd), not
## re-verified here -- this test only confirms the overlay correctly relays
## that value, without racing the action_completed signal that fires at the
## exact moment of completion (which would hide the overlay and freeze
## _process(), making an exact 1.0 assertion racy by construction).
## Timer.time_left is read-only in Godot 4.6.2/4.6.3 (docs/tech-debt-register.md)
## so this restarts the real Timer with a short bounded duration and checks
## shortly before it fires (~0.25s wall time, not flaky).
func test_progress_bar_shows_near_full_fill_shortly_before_completion() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()
	var progress_bar: ProgressBar = overlay.find_child("ProgressBar") as ProgressBar

	ActionSystem.start_action(&"zrob_drame")
	ActionSystem._timer.start(0.3)

	await overlay.get_tree().create_timer(0.25).timeout
	runner.simulate_frames(1)

	assert_float(progress_bar.value).is_greater(0.7)
	assert_bool(overlay.visible).is_true()

## AC: action_completed hides the overlay and disables _process().
func test_action_completed_hides_overlay_and_disables_process() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()
	ActionSystem.start_action(&"zrob_drame")
	assert_bool(overlay.visible).is_true()

	ActionSystem.action_completed.emit(&"zrob_drame", {&"Reach": 10.0, &"Cringe": 20.0, &"Morale": -3.0})

	assert_bool(overlay.visible).is_false()
	assert_bool(overlay.is_processing()).is_false()

## ActionScreen root scene instantiates all 3 zones as siblings.
func test_action_screen_root_instantiates_all_three_zones() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_screen.tscn")
	var root: Node = runner.scene()

	assert_object(root.find_child("ResourceHud", true, false)).is_not_null()
	assert_object(root.find_child("ActionGrid", true, false)).is_not_null()
	assert_object(root.find_child("RunningActionOverlay", true, false)).is_not_null()
