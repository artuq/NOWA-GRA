## Interaction tests for the Card UI swipe gesture (Story 003). Drives real
## InputEventScreenTouch/Drag through GdUnit4's scene_runner into CardScreen's
## _input handler -- the standing UI-evidence method.
##
## Thresholds are computed relative to the live viewport width (not a hardcoded
## 720) so the distance-commit assertions hold regardless of the headless
## window size. Velocity-only commitment is covered by CardSwipeMath's unit
## tests (Story 001) + flagged manual; here the deterministic distance path and
## the gesture wiring (state machine, latch, bounce-back) are what's verified.
extends GdUnitTestSuite

func before_test() -> void:
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN

func after_test() -> void:
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN

func _present_card() -> Dictionary:
	var card: Dictionary = {
		"id": "swipe_test_card",
		"text": "Swipe me.",
		"options": [
			{"label": "Left", "resource_deltas": {&"Reach": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
			{"label": "Right", "resource_deltas": {&"Reach": 5.0}, "counter_increments": {&"risky_choices_count": 1}},
		],
	}
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	return card

## AC: a touch + drag past the start threshold enters DRAGGING and rotates the
## card to CardSwipeMath.rotation_degrees(delta_x, half_width).
func test_drag_enters_dragging_and_rotates_card() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.card_presented.emit(_present_card())
	await runner.simulate_frames(2)

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	var moved: Vector2 = start + Vector2(width * 0.2, 0.0)  # +20% width, under commit
	await runner.simulate_screen_touch_press(0, start)
	await runner.simulate_screen_touch_drag(0, moved)
	await runner.simulate_frames(1)

	assert_int(screen.state).is_equal(screen.State.DRAGGING)
	var card_node: Control = screen.find_child("Card", true, false) as Control
	var expected: float = CardSwipeMath.rotation_degrees(width * 0.2, width / 2.0)
	assert_float(card_node.rotation_degrees).is_equal_approx(expected, 0.5)

## AC: releasing past the 30% commitment threshold to the RIGHT resolves
## option_B (index 1) and hides the modal.
func test_commit_right_resolves_option_b() -> void:
	var card: Dictionary = _present_card()
	DecisionCardSystem.present_next_card([card] as Array[Dictionary])
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.card_presented.emit(card)
	await runner.simulate_frames(2)
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	await runner.simulate_screen_touch_press(0, start)
	await runner.simulate_screen_touch_drag(0, start + Vector2(width * 0.4, 0.0))  # 40% > 30%
	await runner.simulate_screen_touch_release(0)
	await runner.simulate_frames(2)

	# option_B (index 1) => Reach +5
	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(5.0, 0.0001)
	assert_bool(screen.visible).is_false()
	# cleanup
	ResourceManager.apply_delta({&"Reach": reach_before - ResourceManager.get_resource(&"Reach")})

## AC: releasing past the threshold to the LEFT resolves option_A (index 0).
func test_commit_left_resolves_option_a() -> void:
	var card: Dictionary = _present_card()
	DecisionCardSystem.present_next_card([card] as Array[Dictionary])
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.card_presented.emit(card)
	await runner.simulate_frames(2)
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	await runner.simulate_screen_touch_press(0, start)
	await runner.simulate_screen_touch_drag(0, start - Vector2(width * 0.4, 0.0))  # left 40%
	await runner.simulate_screen_touch_release(0)
	await runner.simulate_frames(2)

	# option_A (index 0) => Reach +10
	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(10.0, 0.0001)
	assert_bool(screen.visible).is_false()
	ResourceManager.apply_delta({&"Reach": reach_before - ResourceManager.get_resource(&"Reach")})

## AC: releasing under the threshold (and no flick) bounces back -- no resolve,
## modal stays visible, returns to AWAITING_SWIPE.
func test_uncommitted_release_bounces_back() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.card_presented.emit(_present_card())
	await runner.simulate_frames(2)

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	await runner.simulate_screen_touch_press(0, start)
	await runner.simulate_screen_touch_drag(0, start + Vector2(width * 0.1, 0.0))  # 10% < 30%
	await runner.simulate_screen_touch_release(0)
	await runner.simulate_frames(2)

	assert_bool(screen.visible).is_true()  # not resolved
	assert_int(screen.state).is_equal(screen.State.AWAITING_SWIPE)

## AC: a tap with no drag movement is uncommitted -> bounce-back, no resolve.
func test_tap_without_drag_bounces_back() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.card_presented.emit(_present_card())
	await runner.simulate_frames(2)

	var start: Vector2 = Vector2(screen.get_viewport_rect().size.x / 2.0, 400.0)
	await runner.simulate_screen_touch_press(0, start)
	await runner.simulate_screen_touch_release(0)
	await runner.simulate_frames(2)

	assert_bool(screen.visible).is_true()
	assert_int(screen.state).is_equal(screen.State.AWAITING_SWIPE)

## AC: single-touch latch -- once tracking touch index 0, a second touch (index
## 1) is ignored; dragging index 1 does NOT move the card.
func test_second_touch_is_ignored_while_dragging() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.card_presented.emit(_present_card())
	await runner.simulate_frames(2)

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	await runner.simulate_screen_touch_press(0, start)  # latch index 0
	await runner.simulate_screen_touch_drag(0, start + Vector2(width * 0.15, 0.0))
	await runner.simulate_frames(1)
	var card_node: Control = screen.find_child("Card", true, false) as Control
	var pos_after_index0: Vector2 = card_node.position

	# A second finger (index 1) starts and drags -- must be ignored entirely.
	await runner.simulate_screen_touch_press(1, start)
	await runner.simulate_screen_touch_drag(1, start + Vector2(width * 0.4, 0.0))
	await runner.simulate_frames(1)

	assert_vector(card_node.position).is_equal_approx(pos_after_index0, Vector2(0.5, 0.5))
	assert_int(screen.state).is_equal(screen.State.DRAGGING)
