## DecisionCardSystem owns card selection and resolution: a 2-action
## cooldown counter (Story 001, this file's current scope), weighted-random
## selection scaled by Cringe (Story 002), and resolution writes to
## ResourceManager/HistoryFlagManager (Story 003).
##
## Implements TR-dcs-002 / ADR-0005: cooldown is an integer counter (not a
## `Timer`), decremented on every `ActionSystem.action_completed` signal.
## When it reaches 0, the eligible pool is built (cards whose
## `trigger_condition` passes and whose `milestone_to_set` isn't already
## set) — if non-empty, advances to `presenting`; if empty, resets the
## counter and retries on the next action. Empty pool never permanently
## halts the action loop.
##
## ADR-0005's Implementation Guidelines pseudocode is stale relative to this
## implementation: it assumes cards are `Resource` objects with `.intensity`/
## `.id`, and that `OnboardingGate.is_card_suppressed()` exists. Neither is
## true — `CardContentDatabase.get_all_cards()` returns `Array[Dictionary]`,
## and `OnboardingGate` doesn't exist yet (explicitly out of scope, zero GDD
## acceptance criteria reference it).
##
## Registered as a Godot Autoload singleton per ADR-0001, after `ActionSystem`
## (depends on `ActionSystem.action_completed` existing and ready).
##
## Usage example:
##   # production code never touches _build_eligible_pool()/_check_pool()
##   # directly with arguments — that's a test-only seam, see below.
extends Node

## Per-action cooldown before the next card-eligibility check.
## design/registry/entities.yaml: decision_card_cooldown = 2.
const COOLDOWN_ACTIONS: int = 2

## State machine per the GDD: `COOLDOWN` is the resting state between cards.
## `CHECKING`/`PRESENTING`/`RESOLVING` are this epic's full lifecycle —
## Story 001 only drives `COOLDOWN`→`CHECKING`→(`PRESENTING`|`COOLDOWN`);
## `PRESENTING`→`RESOLVING`→`COOLDOWN` is Story 003's scope.
enum State { COOLDOWN, CHECKING, PRESENTING, RESOLVING }

## Current lifecycle state. Public so tests and peer modules can assert on
## it directly, matching this codebase's existing public-state-field
## convention (e.g. `ActionSystem.current_action_id`, `SaveSystem.state`).
var state: State = State.COOLDOWN

## Emitted by present_next_card() when a card enters PRESENTING, carrying the
## chosen card Dictionary. The only signal on this system. Card UI's entry
## trigger (ADR-0008) -- an additive notification mirroring ActionSystem's
## action_started (ADR-0007); never emitted on an empty pool (present_next_card
## is only ever called with a non-empty pool, see _check_pool). Lets Card UI
## react without polling state or reading the private _presented_card.
signal card_presented(card: Dictionary)

var _actions_until_check: int = COOLDOWN_ACTIONS

## Flat weight floor every eligible card receives, independent of Cringe or
## intensity. GDD Tuning Knob: start 10, safe range 5-20.
const BASE_WEIGHT: float = 10.0

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed)
	_rng.randomize()


## Test hook only — production code never calls this. Allows tests to pin
## `_rng` to a fixed seed, satisfying coding-standards.md's "no random
## seeds" determinism rule for the weighted-pick statistical tests.
func set_seed(s: int) -> void:
	_rng.seed = s


func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	if state != State.COOLDOWN:
		return  # a card is already being checked/presented/resolved — do not double-trigger
	_actions_until_check -= 1
	if _actions_until_check <= 0:
		state = State.CHECKING
		_check_pool()


## [param cards_override] is a test-only seam, default `null` (unused —
## production code never passes this argument). When non-null (including an
## explicitly empty `[]`), the eligible pool is built from that array instead
## of `CardContentDatabase.get_all_cards()` — added per QL-STORY-READY
## (2026-06-24) so the empty-pool branch (AC-3) can be tested with a
## genuinely empty input. All 12 real MVP cards use `trigger_condition ==
## "always"` and can never be reduced to a true empty pool through milestone
## exclusion alone (only 3 of 12 cards are milestone-bearing), so `null` (not
## an empty array) is the "unused" sentinel — a test passing `[]` must be
## distinguishable from a caller passing nothing at all.
func _check_pool(cards_override: Variant = null) -> void:
	var pool: Array[Dictionary] = _build_eligible_pool(cards_override)
	if pool.is_empty():
		_actions_until_check = COOLDOWN_ACTIONS
		state = State.COOLDOWN
		return
	present_next_card(pool)


## [param cards_override] threads through to the same test-only seam
## documented on [method _check_pool] — same null-sentinel contract.
func _build_eligible_pool(cards_override: Variant = null) -> Array[Dictionary]:
	var source: Array[Dictionary] = Array(cards_override, TYPE_DICTIONARY, "", null) if cards_override != null else CardContentDatabase.get_all_cards()
	var pool: Array[Dictionary] = []
	for card: Dictionary in source:
		if not _trigger_condition_met(card["trigger_condition"]):
			continue
		if _is_milestone_exhausted(card):
			continue
		pool.append(card)
	return pool


func _trigger_condition_met(condition: String) -> bool:
	# MVP: only "always" is used by any of the 12 cards. A real expression
	# parser (e.g. "risky_choices_count >= 3") is explicitly out of scope —
	# GDD Open Questions defers grammar design to Vertical Slice+.
	return condition == "always"


