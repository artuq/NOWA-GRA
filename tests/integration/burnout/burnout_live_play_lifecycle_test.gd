## Integration coverage for BurnoutSystem's scene-owned live-play gate.
## ActionScreen is the sole lifecycle owner: boot/start/offline/challenge
## scenes never opt in, so the Autoload cannot advance there.
extends GdUnitTestSuite

const ACTION_SCREEN: PackedScene = preload("res://scenes/action_screen/action_screen.tscn")


func before_test() -> void:
	BurnoutSystem.set_live_play_active(false)


func after_test() -> void:
	BurnoutSystem.set_live_play_active(false)


func test_action_screen_activates_burnout_and_teardown_deactivates_it() -> void:
	var screen: Control = ACTION_SCREEN.instantiate()
	add_child(screen)
	await get_tree().process_frame

	assert_bool(BurnoutSystem.is_live_play_active()).is_true()
	assert_bool(BurnoutSystem.is_processing()).is_true()

	screen.free()

	assert_bool(BurnoutSystem.is_live_play_active()).is_false()
	assert_bool(BurnoutSystem.is_processing()).is_false()
