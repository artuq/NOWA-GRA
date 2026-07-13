## ClassPathSystem owns the player's class path progression: per-path
## affiliation floats [0.0–100.0], tier ints [0–5] (MVP: 0–2), and the active
## path identity.
##
## Implements TR-cps-001..005 / ADR-0010: registered as Autoload #9 in Project
## Settings → Autoload (below DecisionCardSystem — subscriber-below-emitter
## rule, ADR-0001). Subscribes to DecisionCardSystem.card_resolved to update
## affiliation when a path-tagged card resolves; the path counter in
## HistoryFlagManager is already incremented when that signal fires (ADR-0010
## §2 ordering contract). Pull model: ActionSystem queries
## get_active_multiplier() at reward resolution — this module never references
## ActionSystem.
##
## MVP scope (Sprint 8): 2 paths (pato_streamer, guru_celebryta), Tier 1–2
## bonuses only, card affiliation only. invest() is a stub returning false —
## the active investment mechanic is Vertical Slice scope.
##
## Story class-path-full/001 (2026-07-13, ADR-0010 §11): expanded path
## registration and _MULTIPLIER_TABLE to all 4 GDD paths × Tiers 1-5 (data
## only — TIER_THRESHOLDS already generalized). invest() remains a stub;
## active investment ships in class-path-full/002.
##
## Usage example:
##   var tier: int = ClassPathSystem.get_tier(&"pato_streamer")
##   var mult: float = ClassPathSystem.get_active_multiplier(&"zrob_drame")
extends Node

## Tier thresholds: index = tier, value = inclusive minimum affiliation.
## Source: design/quick-specs/class-path-system-2026-07-01.md (20/40/60/80/100).
const TIER_THRESHOLDS: Array[float] = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]

## Affiliation gained per resolved path-tagged card (either option counts).
## GDD Tuning Knob: default 4.0, safe range 2.0–8.0.
## ponytail: const, not external balance data — extraction to .tres/JSON is a
## project-wide tech-debt item shared with ActionSystem.ACTION_REWARDS.
const CARD_AFFILIATION_PER_CHOICE: float = 4.0

## Maximum affiliation contribution from card choices per era. Active
## investment (Vertical Slice) can push total affiliation above this cap.
const CARD_CONTRIBUTION_MAX: float = 60.0

## Multiplier table: path_id -> tier (int) -> action_id -> Reach multiplier.
## Any unregistered combination resolves to 1.0 in get_active_multiplier().
## get_active_multiplier() only resolves Reach bonuses tied to a specific
## named action — this is a strict subset of the GDD's Tier Bonuses by Path
## table (design/gdd/class-path-system.md §Detailed Design). Most tier
## bonuses (Sponsor income, Morale floor, Haters conversion rate, action
## slots, unlock cost, signature cards, etc.) are NOT expressible as an
## action-keyed Reach multiplier and are intentionally represented as an
## empty {} tier entry here — their gameplay hooks belong to whichever
## system consumes them (ADR-0010 §11 / Story class-path-full/001 Out of
## Scope). All 4 paths list explicit keys 1-5 so a missing tier is always a
## deliberate `{}`, never an accidental omission.
## Source: pato T1 "Zrób dramę" +30% / T2 continuation to +60% (shipped MVP,
## unchanged); guru T1 "Zrób wywiad" +20% / T2 continuation to +40% (shipped
## MVP, unchanged — GDD's revised guru bonus text (Sponsor income) does not
## have a resolution hook yet, tracked as a pre-existing gap, not touched by
## this story); ekspert T2 "Nagraj vloga" +20% (only expressible ekspert
## entry — T1's "passive Reach floor" is a floor mechanic, not an
## action-keyed multiplier); biznesmen has no Reach-action-keyed bonus at
## any tier (its bonuses are Sponsor income, cooldown, and Morale cost —
## all {} ).
const _MULTIPLIER_TABLE: Dictionary[StringName, Dictionary] = {
	&"pato_streamer": {
		1: {&"zrob_drame": 1.3},
		2: {&"zrob_drame": 1.6},
		3: {},
		4: {},
		5: {},
	},
	&"guru_celebryta": {
		1: {&"udziel_wywiadu": 1.2},
		2: {&"udziel_wywiadu": 1.4},
		3: {},
		4: {},
		5: {},
	},
	&"ekspert_niszowy": {
		1: {},
		2: {&"nagraj_vloga": 1.2},
		3: {},
		4: {},
		5: {},
	},
	&"biznesmen_contentu": {
		1: {},
		2: {},
		3: {},
		4: {},
		5: {},
	},
}

