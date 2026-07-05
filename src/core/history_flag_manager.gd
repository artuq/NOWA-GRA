## HistoryFlagManager owns the boolean milestone flags and integer pattern
## counters that record permanent player history.
##
## Implements TR-hist-001 / ADR-0001: a single Autoload owning a flag log
## plus pattern counters. set_milestone() / increment_counter() are the sole
## write paths for their respective stores (ADR-0001 direct-call ownership).
## Milestones are one-time and immutable once set — no unset_milestone() API
## exists, by design (GDD Pillar 2: decisions cannot be undone). Counters are
## monotonically increasing — increment_counter() rejects amount < 0 with no
## mutation; there is no decrement path, structurally, not just by convention.
##
## Registered as a Godot Autoload singleton per the Control Manifest's boot
## order — position 2, immediately after ResourceManager and before
## ActionSystem (ADR-0001).
##
## Path Resolution Algorithm: resolve_path_eligibility() (Story 002) is a pure
## query layer over the counters above — filters registered paths by
## threshold, then breaks ties by a minimum margin; returns null on zero or
## ambiguous eligibility. Deciding when/how to commit a path belongs to the
## future Class Path System, not this module.
##
## Usage example:
##   HistoryFlagManager.set_milestone(&"card.exposed_friend.chosen")
##   if HistoryFlagManager.has_milestone(&"card.exposed_friend.chosen"):
##       pass
##   HistoryFlagManager.increment_counter(&"risky_choices_count")
##   var count: int = HistoryFlagManager.get_counter(&"risky_choices_count")
##   if HistoryFlagManager.counter_above_threshold(&"risky_choices_count", 5):
##       pass
extends Node

## One-time boolean milestone flags, keyed by milestone name. Absent key means
## unset (false) — see has_milestone(). No unset_milestone() API exists.
var _milestones: Dictionary[StringName, bool] = {}

## Monotonically increasing integer pattern counters, keyed by counter name.
## Absent key means 0 — see get_counter(). No decrement path exists.
var _counters: Dictionary[StringName, int] = {}


## Sets milestone [param flag_name] to true. Idempotent — calling this on an
## already-set milestone is a no-op in effect (no error, no side effect,
## state unchanged). There is no corresponding unset; once true, always true.
##
## Example:
##   HistoryFlagManager.set_milestone(&"card.exposed_friend.chosen")
func set_milestone(flag_name: StringName) -> void:
	_milestones[flag_name] = true
	SaveSystem.mark_dirty()


## Returns whether milestone [param flag_name] has ever been set. Returns
## `false` for a milestone never written, with no error.
##
## Example:
##   if HistoryFlagManager.has_milestone(&"card.exposed_friend.chosen"):
##       pass
func has_milestone(flag_name: StringName) -> bool:
	return _milestones.get(flag_name, false)


## Increases counter [param counter_name] by [param amount] (default `1`).
## Rejects (no mutation) if [param amount] is negative — counters never
## decrease; this is the only validation this module performs. A counter
## never written defaults to `0` before the increment is applied.
##
## Example:
##   HistoryFlagManager.increment_counter(&"risky_choices_count")
##   HistoryFlagManager.increment_counter(&"risky_choices_count", 4)
func increment_counter(counter_name: StringName, amount: int = 1) -> void:
	if amount < 0:
		return
	_counters[counter_name] = _counters.get(counter_name, 0) + amount
	SaveSystem.mark_dirty()


## Returns the current value of counter [param counter_name], or `0` if it
## has never been written.
##
## Example:
##   var count: int = HistoryFlagManager.get_counter(&"risky_choices_count")
func get_counter(counter_name: StringName) -> int:
	return _counters.get(counter_name, 0)


## Returns whether counter [param counter_name]'s current value is greater
## than or equal to [param threshold] (inclusive boundary, despite the
## method name).
##
## Example:
##   if HistoryFlagManager.counter_above_threshold(&"risky_choices_count", 5):
##       pass
func counter_above_threshold(counter_name: StringName, threshold: int) -> bool:
	return get_counter(counter_name) >= threshold


