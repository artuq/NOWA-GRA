## Integration tests for DecisionCardSystem.inject_priority_card() (Story
## prestige-checkpoint/002, TR-pcs-003, ADR-0012 §4). Covers all 4 acceptance
## criteria: first call presents immediately bypassing pool selection,
## weighting, and cooldown; normal pool-driven presentation stays blocked
## while a priority card is pending; a concurrent injection attempt is
## rejected via a REAL runtime guard (not just the stripped-in-release
## `assert()` the ADR flags as insufficient); and the cooldown counter keeps
## accumulating underneath the pending window rather than freezing.
##
## DecisionCardSystem is normally an Autoload singleton, but for test
## isolation each test instantiates a fresh instance directly from the
## script, matching Story 001/002/003's established precedent (see
## cooldown_pool_test.gd / card_resolution_test.gd). This suite connects to
## the REAL `ActionSystem.action_completed` signal (there is only one
## ActionSystem Autoload) -- emitting it directly drives
## `_on_action_completed()` without disturbing ActionSystem's own state.
##
## `inject_priority_card()` calls the real `CardContentDatabase.get_card()`,
## so this suite uses real MVP card ids ("hater_callout", "staged_drama")
## rather than synthetic fixtures. `hater_callout` has no `milestone_to_set`
## on either option, so resolving it here never permanently excludes it from
## other suites. Resolving it DOES write real resource deltas and increment
## real HistoryFlagManager counters -- snapshotted/restored in
## before_test()/after_test() per card_resolution_test.gd's established
## pattern.
extends GdUnitTestSuite

const DecisionCardSystemScript: GDScript = preload("res://src/core/decision_card_system.gd")

var _instances: Array[Node] = []

var _onboarding_phase_snapshot: int
var _resource_snapshot: Dictionary[StringName, float] = {}
var _risky_counter_snapshot: int = 0
var _pato_counter_snapshot: int = 0


func before_test() -> void:
	# Force the real OnboardingGate un-suppressed, same precedent as
	# cooldown_pool_test.gd / card_resolution_test.gd -- restored in after_test().
	_onboarding_phase_snapshot = OnboardingGate.phase
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	_risky_counter_snapshot = HistoryFlagManager.get_counter(&"risky_choices_count")
	_pato_counter_snapshot = HistoryFlagManager.get_counter(&"pato_streamer_choices_count")
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
			"risky_choices_count": _risky_counter_snapshot,
			"pato_streamer_choices_count": _pato_counter_snapshot,
		},
	})
	# resolve_choice()/apply_delta() above mark the real SaveSystem dirty --
	# stop its debounce timer so a delayed save_now() can't fire mid-suite,
	# same precedent as card_resolution_test.gd / cooldown_pool_test.gd.
	SaveSystem._debounce_timer.stop()


func _new_decision_card_system() -> Node:
	var instance: Node = DecisionCardSystemScript.new()
	add_child(instance)
	_instances.append(instance)
	return instance


# --- AC-1: first call presents immediately, bypassing pool/weighting/cooldown ---

func test_inject_priority_card_presents_immediately_bypassing_pool_and_cooldown() -> void:
	var dcs: Node = _new_decision_card_system()
	# Sanity: cooldown has not elapsed and nothing is pending yet -- a normal
	# _check_pool()-driven presentation could not happen right now.
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	assert_int(dcs._actions_until_check).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS)

	var received: Array = []
	var _on_card_presented := func(card: Dictionary) -> void:
		received.append(card)
	dcs.card_presented.connect(_on_card_presented)

	var result: bool = dcs.inject_priority_card(&"hater_callout")

	dcs.card_presented.disconnect(_on_card_presented)
	assert_bool(result).override_failure_message(
		"first inject_priority_card() call must succeed when nothing is pending"
	).is_true()
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)
	assert_str(dcs._presented_card["id"]).is_equal("hater_callout")
	assert_int(received.size()).is_equal(1)
	assert_str(received[0]["id"]).is_equal("hater_callout")
	# Cooldown counter is untouched by the injection call itself -- it was
	# never consulted to gate this presentation.
	assert_int(dcs._actions_until_check).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS)
	assert_bool(dcs._priority_card_pending).is_true()


## Regression for a BLOCKING code-review finding (2026-07-14, qa-tester):
## CardContentDatabase.get_card() returns {} for an unknown card_id with no
## error of its own -- presenting {} would previously crash downstream in
## _card_intensity() ("options" key missing on an empty Dictionary, hit
## inside _weighted_pick()/present_next_card() the moment weighting runs).
## inject_priority_card() now validates the lookup itself and rejects
## up-front instead, matching the story's own "fail safe, not silently"
## convention used elsewhere in this codebase (Core Rule 4a's gate, etc.).
func test_inject_priority_card_rejects_unknown_card_id_without_crashing() -> void:
	var dcs: Node = _new_decision_card_system()
	var result: bool = dcs.inject_priority_card(&"this_card_id_does_not_exist")

	assert_bool(result).override_failure_message(
		"inject_priority_card() must reject an unknown card_id, not present an empty card"
	).is_false()
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	assert_bool(dcs._priority_card_pending).override_failure_message(
		"a rejected injection (unknown card_id) must not leave _priority_card_pending stuck true"
	).is_false()
	assert_object(dcs._presented_card).is_equal({})


