## Interaction tests for CardScreen (Story 002, Card UI epic) + the new
## DecisionCardSystem.card_presented signal. Uses GdUnit4's scene_runner() to
## instantiate the real modal headlessly -- the standing UI-evidence method.
##
## DecisionCardSystem is an Autoload; its state and counters are reset/snapshot
## around tests so resolution side effects don't leak. resolve_choice() writes
## to ResourceManager/HistoryFlagManager, so those are snapshotted too (same
## pattern as card_resolution_test.gd).
extends GdUnitTestSuite

const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

var _resource_snapshot: Dictionary[StringName, float] = {}

func before_test() -> void:
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	# Ensure the live DecisionCardSystem Autoload is idle so the modal under
	# test controls its own visibility cleanly.
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN

func after_test() -> void:
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN

func _single_card_pool(card: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = [card]
	return pool

func _synthetic_card(id: String) -> Dictionary:
	return {
		"id": id,
		"trigger_condition": "always",
		"text": "A juicy dilemma appears.",
		"options": [
			{"label": "Sell out", "resolution_reaction": "Sold. 10k watched.", "resource_deltas": {&"Reach": 10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Stay true", "resolution_reaction": "Kept it real. 5k watched.", "resource_deltas": {&"Reach": 5.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	}

## AC: present_next_card emits card_presented exactly once with the chosen card,
## on a FRESH (non-Autoload) instance so we control the pool.
func test_present_next_card_emits_card_presented_with_the_card() -> void:
	var dcs: Node = DecisionCardSystemScript.new()
	add_child(dcs)
	var emitted: Array[Dictionary] = []
	dcs.card_presented.connect(func(card: Dictionary) -> void: emitted.append(card))

	var card: Dictionary = _synthetic_card("test_signal_card")
	dcs.present_next_card(_single_card_pool(card))

	assert_int(emitted.size()).is_equal(1)
	assert_str(emitted[0]["id"]).is_equal("test_signal_card")
	dcs.queue_free()

## AC: the modal appears (visible) on card_presented and shows the card content
## (situation text + both option labels with directional arrows).
func test_modal_appears_and_shows_content_on_signal() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	assert_bool(screen.visible).is_false()  # hidden until a card is presented

	DecisionCardSystem.card_presented.emit(_synthetic_card("test_content_card"))

	assert_bool(screen.visible).is_true()
	assert_str((screen.find_child("SituationLabel") as Label).text).is_equal("A juicy dilemma appears.")
	assert_str((screen.find_child("OptionALabel") as Label).text).is_equal("← Sell out")
	assert_str((screen.find_child("OptionBLabel") as Label).text).is_equal("Stay true →")

## AC: empty placeholder copy falls back to the card id (title) and neutral
## "Option A/B" arrow labels (CardContentDatabase's text/labels are empty,
## no category field -- documented gap).
func test_modal_falls_back_for_empty_placeholder_copy() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	var empty_card: Dictionary = {
		"id": "hater_callout",
		"text": "",
		"options": [{"label": ""}, {"label": ""}],
	}

	DecisionCardSystem.card_presented.emit(empty_card)

	assert_str((screen.find_child("SituationLabel") as Label).text).is_equal("hater_callout")
	assert_str((screen.find_child("OptionALabel") as Label).text).is_equal("← Option A")
	assert_str((screen.find_child("OptionBLabel") as Label).text).is_equal("Option B →")

## AC: resolving calls DecisionCardSystem.resolve_choice with the right index
## and hides the modal. Driven against a fresh DCS so resolve_choice has a
## real presented card to act on.
func test_resolve_calls_resolve_choice_and_hides() -> void:
	# Drive a real presented card through the live Autoload so resolve_choice
	# (which requires state==PRESENTING + a _presented_card) actually applies.
	var card: Dictionary = _synthetic_card("test_resolve_card")
	DecisionCardSystem.present_next_card(_single_card_pool(card))  # emits, sets PRESENTING

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	# The modal also caught the present via its own connection during _ready?
	# No -- present happened before the modal existed; emit again so it shows.
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.card_presented.emit(card)
	assert_bool(screen.visible).is_true()
	screen.resolution_beat_seconds = 0.05
	screen.resolution_beat_per_char = 0.0
	screen.resolution_beat_milestone_bonus = 0.0  # keep the beat short for the test
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	screen.resolve(0)  # option_A: Reach +10

	# Effects apply synchronously (before the beat's await); the card stays up
	# showing the reaction during the resolving beat, then dismisses.
	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(10.0, 0.0001)
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.COOLDOWN)
	assert_bool(screen.visible).is_true()
	assert_str((screen.find_child("SituationLabel") as Label).text).is_equal("Sold. 10k watched.")
	await get_tree().create_timer(0.12).timeout
	assert_bool(screen.visible).is_false()

## AC (gap closed, flagged by code review): card_presented is NOT emitted when
## the eligible pool is empty -- only present_next_card emits, and _check_pool
## never calls it on an empty pool. Driven via the _check_pool test seam with
## an explicitly empty override.
func test_card_presented_not_emitted_on_empty_pool() -> void:
	var dcs: Node = DecisionCardSystemScript.new()
	add_child(dcs)
	var emit_count: Array[int] = [0]
	dcs.card_presented.connect(func(_card: Dictionary) -> void: emit_count[0] += 1)

	var empty: Array[Dictionary] = []
	dcs._check_pool(empty)  # empty pool -> resets to COOLDOWN, no present, no emit

	assert_int(emit_count[0]).is_equal(0)
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	dcs.queue_free()

## AC (gap closed, flagged by code review): resolve(1) routes option_B's index,
## distinct from resolve(0). Uses a card whose two options have different Reach
## so the applied delta proves which index was passed.
func test_resolve_passes_option_b_index() -> void:
	var card: Dictionary = _synthetic_card("test_resolve_b_card")  # opt0 Reach+10, opt1 Reach+5
	DecisionCardSystem.present_next_card(_single_card_pool(card))
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.card_presented.emit(card)
	screen.resolution_beat_seconds = 0.05
	screen.resolution_beat_per_char = 0.0
	screen.resolution_beat_milestone_bonus = 0.0
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	screen.resolve(1)  # option_B: Reach +5 (not +10)

	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(5.0, 0.0001)
	await get_tree().create_timer(0.12).timeout  # let the beat finish before teardown

## AC: resolution-beat duration formula — base + per-char reading time, plus a
## fixed bonus for milestone-setting choices (heavier beat). Pure method check,
## no timing/await.
func test_resolution_beat_duration_formula() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	screen.resolution_beat_seconds = 1.5
	screen.resolution_beat_per_char = 0.04
	screen.resolution_beat_milestone_bonus = 1.0

	# 10-char reaction, no milestone: 1.5 + 10*0.04 = 1.9
	assert_float(screen._resolution_beat_duration("0123456789", false)).is_equal_approx(1.9, 0.0001)
	# longer text holds longer: 25 chars -> 1.5 + 1.0 = 2.5
	assert_float(screen._resolution_beat_duration("0123456789012345678901234", false)).is_equal_approx(2.5, 0.0001)
	# milestone adds a full second: 10 chars + milestone -> 1.9 + 1.0 = 2.9
	assert_float(screen._resolution_beat_duration("0123456789", true)).is_equal_approx(2.9, 0.0001)

## AC: a milestone-setting choice gets the heavier beat end-to-end (the option's
## milestone flag flows into the duration).
func test_milestone_choice_gets_heavier_beat() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	var milestone_card: Dictionary = {
		"id": "test_milestone_card",
		"text": "Big permanent choice.",
		"options": [
			{"label": "Do it", "resolution_reaction": "Done.", "resource_deltas": {}, "milestone_to_set": &"card.test.flag"},
			{"label": "Skip", "resolution_reaction": "Skipped.", "resource_deltas": {}},
		],
	}
	DecisionCardSystem.card_presented.emit(milestone_card)
	# option 0 sets a milestone, option 1 does not -> 0 must hold longer.
	var with_milestone: float = screen._resolution_beat_duration("X", screen._option_sets_milestone(0))
	var without_milestone: float = screen._resolution_beat_duration("X", screen._option_sets_milestone(1))
	assert_float(with_milestone - without_milestone).is_equal_approx(screen.resolution_beat_milestone_bonus, 0.0001)

## AC: the resolving beat — on resolve the card stays up and swaps the situation
## text to the chosen option's resolution_reaction, then dismisses after the beat.
func test_resolution_beat_shows_reaction_then_dismisses() -> void:
	var card: Dictionary = _synthetic_card("test_beat_card")
	DecisionCardSystem.present_next_card(_single_card_pool(card))
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	DecisionCardSystem.state = DecisionCardSystem.State.PRESENTING
	DecisionCardSystem.card_presented.emit(card)
	screen.resolution_beat_seconds = 0.05
	screen.resolution_beat_per_char = 0.0
	screen.resolution_beat_milestone_bonus = 0.0
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	screen.resolve(1)  # Stay true -> "Kept it real. 5k watched."

	# During the beat: still visible, situation text replaced by the reaction.
	assert_bool(screen.visible).is_true()
	assert_str((screen.find_child("SituationLabel") as Label).text).is_equal("Kept it real. 5k watched.")
	# After the beat: dismissed.
	await get_tree().create_timer(0.12).timeout
	assert_bool(screen.visible).is_false()
	ResourceManager.apply_delta({&"Reach": reach_before - ResourceManager.get_resource(&"Reach")})

## AC (gap closed, flagged by code review): resolve() is a no-op when the modal
## is hidden (no card shown) -- guards against a stray call, mirroring
## resolve_choice()'s own state guard. No resource change, stays hidden.
func test_resolve_is_noop_when_hidden() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/card_screen.tscn")
	var screen: Node = runner.scene()
	assert_bool(screen.visible).is_false()
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	screen.resolve(0)  # nothing presented -> must no-op

	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(reach_before, 0.0001)
	assert_bool(screen.visible).is_false()

## AC: the modal's root is a full-rect STOP Control and the top sibling under
## ActionScreen -- so while shown it consumes input before the Action UI zones
## beneath. (Headless can't simulate a real touch landing on a button beneath a
## modal, so this verifies the structural guarantee: root mouse_filter STOP +
## CardScreen is the last child of ActionScreen.)
func test_card_screen_is_topmost_stop_modal_under_action_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_screen.tscn")
	var root: Node = runner.scene()
	var card_screen: Control = root.find_child("CardScreen", true, false) as Control

	assert_object(card_screen).is_not_null()
	assert_int(card_screen.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	# CardScreen must be the LAST child of ActionScreen (drawn on top of the
	# Resource HUD / Action Grid / Running Action Overlay zones).
	assert_object(root.get_child(root.get_child_count() - 1)).is_equal(card_screen)
	# Idle by default -> invisible -> does not block the Action UI beneath.
	assert_bool(card_screen.visible).is_false()
