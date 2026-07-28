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
## ADR-0005's code sample was rewritten 2026-07-06 (Sprint 9 story 9-5) to
## match this implementation — the old staleness caveat no longer applies.
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
## chosen card Dictionary. Card UI's entry trigger (ADR-0008) -- an additive
## notification mirroring ActionSystem's action_started (ADR-0007); never
## emitted on an empty pool (present_next_card is only ever called with a
## non-empty pool, see _check_pool). Lets Card UI react without polling state
## or reading the private _presented_card.
signal card_presented(card: Dictionary)

## Emitted after the player resolves a presented card and _presented_card is
## cleared. ActionSystem connects to this to lift card-based queue suspension
## (Action System Story 003 — Action Queue; its zero-param handler is valid —
## Godot 4 drops extra signal args for narrower handlers). ClassPathSystem
## connects to update path affiliation (ADR-0010). Emitted before the cooldown
## counter resets so listeners observe the card-gone state cleanly.
## [param path_tag] is &"" for neutral cards; subscribers must assume the path
## counter in HistoryFlagManager IS already incremented when this fires.
signal card_resolved(card_id: StringName, path_tag: StringName, option_chosen: StringName)

var _actions_until_check: int = COOLDOWN_ACTIONS

## Story 002 (TR-pcs-003, ADR-0012 §4): orthogonal to `state` above -- tracks
## whether a card was force-presented via [method inject_priority_card]
## rather than selected through the normal `cooldown -> checking -> presenting`
## cycle. While `true`, [method _on_action_completed] still decrements
## `_actions_until_check` (the cooldown counter keeps accumulating
## underneath) but never calls [method _check_pool], so no pool-selected card
## can present until the priority card resolves. Cleared in
## [method resolve_choice].
var _priority_card_pending: bool = false

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
	if OnboardingGate.is_card_suppressed():
		return  # Phase 1: don't even decrement, per onboarding-tutorial.md
	if _priority_card_pending:
		# Story 002 (TR-pcs-003): a priority card is being shown -- normal
		# pool-driven presentation stays blocked (never reaches _check_pool()
		# below), but the cooldown counter must NOT freeze; it keeps counting
		# completed actions underneath so a normal card is immediately
		# eligible the instant the priority card resolves (see resolve_choice()).
		_actions_until_check -= 1
		return
	if state != State.COOLDOWN:
		return  # a card is already being checked/presented/resolved — do not double-trigger
	_actions_until_check -= 1
	if _actions_until_check <= 0:
		state = State.CHECKING
		_check_pool()


## Forces the cooldown counter to 0 -- called only by OnboardingGate, at the
## Phase 1->2 transition (architecture.md Decision: ownership-clear direct
## write, OnboardingGate owns this call, ADR-0005). The next completed action
## triggers an immediate pool check.
func force_cooldown_zero() -> void:
	_actions_until_check = 0


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


## Grammar: `"always"` (all MVP cards) or `"class_path_tier:{path_id}:{min_tier}"`
## (Story class-path-full/004, ADR-0010 §10, TR-cps-006 — the 4 Tier-5
## signature cards in CardContentDatabase). A full general-purpose expression
## parser (e.g. "risky_choices_count >= 3") remains out of scope — GDD Open
## Questions defers that to Vertical Slice+; this is a single additive
## special-case entry, not a parser. `ClassPathSystem.get_tier()` is a pure
## read (ADR-0010 pull model) — this stays the only new coupling, no push-based
## pool-mutation API added. A malformed `"class_path_tier:..."` string (wrong
## segment count) falls through to `false` rather than an out-of-range crash
## on `parts[1]`/`parts[2]` (GDD AC-3 edge case).
func _trigger_condition_met(condition: String) -> bool:
	if condition == "always":
		return true
	if condition.begins_with("class_path_tier:"):
		var parts: PackedStringArray = condition.split(":")  # "class_path_tier:{path_id}:{min_tier}"
		# int() on a non-numeric string silently returns 0 in GDScript (no
		# error) rather than failing — without this check, a malformed
		# min_tier segment (e.g. "class_path_tier:pato_streamer:abc") would
		# silently become "get_tier(...) >= 0", always true, incorrectly
		# unlocking the card at Tier 0 (found in code review, 2026-07-13).
		if parts.size() != 3 or not parts[2].is_valid_int():
			return false
		return ClassPathSystem.get_tier(StringName(parts[1])) >= int(parts[2])
	return false


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


