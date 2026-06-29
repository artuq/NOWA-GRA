## OnboardingGate sequences the player's first session: Decision Card System
## stays suppressed until all 3 action types have each completed at least once
## (variety, not count -- onboarding-tutorial.md's Phase 1), then the next
## completed action forces an immediate first card (Phase 1->2). From
## phase_normal onward this module never intervenes again.
##
## This system performs no calculations (per the GDD's Formulas section) --
## pure state-machine sequencing, same shape as History Flag System's Path
## Resolution Algorithm. It has no UI, no visuals, no signals of its own (per
## the GDD's UI/Visual Requirements: "None").
##
## Story 001 scope: the state machine in isolation, callable directly by tests
## with synthetic action IDs -- no real ActionSystem/DecisionCardSystem
## dependency here (Story 002 wires the real signal subscription + the
## force_cooldown_zero() call; Story 003 adds persistence).
##
## Registered as a Godot Autoload singleton per ADR-0001, between
## OfflineProgressSystem and DecisionCardSystem (control-manifest.md's
## documented exact order -- both OnboardingGate and DecisionCardSystem
## subscribe to ActionSystem.action_completed, so both must be registered
## below ActionSystem; Story 002 wires the registration).
extends Node

## The 3 onboarding phases (onboarding-tutorial.md's States and Transitions).
## phase_normal is terminal -- no further transitions once reached.
enum Phase { PURE_ACTION, FIRST_CARD_PENDING, NORMAL }

var phase: Phase = Phase.PURE_ACTION

## Set semantics (Dictionary-as-set, the established project idiom -- see
## HistoryFlagManager._milestones): StringName action_id -> true. Tracks
## DISTINCT types seen, never a count -- the variety gate checks set size,
## not how many actions completed in total.
var _completed_types: Dictionary[StringName, bool] = {}

## The 3 action types the variety gate requires, per onboarding-tutorial.md's
## Tuning Knobs ("Required action types before first card: All 3" -- a
## documented design lock, not a tunable-down value). Matches
## ActionSystem.ACTION_DURATIONS' keys exactly.
const REQUIRED_TYPES: Array[StringName] = [&"nagraj_vloga", &"zrob_drame", &"przeprosiny"]

func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed_signal)


## Real signal handler (Story 002). Detects the exact PURE_ACTION ->
## FIRST_CARD_PENDING transition via a before/after phase comparison, rather
## than embedding the cross-module call inside on_action_completed() itself --
## keeps that method's Story 001 unit tests free of any DecisionCardSystem
## dependency. [param _rewards] is unused -- onboarding only cares which
## action completed, never its reward payload.
##
## force_cooldown_zero() is called DEFERRED, not directly. Both OnboardingGate
## and DecisionCardSystem subscribe to the same ActionSystem.action_completed
## signal; phase flips synchronously, so DecisionCardSystem's own handler for
## THIS SAME transition-causing action would already see is_card_suppressed()
## == false (regardless of which Autoload connected first) and could decrement/
## trigger a pool check on the transition action itself -- violating the GDD's
## "first card appears after the NEXT completed action (4th overall, at
## minimum)". Deferring the cooldown-zero write guarantees it lands strictly
## AFTER this event's full synchronous handler chain, affecting only the
## action after the transition -- independent of Autoload connection order.
func _on_action_completed_signal(action_id: StringName, _rewards: Dictionary) -> void:
	var was_pure_action: bool = phase == Phase.PURE_ACTION
	on_action_completed(action_id)
	if was_pure_action and phase == Phase.FIRST_CARD_PENDING:
		DecisionCardSystem.call_deferred(&"force_cooldown_zero")


## Called once per completed action. Story 002 wires this to the real
## ActionSystem.action_completed signal; this story's tests call it directly
## with synthetic IDs. [param action_id] is ignored once in
## FIRST_CARD_PENDING or NORMAL -- only PURE_ACTION's variety gate reads it.
func on_action_completed(action_id: StringName) -> void:
	match phase:
		Phase.PURE_ACTION:
			_completed_types[action_id] = true
			if _completed_types.size() >= REQUIRED_TYPES.size():
				phase = Phase.FIRST_CARD_PENDING
		Phase.FIRST_CARD_PENDING:
			phase = Phase.NORMAL
		Phase.NORMAL:
			pass  # terminal, no further transitions


## True only during PURE_ACTION -- the only phase where Decision Card System's
## pool-checking is suppressed. DecisionCardSystem reads this directly
## (ownership-clear read, ADR-0005) before any cooldown decrement.
func is_card_suppressed() -> bool:
	return phase == Phase.PURE_ACTION
