## Interaction tests for the Card UI swipe gesture (Story 003). Injects
## synthetic InputEventScreenTouch/Drag DIRECTLY into CardScreen._input() --
## NOT via runner.simulate_screen_touch_*(), whose window-to-viewport
## coordinate scaling in the headless harness inflates drag deltas (observed
## 2.5x on 2026-07-05, turning a 20%-width drag into a full-clamp rotation
## and breaking every distance-threshold assertion). Direct injection keeps
## positions in the same space the assertions compute in (viewport rect),
## and synthetic drags carry velocity == 0, making the flick-commit branch
## structurally unreachable -- no settle-drag workaround needed.
##
## Velocity-only commitment is covered by CardSwipeMath's unit tests
## (Story 001) + flagged manual; here the deterministic distance path and
## the gesture wiring (state machine, latch, bounce-back) are what's verified.
extends GdUnitTestSuite

var _onboarding_phase_snapshot: int

func before_test() -> void:
	# See cooldown_pool_test.gd's before_test() comment: force the real
	# OnboardingGate un-suppressed so committed swipes' resolve_choice() calls
	# aren't affected by onboarding state. Restored in after_test().
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN

func after_test() -> void:
	OnboardingGate.phase = _onboarding_phase_snapshot
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN
	# Committed swipes in this suite resolve real cards, marking the real
	# SaveSystem dirty (2026-06-29 fix) -- stop its debounce timer so a delayed
	# save_now() can't fire mid-suite. See cooldown_pool_test.gd.
	SaveSystem._debounce_timer.stop()

## Synthetic-event helpers: positions are viewport-space, velocity is 0.
func _press(screen: Node, index: int, pos: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = true
	event.position = pos
	screen._input(event)


func _drag_to(screen: Node, index: int, pos: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = pos
	event.velocity = Vector2.ZERO
	screen._input(event)


func _release(screen: Node, index: int, pos: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = false
	event.position = pos
	screen._input(event)


func _present_card() -> Dictionary:
	var card: Dictionary = {
		"id": "swipe_test_card",
		"text": "Swipe me.",
		"options": [
			{"label": "Left", "resolution_reaction": "Chose left.", "resource_deltas": {&"Reach": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
			{"label": "Right", "resolution_reaction": "Chose right.", "resource_deltas": {&"Reach": 5.0}, "counter_increments": {&"risky_choices_count": 1}},
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
	_press(screen, 0, start)
	_drag_to(screen, 0, moved)
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
	screen.resolution_beat_seconds = 0.05
	screen.resolution_beat_per_char = 0.0
	screen.resolution_beat_milestone_bonus = 0.0
	await runner.simulate_frames(2)
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	var committed: Vector2 = start + Vector2(width * 0.4, 0.0)  # 40% > 30%
	_press(screen, 0, start)
	_drag_to(screen, 0, committed)
	_release(screen, 0, committed)
	await runner.simulate_frames(2)

	# option_B (index 1) => Reach +5, applied synchronously on release.
	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(5.0, 0.0001)
	await get_tree().create_timer(0.12).timeout  # resolution beat then dismiss
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
	screen.resolution_beat_seconds = 0.05
	screen.resolution_beat_per_char = 0.0
	screen.resolution_beat_milestone_bonus = 0.0
	await runner.simulate_frames(2)
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	var committed_left: Vector2 = start - Vector2(width * 0.4, 0.0)  # left 40%
	_press(screen, 0, start)
	_drag_to(screen, 0, committed_left)
	_release(screen, 0, committed_left)
	await runner.simulate_frames(2)

	# option_A (index 0) => Reach +10
	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(10.0, 0.0001)
	await get_tree().create_timer(0.12).timeout  # resolution beat then dismiss
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
	var held: Vector2 = start + Vector2(width * 0.1, 0.0)  # 10% < 30%
	_press(screen, 0, start)
	_drag_to(screen, 0, held)  # synthetic drag: velocity == 0, flick branch unreachable
	_release(screen, 0, held)
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
	_press(screen, 0, start)
	_release(screen, 0, start)
	await runner.simulate_frames(2)

	assert_bool(screen.visible).is_true()
	assert_int(screen.state).is_equal(screen.State.AWAITING_SWIPE)

## AC: during a drag the option label in the drag direction is emphasised
## (scale up) and the opposite one dimmed (alpha down); on bounce-back both reset.
func test_drag_emphasises_direction_label_and_resets() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.card_presented.emit(_present_card())
	await runner.simulate_frames(2)
	var label_a: Label = screen.find_child("OptionALabel", true, false) as Label
	var label_b: Label = screen.find_child("OptionBLabel", true, false) as Label

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	var held: Vector2 = start + Vector2(width * 0.15, 0.0)  # heading right -> option_B
	_press(screen, 0, start)
	_drag_to(screen, 0, held)
	await runner.simulate_frames(1)

	# Right drag: B emphasised (scale > 1, full alpha), A dimmed (alpha < 1).
	assert_float(label_b.scale.x).is_greater(1.0)
	assert_float(label_a.modulate.a).is_less(1.0)

	# Release under threshold (velocity 0) -> bounce-back resets both labels.
	_release(screen, 0, held)
	await runner.simulate_frames(2)
	assert_float(label_a.scale.x).is_equal_approx(1.0, 0.001)
	assert_float(label_b.scale.x).is_equal_approx(1.0, 0.001)
	assert_float(label_a.modulate.a).is_equal_approx(1.0, 0.001)
	assert_float(label_b.modulate.a).is_equal_approx(1.0, 0.001)

## AC: single-touch latch -- once tracking touch index 0, a second touch (index
## 1) is ignored; dragging index 1 does NOT move the card.
func test_second_touch_is_ignored_while_dragging() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.card_presented.emit(_present_card())
	await runner.simulate_frames(2)

	var width: float = screen.get_viewport_rect().size.x
	var start: Vector2 = Vector2(width / 2.0, 400.0)
	_press(screen, 0, start)  # latch index 0
	_drag_to(screen, 0, start + Vector2(width * 0.15, 0.0))
	await runner.simulate_frames(1)

	# A second finger (index 1) starts and drags -- must be ignored entirely.
	_press(screen, 1, start)
	_drag_to(screen, 1, start + Vector2(width * 0.4, 0.0))
	await runner.simulate_frames(1)

	# Assert the latch DIRECTLY: index 0 is still tracked (the second finger
	# did not steal tracking), and we're still mid-drag.
	assert_int(screen._tracked_index).is_equal(0)
	assert_int(screen.state).is_equal(screen.State.DRAGGING)
