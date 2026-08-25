## Integration tests for Tier-5 Signature Card Wiring (Story
## class-path-full/004, ADR-0010 §10, TR-cps-006, GDD Signals table + Story
## AC-1/AC-2/AC-3).
##
## Unlike the other class-path suites (class_path_core_test.gd,
## class_path_tiebreak_test.gd, class_path_investment_test.gd), this suite
## CANNOT instantiate a detached ClassPathSystem: DecisionCardSystem's
## `_trigger_condition_met()` reads the real `ClassPathSystem` Autoload by
## name (ADR-0010 §10's pull-model grammar entry, not an injected
## dependency), so the eligible-pool half of every assertion here is only
## observable against the real singleton. Each test therefore mutates the
## real Autoload directly (same "seed contribution, recalc" technique
## class_path_tiebreak_test.gd uses on a detached instance) and restores it
## in after_test() via serialize_state()/restore_state(), first fully
## wiping via reset_era_state() so no leaked Dictionary key survives between
## tests (restore_state() only overwrites keys present in its snapshot, it
## does not clear extras — reset_era_state() is the only full-wipe path).
##
## reset_era_state() writes permanent meta milestone flags to the real
## HistoryFlagManager as a side effect (one-way, no unset API) -- same
## accepted cross-test leakage as class_path_core_test.gd's header comment.
##
## DecisionCardSystem itself IS instantiated fresh/detached per test (same
## precedent as card_resolution_test.gd) since _build_eligible_pool() takes
## no dependency on its own instance state, only on CardContentDatabase (real,
## read-only Autoload) and the real ClassPathSystem Autoload via
## _trigger_condition_met().
extends GdUnitTestSuite

const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

var _instances: Array[Node] = []
var _cps_snapshot: Dictionary = {}


func before_test() -> void:
	_instances = []
	_cps_snapshot = ClassPathSystem.serialize_state()


func after_test() -> void:
	# Full wipe first -- restore_state() alone would leave any path key this
	# test added (and the snapshot didn't have) stuck at its test value.
	ClassPathSystem.reset_era_state()
	ClassPathSystem.restore_state(_cps_snapshot)
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	# ClassPathSystem/HistoryFlagManager writes above mark the real SaveSystem
	# dirty -- stop its debounce timer so a delayed save_now() can't fire
	# mid-suite (same precedent as class_path_core_test.gd / card_resolution_test.gd).
	SaveSystem._debounce_timer.stop()


func _new_decision_card_system() -> Node:
	var instance: Node = DecisionCardSystemScript.new()
	add_child(instance)
	_instances.append(instance)
	return instance


## Pushes the REAL ClassPathSystem singleton's card_contribution for
## [param path_id] to [param value] and re-derives the total affiliation --
## same seeding technique as class_path_tiebreak_test.gd's _seed_affiliation,
## applied to the Autoload instead of a detached instance (required here,
## see file header).
func _seed_singleton_affiliation(path_id: StringName, value: float) -> void:
	ClassPathSystem._card_contribution[path_id] = value
	ClassPathSystem._recalculate_total_affiliation(path_id)


func _pool_ids(pool: Array[Dictionary]) -> Array:
	var ids: Array = []
	for card: Dictionary in pool:
		ids.append(card["id"])
	return ids


# --- AC-1: signature_card_unlocked fires exactly once at Tier 5, card enters the pool ---

func test_tier5_emits_signature_card_unlocked_exactly_once_and_card_enters_pool() -> void:
	var received: Array = []
	var _on_unlocked := func(card_id: StringName) -> void:
		received.append(card_id)
	ClassPathSystem.signature_card_unlocked.connect(_on_unlocked)

	_seed_singleton_affiliation(&"pato_streamer", 100.0)

	ClassPathSystem.signature_card_unlocked.disconnect(_on_unlocked)
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(5)
	assert_int(received.size()).override_failure_message(
		"signature_card_unlocked must fire exactly once when a path first reaches Tier 5"
	).is_equal(1)
	assert_that(received[0]).is_equal(&"viral_moment")

	var dcs: Node = _new_decision_card_system()
	var pool: Array[Dictionary] = dcs._build_eligible_pool(null)
	assert_array(_pool_ids(pool)).override_failure_message(
		"viral_moment must be in the eligible pool once pato_streamer is Tier 5"
	).contains(["viral_moment"])


