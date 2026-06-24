## Interaction test for RunningActionOverlay (Story 004, Action UI epic).
## Uses GdUnit4's scene_runner() to instantiate the real scene headlessly --
## same evidence approach as Stories 002/003.
##
## ActionSystem state is reset per before_test()/after_test() to guarantee
## idle state, since start_action() is a single-concurrency gate.
extends GdUnitTestSuite

func before_test() -> void:
	ActionSystem.current_action_id = &""

func after_test() -> void:
	ActionSystem.current_action_id = &""

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

## AC: action_started makes the overlay visible, enables _process(), and
## shows the action name.
func test_action_started_shows_overlay_and_enables_process() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/running_action_overlay.tscn")
	var overlay: Node = runner.scene()

	ActionSystem.start_action(&"zrob_drame")

	assert_bool(overlay.visible).is_true()
	assert_bool(overlay.is_processing()).is_true()
	assert_str((overlay.find_child("ActionNameLabel") as Label).text).is_equal("zrob_drame")

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
