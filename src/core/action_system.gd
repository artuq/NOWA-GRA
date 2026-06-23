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
## Scope note (Story 001 / TR-act-001): this story implements ONLY the timer
## and concurrency contract. Reward tables, the Morale-multiplier scaling of
## the Reach reward, and the `ResourceManager.apply_delta()` write on
## resolution are Story 002 (see ADR-0004's 2026-06-23 correction note) —
## `_on_action_timeout()` here only resets state and emits the bare
## `action_id`.
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

## The currently running action's id, or `&""` when idle. This is the sole
## state field gating concurrency — `start_action()` is the only writer.
var current_action_id: StringName = &""

var _timer: Timer

## Emitted when the running action's Timer elapses. Carries the bare
## completed action_id — Story 002 extends this signal's payload with
## resolved reward deltas; do not add that here.
signal action_completed(action_id: StringName)


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


func _on_action_timeout() -> void:
	var completed_id: StringName = current_action_id
	current_action_id = &""
	action_completed.emit(completed_id)