## Edge case: two paths reaching Tier 5 in the same update -- both signature
## cards appear, each exactly once.
func test_two_paths_reach_tier5_together_both_cards_unlock_once_each() -> void:
	var received: Array = []
	var _on_unlocked := func(card_id: StringName) -> void:
		received.append(card_id)
	ClassPathSystem.signature_card_unlocked.connect(_on_unlocked)

	_seed_singleton_affiliation(&"pato_streamer", 100.0)
	_seed_singleton_affiliation(&"guru_celebryta", 100.0)

	ClassPathSystem.signature_card_unlocked.disconnect(_on_unlocked)
	assert_int(received.size()).is_equal(2)
	assert_array(received).contains_exactly_in_any_order([&"viral_moment", &"brand_deal_of_the_century"])

	var dcs: Node = _new_decision_card_system()
	var ids: Array = _pool_ids(dcs._build_eligible_pool(null))
	assert_bool(ids.has("viral_moment")).is_true()
	assert_bool(ids.has("brand_deal_of_the_century")).is_true()


# --- AC-2: era reset removes the card and emits signature_card_removed ---

func test_era_reset_emits_signature_card_removed_and_card_leaves_pool() -> void:
	_seed_singleton_affiliation(&"pato_streamer", 100.0)
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(5)

	var received: Array = []
	var _on_removed := func(card_id: StringName) -> void:
		received.append(card_id)
	ClassPathSystem.signature_card_removed.connect(_on_removed)

	ClassPathSystem.reset_era_state()

	ClassPathSystem.signature_card_removed.disconnect(_on_removed)
	assert_int(received.size()).override_failure_message(
		"signature_card_removed must fire when a Tier-5 path resets"
	).is_equal(1)
	assert_that(received[0]).is_equal(&"viral_moment")
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(0)

	var dcs: Node = _new_decision_card_system()
	var ids: Array = _pool_ids(dcs._build_eligible_pool(null))
	assert_bool(ids.has("viral_moment")).override_failure_message(
		"viral_moment must leave the pool once pato_streamer's tier resets to 0"
	).is_false()


## Regression for a BLOCKING code-review gap (qa-tester, 2026-07-13):
## multiple paths simultaneously at Tier 5 during era reset -- each must get
## exactly one removal signal, not zero or duplicated.
func test_era_reset_with_two_paths_at_tier5_each_emits_removal_once() -> void:
	_seed_singleton_affiliation(&"pato_streamer", 100.0)
	_seed_singleton_affiliation(&"guru_celebryta", 100.0)
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(5)
	assert_int(ClassPathSystem.get_tier(&"guru_celebryta")).is_equal(5)

	var received: Array = []
	var _on_removed := func(card_id: StringName) -> void:
		received.append(card_id)
	ClassPathSystem.signature_card_removed.connect(_on_removed)

	ClassPathSystem.reset_era_state()

	ClassPathSystem.signature_card_removed.disconnect(_on_removed)
	assert_int(received.size()).override_failure_message(
		"each of 2 simultaneously-Tier-5 paths must emit signature_card_removed exactly once, not 0 or duplicated"
	).is_equal(2)
	assert_array(received).contains_exactly_in_any_order([&"viral_moment", &"brand_deal_of_the_century"])


## Edge case: reset with no path at Tier 5 must be a no-op for these signals
## -- no spurious removal.
func test_era_reset_with_no_tier5_path_emits_no_removal_signal() -> void:
	_seed_singleton_affiliation(&"pato_streamer", 45.0)  # Tier 2, not Tier 5
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(2)

	var received: Array = []
	var _on_removed := func(card_id: StringName) -> void:
		received.append(card_id)
	ClassPathSystem.signature_card_removed.connect(_on_removed)

	ClassPathSystem.reset_era_state()

	ClassPathSystem.signature_card_removed.disconnect(_on_removed)
	assert_int(received.size()).override_failure_message(
		"reset_era_state() must not emit signature_card_removed when no path was at Tier 5"
	).is_equal(0)


