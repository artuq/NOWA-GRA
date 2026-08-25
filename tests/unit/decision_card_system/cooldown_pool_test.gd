## Unit tests for DecisionCardSystem's cooldown mechanism and pool
## eligibility (Story 001, TR-dcs-002). Covers all 8 acceptance criteria:
## state transitions (cooldown->checking->presenting/cooldown), the 2-action
## cooldown counter, empty-pool retry, milestone exclusion, and the
## all-"always"-trigger no-op for MVP.
##
## DecisionCardSystem is normally an Autoload singleton, but for test
## isolation each test instantiates a fresh instance directly from the
## script, matching this codebase's established Story 001/002 precedent for
## other Autoloads. UNLIKE those modules, this one connects to the REAL
## `ActionSystem.action_completed` signal (there is only one ActionSystem
## Autoload) -- emitting that signal directly from tests drives
## `_on_action_completed()` without disturbing ActionSystem's own internal
## state (no `start_action()` call is ever made here).
##
## Milestone-exclusion tests (AC-7) use a SYNTHETIC card with a dedicated
## test-only milestone name, never the real `card.staged_drama.chosen_risky`/
## `card.cancel_threat.apologized`/`card.algorithm_hack.saved` strings --
## those milestones can never be unset (HistoryFlagManager's documented
## immutability), so permanently setting them here would silently exclude
## those 3 real cards from every OTHER suite that runs afterward in the same
## test invocation (e.g. a future Story 002 weighted-selection suite
## asserting "all 12 cards eligible at Cringe=100"). Testing the exclusion
## LOGIC against a synthetic card with a private test-only milestone proves
## the same code path without that cross-suite contamination risk.
extends GdUnitTestSuite

const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

const _TEST_MILESTONE: StringName = &"test.decision_card_pool.fixture"

var _instances: Array[Node] = []


var _onboarding_phase_snapshot: int

func before_test() -> void:
	# This suite tests DecisionCardSystem's OWN cooldown/pool logic in
	# isolation -- _on_action_completed() now reads the real global
	# OnboardingGate.is_card_suppressed() (Story 002, additive), so force it
	# to NORMAL (un-suppressed) here, independent of whatever other tests left
	# the real OnboardingGate in. Restored in after_test().
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL
	_instances = []


func after_test() -> void:
	OnboardingGate.phase = _onboarding_phase_snapshot
	# Real apply_delta/set_milestone/increment_counter calls in this suite now
	# mark the real SaveSystem dirty (since the 2026-06-29 mark_dirty fix) --
	# stop its debounce timer so a delayed save_now() doesn't fire mid-suite
	# and write live state to a real user://save.json (observed bug: this
	# polluted an unrelated later test's milestone assertions).
	SaveSystem._debounce_timer.stop()
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.queue_free()


func _new_decision_card_system() -> Node:
	var instance: Node = DecisionCardSystemScript.new()
	add_child(instance)
	_instances.append(instance)
	return instance


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


## AC-1: after 2 completed actions, the system advances past COOLDOWN (the
## intermediate CHECKING state is not synchronously observable -- _check_pool()
## runs within the same call -- so this asserts the end state reached, not a
## literal CHECKING snapshot).
func test_two_actions_advance_past_cooldown() -> void:
	var dcs: Node = _new_decision_card_system()

	ActionSystem.action_completed.emit(&"test_action", {})
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)

	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(dcs.state).is_not_equal(DecisionCardSystemScript.State.COOLDOWN)


## Not a numbered AC, but explicit intentional behavior per Implementation
## Notes: while state != COOLDOWN (a card is already being checked/
## presented/resolved), action_completed must not decrement the counter or
## double-trigger _check_pool(). Flagged by code review as a real regression
## risk if untested.
func test_action_completed_is_ignored_while_not_in_cooldown() -> void:
	var dcs: Node = _new_decision_card_system()
	dcs._check_pool()  # real database, all eligible -> advances to PRESENTING
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)

	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)
	assert_int(dcs._actions_until_check).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS)


## AC-2: checking with >=1 eligible card -> presenting, exactly one pool
## built (which card is chosen is Story 002's scope -- this story only
## confirms the transition and that a non-empty pool was found).
func test_checking_with_real_database_advances_to_presenting() -> void:
	var dcs: Node = _new_decision_card_system()

	dcs._check_pool()

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)


## AC-3: checking with 0 eligible cards -> cooldown (reset), via the
## test-only cards_override seam -- exercises the real empty-pool branch
## end-to-end, not a partial/indirect proxy.
func test_checking_with_empty_override_pool_resets_to_cooldown() -> void:
	var dcs: Node = _new_decision_card_system()

	dcs._check_pool([])

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	assert_int(dcs._actions_until_check).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS)


## AC-4/AC-5: cooldown requires exactly 2 actions -- 1 action is not enough.
func test_cooldown_requires_exactly_two_actions_not_one() -> void:
	var dcs: Node = _new_decision_card_system()

	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	assert_int(dcs._actions_until_check).is_equal(1)


## AC-6: an empty-pool reset doesn't permanently halt the loop -- 2 more
## actions from that point re-reach CHECKING (and, with the real database
## all eligible, settle to PRESENTING).
func test_empty_pool_reset_does_not_permanently_halt() -> void:
	var dcs: Node = _new_decision_card_system()
	dcs._check_pool([])
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)

	ActionSystem.action_completed.emit(&"test_action", {})
	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)


## AC-7 (milestone exclusion, excluded case): a card whose chosen option's
## milestone_to_set is already set is excluded from the pool. Uses a
## synthetic card + dedicated test-only milestone -- see suite header note.
func test_card_with_set_milestone_is_excluded_from_pool() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card("test_milestone_card", _TEST_MILESTONE)
	HistoryFlagManager.set_milestone(_TEST_MILESTONE)

	var pool: Array[Dictionary] = dcs._build_eligible_pool([card])

	assert_int(pool.size()).is_equal(0)


## AC-7 (milestone exclusion, eligible case): a card with no milestone_to_set
## remains eligible regardless of past appearances.
func test_card_without_milestone_remains_eligible() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card("test_no_milestone_card")

	var pool: Array[Dictionary] = dcs._build_eligible_pool([card])

	assert_int(pool.size()).is_equal(1)


## AC-8: all "always"-gated real cards pass trigger_condition -> filtering is
## a no-op (assuming no milestones are set, which this suite never does
## against real card IDs -- see header note). Count is 27:
## 12 MVP + 4 wave-2 + 8 wave-3 + 2 skill challenges + 1 cultural-humor card.
## The 4 Tier-5 signatures (tier-gated) and Wypalenie
## (trigger_condition=="never") are correctly excluded from this pool.
func test_all_always_gated_real_cards_pass_trigger_condition() -> void:
	var dcs: Node = _new_decision_card_system()

	var pool: Array[Dictionary] = dcs._build_eligible_pool()

	assert_int(pool.size()).is_equal(27)
