## RunningActionOverlay is one of 3 sibling Control-node zones under the
## ActionScreen root scene (ADR-0007). The sole action-progress zone using
## `_process()` -- gated by set_process(bool), toggled on
## ActionSystem.action_started/action_completed, with an explicit initial-
## state check in _ready() (Control nodes process by default).
##
## Performance: action-progress polling is isolated here (ADR-0007) -- O(1)
## per frame while active (one get_progress() call, one
## fill update), zero cost while idle.
##
## Usage: instanced as a child of ActionScreen (res://scenes/action_screen/action_screen.tscn).
class_name RunningActionOverlay
extends Control

@onready var _progress_bar: ProgressBar = %ProgressBar
@onready var _action_name_label: Label = %ActionNameLabel
@onready var _remaining_time_label: Label = %RemainingTimeLabel

func _ready() -> void:
	_action_name_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_remaining_time_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ActionSystem.action_started.connect(_on_action_started)
	ActionSystem.action_completed.connect(_on_action_completed)
	SettingsSystem.language_changed.connect(_on_language_changed)
	# Explicit initial-state check -- Control nodes process by default.
	# Without this, the overlay would poll needlessly from scene load until
	# the first action_started/action_completed signal ever fires (ADR-0007
	# engine specialist finding, 2026-06-24).
	var is_running: bool = not ActionSystem.current_action_id.is_empty()
	set_process(is_running)
	visible = is_running
	if is_running:
		_action_name_label.text = ActionSystem.get_display_name(ActionSystem.current_action_id)


func _process(_delta: float) -> void:
	var progress: float = ActionSystem.get_progress()
	_progress_bar.value = progress
	# Read the effective duration captured when the action started. This keeps
	# Class Path speed bonuses aligned with get_progress() without reaching
	# into ActionSystem's private Timer (ADR-0001/ADR-0010).
	var duration: float = ActionSystem.get_current_duration()
	var remaining: float = duration * (1.0 - progress)
	_remaining_time_label.text = tr("ACTION_REMAINING_SECONDS") % int(ceil(remaining))


func _on_action_started(action_id: StringName) -> void:
	# Fixed a real bug found via user playtesting: this previously showed the
	# raw action_id (e.g. "zrob_drame") instead of a display name.
	# The stable display key lives on ActionSystem (not ActionGrid) so this zone
	# can localize without cross-zone coupling (ADR-0007).
	_action_name_label.text = ActionSystem.get_display_name(action_id)
	_progress_bar.value = 0.0
	visible = true
	set_process(true)


func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	set_process(false)
	visible = false


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	if ActionSystem.current_action_id == &"":
		return
	_action_name_label.text = ActionSystem.get_display_name(ActionSystem.current_action_id)
	# Refresh the time string immediately instead of waiting for the next frame.
	_process(0.0)