## Forces [param card_id] to present on the next available frame, bypassing
## [method _build_eligible_pool]'s `trigger_condition`/milestone filtering,
## [method _weighted_pick]'s weighting, and the cooldown counter entirely
## (TR-pcs-003, ADR-0012 §4, GDD `prestige-checkpoint-system.md` Core Rule 6).
## General-purpose: BurnoutSystem's `"final_burnout"` card is the first
## caller (TR-pcs-007, out of this story's scope), but nothing here is
## Burnout-specific -- any future forced-card mechanic can call this too.
##
## Adds a `_priority_card_pending` state orthogonal to the existing
## `cooldown -> checking -> presenting -> resolving` cycle: while pending,
## normal pool-driven presentation is blocked (see [method _on_action_completed])
## but the cooldown counter keeps accumulating underneath, so a normal card
## is immediately eligible the instant the priority card resolves (see
## [method resolve_choice]).
##
## Returns `false` (no-op, the pending card is untouched) if a priority card
## is already pending -- no queueing. This is a REAL runtime guard, not just
## an `assert()`: asserts are stripped in exported release builds and are
## insufficient on their own to satisfy this rejection contract there.
##
## Also returns `false` (no-op, `_priority_card_pending` never set) if [param
## card_id] does not resolve to a real card -- [method CardContentDatabase.get_card]
## returns `{}` on an unknown id with no error of its own, and presenting `{}`
## would crash downstream in [method _card_intensity] ("options" key missing
## on an empty Dictionary, hit inside [method _weighted_pick]/[method present_next_card])
## the moment weighting runs, not at this call site -- found in code review,
## 2026-07-14. Validated here so a bad id fails loud-but-safe at the call
## site instead of corrupting state (`_priority_card_pending = true` with no
## card actually presented) and crashing on the next completed action.
func inject_priority_card(card_id: StringName) -> bool:
	if _priority_card_pending:
		return false
	var card: Dictionary = CardContentDatabase.get_card(card_id)
	if card.is_empty():
		push_error("inject_priority_card(%s): unknown card_id, no-op" % card_id)
		return false
	_priority_card_pending = true
	var pool: Array[Dictionary] = [card]
	present_next_card(pool)
	return true


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
	# Captured before _presented_card is cleared below — carried on card_resolved (ADR-0010).
	var resolved_card_id: StringName = StringName(_presented_card.get("id", ""))
	var resolved_path_tag: StringName = StringName(_presented_card.get("path_tag", ""))
	var resolved_option_label: StringName = StringName(option.get("label", ""))

	# option["resource_deltas"] is an untyped Dictionary at runtime (card data
	# is stored as plain Dictionary literals, even when nested inside a typed
	# Array[Dictionary] — Godot does not propagate element typing into nested
	# literals). ResourceManager.apply_delta() requires a typed
	# Dictionary[StringName, float], so an explicit conversion is required —
	# same class of fix as Story 001/002's Array(...) typed-conversion calls.
	var resource_deltas: Dictionary[StringName, float] = Dictionary(option["resource_deltas"], TYPE_STRING_NAME, "", null, TYPE_FLOAT, "", null)
	# Class path sponsor-income effect (tier-fill 2026-07-28, ADR-0010 pull
	# model — same direction as the existing class_path_tier trigger_condition
	# read): positive Sponsors card rewards scale under guru T5 (×2) /
	# biznesmen T3 (×1.5); 1.0 (no-op) otherwise. Negative deltas (costs)
	# are never scaled — income multiplier, not a cost discount.
	if resource_deltas.get(&"Sponsors", 0.0) > 0.0:
		resource_deltas[&"Sponsors"] = roundf(
			resource_deltas[&"Sponsors"] * ClassPathSystem.get_sponsor_income_multiplier()
		)
	if not resource_deltas.is_empty():
		ResourceManager.apply_delta(resource_deltas)

	for counter_name: StringName in option["counter_increments"]:
		HistoryFlagManager.increment_counter(counter_name, option["counter_increments"][counter_name])
	if option.has("milestone_to_set"):
		HistoryFlagManager.set_milestone(option["milestone_to_set"])

	# Path counter increments BEFORE card_resolved fires, so ClassPathSystem's
	# handler reads the already-incremented value (ADR-0010 §2 ordering contract).
	if resolved_path_tag != &"":
		HistoryFlagManager.increment_counter(StringName(String(resolved_path_tag) + "_choices_count"))

	_presented_card = {}
	card_resolved.emit(resolved_card_id, resolved_path_tag, resolved_option_label)
	if _priority_card_pending:
		# Story 002 (TR-pcs-003): do NOT reset the counter here -- it already
		# kept accumulating underneath while this priority card was pending
		# (see _on_action_completed()), so a normal card can become
		# immediately eligible on the very next completed action if the
		# threshold is already met.
		_priority_card_pending = false
	else:
		_actions_until_check = COOLDOWN_ACTIONS
	state = State.COOLDOWN