## Suggestion from code review (2026-07-13): a path can reach Tier 5, era
## reset, then reach Tier 5 again in a NEW era -- unlock must fire again, not
## be suppressed by any "already unlocked once" state (there is none, but
## this was previously unverified).
func test_signature_card_unlocks_again_in_a_new_era() -> void:
	_seed_singleton_affiliation(&"pato_streamer", 100.0)
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(5)
	ClassPathSystem.reset_era_state()
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(0)

	var received: Array = []
	var _on_unlocked := func(card_id: StringName) -> void:
		received.append(card_id)
	ClassPathSystem.signature_card_unlocked.connect(_on_unlocked)

	_seed_singleton_affiliation(&"pato_streamer", 100.0)

	ClassPathSystem.signature_card_unlocked.disconnect(_on_unlocked)
	assert_int(received.size()).override_failure_message(
		"signature_card_unlocked must fire again on a fresh Tier-5 reach in a new era"
	).is_equal(1)
	assert_that(received[0]).is_equal(&"viral_moment")


# --- AC-3: trigger_condition grammar parsing ---

func test_grammar_below_threshold_returns_false() -> void:
	_seed_singleton_affiliation(&"pato_streamer", 65.0)  # Tier 3, not 5
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(3)
	var dcs: Node = _new_decision_card_system()
	assert_bool(dcs._trigger_condition_met("class_path_tier:pato_streamer:5")).is_false()


func test_grammar_exactly_at_threshold_returns_true() -> void:
	_seed_singleton_affiliation(&"pato_streamer", 100.0)  # Tier 5
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(5)
	var dcs: Node = _new_decision_card_system()
	assert_bool(dcs._trigger_condition_met("class_path_tier:pato_streamer:5")).is_true()


func test_grammar_always_still_returns_true() -> void:
	var dcs: Node = _new_decision_card_system()
	assert_bool(dcs._trigger_condition_met("always")).is_true()


func test_grammar_unknown_condition_returns_false() -> void:
	var dcs: Node = _new_decision_card_system()
	assert_bool(dcs._trigger_condition_met("some_future_grammar:x")).is_false()


## Malformed "class_path_tier:..." strings (wrong segment count) must not
## crash on an out-of-range parts[1]/parts[2] access -- they return false.
func test_grammar_malformed_missing_segments_returns_false_not_crash() -> void:
	var dcs: Node = _new_decision_card_system()
	assert_bool(dcs._trigger_condition_met("class_path_tier:")).is_false()
	assert_bool(dcs._trigger_condition_met("class_path_tier:pato_streamer")).is_false()


func test_grammar_malformed_too_many_segments_returns_false_not_crash() -> void:
	var dcs: Node = _new_decision_card_system()
	assert_bool(dcs._trigger_condition_met("class_path_tier:pato_streamer:5:extra")).is_false()


## Regression for a BLOCKING code-review finding (2026-07-13, qa-tester):
## int() on a non-numeric string silently returns 0 in GDScript rather than
## erroring, so a malformed min_tier segment would previously become
## "get_tier(...) >= 0" -- always true, incorrectly unlocking the card at
## Tier 0. Fixed via PackedStringArray.is_valid_int().
func test_grammar_non_numeric_min_tier_returns_false_not_always_true() -> void:
	var dcs: Node = _new_decision_card_system()
	# pato_streamer is at Tier 0 by default (nothing seeded this test) --
	# the pre-fix bug would have made this return true regardless.
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(0)
	assert_bool(dcs._trigger_condition_met("class_path_tier:pato_streamer:abc")).is_false()


func test_grammar_empty_string_returns_false() -> void:
	var dcs: Node = _new_decision_card_system()
	assert_bool(dcs._trigger_condition_met("")).is_false()


# --- Schema: all 4 signature cards exist with the correct trigger_condition ---

func test_all_four_signature_cards_registered_with_correct_trigger_condition() -> void:
	var expected: Dictionary = {
		"viral_moment": "class_path_tier:pato_streamer:5",
		"brand_deal_of_the_century": "class_path_tier:guru_celebryta:5",
		"kult_niszowy": "class_path_tier:ekspert_niszowy:5",
		"ipo_influencera": "class_path_tier:biznesmen_contentu:5",
	}
	for card_id: String in expected:
		var card: Dictionary = CardContentDatabase.get_card(card_id)
		assert_object(card).override_failure_message(
			"expected signature card '%s' to exist in CardContentDatabase" % card_id
		).is_not_equal({})
		assert_str(card["trigger_condition"]).is_equal(expected[card_id])
