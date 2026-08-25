## Integration tests for ChallengeSystem.clear_active_challenges() wired into
## PrestigeSystem._sweep_era_local_flags() (Burnout & Challenge System, Story
## 008, TR-pcs-007, ADR-0013 + ADR-0012 §5). Covers all 4 Acceptance Criteria
## from story-008-era-reset-wiring.md: AC-1 (Choice A clears active
## challenges), AC-2 (Choice B/Defer preserves them), AC-3/AC-4 (ordering
## regression -- the multiplier read must happen strictly before the clear).
##
## AC-3/AC-4's ordering proof note: unlike prestige_flag_sweep_test.gd's own
## AC-3 (which spies on the real ResourceManager.resource_changed SIGNAL to
## observe write order directly), ChallengeSystem.get_combined_meta_
## multiplier() is a plain getter with no signal to spy on -- there is no
## observable event emitted at read time. This suite instead proves the
## ordering by its NECESSARY EFFECT: if clear_active_challenges() ran before
## the multiplier was read, the grant computed by on_burnout_accepted() would
## reflect challenge_mult=1.0 (an empty selection reads as "no challenges
## active"), not the real active multiplier. Asserting BOTH the grant's exact
## numeric value (proves the real multiplier was consumed, not 1.0) AND that
## _active_challenge_ids is empty afterward (proves the clear did happen)
## together rule out every possible wrong ordering just as conclusively as a
## direct call-order spy would -- this is the story's own AC-4 edge-case
## requirement ("assert both") by construction, not a substitute for it.
##
## Reuses prestige_challenge_multiplier_wiring_test.gd's (Story 007) exact
## technique: drives a real ClassPathSystem path to Tier 1, computes the
## expected grant via the real PrestigeFormulas.grant_magnitude() as the
## oracle, snapshots/restores ChallengeSystem's active selection alongside
## PrestigeSystem's own state.
extends GdUnitTestSuite

const _PATO_COUNTER: StringName = &"pato_streamer_choices_count"
const _BONUS_TYPE: StringName = &"META_REACH_MULT"  # pato_streamer's bonus type

var _era_count_snapshot: int
var _meta_totals_snapshot: Dictionary
var _challenge_snapshot: Array[StringName] = []


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	_challenge_snapshot = ChallengeSystem.get_active_challenge_ids()
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func after_test() -> void:
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	ChallengeSystem.select_challenges(_challenge_snapshot)
	PrestigeSystem.restore_state({
		"era_count": _era_count_snapshot,
		"meta_bonus_totals": _meta_totals_snapshot,
	})
	SaveSystem._autosave_suppressed = false
	SaveSystem._debounce_timer.stop()


## Same technique as prestige_grant_wiring_test.gd's _drive_path_to_tier_1():
## 5 resolved cards * 4.0 affiliation each = 20.0, the Tier-1 threshold.
func _drive_pato_to_tier_1() -> void:
	for i: int in 5:
		HistoryFlagManager.increment_counter(_PATO_COUNTER)
		ClassPathSystem._on_card_resolved(&"", &"pato_streamer", &"")


# --- AC-1: Choice A clears active challenges ---

func test_ac1_choice_a_clears_active_challenges() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"bez_tlumu"]
	ChallengeSystem.select_challenges(ids)
	assert_array(ChallengeSystem.get_active_challenge_ids()).is_not_empty()

	PrestigeSystem.on_burnout_accepted()

	assert_array(ChallengeSystem.get_active_challenge_ids()).override_failure_message(
		"active challenges must be cleared by the flag sweep on every accepted burnout"
	).is_empty()


## Edge case: an already-empty selection stays empty and errors on nothing --
## the sweep's clear is idempotent by construction (Array.clear() on an
## already-empty array is a safe no-op).
func test_ac1_edge_already_empty_selection_stays_empty() -> void:
	var ids: Array[StringName] = []
	ChallengeSystem.select_challenges(ids)

	PrestigeSystem.on_burnout_accepted()

	assert_array(ChallengeSystem.get_active_challenge_ids()).is_empty()


# --- AC-2: Choice B (Defer) preserves active challenges ---

func test_ac2_choice_b_defer_leaves_active_challenges_unchanged() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"bez_tlumu"]
	ChallengeSystem.select_challenges(ids)

	PrestigeSystem.on_burnout_deferred(10.0)

	assert_array(ChallengeSystem.get_active_challenge_ids()).override_failure_message(
		"Choice B (Defer) does not transition eras -- on_burnout_deferred() never calls _sweep_era_local_flags(), so active challenges must survive it unchanged"
	).is_equal([&"brak_duszy", &"bez_tlumu"])


# --- AC-3/AC-4: ordering -- multiplier read strictly before the clear ---

## brak_duszy (meta_bonus_multiplier 2.0) + drama_bez_granic (2.5) both
## active -> get_combined_meta_multiplier() == 5.0, same worked combination
## Story 007's own wiring test uses. See this file's header comment for why
## proving BOTH the exact grant value AND the post-call empty selection
## together constitutes the ordering proof this AC requires.
func test_ac3_ac4_grant_reflects_real_multiplier_and_selection_is_cleared_after() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"drama_bez_granic"]
	ChallengeSystem.select_challenges(ids)
	assert_float(ChallengeSystem.get_combined_meta_multiplier()).is_equal_approx(5.0, 0.0001)

	_drive_pato_to_tier_1()
	var was_first: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used." + String(_BONUS_TYPE))
	var total_before: float = PrestigeSystem.get_meta_bonus_total(_BONUS_TYPE)
	var expected_grant_if_multiplier_consumed_before_clear: float = PrestigeFormulas.grant_magnitude(
		_BONUS_TYPE, 1, 5.0, was_first
	)
	var expected_grant_if_wrongly_cleared_first: float = PrestigeFormulas.grant_magnitude(
		_BONUS_TYPE, 1, 1.0, was_first
	)
	# Sanity: the two hypotheses must actually diverge, or a wrong ordering
	# would go undetected by the numeric assertion below.
	assert_float(expected_grant_if_multiplier_consumed_before_clear).is_not_equal(
		expected_grant_if_wrongly_cleared_first
	)

	PrestigeSystem.on_burnout_accepted()

	assert_float(PrestigeSystem.get_meta_bonus_total(_BONUS_TYPE)).override_failure_message(
		"the grant must reflect challenge_mult=5.0 -- if the clear had run before the multiplier was read, this would equal the challenge_mult=1.0 hypothesis instead, proving a wrong ordering"
	).is_equal_approx(total_before + expected_grant_if_multiplier_consumed_before_clear, 0.0001)
	assert_array(ChallengeSystem.get_active_challenge_ids()).override_failure_message(
		"the selection must be cleared by the END of on_burnout_accepted(), confirming the clear did happen (not merely that it happened late)"
	).is_empty()
