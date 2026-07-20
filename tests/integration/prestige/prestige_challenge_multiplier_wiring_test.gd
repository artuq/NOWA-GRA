## Integration tests for PrestigeSystem.on_burnout_accepted()'s challenge_mult
## wiring (Burnout & Challenge System, Story 007, TR-pcs-007, ADR-0013 §"the
## only change to already-shipped PrestigeSystem code"). Covers all 3
## Acceptance Criteria from story-007-meta-multiplier-pull.md: AC-1
## (zero-challenge baseline byte-identical to the prior hardcoded 1.0 stub),
## AC-2 (a real ChallengeSystem.get_combined_meta_multiplier() value actually
## flows into PrestigeFormulas.grant_magnitude()'s pow(challenge_mult, ...)
## term, not just "some different number"), AC-3 (full prestige-suite
## regression -- verified separately via a direct run of
## tests/unit/prestige/ + tests/integration/prestige/, 80/80 passing before
## and after this story's change; not re-embedded as a meta-test here, no
## established precedent in this codebase for one test suite invoking
## another).
##
## Reuses prestige_grant_wiring_test.gd's exact technique: drives a real
## ClassPathSystem path to Tier 1 via the real HistoryFlagManager counter +
## ClassPathSystem._on_card_resolved(), computes the expected grant via the
## real PrestigeFormulas.grant_magnitude() as the oracle (not a hardcoded
## literal, so this suite stays correct regardless of prior milestone state
## in the same process -- same leakage-tolerant precedent that file's header
## comment documents), then calls the real on_burnout_accepted() and checks
## meta_bonus_totals. Additionally snapshots/restores ChallengeSystem's
## active selection around every test, since this story is the first to
## drive on_burnout_accepted() with real active challenges.
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


# --- AC-1: zero-challenge baseline unchanged ---

## Leakage-tolerant (same technique as prestige_grant_wiring_test.gd): reads
## the real is_first state live before acting, uses it as
## PrestigeFormulas.grant_magnitude()'s oracle input with challenge_mult=1.0
## -- proving the zero-challenge case is byte-identical to the prior
## hardcoded stub's behavior, not just "some grant happened".
func test_ac1_zero_active_challenges_grant_matches_pre_story_baseline_exactly() -> void:
	var ids: Array[StringName] = []
	ChallengeSystem.select_challenges(ids)
	assert_float(ChallengeSystem.get_combined_meta_multiplier()).is_equal_approx(1.0, 0.0001)

	_drive_pato_to_tier_1()
	var was_first: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used." + String(_BONUS_TYPE))
	var total_before: float = PrestigeSystem.get_meta_bonus_total(_BONUS_TYPE)
	var expected_grant: float = PrestigeFormulas.grant_magnitude(_BONUS_TYPE, 1, 1.0, was_first)

	PrestigeSystem.on_burnout_accepted()

	assert_float(PrestigeSystem.get_meta_bonus_total(_BONUS_TYPE)).override_failure_message(
		"zero active challenges must produce the exact same grant as the pre-story hardcoded challenge_mult=1.0 stub"
	).is_equal_approx(total_before + expected_grant, 0.0001)


# --- AC-2: nonzero challenge multiplier flows through ---

## brak_duszy (meta_bonus_multiplier 2.0) + drama_bez_granic (2.5) both
## active -> get_combined_meta_multiplier() == 5.0. Compares the REAL grant
## against two oracle computations -- one with challenge_mult=5.0 (expected
## match) and one with challenge_mult=1.0 (expected mismatch) -- proving the
## real 5.0 value actually flowed into grant_magnitude()'s
## pow(challenge_mult, META_CHALLENGE_SCALING_EXPONENT) term, not that some
## other number merely differs from the baseline.
func test_ac2_combined_multiplier_of_five_flows_into_grant_magnitude() -> void:
	var ids: Array[StringName] = [&"brak_duszy", &"drama_bez_granic"]
	ChallengeSystem.select_challenges(ids)
	assert_float(ChallengeSystem.get_combined_meta_multiplier()).is_equal_approx(5.0, 0.0001)

	_drive_pato_to_tier_1()
	var was_first: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used." + String(_BONUS_TYPE))
	var total_before: float = PrestigeSystem.get_meta_bonus_total(_BONUS_TYPE)
	var expected_grant_with_challenges: float = PrestigeFormulas.grant_magnitude(_BONUS_TYPE, 1, 5.0, was_first)
	var expected_grant_without_challenges: float = PrestigeFormulas.grant_magnitude(_BONUS_TYPE, 1, 1.0, was_first)
	# Sanity: the two oracle computations must actually differ, or this test
	# would pass vacuously regardless of which one on_burnout_accepted() used.
	assert_float(expected_grant_with_challenges).is_not_equal(expected_grant_without_challenges)

	PrestigeSystem.on_burnout_accepted()

	assert_float(PrestigeSystem.get_meta_bonus_total(_BONUS_TYPE)).override_failure_message(
		"on_burnout_accepted() must use the real get_combined_meta_multiplier()==5.0, not the old hardcoded 1.0"
	).is_equal_approx(total_before + expected_grant_with_challenges, 0.0001)
