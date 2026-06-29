## Interaction tests for OnboardingGate's real wiring (Story 002, Onboarding/
## Tutorial epic): the real ActionSystem.action_completed subscription, the
## additive DecisionCardSystem.force_cooldown_zero() call, and the suppression
## check in DecisionCardSystem._on_action_completed(). Drives the real
## ActionSystem.action_completed signal directly (rather than waiting on real
## per-action Timers, 4-9s each) -- the established pattern for testing
## signal-driven side effects in this codebase.
##
## OnboardingGate/DecisionCardSystem/ResourceManager/HistoryFlagManager are all
## real Autoloads; their mutable state is snapshotted and restored around each
## test so this suite's onboarding-phase mutations don't leak into other files.
extends GdUnitTestSuite

const VLOG: StringName = &"nagraj_vloga"
const DRAMA: StringName = &"zrob_drame"
const APOLOGY: StringName = &"przeprosiny"

var _onboarding_phase_snapshot: int
var _completed_types_snapshot: Dictionary
var _dcs_state_snapshot: int
var _dcs_actions_until_check_snapshot: int
var _resource_snapshot: Dictionary[StringName, float] = {}

func before_test() -> void:
	_onboarding_phase_snapshot = OnboardingGate.phase
	_completed_types_snapshot = OnboardingGate._completed_types.duplicate()
	_dcs_state_snapshot = DecisionCardSystem.state
	_dcs_actions_until_check_snapshot = DecisionCardSystem._actions_until_check
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	OnboardingGate.phase = OnboardingGate.Phase.PURE_ACTION
	OnboardingGate._completed_types.clear()
	DecisionCardSystem.state = DecisionCardSystem.State.COOLDOWN

func after_test() -> void:
	OnboardingGate.phase = _onboarding_phase_snapshot
	OnboardingGate._completed_types = _completed_types_snapshot
	DecisionCardSystem.state = _dcs_state_snapshot
	DecisionCardSystem._actions_until_check = _dcs_actions_until_check_snapshot
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	SaveSystem._debounce_timer.stop()

## AC: while suppressed (PURE_ACTION), completing actions never decrements
## DecisionCardSystem's cooldown counter, regardless of count.
func test_suppression_blocks_cooldown_decrement() -> void:
	var before: int = DecisionCardSystem._actions_until_check
	for i in 5:
		ActionSystem.action_completed.emit(VLOG, {})  # same type, 5x -- stays suppressed
	assert_int(DecisionCardSystem._actions_until_check).is_equal(before)
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.COOLDOWN)

## AC: the moment the 3rd distinct type completes, OnboardingGate calls
## DecisionCardSystem.force_cooldown_zero() exactly once -- cooldown becomes 0.
## force_cooldown_zero() is deferred (see onboarding_gate.gd's doc comment on
## _on_action_completed_signal) so it lands strictly after this event's full
## synchronous handler chain -- await one frame for it to land.
func test_force_cooldown_zero_fires_at_transition() -> void:
	ActionSystem.action_completed.emit(VLOG, {})
	ActionSystem.action_completed.emit(DRAMA, {})
	assert_int(OnboardingGate.phase).is_equal(OnboardingGate.Phase.PURE_ACTION)

	ActionSystem.action_completed.emit(APOLOGY, {})  # 3rd distinct type
	await get_tree().process_frame

	assert_int(OnboardingGate.phase).is_equal(OnboardingGate.Phase.FIRST_CARD_PENDING)
	assert_int(DecisionCardSystem._actions_until_check).is_equal(0)

## AC: after force_cooldown_zero, the very next completed action triggers an
## immediate pool check (cooldown was 0, decrements to <=0). Awaits a frame
## after the transition action so the deferred force_cooldown_zero() (see
## onboarding_gate.gd's doc comment) actually lands before the 4th action --
## without this await the assertion below would be a tautology, proving
## nothing (code-review finding, 2026-06-29).
func test_next_action_after_transition_triggers_immediate_check() -> void:
	ActionSystem.action_completed.emit(VLOG, {})
	ActionSystem.action_completed.emit(DRAMA, {})
	ActionSystem.action_completed.emit(APOLOGY, {})  # -> FIRST_CARD_PENDING
	await get_tree().process_frame  # let the deferred force_cooldown_zero land

	ActionSystem.action_completed.emit(VLOG, {})  # the next completed action (any type)

	# CardContentDatabase's pool is never empty (12 always-eligible cards,
	# established Decision Card System invariant) -- a real immediate check
	# lands specifically on PRESENTING, not just "not RESOLVING".
	assert_int(DecisionCardSystem.state).is_equal(DecisionCardSystem.State.PRESENTING)

## AC: once phase_normal, DecisionCardSystem operates with zero onboarding
## intervention -- normal cooldown decrements exactly as without OnboardingGate.
func test_phase_normal_zero_intervention() -> void:
	OnboardingGate.phase = OnboardingGate.Phase.NORMAL
	var before: int = DecisionCardSystem._actions_until_check

	ActionSystem.action_completed.emit(VLOG, {})

	assert_int(DecisionCardSystem._actions_until_check).is_equal(before - 1)

## AC: Resources/History Flags never gated -- while suppressed, ResourceManager
## still updates exactly as it would un-suppressed (onboarding only ever gates
## DecisionCardSystem's card-pool checking).
func test_resources_never_gated_while_suppressed() -> void:
	assert_bool(OnboardingGate.is_card_suppressed()).is_true()
	var reach_before: float = ResourceManager.get_resource(&"Reach")

	ResourceManager.apply_delta({&"Reach": 50.0})  # simulates an action's reward application

	assert_float(ResourceManager.get_resource(&"Reach") - reach_before).is_equal_approx(50.0, 0.0001)
