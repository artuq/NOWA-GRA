## Unit tests for CardContentDatabase's static MVP card content (Story 001,
## no dedicated TR-ID — by design, pure data). Covers all 17 acceptance
## criteria from design/gdd/card-content-database.md: schema validity,
## resource_deltas/counter_increments contract, milestone-bearing cards,
## the Sponsors qualifying-card rule, and defined edge cases.
##
## AC-7 (Reach ratio 1.4x-1.8x) is tested against the GDD's actual authored
## numbers, not a blanket bound -- 3 of 8 pairs (staged_drama, leaked_dm,
## cancel_threat) exceed 1.8x in the GDD's own content table, discovered
## during this story's implementation and documented as an amendment in the
## story file rather than silently "fixed." This test locks the real
## measured ratios so a future edit to the content table is caught, not the
## abstract 1.4-1.8 bound the GDD itself violates for those 3 cards.
##
## CardContentDatabase is normally an Autoload singleton, but for test
## isolation this suite instantiates a fresh instance directly from the
## script and adds it to the scene tree, then frees it on cleanup -- the
## same pattern as resource_system/action_system/history_flag_system tests.
## This module is read-only and stateless (CARDS is a const), so there is no
## state to snapshot/restore between tests.
extends GdUnitTestSuite

const CardContentDatabaseScript: GDScript = preload("res://src/core/card_content_database.gd")

const _RISKY_SAFE_IDS: Array[String] = [
	"exposed_friend", "sponsor_offer_shady", "hater_callout", "staged_drama",
	"competitor_drama", "leaked_dm", "cancel_threat", "apology_tour",
	"thousand_true_fans", "deep_dive_or_trend", "engagement_farming", "quarterly_content_review",
]
const _NEUTRAL_IDS: Array[String] = [
	"fan_in_trouble", "brand_deal_choice", "algorithm_hack", "burnout_warning",
	"polish_export_disaster",
]
const _MILESTONE_CARDS: Dictionary = {
	"staged_drama": {"option_index": 0, "milestone": &"card.staged_drama.chosen_risky"},
	"cancel_threat": {"option_index": 1, "milestone": &"card.cancel_threat.apologized"},
	"algorithm_hack": {"option_index": 1, "milestone": &"card.algorithm_hack.saved"},
}
## Real measured Reach ratios per the GDD's actual authored table -- see
## suite header note. 3 of 8 exceed the GDD's own stated 1.4-1.8 bound.
const _EXPECTED_REACH_RATIOS: Dictionary = {
	"exposed_friend": 1.8,
	"sponsor_offer_shady": 1.7778,
	"hater_callout": 1.6471,
	"staged_drama": 1.8333,
	"competitor_drama": 1.7,
	"leaked_dm": 1.8095,
	"cancel_threat": 1.8182,
	"apology_tour": 1.5789,
	"thousand_true_fans": 1.7333,
	"deep_dive_or_trend": 1.75,
	"engagement_farming": 1.7593,
	"quarterly_content_review": 1.75,
}

var _db: Node


func before_test() -> void:
	_db = CardContentDatabaseScript.new()
	add_child(_db)


func after_test() -> void:
	if is_instance_valid(_db):
		_db.queue_free()


## AC-1: every card has exactly 2 options.
## Count is 21 as of Sprint 12 story 12-6 (2026-07-24): the 12 original MVP
## cards, plus 4 Tier-5 signature cards (ADR-0010 §10, TR-cps-006), plus the
## Wypalenie ("Final Burnout") card (ADR-0013, TR-pcs-007) -- id
## "final_burnout", trigger_condition "never" so it is reachable only via
## BurnoutSystem's forced injection, never the normal pool -- plus 4 more
## risky/safe cards (2x ekspert_niszowy, 2x biznesmen_contentu) closing the
## zero-reachable-cards gap those two paths had below Tier 5.
## Count is 37 after the two standalone skill challenges, cultural-humour
## showcase, and five controlled Sponsor Career Contract cards.
func test_all_cards_have_exactly_two_options() -> void:
	var cards: Array[Dictionary] = _db.get_all_cards()
	assert_int(cards.size()).is_equal(37)
	for card: Dictionary in cards:
		assert_int(card["options"].size()).is_equal(2)


