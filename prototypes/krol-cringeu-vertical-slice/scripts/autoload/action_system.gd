# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the core fantasy within 3-5 min, unguided?
# Date: 2026-06-20
#
# Implements ADR-0004: single Timer + current_action_id guard for single-concurrency.
extends Node

const ACTION_DURATIONS := {
	&"record_vlog": 6.0,
	&"start_drama": 9.0,
	&"apologize": 4.0,
}

const ACTION_REWARDS := {
	&"record_vlog": {&"Reach": 5.0, &"Cringe": 2.0, &"Morale": 0.0},
	&"start_drama": {&"Reach": 10.0, &"Cringe": 20.0, &"Morale": -3.0},
	&"apologize": {&"Reach": 6.0, &"Cringe": -15.0, &"Morale": 5.0},
}

const ACTION_LABELS := {
	&"record_vlog": "Record a Vlog",
	&"start_drama": "Start Drama",
	&"apologize": "Apologize Online",
}

var current_action_id: StringName = &""
var _timer: Timer

signal action_completed(action_id: StringName, rewards: Dictionary)

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_action_timeout)
	add_child(_timer)

func start_action(action_id: StringName) -> bool:
	if current_action_id != &"":
		return false
	current_action_id = action_id
	_timer.wait_time = ACTION_DURATIONS[action_id]
	_timer.start()
	return true

func get_progress() -> float:
	if current_action_id == &"" or _timer.wait_time <= 0.0:
		return 0.0
	return 1.0 - (_timer.time_left / _timer.wait_time)

func _on_action_timeout() -> void:
	var completed_id := current_action_id
	var rewards: Dictionary = ACTION_REWARDS[completed_id]
	current_action_id = &""
	action_completed.emit(completed_id, rewards)