## Emitted exactly once per tier crossing for [param path_id] — only from
## _check_tier_progression(), never from getters (ADR-0010 rejected
## side-effecting getters explicitly).
signal tier_unlocked(path_id: StringName, tier: int)

## Emitted when the active path changes. [param path_id] is &"" when no path
## is at Tier 1+ (including after reset_era_state()).
signal active_path_changed(path_id: StringName)

## Per-path affiliation [0.0–100.0]. Absent key = 0.0 (see get_affiliation).
var _affiliation: Dictionary[StringName, float] = {}

## Per-path tier [0–5]. Absent key = 0 (see get_tier). Monotonically
## non-decreasing within an era — only _check_tier_progression() raises it,
## only reset_era_state() clears it.
var _current_tier: Dictionary[StringName, int] = {}

## The active path (highest affiliation among Tier 1+ paths), or &"" if none.
var _active_path: StringName = &""


func _ready() -> void:
	DecisionCardSystem.card_resolved.connect(_on_card_resolved)


## Reacts to every card resolution. Neutral cards (path_tag == &"") are
## ignored. The path counter is already incremented in HistoryFlagManager
## before this handler runs (ADR-0010 §2), so _recalculate_affiliation()
## reads the fresh value.
func _on_card_resolved(_card_id: StringName, path_tag: StringName, _option: StringName) -> void:
	if path_tag == &"":
		return
	_recalculate_affiliation(path_tag)
	_check_tier_progression(path_tag)
	_update_active_path()


## Card-contribution formula from the quick-spec:
## min(count * CARD_AFFILIATION_PER_CHOICE, CARD_CONTRIBUTION_MAX).
func _recalculate_affiliation(path_id: StringName) -> void:
	var count: int = HistoryFlagManager.get_counter(StringName(String(path_id) + "_choices_count"))
	_affiliation[path_id] = minf(float(count) * CARD_AFFILIATION_PER_CHOICE, CARD_CONTRIBUTION_MAX)


## Advances [param path_id]'s tier if its affiliation crossed one or more
## thresholds, emitting tier_unlocked once per newly reached tier level, in
## ascending order, never skipping an intermediate tier (GDD AC, Story
## class-path-full/001). Never lowers a tier.
func _check_tier_progression(path_id: StringName) -> void:
	var affil: float = _affiliation.get(path_id, 0.0)
	var old_tier: int = _current_tier.get(path_id, 0)
	var new_tier: int = old_tier
	for t: int in range(old_tier + 1, TIER_THRESHOLDS.size()):
		if affil >= TIER_THRESHOLDS[t]:
			new_tier = t
		else:
			break
	if new_tier > old_tier:
		for t: int in range(old_tier + 1, new_tier + 1):
			_current_tier[path_id] = t
			tier_unlocked.emit(path_id, t)


## Recomputes the active path: the Tier 1+ path with the highest affiliation.
## Emits active_path_changed only when the value actually changes.
func _update_active_path() -> void:
	var best_path: StringName = &""
	var best_affil: float = 0.0
	for path_id: StringName in _affiliation:
		if _current_tier.get(path_id, 0) >= 1:
			var a: float = _affiliation[path_id]
			if a > best_affil:
				best_affil = a
				best_path = path_id
	if best_path != _active_path:
		_active_path = best_path
		active_path_changed.emit(_active_path)


