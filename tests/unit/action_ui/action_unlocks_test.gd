## Unit tests for ActionUnlocks (milestone-gated action slots, DDR-0001 #3).
## Pure static utility -- the unlock predicate is a function of decision-history
## inputs only, no Autoload/scene dependency (same pattern as CardSwipeMath).
## Verifies the spec's exact thresholds AND the DDR-0001 either-path constraint
## (each slot unlockable via a risky OR a safe condition).
extends GdUnitTestSuite

const ActionUnlocksScript: GDScript = preload("res://src/ui/action_unlocks.gd")

## AC: fresh game (0 decisions, no milestones) -> all 3 gated slots locked.
func test_fresh_game_all_locked() -> void:
	assert_array(ActionUnlocks.unlocked_slots(0, 0, false, false)).is_equal([false, false, false])

## AC: slot 4 unlocks via the risky path alone (risky_choices_count >= 3).
func test_slot4_via_risky_path() -> void:
	assert_array(ActionUnlocks.unlocked_slots(3, 0, false, false)).is_equal([true, false, false])

## AC: slot 4 unlocks via the safe path alone (either-path constraint).
func test_slot4_via_safe_path() -> void:
	assert_array(ActionUnlocks.unlocked_slots(0, 3, false, false)).is_equal([true, false, false])

## AC: slot 4 boundary -- 2 of either path is not enough (inclusive >= 3).
func test_slot4_below_threshold_stays_locked() -> void:
	assert_array(ActionUnlocks.unlocked_slots(2, 2, false, false)).is_equal([false, false, false])

## AC: slot 5 unlocks at 6 via the risky path; slot 4 is also open by then.
func test_slot5_via_risky_path() -> void:
	assert_array(ActionUnlocks.unlocked_slots(6, 0, false, false)).is_equal([true, true, false])

## AC: slot 5 unlocks at 6 via the safe path alone (either-path).
func test_slot5_via_safe_path() -> void:
	assert_array(ActionUnlocks.unlocked_slots(0, 6, false, false)).is_equal([true, true, false])

## AC: slot 5 boundary -- 5 is not enough (slot 4 open, slot 5 still locked).
func test_slot5_below_threshold_stays_locked() -> void:
	assert_array(ActionUnlocks.unlocked_slots(5, 0, false, false)).is_equal([true, false, false])

## AC: slot 6 unlocks via the risky milestone alone (staged_drama.chosen_risky).
func test_slot6_via_risky_milestone() -> void:
	assert_array(ActionUnlocks.unlocked_slots(0, 0, true, false)).is_equal([false, false, true])

## AC: slot 6 unlocks via the safe milestone alone (cancel_threat.apologized).
func test_slot6_via_safe_milestone() -> void:
	assert_array(ActionUnlocks.unlocked_slots(0, 0, false, true)).is_equal([false, false, true])

## AC: slot 6 stays locked with neither milestone, regardless of counters.
func test_slot6_no_milestone_stays_locked() -> void:
	assert_array(ActionUnlocks.unlocked_slots(20, 20, false, false)).is_equal([true, true, false])

## AC: the gated action ids are exactly the 3 expected, in slot order.
func test_gated_action_ids() -> void:
	assert_array(ActionUnlocks.GATED_ACTION_IDS).is_equal([&"nagraj_kolaba", &"udziel_wywiadu", &"wydaj_kurs"])
