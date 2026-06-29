## Unit tests for OnboardingGate's state machine (Story 001, Onboarding/Tutorial
## epic). Tests a fresh instance directly with synthetic action IDs -- no real
## ActionSystem/DecisionCardSystem dependency (Story 002's scope), per the
## GDD's own classification note. Not the live Autoload singleton, so no
## snapshot/restore needed.
extends GdUnitTestSuite

const OnboardingGateScript: GDScript = preload("res://src/core/onboarding_gate.gd")

const VLOG: StringName = &"nagraj_vloga"
const DRAMA: StringName = &"zrob_drame"
const APOLOGY: StringName = &"przeprosiny"

var _instances: Array[Node] = []

func after_test() -> void:
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.free()
	_instances = []

func _fresh() -> Node:
	var gate: Node = OnboardingGateScript.new()
	_instances.append(gate)
	return gate

## AC: 0 types completed, 1 action completes (any type) -> stays PURE_ACTION.
func test_single_action_stays_pure_action() -> void:
	var gate: Node = _fresh()
	gate.on_action_completed(VLOG)
	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)

## AC: 2 distinct types completed, 3rd is a REPEAT of an already-completed
## type -> stays PURE_ACTION (variety not satisfied -- count alone doesn't
## transition).
func test_repeat_of_completed_type_does_not_transition() -> void:
	var gate: Node = _fresh()
	gate.on_action_completed(VLOG)
	gate.on_action_completed(DRAMA)
	gate.on_action_completed(VLOG)  # repeat, not the 3rd distinct type

	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)

## AC: 2 distinct types completed, the previously-untried 3rd type completes
## -> transitions to FIRST_CARD_PENDING immediately.
func test_third_distinct_type_transitions_immediately() -> void:
	var gate: Node = _fresh()
	gate.on_action_completed(VLOG)
	gate.on_action_completed(DRAMA)
	gate.on_action_completed(APOLOGY)  # 3rd distinct type

	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.FIRST_CARD_PENDING)

## AC: the same type completes 5 times in a row -> stays PURE_ACTION (count
## irrelevant, only distinct-type coverage matters).
func test_same_type_five_times_stays_pure_action() -> void:
	var gate: Node = _fresh()
	for i in 5:
		gate.on_action_completed(VLOG)
	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)

## AC: all 6 possible permutations of the 3 types transition at the same
## logical point (after the 3rd distinct type), regardless of order.
func test_all_six_permutations_transition_after_third_distinct_type() -> void:
	var permutations: Array = [
		[VLOG, DRAMA, APOLOGY], [VLOG, APOLOGY, DRAMA],
		[DRAMA, VLOG, APOLOGY], [DRAMA, APOLOGY, VLOG],
		[APOLOGY, VLOG, DRAMA], [APOLOGY, DRAMA, VLOG],
	]
	for perm: Array in permutations:
		var gate: Node = _fresh()
		gate.on_action_completed(perm[0])
		assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)
		gate.on_action_completed(perm[1])
		assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.PURE_ACTION)
		gate.on_action_completed(perm[2])
		assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.FIRST_CARD_PENDING)

## AC: in FIRST_CARD_PENDING, the next action completes -> transitions to
## NORMAL.
func test_first_card_pending_advances_to_normal_on_next_action() -> void:
	var gate: Node = _fresh()
	gate.on_action_completed(VLOG)
	gate.on_action_completed(DRAMA)
	gate.on_action_completed(APOLOGY)  # -> FIRST_CARD_PENDING
	gate.on_action_completed(VLOG)  # the next completed action (any type)

	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.NORMAL)

## AC: in NORMAL, any subsequent action completes -> stays NORMAL (terminal,
## no further transitions).
func test_normal_is_terminal() -> void:
	var gate: Node = _fresh()
	gate.on_action_completed(VLOG)
	gate.on_action_completed(DRAMA)
	gate.on_action_completed(APOLOGY)
	gate.on_action_completed(VLOG)  # -> NORMAL
	gate.on_action_completed(DRAMA)
	gate.on_action_completed(APOLOGY)

	assert_int(gate.phase).is_equal(OnboardingGateScript.Phase.NORMAL)

## AC: is_card_suppressed() is true only in PURE_ACTION; false in
## FIRST_CARD_PENDING and NORMAL.
func test_is_card_suppressed_only_in_pure_action() -> void:
	var gate: Node = _fresh()
	assert_bool(gate.is_card_suppressed()).is_true()

	gate.on_action_completed(VLOG)
	gate.on_action_completed(DRAMA)
	gate.on_action_completed(APOLOGY)  # -> FIRST_CARD_PENDING
	assert_bool(gate.is_card_suppressed()).is_false()

	gate.on_action_completed(VLOG)  # -> NORMAL
	assert_bool(gate.is_card_suppressed()).is_false()
