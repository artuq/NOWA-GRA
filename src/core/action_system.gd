## ActionSystem owns the select-and-wait action loop's timing and
## single-concurrency enforcement.
##
## Implements ADR-0004's mechanism: a single child `Timer` node (one_shot)
## plus a `current_action_id: StringName` field that is `&""` when idle.
## `start_action()` is the sole write path for `current_action_id` (ADR-0001
## direct-call ownership) — it rejects (returns `false`, no mutation) when an
## action is already running OR when the requested `action_id` is not a key
## in `ACTION_DURATIONS`.
##
## Registered as a Godot Autoload singleton per the Control Manifest's boot
## order (after `ResourceManager`, ADR-0001/ADR-0003).
##
## On resolution (Story 002 / TR-act-001, ADR-0004's 2026-06-23 correction):
## `_on_action_timeout()` reads the current Morale via
## `ResourceManager.get_resource(&"Morale")`, scales the base Reach reward by
## `ResourceFormulas.action_effectiveness_multiplier()` (round-half-away-from-
## zero via `roundf`), writes the final Reach/Cringe/Morale deltas in one
## atomic `ResourceManager.apply_delta()` call (ADR-0001 direct-call
## ownership), then emits `action_completed` carrying those same final,
## post-scaling deltas — never the raw `ACTION_REWARDS` base values.
##
## Usage example:
##   if ActionSystem.start_action(&"nagraj_vloga"):
##       # action accepted, now running
##   var progress: float = ActionSystem.get_progress()  # 0.0..1.0, safe to poll every frame
extends Node

## Per-action durations in seconds, keyed by action_id.
## Source: design/gdd/action-system.md Reward table (Nagraj vloga 6s /
## Zrób dramę 9s / Przeproś w internecie 4s).
const ACTION_DURATIONS: Dictionary[StringName, float] = {
	&"nagraj_vloga": 6.0,
	&"zrob_drame": 9.0,
	&"przeprosiny": 4.0,
}

## Per-action base reward deltas, keyed by action_id. `Reach` is scaled by
## the Morale effectiveness multiplier at resolution time (see
## `_on_action_timeout()`); `Cringe` and `Morale` are applied flat, unscaled.
## Source: design/gdd/action-system.md Reward table (Nagraj vloga +5/+2/0 /
## Zrób dramę +10/+20/-3 / Przeproś w internecie +6/-15/+5).
##
## TECH DEBT: this and `ACTION_DURATIONS` are typed const lookups (acceptable
## for this story — mirrors `ResourceManager`'s `_CLAMPED_KEYS` precedent per
## coding-standards.md). Both are candidates for extraction to an external
## `.tres` data resource once balance tuning begins, so designers can retune
## without touching code.
const ACTION_REWARDS: Dictionary[StringName, Dictionary] = {
	&"nagraj_vloga": {&"Reach": 5.0, &"Cringe": 2.0, &"Morale": 0.0},
	&"zrob_drame": {&"Reach": 10.0, &"Cringe": 20.0, &"Morale": -3.0},
	&"przeprosiny": {&"Reach": 6.0, &"Cringe": -15.0, &"Morale": 5.0},
}

## The currently running action's id, or `&""` when idle. This is the sole
## state field gating concurrency — `start_action()` is the only writer.
var current_action_id: StringName = &""

var _timer: Timer

## Emitted after `_on_action_timeout()` writes the resolved deltas via
## `ResourceManager.apply_delta()` (ADR-0001 direct-call pattern,
## notification-only signal). `rewards` carries the FINAL applied deltas
## (post Morale-multiplier scaling), not the raw `ACTION_REWARDS` base
## values — per ADR-0004's 2026-06-23 correction.
signal action_completed(action_id: StringName, rewards: Dictionary[StringName, float])


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_action_timeout)
	add_child(_timer)


## Attempts to start [param action_id]. Returns `true` and starts the Timer
## if idle and [param action_id] is a known key in [constant ACTION_DURATIONS];
## returns `false` with no state mutation otherwise (already running, or
## unknown action_id — never crashes on a missing key).
##
## Example:
##   ActionSystem.start_action(&"zrob_drame")  # true if idle, false if busy/unknown
func start_action(action_id: StringName) -> bool:
	if current_action_id != &"":
		return false  # single-concurrency: reject if one is already running
	if not ACTION_DURATIONS.has(action_id):
		return false  # unknown action_id: reject, no Timer mutation, no crash
	current_action_id = action_id
	_timer.wait_time = ACTION_DURATIONS[action_id]
	_timer.start()
	return true


## Returns the running action's completion fraction in `[0.0, 1.0]`. Returns
## exactly `0.0` when idle or when `wait_time <= 0.0` (divide-by-zero guard) —
## safe to poll every frame from `_process()` (ADR-0004).
##
## Example:
##   var fraction: float = ActionSystem.get_progress()
func get_progress() -> float:
	if current_action_id == &"" or _timer.wait_time <= 0.0:
		return 0.0
	return 1.0 - (_timer.time_left / _timer.wait_time)


## Resolves the completed action: reads the current Morale, scales the base
## Reach reward by `ResourceFormulas.action_effectiveness_multiplier()`
## (round-half-away-from-zero via `roundf`), writes the final Reach/Cringe/
## Morale deltas in one atomic `ResourceManager.apply_delta()` call, then
## emits `action_completed` with those same final, post-scaling deltas.
## Per ADR-0004 (2026-06-23 correction) + ADR-0001's direct-call pattern.
## No-ops if there is no active action (guards against a direct/duplicate
## call when `current_action_id == &""` — the Timer itself never triggers
## this case, since it only fires after `start_action()` sets a valid id).
func _on_action_timeout() -> void:
	if current_action_id == &"":
		return
	var completed_id: StringName = current_action_id
	current_action_id = &""
	var base_rewards: Dictionary = ACTION_REWARDS[completed_id]
	var morale: float = ResourceManager.get_resource(&"Morale")
	var multiplier: float = ResourceFormulas.action_effectiveness_multiplier(morale)
	var scaled_reach: float = roundf(base_rewards[&"Reach"] * multiplier)
	var deltas: Dictionary[StringName, float] = {
		&"Reach": scaled_reach,
		&"Cringe": base_rewards[&"Cringe"],
		&"Morale": base_rewards[&"Morale"],
	}
	ResourceManager.apply_delta(deltas)
	action_completed.emit(completed_id, deltas)
