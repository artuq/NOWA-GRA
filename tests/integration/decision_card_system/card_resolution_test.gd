## Integration tests for DecisionCardSystem's presentation and resolution
## (Story 003, TR-dcs-001/TR-dcs-002). Covers all 5 acceptance criteria:
## presenting->resolving->cooldown transitions, strict resolution order
## (resource_deltas before counter_increments/milestone_to_set), milestone
## timing + excludability, and the no-repeat-prevention edge case.
##
## DecisionCardSystem is normally an Autoload singleton, but for test
## isolation each test instantiates a fresh instance directly from the
## script, matching Stories 001/002's precedent. This suite touches the
## real ResourceManager/HistoryFlagManager Autoloads (resolve_choice()
## writes to both) -- snapshot/restore ResourceManager per save_core_test.gd's
## established pattern.
##
## All milestone-bearing test fixtures use SYNTHETIC cards with a dedicated
## test-only milestone name, never the real staged_drama/cancel_threat/
## algorithm_hack production cards -- those milestones can never be unset
## (HistoryFlagManager's documented immutability), so resolving them for
## real here would permanently exclude those cards from every OTHER suite
## that runs afterward in the same test invocation. Counters ARE restored
## via HistoryFlagManager.restore_state() in after_test() since, unlike
## milestones, counter values can be set to any value (restore_state() is a
## boot-time loader, not gameplay mutation -- see save_core_test.gd's header
## for the same technique).
extends GdUnitTestSuite

const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

const _TEST_COUNTER: StringName = &"test_card_resolution_counter"
const _TEST_MILESTONE: StringName = &"test.card_resolution.fixture"

var _resource_snapshot: Dictionary[StringName, float] = {}
var _counter_snapshot: int = 0
var _instances: Array[Node] = []


var _risky_counter_snapshot: int = 0


var _onboarding_phase_snapshot: int

func before_test() -> void:
	# See cooldown_pool_test.gd's before_test() comment: force the real
	# OnboardingGate un-suppressed so this suite's resolution tests aren't
	# affected by onboarding state. Restored in after_test().
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	_counter_snapshot = HistoryFlagManager.get_counter(_TEST_COUNTER)
	_risky_counter_snapshot = HistoryFlagManager.get_counter(&"risky_choices_count")
	_instances = []


func after_test() -> void:
	OnboardingGate.phase = _onboarding_phase_snapshot
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.queue_free()
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	HistoryFlagManager.restore_state({
		"counters": {
			String(_TEST_COUNTER): _counter_snapshot,
			"risky_choices_count": _risky_counter_snapshot,
		},
	})
	# resolve_choice()/apply_delta() above mark the real SaveSystem dirty
	# (2026-06-29 fix) -- stop its debounce timer so a delayed save_now()
	# can't fire mid-suite and serialize this test's milestone-fixture flag
	# (which has no unset API) into a real user://save.json that would then
	# pollute a later process's tests. See cooldown_pool_test.gd.
	SaveSystem._debounce_timer.stop()


func _new_decision_card_system() -> Node:
	var instance: Node = DecisionCardSystemScript.new()
	add_child(instance)
	_instances.append(instance)
	return instance


func _synthetic_card(id: String, resource_deltas: Dictionary = {}, counter_increments: Dictionary = {}, milestone: Variant = null) -> Dictionary:
	var option_a: Dictionary = {"label": "", "resource_deltas": resource_deltas, "counter_increments": counter_increments}
	if milestone != null:
		option_a["milestone_to_set"] = milestone
	return {
		"id": id,
		"trigger_condition": "always",
		"text": "",
		"options": [option_a, {"label": "", "resource_deltas": {}, "counter_increments": {}}],
	}


## Wraps a single card in a properly-typed Array[Dictionary] -- a bare `[card]`
## literal does not satisfy a typed-array parameter at the call site (the
## same class of bug fixed in Story 002's _weighted_pick tests).
func _single_card_pool(card: Dictionary) -> Array[Dictionary]:
	var pool: Array[Dictionary] = [card]
	return pool


## AC-1/AC-2: presenting->resolving->cooldown after a choice, with effects
## applied (state settles to COOLDOWN by the time resolve_choice() returns --
## synchronous, no intermediate frame to observe RESOLVING separately).
func test_presenting_to_resolving_to_cooldown_on_choice() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card("test_basic_card")
	dcs.present_next_card(_single_card_pool(card))
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)

	dcs.resolve_choice(0)

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	assert_int(dcs._actions_until_check).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS)
	assert_object(dcs._presented_card).is_equal({})


