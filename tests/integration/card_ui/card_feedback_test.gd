## Integration tests for CardScreen's Juice Card channel (Juice/Feedback
## Story 003, TR-juice-002/005/006, ADR-0011 §3). Covers the QA test cases
## embedded in the story: magnitude tier gating (pulse always, shake only at
## m >= 0.3), scale returning to ONE (incl. interrupt), direct-resolve pivot
## centring, rest-position return after shake, no-valence param identity,
## backgrounding during RESOLVING, and the payoff-beat clamp (TR-juice-005).
##
## Synthetic cards use Morale/Cringe deltas chosen to land exact magnitudes
## (Morale +3 -> 0.1; Morale +9 -> 0.3; Cringe +17.5 -> 0.5; Cringe +24.5 ->
## 0.7; Cringe +31.5 -> 0.9). resolve() applies real deltas via
## DecisionCardSystem — resources snapshot/restored per the suite convention.
extends GdUnitTestSuite

var _resource_snapshot: Dictionary[StringName, float] = {}
var _onboarding_phase_snapshot: int


func before_test() -> void:
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")


func after_test() -> void:
	OnboardingGate.phase = _onboarding_phase_snapshot
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	SaveSystem._debounce_timer.stop()


func _card_with_deltas(deltas: Dictionary) -> Dictionary:
	return {
		"id": "juice_test_card",
		"text": "Feel me.",
		"options": [
			{"label": "A", "resolution_reaction": "Done.", "resource_deltas": deltas, "counter_increments": {}},
			{"label": "B", "resolution_reaction": "Done.", "resource_deltas": {}, "counter_increments": {}},
		],
	}


## Presents [param card] on a fresh CardScreen with a fast resolution beat.
func _present(card: Dictionary) -> Node:
	DecisionCardSystem.present_next_card([card] as Array[Dictionary])
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.card_presented.emit(card)
	screen.resolution_beat_seconds = 0.05
	screen.resolution_beat_per_char = 0.0
	screen.resolution_beat_milestone_bonus = 0.0
	return screen


# --- AC-1: tier gating ---

func test_low_magnitude_pulses_without_shake() -> void:
	var screen: Node = _present(_card_with_deltas({&"Morale": 3.0}))  # m = 0.1
	await get_tree().process_frame

	screen.resolve(0)
	await get_tree().process_frame

	assert_float(screen._last_juice_magnitude).is_equal_approx(0.1, 0.001)
	assert_bool(screen._juice_pulse_tween != null and screen._juice_pulse_tween.is_running()).is_true()
	assert_bool(screen._juice_shake_tween == null).is_true()  # never created below 0.3
	await get_tree().create_timer(0.4).timeout


func test_mid_magnitude_pulses_and_shakes() -> void:
	var screen: Node = _present(_card_with_deltas({&"Cringe": 17.5}))  # m = 0.5
	await get_tree().process_frame

	screen.resolve(0)
	await get_tree().process_frame

	assert_float(screen._last_juice_magnitude).is_equal_approx(0.5, 0.001)
	assert_bool(screen._juice_pulse_tween.is_running()).is_true()
	assert_bool(screen._juice_shake_tween != null and screen._juice_shake_tween.is_running()).is_true()
	await get_tree().create_timer(0.5).timeout


func test_boundary_0_7_enters_high_tier() -> void:
	var screen: Node = _present(_card_with_deltas({&"Cringe": 24.5}))  # m = 0.7 exactly (high-tier floor)
	await get_tree().process_frame

	screen.resolve(0)
	await get_tree().process_frame

	assert_float(screen._last_juice_magnitude).is_equal_approx(0.7, 0.001)
	assert_bool(screen._juice_shake_tween != null and screen._juice_shake_tween.is_running()).is_true()
	# High-tier boundary values (amp exactly 4.0px, duration 0.15s at m=0.7)
	# are asserted in FeedbackMath's unit suite — here we assert the channel
	# actually consumes the high-tier branch.
	await get_tree().create_timer(0.5).timeout


## Gap closure (code review 2026-07-06): on a long-lived screen, a no-shake
## resolve after a shaking one must null the shake tween — the field is an
## honest "no shake this resolve" signal, not a stale dead reference.
func test_shake_tween_nulled_on_subsequent_low_magnitude_resolve() -> void:
	var screen: Node = _present(_card_with_deltas({&"Cringe": 31.5}))  # m = 0.9 — shakes
	await get_tree().process_frame
	screen.resolve(0)
	await get_tree().create_timer(0.4).timeout  # beat done, screen HIDDEN

	# Second card on the SAME screen instance, low magnitude.
	var low_card: Dictionary = _card_with_deltas({&"Morale": 3.0})  # m = 0.1
	DecisionCardSystem.present_next_card([low_card] as Array[Dictionary])
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.card_presented.emit(low_card)
	await get_tree().process_frame
	screen.resolve(0)
	await get_tree().process_frame

	assert_bool(screen._juice_shake_tween == null).is_true()
	await get_tree().create_timer(0.4).timeout


