## Unit tests for DecisionCardSystem's weighted card selection formula
## (Story 002, TR-dcs-001). Covers all 9 acceptance criteria: exact weight/
## probability values at Cringe=0 and Cringe=100, milestone exclusion
## (re-verified from this story's perspective), the 1-card degenerate case,
## and Cringe=0 with only risky/safe cards eligible.
##
## DecisionCardSystem is normally an Autoload singleton, but for test
## isolation each test instantiates a fresh instance directly from the
## script, matching Story 001's precedent. This suite reads the real
## ResourceManager Autoload's Cringe value (via apply_delta) and the real
## CardContentDatabase's "always"-eligible cards for the exact-value
## assertions, following save_core_test.gd's established snapshot/restore
## pattern for ResourceManager.
##
## Story class-path-full/004 (2026-07-13) added 4 Tier-5 signature cards to
## CardContentDatabase, gated by a "class_path_tier:..." trigger_condition
## instead of "always" -- excluded by `_always_eligible_cards()` below, which
## filters `CardContentDatabase.get_all_cards()` down to `trigger_condition
## == "always"` rather than reading the raw card array, keeping this suite's
## intent (the "always" pool) correct regardless of future card-count growth.
## Sprint 12 story 12-6 (2026-07-24) added 4 more "always" cards (12 -> 16);
## this suite's exact weight/probability constants were updated to match --
## see _EXPECTED_WEIGHTS_AT_100/_EXPECTED_PROBABILITIES_AT_100's own notes.
##
## Per QL-STORY-READY's review of this story, all float comparisons use
## is_equal_approx() with a small epsilon, never ==, even though these are
## clean integer-derived values with no expected drift.
extends GdUnitTestSuite

const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

const _RISKY_SAFE_IDS: Array[String] = [
	"exposed_friend", "sponsor_offer_shady", "hater_callout", "staged_drama",
	"competitor_drama", "leaked_dm", "cancel_threat", "apology_tour",
]
const _NEUTRAL_IDS: Array[String] = [
	"fan_in_trouble", "brand_deal_choice", "algorithm_hack", "burnout_warning",
]
## Exact weights at Cringe=100 per the GDD's Formulas table, plus the 4
## Sprint 12 wave-2 cards (weight = BASE_WEIGHT + risky-option Cringe delta,
## per _card_weight()/_card_intensity()): quarterly_content_review 10+20=30,
## engagement_farming 10+28=38, deep_dive_or_trend 10+18=28,
## thousand_true_fans 10+15=25.
## Wave-3 cards (2026-07-28), same formula: masterclass_launch 10+26=36,
## guru_retreat 10+24=34, wikipedia_correction 10+16=26,
## sponsored_inaccuracy 10+20=30, ai_content_farm 10+30=40,
## merch_drop_qa 10+27=37, trend_hijack_tragedy 10+30=40,
## old_friend_collab 10+22=32.
const _EXPECTED_WEIGHTS_AT_100: Dictionary = {
	"staged_drama": 45.0, "leaked_dm": 42.0, "cancel_threat": 40.0,
	"exposed_friend": 38.0, "hater_callout": 35.0, "competitor_drama": 34.0,
	"sponsor_offer_shady": 32.0, "apology_tour": 30.0,
	"engagement_farming": 38.0, "quarterly_content_review": 30.0,
	"deep_dive_or_trend": 28.0, "thousand_true_fans": 25.0,
	"masterclass_launch": 36.0, "guru_retreat": 34.0,
	"wikipedia_correction": 26.0, "sponsored_inaccuracy": 30.0,
	"ai_content_farm": 40.0, "merch_drop_qa": 37.0,
	"trend_hijack_tragedy": 40.0, "old_friend_collab": 32.0,
}
## Exact probabilities at Cringe=100 -- pool weight is 732.0 as of wave 3
## (was 457.0 after story 12-6; +275.0 from the 8 wave-3 cards' weights:
## 36+34+26+30+40+37+40+32=275). Raw weights of older cards unchanged;
## probabilities recomputed against the grown denominator.
const _EXPECTED_PROBABILITIES_AT_100: Dictionary = {
	"staged_drama": 0.0615, "leaked_dm": 0.0574, "cancel_threat": 0.0546,
	"exposed_friend": 0.0519, "hater_callout": 0.0478, "competitor_drama": 0.0464,
	"sponsor_offer_shady": 0.0437, "apology_tour": 0.0410,
	"engagement_farming": 0.0519, "quarterly_content_review": 0.0410,
	"deep_dive_or_trend": 0.0383, "thousand_true_fans": 0.0342,
	"masterclass_launch": 0.0492, "guru_retreat": 0.0464,
	"wikipedia_correction": 0.0355, "sponsored_inaccuracy": 0.0410,
	"ai_content_farm": 0.0546, "merch_drop_qa": 0.0505,
	"trend_hijack_tragedy": 0.0546, "old_friend_collab": 0.0437,
}

