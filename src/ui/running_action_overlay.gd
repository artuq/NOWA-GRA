## RunningActionOverlay is one of 3 sibling Control-node zones under the
## ActionScreen root scene (ADR-0007). The sole zone using `_process()` in
## Action UI -- gated by set_process(bool), toggled on
## ActionSystem.action_started/action_completed, with an explicit initial-
## state check in _ready() (Control nodes process by default).
##
## Performance: the only zone using _process() (ADR-0007's explicit scoping
## decision) -- O(1) per frame while active (one get_progress() call, one
## fill update), zero cost while idle.
##
## Usage: instanced as a child of ActionScreen (res://scenes/action_screen/action_screen.tscn).
class_name RunningActionOverlay
extends Control

@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _remaining_time_label: Label = %RemainingTimeLabel

func _ready() -> void:
	ActionSystem.action_started.connect(_on_action_started)
	ActionSystem.action_completed.connect(_on_action_completed)
	# Explicit initial-state check -- Control nodes process by default.
	# Without this, the overlay would poll needlessly from scene load until
	# the first action_started/action_completed signal ever fires (ADR-0007
	# engine specialist finding, 2026-06-24).
	var is_running: bool = not ActionSystem.current_action_id.is_empty()
	set_process(is_running)
	visible = is_running
	if is_running:
		_action_name_label.text = String(ActionSystem.current_action_id)


func _process(_delta: float) -> void:
	var progress: float = ActionSystem.get_progress()
	_progress_bar.value = progress
	# ACTION_DURATIONS is ActionSystem's public const lookup -- using it here
	# rather than reaching into ActionSystem's private _timer field respects
	# the Autoload's encapsulation (ADR-0001).
	var duration: float = ActionSystem.ACTION_DURATIONS.get(ActionSystem.current_action_id, 0.0)
	var remaining: float = duration * (1.0 - progress)
	_remaining_time_label.text = "%ds" % int(ceil(remaining))


func _on_action_started(action_id: StringName) -> void:
	_action_name_label.text = String(action_id)
	_progress_bar.value = 0.0
	visible = true
	set_process(true)


func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	set_process(false)
	visible = false