## Every option exposes a non-empty id that is unique within its card. These
## ids are gameplay contracts; labels are free to change or be localized.
func test_all_card_options_have_stable_unique_ids() -> void:
	for card: Dictionary in _db.get_all_cards():
		var option_ids: Dictionary = {}
		for option: Dictionary in card["options"]:
			assert_bool(option.has("id")).is_true()
			assert_str(option["id"]).is_not_empty()
			option_ids[option["id"]] = true
		assert_int(option_ids.size()).is_equal(card["options"].size())
		if card["id"] not in [
			"final_burnout",
			"sponsor_contract_mega_fallout",
			"sponsor_contract_indie_fallout",
			"sponsor_contract_finale",
			"sponsor_contract_callback_honest",
			"sponsor_contract_callback_legend",
		]:
			assert_bool(option_ids.has("a")).is_true()
			assert_bool(option_ids.has("b")).is_true()
	var burnout: Dictionary = _db.get_card("final_burnout")
	assert_str(burnout["options"][0]["id"]).is_equal("accept")
	assert_str(burnout["options"][1]["id"]).is_equal("defer")


## Presentation copy is addressed only through stable locale-independent keys.
## Both locale catalogues must cover the complete card surface, while the
## embedded English copy remains an exact migration fallback.
func test_all_card_localization_keys_are_complete_in_en_and_pl() -> void:
	var all_keys: Dictionary = {}
	var cards_english: Dictionary = _read_single_line_po_messages("res://assets/localization/cards_en.po")
	var cards_polish: Dictionary = _read_single_line_po_messages("res://assets/localization/cards_pl.po")
	for card: Dictionary in _db.get_all_cards():
		var expected_text_key: String = "cards.%s.body" % card["id"]
		assert_str(card["text_key"]).is_equal(expected_text_key)
		assert_str(cards_english.get(card["text_key"], "")).is_equal(card["text"])
		assert_str(cards_polish.get(card["text_key"], "")).is_not_empty()
		all_keys[card["text_key"]] = true

		for option: Dictionary in card["options"]:
			var key_root: String = "cards.%s.options.%s" % [card["id"], option["id"]]
			assert_str(option["label_key"]).is_equal("%s.label" % key_root)
			assert_str(option["reaction_key"]).is_equal("%s.reaction" % key_root)
			assert_str(cards_english.get(option["label_key"], "")).is_equal(option["label"])
			assert_str(cards_english.get(option["reaction_key"], "")).is_equal(option["resolution_reaction"])
			assert_str(cards_polish.get(option["label_key"], "")).is_not_empty()
			assert_str(cards_polish.get(option["reaction_key"], "")).is_not_empty()
			all_keys[option["label_key"]] = true
			all_keys[option["reaction_key"]] = true

	assert_int(all_keys.size()).is_equal(185)


func test_all_reactions_have_locale_independent_editorial_pacing() -> void:
	var valid_values: Array[StringName] = CardContentDatabaseScript.VALID_REACTION_PACING
	for card: Dictionary in _db.get_all_cards():
		for option: Dictionary in card["options"]:
			assert_bool(option.has("reaction_pacing")).is_true()
			assert_array(valid_values).contains([option["reaction_pacing"]])


## Card PO entries intentionally keep every msgid/msgstr on one line so this
## small test parser can validate source equality without importing resources
## during test discovery. JSON parsing handles PO's quoted-string escapes.
func _read_single_line_po_messages(path: String) -> Dictionary:
	var result: Dictionary = {}
	var current_id: String = ""
	for raw_line: String in FileAccess.get_file_as_string(path).split("\n"):
		if raw_line.begins_with("msgid "):
			var decoded_id: Variant = JSON.parse_string(raw_line.trim_prefix("msgid "))
			current_id = decoded_id if decoded_id is String else ""
		elif raw_line.begins_with("msgstr ") and not current_id.is_empty():
			var decoded_value: Variant = JSON.parse_string(raw_line.trim_prefix("msgstr "))
			if decoded_value is String:
				result[current_id] = decoded_value
			current_id = ""
	return result