var _resource_snapshot: Dictionary[StringName, float] = {}
var _instances: Array[Node] = []


var _onboarding_phase_snapshot: int

func before_test() -> void:
	# See cooldown_pool_test.gd's before_test() comment: force the real
	# OnboardingGate un-suppressed so this suite's own weighting logic isn't
	# affected by onboarding state. Restored in after_test().
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_instances = []


func after_test() -> void:
	OnboardingGate.phase = _onboarding_phase_snapshot
	# See cooldown_pool_test.gd's after_test() comment: real mutation call
	# sites now mark the real SaveSystem dirty (2026-06-29 fix) -- stop its
	# debounce timer so a delayed save_now() can't fire mid-suite.
	SaveSystem._debounce_timer.stop()
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	SaveSystem._debounce_timer.stop()  # the restore above re-arms it


func _new_decision_card_system() -> Node:
	var instance: Node = DecisionCardSystemScript.new()
	add_child(instance)
	_instances.append(instance)
	return instance


func _set_cringe(value: float) -> void:
	ResourceManager.apply_delta({&"Cringe": value - ResourceManager.get_resource(&"Cringe")})


## All "always"-gated cards (16 as of Sprint 12 story 12-6) -- excludes the
## 4 Tier-5 signature cards (Story class-path-full/004), which use a
## "class_path_tier:..." trigger_condition, not "always". See file header.
func _always_eligible_cards() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for card: Dictionary in CardContentDatabase.get_all_cards():
		if card["trigger_condition"] == "always":
			result.append(card)
	return result


func _synthetic_card(id: String, milestone: Variant = null) -> Dictionary:
	var option_a: Dictionary = {"label": "", "resource_deltas": {}, "counter_increments": {}}
	if milestone != null:
		option_a["milestone_to_set"] = milestone
	return {
		"id": id,
		"trigger_condition": "always",
		"text": "",
		"options": [option_a, {"label": "", "resource_deltas": {}, "counter_increments": {}}],
	}


## AC-1/AC-2: Cringe=0, all "always"-eligible real cards -> every weight ==
## BASE_WEIGHT, uniform 1/N probability each -- N is the live pool size, not
## a hardcoded count (see _always_eligible_cards()'s own header note on why:
## Sprint 12 story 12-6 added 4 more "always" cards, 12 -> 16, and this test
## should stay correct through future pool-size changes rather than needing
## a manual update each time).
func test_cringe_zero_all_cards_have_base_weight() -> void:
	_set_cringe(0.0)
	var dcs: Node = _new_decision_card_system()
	var pool: Array[Dictionary] = _always_eligible_cards()

	var total: float = 0.0
	for card: Dictionary in pool:
		var w: float = dcs._card_weight(card, 0.0)
		assert_float(w).is_equal_approx(DecisionCardSystemScript.BASE_WEIGHT, 0.0001)
		total += w

	for card: Dictionary in pool:
		var probability: float = dcs._card_weight(card, 0.0) / total
		assert_float(probability).is_equal_approx(1.0 / pool.size(), 0.001)


## AC-3/AC-4/AC-5: Cringe=100, all "always"-eligible real cards -> exact
## weights, probabilities, and a 4.5x ratio between the top card and a
## neutral card. Pool total is 732.0 as of wave 3, 2026-07-28 (see
## _EXPECTED_PROBABILITIES_AT_100's own header note).
func test_cringe_hundred_exact_weights_probabilities_and_ratio() -> void:
	var dcs: Node = _new_decision_card_system()
	var pool: Array[Dictionary] = _always_eligible_cards()

	var total: float = 0.0
	var weight_by_id: Dictionary = {}
	for card: Dictionary in pool:
		var w: float = dcs._card_weight(card, 100.0)
		weight_by_id[card["id"]] = w
		total += w

	for card_id: String in _EXPECTED_WEIGHTS_AT_100:
		assert_float(weight_by_id[card_id]).is_equal_approx(_EXPECTED_WEIGHTS_AT_100[card_id], 0.0001)
	for card_id: String in _NEUTRAL_IDS:
		assert_float(weight_by_id[card_id]).is_equal_approx(10.0, 0.0001)

	assert_float(total).is_equal_approx(732.0, 0.0001)

	for card_id: String in _EXPECTED_PROBABILITIES_AT_100:
		var probability: float = weight_by_id[card_id] / total
		assert_float(probability).is_equal_approx(_EXPECTED_PROBABILITIES_AT_100[card_id], 0.001)
	for card_id: String in _NEUTRAL_IDS:
		var probability: float = weight_by_id[card_id] / total
		assert_float(probability).is_equal_approx(10.0 / 732.0, 0.001)

	var top_weight: float = weight_by_id["staged_drama"]
	var neutral_weight: float = weight_by_id["fan_in_trouble"]
	assert_float(top_weight / neutral_weight).is_equal_approx(4.5, 0.001)