## Returns [param path_id]'s current affiliation [0.0–100.0], or 0.0 if the
## path has never gained any. Pure read — no side effects (ADR-0010).
func get_affiliation(path_id: StringName) -> float:
	return _affiliation.get(path_id, 0.0)


## Returns [param path_id]'s current tier [0–5], or 0 if never advanced.
## Pure read — no side effects.
func get_tier(path_id: StringName) -> int:
	return _current_tier.get(path_id, 0)


## Returns the active path id, or &"" if no path has reached Tier 1.
func get_active_path() -> StringName:
	return _active_path


## Returns the Reach multiplier for [param action_id] under the active path
## at its current tier, or 1.0 when there is no active path or no registered
## bonus. Called by ActionSystem._on_action_timeout() at reward resolution
## (ADR-0010 pull model — this module never calls into ActionSystem).
func get_active_multiplier(action_id: StringName) -> float:
	if _active_path.is_empty():
		return 1.0
	var tier: int = _current_tier.get(_active_path, 0)
	var path_entry: Dictionary = _MULTIPLIER_TABLE.get(_active_path, {})
	var tier_entry: Dictionary = path_entry.get(tier, {})
	return float(tier_entry.get(action_id, 1.0))


## Active investment stub — Vertical Slice scope (quick-spec §Investment).
## Always returns false in MVP: no resource is spent, no affiliation changes.
func invest(_path_id: StringName, _resource_id: StringName, _amount: float) -> bool:
	return false


## Restores persisted affiliation/tier/active-path state from [param data]
## (as written by SaveSystem). Missing keys default to zero state — the
## first-session `{}` case is safe per ADR-0003's restore_state() contract.
func restore_state(data: Dictionary) -> void:
	var affil_in: Dictionary = data.get("affiliation", {})
	for key: String in affil_in:
		_affiliation[StringName(key)] = float(affil_in[key])
	var tier_in: Dictionary = data.get("current_tier", {})
	for key: String in tier_in:
		_current_tier[StringName(key)] = int(tier_in[key])
	_active_path = StringName(data.get("active_path", ""))


## Returns this module's persisted state as a JSON-serializable Dictionary
## (plain String keys — StringName is not a JSON type), mirroring
## HistoryFlagManager.serialize_state()'s convention. Read by SaveSystem.
func serialize_state() -> Dictionary:
	var affil_out: Dictionary = {}
	for key: StringName in _affiliation:
		affil_out[String(key)] = _affiliation[key]
	var tier_out: Dictionary = {}
	for key: StringName in _current_tier:
		tier_out[String(key)] = _current_tier[key]
	return {"affiliation": affil_out, "current_tier": tier_out, "active_path": String(_active_path)}


## Resets all era-local path state: affiliation, tiers, and the per-path
## choice counters in HistoryFlagManager. Permanent meta milestone flags
## (class_path.{path}.best_tier.{N}, class_path.{path}.era_completed) are
## written BEFORE clearing, so they survive the reset (quick-spec Era Reset
## table). MVP: callable from debug/tests only; Alpha: BurnoutSystem wires
## its era_transitioned signal to this method (deferred per ADR-0010 §6).
func reset_era_state() -> void:
	for path_id: StringName in _affiliation:
		var tier: int = _current_tier.get(path_id, 0)
		for t: int in range(1, tier + 1):
			HistoryFlagManager.set_milestone(StringName("class_path." + String(path_id) + ".best_tier." + str(t)))
		if _active_path == path_id:
			HistoryFlagManager.set_milestone(StringName("class_path." + String(path_id) + ".era_completed"))
		HistoryFlagManager.reset_counter(StringName(String(path_id) + "_choices_count"))
	_affiliation.clear()
	_current_tier.clear()
	# Same emit-only-on-change contract as _update_active_path() — a reset with
	# no active path (nothing ever reached Tier 1) emits nothing.
	if _active_path != &"":
		_active_path = &""
		active_path_changed.emit(&"")