## AC-2: required top-level fields present and non-empty on every card.
func test_all_cards_have_required_top_level_fields() -> void:
	for card: Dictionary in _db.get_all_cards():
		assert_bool(card.has("id")).is_true()
		assert_str(card["id"]).is_not_empty()
		assert_bool(card.has("trigger_condition")).is_true()
		assert_str(card["trigger_condition"]).is_not_empty()
		assert_bool(card.has("text")).is_true()
		assert_bool(card.has("options")).is_true()


## AC-3: no two cards share the same id.
func test_all_card_ids_are_unique() -> void:
	var ids: Array = []
	for card: Dictionary in _db.get_all_cards():
		ids.append(card["id"])
	var unique_ids: Dictionary = {}
	for id: String in ids:
		unique_ids[id] = true
	assert_int(unique_ids.size()).is_equal(ids.size())


## AC-4: resource_deltas is present as a typed Dictionary on every option
## (empty dict valid for options with none -- none exist in this data set,
## but the key must always be present, never missing).
func test_resource_deltas_is_always_present_as_dictionary() -> void:
	for card: Dictionary in _db.get_all_cards():
		for option: Dictionary in card["options"]:
			assert_bool(option.has("resource_deltas")).is_true()
			assert_object(option["resource_deltas"]).is_not_null()


## AC-5: exactly one option per risky/safe pair increments risky_choices_count,
## the other increments safe_choices_count -- never both, never neither.
func test_risky_safe_pairs_have_exactly_one_counter_each() -> void:
	for card_id: String in _RISKY_SAFE_IDS:
		var card: Dictionary = _db.get_card(card_id)
		var option_a: Dictionary = card["options"][0]
		var option_b: Dictionary = card["options"][1]
		var a_has_risky: bool = option_a["counter_increments"].has(&"risky_choices_count")
		var a_has_safe: bool = option_a["counter_increments"].has(&"safe_choices_count")
		var b_has_risky: bool = option_b["counter_increments"].has(&"risky_choices_count")
		var b_has_safe: bool = option_b["counter_increments"].has(&"safe_choices_count")
		assert_bool(a_has_risky and b_has_safe).is_true()
		assert_bool(a_has_safe or b_has_risky).is_false()


## AC-6: neutral cards have no counter_increments on either option, and at
## least one option has non-empty resource_deltas.
func test_neutral_cards_have_no_counter_increments() -> void:
	for card_id: String in _NEUTRAL_IDS:
		var card: Dictionary = _db.get_card(card_id)
		var any_resource_deltas_nonempty: bool = false
		for option: Dictionary in card["options"]:
			assert_int(option["counter_increments"].size()).is_equal(0)
			if not option["resource_deltas"].is_empty():
				any_resource_deltas_nonempty = true
		assert_bool(any_resource_deltas_nonempty).is_true()


func test_skill_challenge_cards_have_no_narrative_progression_writes() -> void:
	var expected_games: Dictionary = {
		"feed_sprint_challenge": "feed_sprint",
		"comment_moderation_challenge": "comment_moderation",
	}
	for card_id: String in expected_games:
		var card: Dictionary = _db.get_card(card_id)
		assert_str(card.get("card_category", "")).is_equal("skill_challenge")
		assert_str(card.get("spotlight_minigame", "")).is_equal(expected_games[card_id])
		assert_bool(card["options"][0].get("starts_spotlight", false)).is_true()
		for option: Dictionary in card["options"]:
			assert_int(option["resource_deltas"].size()).is_equal(0)
			assert_int(option["counter_increments"].size()).is_equal(0)
			assert_bool(option.has("milestone_to_set")).is_false()