## AC-3: resolution order -- resource_deltas committed to ResourceManager
## strictly before counter_increments/milestone_to_set committed to
## HistoryFlagManager. Verified by capturing HistoryFlagManager's state
## INSIDE the ResourceManager.resource_changed signal handler (which fires
## synchronously, before resolve_choice() proceeds to its next statement) --
## same technique as action_system_reward_resolution_test.gd's AC-6.
func test_resolution_applies_resources_before_history_flags() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card(
		"test_ordering_card",
		{&"Reach": 10.0},
		{_TEST_COUNTER: 1},
		_TEST_MILESTONE,
	)
	dcs.present_next_card(_single_card_pool(card))

	var counter_during_resource_write: Array = [-1]
	var milestone_during_resource_write: Array = [true]
	var _on_resource_changed := func(_key: StringName, _new_value: float, _old_value: float) -> void:
		counter_during_resource_write[0] = HistoryFlagManager.get_counter(_TEST_COUNTER)
		milestone_during_resource_write[0] = HistoryFlagManager.has_milestone(_TEST_MILESTONE)
	ResourceManager.resource_changed.connect(_on_resource_changed)

	dcs.resolve_choice(0)

	ResourceManager.resource_changed.disconnect(_on_resource_changed)

	# Guard against a vacuous pass: confirm the signal handler actually ran
	# (counter_during_resource_write[0] would still be its -1 sentinel if
	# resource_changed never fired for this delta).
	assert_int(counter_during_resource_write[0]).is_not_equal(-1)
	# At the moment the resource write committed, History Flag state was
	# still PRE-resolution -- proving resources commit first.
	assert_int(counter_during_resource_write[0]).is_equal(_counter_snapshot)
	assert_bool(milestone_during_resource_write[0]).is_false()
	# After resolve_choice() fully returns, History Flag state now reflects
	# the resolution.
	assert_int(HistoryFlagManager.get_counter(_TEST_COUNTER)).is_equal(_counter_snapshot + 1)
	assert_bool(HistoryFlagManager.has_milestone(_TEST_MILESTONE)).is_true()


## AC-4: a chosen option with both resource_deltas and milestone_to_set --
## milestone is recorded (confirmed after resolution completes, per AC-3's
## ordering proof above), and the card becomes excludable starting the next
## checking cycle (not synchronously during resolution itself).
func test_milestone_card_becomes_excludable_next_cycle() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card("test_excludable_card", {}, {}, _TEST_MILESTONE)
	dcs.present_next_card(_single_card_pool(card))

	dcs.resolve_choice(0)

	assert_bool(HistoryFlagManager.has_milestone(_TEST_MILESTONE)).is_true()
	var pool: Array[Dictionary] = dcs._build_eligible_pool(_single_card_pool(card))
	assert_int(pool.size()).is_equal(0)


## AC-5: a non-milestone card just resolved may be selected again -- no
## repeat-prevention exists anywhere in this system.
func test_non_milestone_card_may_repeat_after_resolution() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card("test_repeatable_card")
	dcs.present_next_card(_single_card_pool(card))
	dcs.resolve_choice(0)

	var pool: Array[Dictionary] = dcs._build_eligible_pool(_single_card_pool(card))

	assert_int(pool.size()).is_equal(1)


## Not a numbered AC, but a real regression closer: confirms resolve_choice()
## works against an actual CardContentDatabase card (not just synthetic test
## fixtures), since the untyped-Dictionary-to-typed-Dictionary conversion bug
## fixed in resolve_choice() would have broken on real card data too -- this
## proves the fix holds end-to-end on production content.
func test_resolve_choice_works_against_a_real_card() -> void:
	var dcs: Node = _new_decision_card_system()
	var real_card: Dictionary = CardContentDatabase.get_card("hater_callout")
	var before_reach: float = ResourceManager.get_resource(&"Reach")
	var before_cringe: float = ResourceManager.get_resource(&"Cringe")
	dcs.present_next_card(_single_card_pool(real_card))

	dcs.resolve_choice(0)  # risky option: Reach +140, Cringe +25, Morale -15, risky_choices_count +1

	assert_float(ResourceManager.get_resource(&"Reach") - before_reach).is_equal_approx(140.0, 0.0001)
	assert_float(ResourceManager.get_resource(&"Cringe") - before_cringe).is_equal_approx(25.0, 0.0001)
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)


## Not a numbered AC, but a real regression risk flagged by code review:
## resolve_choice() must no-op (not crash) when called while state !=
## PRESENTING -- guards against a double-tap on touch input before Card UI
## disables itself after the first choice. Without the guard, this would
## crash on _presented_card["options"][option_index] against an
## already-cleared {}.
func test_resolve_choice_is_noop_when_not_presenting() -> void:
	var dcs: Node = _new_decision_card_system()
	var card: Dictionary = _synthetic_card("test_double_call_card", {&"Reach": 50.0})
	dcs.present_next_card(_single_card_pool(card))
	dcs.resolve_choice(0)  # first call resolves normally, state -> COOLDOWN
	var reach_after_first_resolve: float = ResourceManager.get_resource(&"Reach")

	dcs.resolve_choice(0)  # second call: state is COOLDOWN, not PRESENTING -- must no-op

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(reach_after_first_resolve, 0.0001)


## Companion case: resolve_choice() called with no card ever presented
## (state still COOLDOWN, _presented_card still {}) must also no-op.
func test_resolve_choice_is_noop_when_no_card_presented() -> void:
	var dcs: Node = _new_decision_card_system()

	dcs.resolve_choice(0)

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