## AC-6: a card whose chosen option's milestone_to_set is already set has
## zero weight (absent from the pool entirely -- re-verifies Story 001's
## filter from this story's perspective; this story never sees an excluded
## card in its input pool).
func test_milestone_excluded_card_is_absent_from_pool_passed_to_weighting() -> void:
	var dcs: Node = _new_decision_card_system()
	var excluded_milestone: StringName = &"test.weighted_selection.excluded_fixture"
	var card: Dictionary = _synthetic_card("test_excluded_card", excluded_milestone)
	HistoryFlagManager.set_milestone(excluded_milestone)

	var pool: Array[Dictionary] = dcs._build_eligible_pool([card])

	assert_int(pool.size()).is_equal(0)


## AC-7: a card with no milestone_to_set remains eligible regardless of past
## appearances -- no tracking exists anywhere in this system beyond the
## milestone mechanism.
func test_non_milestone_card_remains_eligible_for_weighting() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card("test_eligible_card")

	var pool: Array[Dictionary] = dcs._build_eligible_pool([card])

	assert_int(pool.size()).is_equal(1)


## AC-8: a pool with exactly 1 card selects with 100% certainty, same
## formula, no special case -- confirmed across multiple distinct seeds.
func test_single_card_pool_always_selected() -> void:
	var dcs: Node = _new_decision_card_system()
	var pool: Array[Dictionary] = [CardContentDatabase.get_card("apology_tour")]

	for seed_value in [0, 1, 12345, 999999]:
		dcs.set_seed(seed_value)
		var picked: Dictionary = dcs._weighted_pick(pool)
		assert_str(picked["id"]).is_equal("apology_tour")


## AC-9: Cringe=0, pool contains only risky/safe cards (no neutral eligible)
## -> all weights == BASE_WEIGHT, equal probability.
func test_cringe_zero_risky_safe_only_pool_has_equal_weights() -> void:
	var dcs: Node = _new_decision_card_system()
	var pool: Array[Dictionary] = []
	for card_id: String in _RISKY_SAFE_IDS:
		pool.append(CardContentDatabase.get_card(card_id))

	for card: Dictionary in pool:
		var w: float = dcs._card_weight(card, 0.0)
		assert_float(w).is_equal_approx(DecisionCardSystemScript.BASE_WEIGHT, 0.0001)


## Not a numbered AC, but a real regression risk flagged by code review:
## _weighted_pick() must not crash on an empty pool (a future caller
## bypassing _check_pool()'s external guard) -- it returns {} instead of
## indexing pool[-1] out of bounds.
func test_weighted_pick_with_empty_pool_returns_empty_dict_not_crash() -> void:
	var dcs: Node = _new_decision_card_system()
	var empty_pool: Array[Dictionary] = []

	var picked: Dictionary = dcs._weighted_pick(empty_pool)

	assert_object(picked).is_equal({})


## Statistical sanity check (per the story's own "Statistical/determinism
## testing note"): a 2-card pool with very different weights must be able
## to select EITHER card across a range of seeds -- proves the cumulative-
## roll algorithm isn't structurally biased to always returning the same
## index, without needing a dedicated roll-injection seam.
func test_weighted_pick_can_select_either_card_in_a_two_card_pool() -> void:
	var dcs: Node = _new_decision_card_system()
	_set_cringe(100.0)
	var pool: Array[Dictionary] = [CardContentDatabase.get_card("staged_drama"), CardContentDatabase.get_card("fan_in_trouble")]

	var picked_ids: Dictionary = {}
	for seed_value in range(50):
		dcs.set_seed(seed_value)
		var picked: Dictionary = dcs._weighted_pick(pool)
		picked_ids[picked["id"]] = true

	assert_int(picked_ids.size()).is_equal(2)