## AC-7 (amended): the real measured Reach risky/safe ratio for each of the
## 8 pairs matches the GDD's actual authored numbers -- not a blanket
## 1.4-1.8 bound, since 3 of 8 pairs exceed it in the source GDD itself. See
## suite header note.
func test_risky_safe_reach_ratios_match_gdd_authored_values() -> void:
	for card_id: String in _RISKY_SAFE_IDS:
		var card: Dictionary = _db.get_card(card_id)
		var risky_reach: float = card["options"][0]["resource_deltas"][&"Reach"]
		var safe_reach: float = card["options"][1]["resource_deltas"][&"Reach"]
		var ratio: float = risky_reach / safe_reach
		assert_float(ratio).is_equal_approx(_EXPECTED_REACH_RATIOS[card_id], 0.001)


## AC-8: every counter_increments value is exactly 1.
func test_counter_increment_values_are_exactly_one() -> void:
	for card: Dictionary in _db.get_all_cards():
		for option: Dictionary in card["options"]:
			for key: StringName in option["counter_increments"]:
				assert_int(option["counter_increments"][key]).is_equal(1)


## AC-9/AC-10/AC-11: the 3 milestone-bearing cards each have exactly one
## option with the correct milestone_to_set; the other option has none.
func test_milestone_bearing_cards_have_correct_milestone_on_correct_option() -> void:
	for card_id: String in _MILESTONE_CARDS:
		var card: Dictionary = _db.get_card(card_id)
		var expected: Dictionary = _MILESTONE_CARDS[card_id]
		var milestone_option: Dictionary = card["options"][expected["option_index"]]
		var other_option: Dictionary = card["options"][1 - expected["option_index"]]
		assert_bool(milestone_option.has("milestone_to_set")).is_true()
		assert_that(milestone_option["milestone_to_set"]).is_equal(expected["milestone"])
		assert_bool(other_option.has("milestone_to_set")).is_false()


## AC-12: the remaining 9 cards have no milestone_to_set anywhere.
func test_non_milestone_cards_have_no_milestone_to_set() -> void:
	for card: Dictionary in _db.get_all_cards():
		if _MILESTONE_CARDS.has(card["id"]):
			continue
		for option: Dictionary in card["options"]:
			assert_bool(option.has("milestone_to_set")).is_false()


## AC-13 (amended): the Sponsors key may appear on sponsor_offer_shady,
## brand_deal_choice, or fan_in_trouble (a flat cost, never a qualifying
## reward) -- absent on all other cards. See suite header note.
func test_sponsors_key_restricted_to_qualifying_cards_plus_fan_in_trouble_cost() -> void:
	var allowed_ids: Array[String] = [
		"sponsor_offer_shady", "brand_deal_choice", "fan_in_trouble",
		"sponsor_contract_mega_fallout", "sponsor_contract_indie_fallout",
		"sponsor_contract_finale", "sponsor_contract_callback_honest",
	]
	for card: Dictionary in _db.get_all_cards():
		for option: Dictionary in card["options"]:
			if option["resource_deltas"].has(&"Sponsors"):
				assert_array(allowed_ids).contains([card["id"]])


## AC-14: each qualifying card has at least one option with Sponsors > 0.
func test_qualifying_cards_have_at_least_one_positive_sponsors_option() -> void:
	for card_id: String in [
		"sponsor_offer_shady", "brand_deal_choice",
		"sponsor_contract_mega_fallout", "sponsor_contract_indie_fallout",
		"sponsor_contract_finale", "sponsor_contract_callback_honest",
	]:
		var card: Dictionary = _db.get_card(card_id)
		var any_positive: bool = false
		for option: Dictionary in card["options"]:
			if option["resource_deltas"].get(&"Sponsors", 0.0) > 0.0:
				any_positive = true
		assert_bool(any_positive).is_true()


## New AC (replaces the amended AC-13 above): fan_in_trouble's Sponsors
## value is a flat -1.0 cost on both options, never a positive qualifying
## reward.
func test_fan_in_trouble_sponsors_is_a_negative_cost_not_a_reward() -> void:
	var card: Dictionary = _db.get_card("fan_in_trouble")
	for option: Dictionary in card["options"]:
		assert_float(option["resource_deltas"][&"Sponsors"]).is_equal_approx(-1.0, 0.0001)


