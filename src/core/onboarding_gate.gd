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

## Persisted one-shot showcase flag. Missing on older saves means the player
## has not seen the newly introduced Skill Challenge tutorial yet.
var _skill_challenge_intro_seen: bool = false
var _seen_skill_challenges: Dictionary[StringName, bool] = {}
## One-time first-session showcase progress. Unlike `_seen_skill_challenges`,
## this includes ordinary cards deliberately featured by onboarding (the
## guaranteed Sponsor deal and Polish-humour card).
var _seen_showcase_cards: Dictionary[StringName, bool] = {}

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
##
## Marks the save dirty (Story 003) only when something actually changes --
## a repeat-type call in PURE_ACTION or any call in NORMAL is a true no-op and
## must not mark dirty (same guarded-mutation stance as ResourceManager.
## apply_delta's non-empty-deltas guard, 2026-06-29 fix).
func on_action_completed(action_id: StringName) -> void:
	match phase:
		Phase.PURE_ACTION:
			if _completed_types.has(action_id):
				return  # repeat of an already-seen type -- no real mutation
			_completed_types[action_id] = true
			if _completed_types.size() >= REQUIRED_TYPES.size():
				phase = Phase.FIRST_CARD_PENDING
			SaveSystem.mark_dirty()
		Phase.FIRST_CARD_PENDING:
			phase = Phase.NORMAL
			SaveSystem.mark_dirty()
		Phase.NORMAL:
			pass  # terminal, no further transitions, no mutation


## True only during PURE_ACTION -- the only phase where Decision Card System's
## pool-checking is suppressed. DecisionCardSystem reads this directly
## (ownership-clear read, ADR-0005) before any cooldown decrement.
func is_card_suppressed() -> bool:
	return phase == Phase.PURE_ACTION


func should_show_skill_challenge_intro() -> bool:
	return not _skill_challenge_intro_seen


func has_seen_skill_challenge(card_id: StringName) -> bool:
	return _seen_skill_challenges.has(card_id)


func has_seen_showcase_card(card_id: StringName) -> bool:
	return _seen_showcase_cards.has(card_id)


func has_started_card_showcase() -> bool:
	return not _seen_showcase_cards.is_empty()


func mark_showcase_card_seen(card_id: StringName) -> void:
	if card_id == &"" or _seen_showcase_cards.has(card_id):
		return
	_seen_showcase_cards[card_id] = true
	SaveSystem.mark_dirty()


func mark_skill_challenge_intro_seen(card_id: StringName = &"feed_sprint_challenge") -> void:
	if card_id == &"" or _seen_skill_challenges.has(card_id):
		return
	_seen_skill_challenges[card_id] = true
	_seen_showcase_cards[card_id] = true
	if card_id == &"feed_sprint_challenge":
		_skill_challenge_intro_seen = true
	SaveSystem.mark_dirty()


## Returns this module's persisted state, per the established sibling
## convention (ResourceManager.serialize_state(), HistoryFlagManager.
## serialize_state()) -- plain String keys/values only (JSON-serializable;
## StringName is not a JSON type, per save_system.gd's own convention).
##
## Example:
##   var snapshot: Dictionary = OnboardingGate.serialize_state()
func serialize_state() -> Dictionary:
	var types: Array[String] = []
	for key: StringName in _completed_types:
		types.append(String(key))
	var seen_challenges: Array[String] = []
	for card_id: StringName in _seen_skill_challenges:
		seen_challenges.append(String(card_id))
	var seen_showcase_cards: Array[String] = []
	for card_id: StringName in _seen_showcase_cards:
		seen_showcase_cards.append(String(card_id))
	return {
		"phase": phase,
		"completed_types": types,
		"skill_challenge_intro_seen": _skill_challenge_intro_seen,
		"seen_skill_challenges": seen_challenges,
		"seen_showcase_cards": seen_showcase_cards,
	}


## Restores from [param data] (the "onboarding" sub-dict from the save file,
## or `{}` on first session / a save predating this story). Does NOT call
## SaveSystem.mark_dirty() -- a load must never re-trigger a save (same rule
## as ResourceManager.restore_state()/HistoryFlagManager.restore_state()).
##
## First-card hook (quick-spec first-card-hook-onboarding-2026-07-06, user
## decision): a FRESH session skips PURE_ACTION entirely -- phase starts at
## FIRST_CARD_PENDING with the card cooldown pre-zeroed, so the first card
## lands right after action #1 (~6-10s in), inside the web portals' 15-20s
## judgment window. The variety gate machinery stays for corrupted-save
## fallback and future tutorial use; restored mid-run saves keep their
## persisted phase unchanged. force_cooldown_zero() is deferred (same
## ordering rationale as the Phase 1->2 call) and idempotent -- the double
## restore_state() call at boot (SaveSystem._ready + BootController) is safe.
##
## Example:
##   OnboardingGate.restore_state(data.get("onboarding", {}))
func restore_state(data: Dictionary) -> void:
	if data.is_empty():
		_skill_challenge_intro_seen = false
		_seen_skill_challenges.clear()
		_seen_showcase_cards.clear()
		phase = Phase.FIRST_CARD_PENDING
		_completed_types.clear()
		DecisionCardSystem.call_deferred(&"force_cooldown_zero")
		return
	_skill_challenge_intro_seen = bool(data.get("skill_challenge_intro_seen", false))
	_seen_skill_challenges.clear()
	for card_id: String in data.get("seen_skill_challenges", []):
		_seen_skill_challenges[StringName(card_id)] = true
	_seen_showcase_cards.clear()
	for card_id: String in data.get("seen_showcase_cards", []):
		_seen_showcase_cards[StringName(card_id)] = true
	# Older saves tracked only minigames. Preserve those discoveries while
	# allowing the newly added Sponsor/humour showcase cards to appear once.
	for card_id: StringName in _seen_skill_challenges:
		_seen_showcase_cards[card_id] = true
	# Migration from the first one-boolean prototype schema.
	if _skill_challenge_intro_seen:
		_seen_skill_challenges[&"feed_sprint_challenge"] = true
		_seen_showcase_cards[&"feed_sprint_challenge"] = true
	# `as Phase` performs no range validation -- a corrupted/hand-edited save
	# with an out-of-enum value would silently fall through every match arm as
	# a no-op (code-review note, 2026-06-29). Validate against the enum's real
	# range explicitly, falling back to PURE_ACTION on any out-of-range value,
	# matching SaveSystem's own "corruption -> first-session defaults, never
	# crash" contract.
	var raw_phase: int = int(data.get("phase", Phase.PURE_ACTION))
	phase = raw_phase as Phase if raw_phase >= 0 and raw_phase <= Phase.NORMAL else Phase.PURE_ACTION
	_completed_types.clear()
	for type_str: String in data.get("completed_types", []):
		_completed_types[StringName(type_str)] = true