# --- AC-2: blocks normal pool-driven presentation while pending ---

func test_priority_card_pending_blocks_normal_pool_presentation() -> void:
	var dcs: Node = _new_decision_card_system()
	dcs.inject_priority_card(&"hater_callout")
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)

	# Well more than the 2-action cooldown threshold -- if presentation were
	# NOT blocked, this would have already advanced past the injected card
	# via a normal _check_pool() cycle.
	ActionSystem.action_completed.emit(&"test_action", {})
	ActionSystem.action_completed.emit(&"test_action", {})
	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)
	assert_str(dcs._presented_card["id"]).override_failure_message(
		"the pending priority card must remain sole -- no normal card may swap in"
	).is_equal("hater_callout")


# --- AC-3: rejects concurrent injection via a real runtime guard ---

func test_inject_priority_card_rejects_concurrent_injection() -> void:
	var dcs: Node = _new_decision_card_system()
	var first: bool = dcs.inject_priority_card(&"hater_callout")
	assert_bool(first).is_true()

	# This must be a REAL early-return guard, not solely an assert() -- the
	# ADR/story flag assert() as stripped in exported release builds, so the
	# rejection contract must hold with asserts compiled out entirely. There
	# is no way to disable asserts from GDScript at runtime to prove this
	# directly in-process, so this test instead proves the return-value path
	# taken is the explicit early `return false` (verified by code inspection
	# during review): calling again returns false and leaves state untouched.
	var second: bool = dcs.inject_priority_card(&"staged_drama")

	assert_bool(second).override_failure_message(
		"a second inject_priority_card() call while one is pending must be rejected (false), no queueing"
	).is_false()
	assert_str(dcs._presented_card["id"]).override_failure_message(
		"the originally pending card must remain sole after a rejected concurrent injection"
	).is_equal("hater_callout")
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)
	assert_bool(dcs._priority_card_pending).is_true()


## Companion: a third and fourth attempt are rejected the same way -- proves
## rejection isn't a one-shot guard that silently opens back up.
func test_inject_priority_card_rejects_repeated_concurrent_injections() -> void:
	var dcs: Node = _new_decision_card_system()
	dcs.inject_priority_card(&"hater_callout")

	assert_bool(dcs.inject_priority_card(&"staged_drama")).is_false()
	assert_bool(dcs.inject_priority_card(&"competitor_drama")).is_false()

	assert_str(dcs._presented_card["id"]).is_equal("hater_callout")


# --- AC-4: cooldown counter keeps accumulating underneath the pending window ---

func test_cooldown_counter_keeps_accumulating_while_priority_card_pending() -> void:
	var dcs: Node = _new_decision_card_system()
	dcs.inject_priority_card(&"hater_callout")
	assert_int(dcs._actions_until_check).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS)

	# 3 actions complete during the pending window -- more than the 2-action
	# cooldown threshold, driving the counter below zero. Presentation must
	# stay blocked throughout (AC-2), but the counter itself must NOT freeze.
	ActionSystem.action_completed.emit(&"test_action", {})
	ActionSystem.action_completed.emit(&"test_action", {})
	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(dcs._actions_until_check).override_failure_message(
		"cooldown counter must keep decrementing underneath a pending priority card, not freeze"
	).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS - 3)
	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.PRESENTING)

	dcs.resolve_choice(0)

	assert_int(dcs.state).is_equal(DecisionCardSystemScript.State.COOLDOWN)
	assert_bool(dcs._priority_card_pending).is_false()
	# The counter must reflect the 3 completions accumulated during the
	# pending window -- resolving a priority card must NOT reset it back to
	# COOLDOWN_ACTIONS the way resolving a normal card does.
	assert_int(dcs._actions_until_check).override_failure_message(
		"resolving a priority card must not reset the cooldown counter -- it already accumulated during the pending window"
	).is_equal(DecisionCardSystemScript.COOLDOWN_ACTIONS - 3)

	# The threshold is already met (counter <= 0) -- the very next completed
	# action must immediately advance to a normal pool-selected presentation,
	# proving the accumulated cooldown carried through.
	ActionSystem.action_completed.emit(&"test_action", {})

	assert_int(dcs.state).override_failure_message(
		"a normal card must become immediately eligible once the priority card resolves, since the cooldown threshold was already met underneath"
	).is_equal(DecisionCardSystemScript.State.PRESENTING)
	# Which real card the weighted pick lands on is Story 002's (weighted
	# selection) concern, not this story's -- not asserted here to keep this
	# test deterministic without pinning an RNG seed.