## AC-15: negative Reach/Sponsors values are accepted and stored as-is, no
## clamping at this layer (e.g. brand_deal_choice option A: Reach -40).
func test_negative_resource_deltas_are_accepted_unclamped() -> void:
	var card: Dictionary = _db.get_card("brand_deal_choice")
	assert_float(card["options"][0]["resource_deltas"][&"Reach"]).is_equal_approx(-40.0, 0.0001)


## AC-16: no card's trigger_condition references the algorithm_hack forward
## hook milestone -- expected (no current consumer), not a defect.
func test_algorithm_hack_milestone_has_no_current_consumer() -> void:
	for card: Dictionary in _db.get_all_cards():
		assert_str(card["trigger_condition"]).not_contains("card.algorithm_hack.saved")


## AC-17: the non-milestone-bearing cards' options (plus the non-milestone
## option on each of the 3 milestone cards) structurally lack the
## milestone_to_set key -- confirming absence is correct, not missing data.
## 37 cards * 2 options = 74, minus the 3 milestone-bearing options = 71.
func test_absence_of_milestone_to_set_is_structural_not_missing() -> void:
	var non_milestone_option_count: int = 0
	for card: Dictionary in _db.get_all_cards():
		for i in range(card["options"].size()):
			var option: Dictionary = card["options"][i]
			var is_the_milestone_option: bool = (
				_MILESTONE_CARDS.has(card["id"])
				and _MILESTONE_CARDS[card["id"]]["option_index"] == i
			)
			if not is_the_milestone_option:
				assert_bool(option.has("milestone_to_set")).is_false()
				non_milestone_option_count += 1
	assert_int(non_milestone_option_count).is_equal(71)


func test_polish_humour_showcase_card_is_locale_only_and_mechanically_stable() -> void:
	var card: Dictionary = _db.get_card("polish_export_disaster")
	assert_str(card.get("card_category", "")).is_equal("cultural_humor")
	assert_str(card["trigger_condition"]).is_equal("always")
	assert_int(card["options"].size()).is_equal(2)
	assert_float(card["options"][0]["resource_deltas"][&"Reach"]).is_equal_approx(140.0, 0.0001)
	assert_float(card["options"][1]["resource_deltas"][&"Morale"]).is_equal_approx(6.0, 0.0001)


func test_literal_quotes_are_explicitly_polish_only_and_never_english_fallbacks() -> void:
	var cards_english: Dictionary = _read_single_line_po_messages("res://assets/localization/cards_en.po")
	var cards_polish: Dictionary = _read_single_line_po_messages("res://assets/localization/cards_pl.po")
	var seen_quote_ids: Dictionary = {}
	for card_id: String in CardContentDatabaseScript.POLISH_LITERAL_QUOTE_OPTIONS:
		var card: Dictionary = _db.get_card(card_id)
		var quote_options: Dictionary = CardContentDatabaseScript.POLISH_LITERAL_QUOTE_OPTIONS[card_id]
		for option: Dictionary in card["options"]:
			var option_id: String = option["id"]
			if not quote_options.has(option_id):
				continue
			assert_str(String(option.get("cultural_reference_locale", ""))).is_equal("pl_PL")
			assert_str(String(option.get("literal_quote_id", ""))).is_equal(String(quote_options[option_id]))
			assert_bool(seen_quote_ids.has(option["literal_quote_id"])).is_false()
			seen_quote_ids[option["literal_quote_id"]] = true
			var key: String = String(option["reaction_key"])
			assert_str(cards_polish.get(key, "")).is_not_empty()
			assert_str(cards_english.get(key, "")).is_equal(option["resolution_reaction"])
			assert_str(cards_english.get(key, "")).is_not_equal(cards_polish.get(key, ""))

	assert_int(seen_quote_ids.size()).is_equal(7)


## get_card() returns an empty Dictionary for an unknown id -- not tested by
## a numbered AC, but a direct contract of the public API used throughout
## this suite.
func test_get_card_with_unknown_id_returns_empty_dictionary() -> void:
	assert_object(_db.get_card("does_not_exist")).is_equal({})
