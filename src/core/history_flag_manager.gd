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
## Path Resolution Algorithm (resolve_path_eligibility()) is Story 002 — out
## of scope here; this module only provides the primitives it will read.
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