## Resets counter [param counter_name] to 0. Intended only for era-local path
## counters (`pato_streamer_choices_count` etc.) during ClassPathSystem.reset_era_state().
## All other counters remain monotonically increasing per GDD Pillar 2.
func reset_counter(counter_name: StringName) -> void:
	_counters.erase(counter_name)
	SaveSystem.mark_dirty()


## Class Path registrations for resolve_path_eligibility(): each entry's
## `threshold_min` is the inclusive minimum (per counter_above_threshold()'s
## `>=` semantics) a path's counter must reach to be eligible at all. Future
## paths (Vertical Slice/Alpha) register here; the algorithm itself never
## changes.
const _REGISTERED_PATHS: Array[Dictionary] = [
	{"path": "Pato-Streamer Hazardowy", "counter": &"risky_choices_count", "threshold_min": 5},
	{"path": "Guru-Celebryta", "counter": &"safe_choices_count", "threshold_min": 5},
]

## Tie-break margin for resolve_path_eligibility(): when two or more paths
## are eligible, the leading path's counter must exceed the runner-up's by at
## least this much (inclusive `>=`) to resolve; otherwise the pattern is
## still ambiguous and resolution returns null.
const _MARGIN: int = 2


## Returns the highest-scoring eligible class path's name, or `null` if zero
## paths are eligible, or if the top two eligible paths are within [constant
## _MARGIN] of each other (ambiguous — not yet resolved, never guessed). Pure
## query: no side effects, no mutation, no path is ever committed here.
##
## Example:
##   var path: Variant = HistoryFlagManager.resolve_path_eligibility()
##   if path != null:
##       pass
func resolve_path_eligibility() -> Variant:
	var eligible: Array[Dictionary] = []
	for registered_path: Dictionary in _REGISTERED_PATHS:
		if counter_above_threshold(registered_path["counter"], registered_path["threshold_min"]):
			eligible.append(registered_path)

	if eligible.is_empty():
		return null

	eligible.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return get_counter(a["counter"]) > get_counter(b["counter"])
	)

	var highest: Dictionary = eligible[0]
	if eligible.size() == 1:
		return highest["path"]

	var second: Dictionary = eligible[1]
	if get_counter(highest["counter"]) - get_counter(second["counter"]) >= _MARGIN:
		return highest["path"]
	return null


## Returns this module's persisted state as a JSON-serializable `Dictionary`
## (plain `String` keys throughout — `StringName` is not a JSON type). Only
## milestones currently set to `true` are included, per the GDD save schema
## ("only milestones set to true"). Read by `SaveSystem.save_now()` (ADR-0002).
##
## Example:
##   var snapshot: Dictionary = HistoryFlagManager.serialize_state()
func serialize_state() -> Dictionary:
	var milestones_out: Dictionary = {}
	for key: StringName in _milestones:
		if _milestones[key]:
			milestones_out[String(key)] = true
	var counters_out: Dictionary = {}
	for key: StringName in _counters:
		counters_out[String(key)] = _counters[key]
	return {"milestones": milestones_out, "counters": counters_out}


## Restores this module's state from [param data] (as produced by
## [method serialize_state]). Missing keys default safely — an empty
## [param data] (`{}`, the first-session case) leaves every milestone unset
## and every counter at `0`, per ADR-0003's `restore_state()` contract.
## Called by `SaveSystem.load_save()` at boot, before `ready`. Note: like
## [method set_milestone], this only ever sets milestones to `true`, never
## clears one absent from [param data] — a save written without a previously-
## true milestone (data loss/corruption) will not un-set it on restore. This
## is the same one-way-ratchet design as the live API, now also baked into
## persistence, not just gameplay (GDD Pillar 2: decisions cannot be undone).
##
## Example:
##   HistoryFlagManager.restore_state({"milestones": {"card.x": true}, "counters": {"risky_choices_count": 3}})
func restore_state(data: Dictionary) -> void:
	var milestones_in: Dictionary = data.get("milestones", {})
	for key: String in milestones_in:
		_milestones[StringName(key)] = true
	var counters_in: Dictionary = data.get("counters", {})
	for key: String in counters_in:
		_counters[StringName(key)] = int(counters_in[key])