func _is_milestone_exhausted(card: Dictionary) -> bool:
	# Story 002 also reads this when building its own pool view — kept here
	# since it's pool-eligibility logic, not weighting logic.
	for option: Dictionary in card["options"]:
		if option.has("milestone_to_set") and HistoryFlagManager.has_milestone(option["milestone_to_set"]):
			return true
	return false


## Per the GDD's Formulas section: "the risky option's Cringe delta (for
## risky/safe cards) or 0 (for neutral cards)." Derived at selection time —
## CardContentDatabase's Dictionary schema has no stored `.intensity` field.
## A card's risky option is identified by which option increments
## `risky_choices_count`; neutral cards have no such option on either side,
## so the loop falls through to the `0.0` fallback.
func _card_intensity(card: Dictionary) -> float:
	for option: Dictionary in card["options"]:
		if option["counter_increments"].has(&"risky_choices_count"):
			return option["resource_deltas"].get(&"Cringe", 0.0)
	return 0.0


func _card_weight(card: Dictionary, current_cringe: float) -> float:
	return BASE_WEIGHT + (current_cringe / 100.0) * _card_intensity(card)


## Picks one card from [param pool] via a cumulative-weight roll. [param
## pool] must be non-empty — [method _check_pool] only calls this when
## `pool.size() > 0`. Selection probability = weight(card) / sum(all
## weights), recomputed fresh each call (not pre-normalized). Defends
## against a future caller bypassing that contract: returns `{}` rather
## than crashing on `pool[-1]`'s out-of-bounds access on an empty array.
func _weighted_pick(pool: Array[Dictionary]) -> Dictionary:
	if pool.is_empty():
		push_error("_weighted_pick() called with an empty pool — this should never happen, _check_pool() must guard against it")
		return {}
	var current_cringe: float = ResourceManager.get_resource(&"Cringe")
	var weights: Array[float] = []
	var total: float = 0.0
	for card: Dictionary in pool:
		var w: float = _card_weight(card, current_cringe)
		weights.append(w)
		total += w
	var roll: float = _rng.randf() * total
	var cumulative: float = 0.0
	for i in pool.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return pool[i]
	return pool[-1]  # float-rounding fallback, never reached in practice


## The currently presented card, or `{}` if none. Public-ish via the
## `Dictionary` return shape (no getter restriction) so tests/Card UI can
## inspect what's being shown.
var _presented_card: Dictionary = {}


## Selects a card from [param pool] (via [method _weighted_pick], Story 002)
## and advances to `PRESENTING`. Called by [method _check_pool] once it has
## a non-empty pool — single-concurrency is implicit (only one card is ever
## presented at a time, since [method _check_pool] itself only runs from
## `COOLDOWN`).
func present_next_card(pool: Array[Dictionary]) -> void:
	_presented_card = _weighted_pick(pool)
	state = State.PRESENTING
	card_presented.emit(_presented_card)


## Called when the player chooses an option ([param option_index]: `0` or
## `1`, matching the card schema's exactly-2-options contract). Card UI
## (undesigned) will eventually call this; for now it's the public seam
## tests drive directly.
##
## No-ops (no mutation, no state change) if called while `state != PRESENTING`
## — guards against a double-tap/double-call before Card UI disables its own
## input on first choice (this project targets touch-only mobile input per
## technical-preferences.md, where double-tap is a realistic input pattern,
## not a hypothetical). Without this guard, a second call would crash on
## `_presented_card["options"][option_index]` against an already-cleared `{}`.
##
## Resolution order is architecturally locked (ADR-0005): `resource_deltas`
## applied to `ResourceManager` strictly BEFORE `counter_increments`/
## `milestone_to_set` applied to `HistoryFlagManager` — never reversed or
## interleaved. Sequential GDScript statements (no `await`) guarantee this
## ordering structurally, not just by convention.
func resolve_choice(option_index: int) -> void:
	if state != State.PRESENTING:
		return  # no card presented, or already resolving/resolved — no-op, not a crash
	state = State.RESOLVING
	var option: Dictionary = _presented_card["options"][option_index]

	# option["resource_deltas"] is an untyped Dictionary at runtime (card data
	# is stored as plain Dictionary literals, even when nested inside a typed
	# Array[Dictionary] — Godot does not propagate element typing into nested
	# literals). ResourceManager.apply_delta() requires a typed
	# Dictionary[StringName, float], so an explicit conversion is required —
	# same class of fix as Story 001/002's Array(...) typed-conversion calls.
	var resource_deltas: Dictionary[StringName, float] = Dictionary(option["resource_deltas"], TYPE_STRING_NAME, "", null, TYPE_FLOAT, "", null)
	if not resource_deltas.is_empty():
		ResourceManager.apply_delta(resource_deltas)

	for counter_name: StringName in option["counter_increments"]:
		HistoryFlagManager.increment_counter(counter_name, option["counter_increments"][counter_name])
	if option.has("milestone_to_set"):
		HistoryFlagManager.set_milestone(option["milestone_to_set"])

	_presented_card = {}
	_actions_until_check = COOLDOWN_ACTIONS
	state = State.COOLDOWN
