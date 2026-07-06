## Interaction test for ActionGrid's milestone/counter-gated slot unlocking
## (DDR-0001 #3, quick spec milestone-gated-action-slots-2026-06-30). Uses
## scene_runner() to instantiate the real grid and asserts the
## grid -> HistoryFlagManager -> ActionUnlocks -> activate pipeline.
##
## Coverage split: slots 4 & 5 are driven via the two gating COUNTERS
## (risky_choices_count / safe_choices_count), which can be reset cleanly per
## test (HistoryFlagManager.restore_state sets counters to any value without
## marking dirty). Slot 6 gates on two real milestones
## (card.staged_drama.chosen_risky / card.cancel_threat.apologized) which are
## immutable once set (no unset API by design) and would pollute every later
## test's "locked" assertions -- so its predicate is covered exhaustively by the
## pure ActionUnlocks unit test instead; the activation pipeline is identical for
## all 3 slots and is proven here via slots 4/5.
extends GdUnitTestSuite

var _risky_snapshot: int
var _safe_snapshot: int

func before_test() -> void:
	ActionSystem.current_action_id = &""
	_risky_snapshot = HistoryFlagManager.get_counter(&"risky_choices_count")
	_safe_snapshot = HistoryFlagManager.get_counter(&"safe_choices_count")
	_set_counters(0, 0)

func after_test() -> void:
	ActionSystem.current_action_id = &""
	_set_counters(_risky_snapshot, _safe_snapshot)

## restore_state sets the counters without marking the save dirty (a load, not a
## mutation) -- the clean way to force a known gating state.
func _set_counters(risky: int, safe: int) -> void:
	HistoryFlagManager.restore_state({"counters": {
		"risky_choices_count": risky, "safe_choices_count": safe,
	}})

func _gated_button(grid: Node, slot: int) -> Button:
	return grid.find_child("Slot%dButton" % slot) as Button

## Locked-state predicate per the Story 005 (locked slot preview) contract:
## locked slots are NOT disabled (they stay enabled for tap -> toast) -- the
## observable locked state is the grayed icon (LOCKED_MODULATE alpha) plus
## the padlock badge (texture, replaced the 🔒 text prefix 2026-07-06 --
## OpenSans has no padlock glyph, it rendered as a hex box on web).
func _assert_slot_locked(grid: Node, slot: int) -> void:
	assert_object((grid.find_child("Slot%dIcon" % slot) as TextureRect).modulate).is_equal(ActionGrid.LOCKED_MODULATE)
	assert_object(grid._lock_badges[slot - 4]).is_not_null()

func _assert_slot_unlocked(grid: Node, slot: int) -> void:
	assert_object((grid.find_child("Slot%dIcon" % slot) as TextureRect).modulate).is_equal(Color.WHITE)
	assert_object(grid._lock_badges[slot - 4]).is_null()
	assert_bool(_gated_button(grid, slot).disabled).is_false()

## AC: fresh game (0 decisions) -> all 3 gated slots (4/5/6) locked (grayed
## preview with lock prefix; buttons stay enabled for tap -> toast, Story 005).
func test_fresh_game_gated_slots_locked() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	for slot in [4, 5, 6]:
		_assert_slot_locked(grid, slot)

## AC: slot 4 unlocks via the risky path alone (risky_choices_count >= 3).
func test_slot4_unlocks_via_risky_path() -> void:
	_set_counters(3, 0)
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	_assert_slot_unlocked(grid, 4)
	assert_str((grid.find_child("Slot4Title") as Label).text).is_equal("Record a Collab")
	# Slot 5 (threshold 6) still locked at risky=3.
	_assert_slot_locked(grid, 5)

## AC: slot 4 unlocks via the safe path alone (DDR-0001 either-path constraint --
## the clean-path player is never locked out).
func test_slot4_unlocks_via_safe_path() -> void:
	_set_counters(0, 3)
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	_assert_slot_unlocked(grid, 4)

## AC: slot 5 unlocks at the higher threshold (>= 6), either path.
func test_slot5_unlocks_at_higher_threshold() -> void:
	_set_counters(0, 6)
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	_assert_slot_unlocked(grid, 5)
	assert_str((grid.find_child("Slot5Title") as Label).text).is_equal("Give an Interview")

## AC: an unlocked gated slot is tappable and starts its action.
func test_unlocked_gated_slot_starts_its_action() -> void:
	_set_counters(3, 0)
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var slot4: Button = _gated_button(runner.scene(), 4)

	slot4.pressed.emit()

	assert_str(String(ActionSystem.current_action_id)).is_equal("nagraj_kolaba")

## AC: a slot unlocked mid-session (a card resolved between actions bumped a
## counter) appears after the next completed action -- the grid re-evaluates on
## action_completed.
func test_slot_unlocks_mid_session_on_action_completed() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	_assert_slot_locked(grid, 4)  # starts locked at 0

	# Simulate a card resolution between actions bumping risky to the threshold,
	# then an action completing.
	_set_counters(3, 0)
	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 5.0, &"Cringe": 2.0, &"Morale": 0.0})

	_assert_slot_unlocked(grid, 4)  # now unlocked + enabled
	assert_str((grid.find_child("Slot4Title") as Label).text).is_equal("Record a Collab")