func test_boundary_0_3_shakes() -> void:
	var screen: Node = _present(_card_with_deltas({&"Morale": 9.0}))  # m = 0.3 exactly (inclusive)
	await get_tree().process_frame

	screen.resolve(0)
	await get_tree().process_frame

	assert_float(screen._last_juice_magnitude).is_equal_approx(0.3, 0.001)
	assert_bool(screen._juice_shake_tween != null).is_true()
	await get_tree().create_timer(0.4).timeout


# --- AC-2: scale returns to ONE (including interrupt by next present) ---

func test_scale_resets_to_one_on_next_present() -> void:
	var screen: Node = _present(_card_with_deltas({&"Cringe": 31.5}))  # m = 0.9
	await get_tree().process_frame
	var card_node: Control = screen.find_child("Card", true, false) as Control

	screen.resolve(0)
	await get_tree().process_frame  # pulse mid-flight — scale != ONE

	# Interrupt: present the next card immediately, before the pulse settles.
	DecisionCardSystem.card_presented.emit(_card_with_deltas({}))
	assert_that(card_node.scale).is_equal(Vector2.ONE)
	await get_tree().create_timer(0.5).timeout


# --- AC-3: direct resolve() centres the pivot itself ---

func test_direct_resolve_sets_pivot_to_centre() -> void:
	var screen: Node = _present(_card_with_deltas({&"Morale": 3.0}))
	await get_tree().process_frame
	var card_node: Control = screen.find_child("Card", true, false) as Control
	card_node.pivot_offset = Vector2.ZERO  # simulate no-drag default

	screen.resolve(0)

	assert_that(card_node.pivot_offset).is_equal(card_node.size / 2.0)
	await get_tree().create_timer(0.4).timeout


# --- AC-4: shake returns exactly to rest position ---

func test_shake_returns_to_rest_position() -> void:
	var screen: Node = _present(_card_with_deltas({&"Cringe": 31.5}))  # m = 0.9, max-tier shake
	await get_tree().process_frame
	var card_node: Control = screen.find_child("Card", true, false) as Control
	var rest: Vector2 = card_node.position

	screen.resolve(0)
	await get_tree().create_timer(0.7).timeout  # shake (<=0.40s) + pulse fully settled

	assert_float(card_node.position.distance_to(rest)).is_less_equal(0.01)
	assert_that(card_node.scale).is_equal(Vector2.ONE)


# --- AC-5: no-valence param identity ---

func test_mirrored_outcomes_produce_identical_magnitude() -> void:
	var screen_loss: Node = _present(_card_with_deltas({&"Cringe": 17.5, &"Morale": -3.0}))
	await get_tree().process_frame
	screen_loss.resolve(0)
	var loss_magnitude: float = screen_loss._last_juice_magnitude
	await get_tree().create_timer(0.4).timeout

	var screen_win: Node = _present(_card_with_deltas({&"Cringe": -17.5, &"Morale": 3.0}))
	await get_tree().process_frame
	screen_win.resolve(0)
	var win_magnitude: float = screen_win._last_juice_magnitude
	await get_tree().create_timer(0.4).timeout

	assert_float(win_magnitude).is_equal(loss_magnitude)


# --- AC-7: backgrounding during RESOLVING kills juice tweens ---

func test_backgrounding_during_resolving_leaves_clean_state() -> void:
	var screen: Node = _present(_card_with_deltas({&"Cringe": 31.5}))
	await get_tree().process_frame
	var card_node: Control = screen.find_child("Card", true, false) as Control

	screen.resolve(0)
	await get_tree().process_frame  # mid-pulse/shake, state == RESOLVING

	screen.notification(Node.NOTIFICATION_APPLICATION_PAUSED)

	assert_bool(screen._juice_pulse_tween.is_running()).is_false()
	if screen._juice_shake_tween != null:
		assert_bool(screen._juice_shake_tween.is_running()).is_false()
	assert_that(card_node.scale).is_equal(Vector2.ONE)
	await get_tree().create_timer(0.4).timeout


# --- AC-8: payoff-beat clamp (TR-juice-005) ---

func test_payoff_beat_clamps_to_gdd_bounds_at_default_knobs() -> void:
	# Fresh screen, DEFAULT knobs (not the lowered test values).
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()

	assert_float(screen._resolution_beat_duration("", false)).is_equal_approx(1.5, 0.001)          # floor
	assert_float(screen._resolution_beat_duration("a".repeat(30), false)).is_equal_approx(2.0, 0.001)   # midpoint
	assert_float(screen._resolution_beat_duration("a".repeat(60), false)).is_equal_approx(2.5, 0.001)   # ceiling
	assert_float(screen._resolution_beat_duration("a".repeat(200), false)).is_equal_approx(2.5, 0.001)  # clamped
	# card-ui.md's milestone bonus rides ON TOP of the text clamp (documented
	# GDD reconciliation — juice GDD clamps text scaling, card-ui GDD demands
	# the heavier milestone beat).
	assert_float(screen._resolution_beat_duration("a".repeat(200), true)).is_equal_approx(3.5, 0.001)
