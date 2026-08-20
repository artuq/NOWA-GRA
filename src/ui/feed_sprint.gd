## Three-lane deterministic Skill Challenge embedded in CardScreen. The node
## owns input/timing only and emits a normalized score; reward math remains in
## DecisionCardSystem.
class_name FeedSprint
extends Control

signal finished(score: float, abandoned: bool)

const TREND_COLOR: Color = Color(0.42, 0.90, 0.93, 1.0)
const STRIKE_COLOR: Color = Color(1.0, 0.42, 0.48, 1.0)
const ACTIVE_LANE_COLOR: Color = Color(0.96, 0.96, 0.97, 1.0)
const INACTIVE_LANE_COLOR: Color = Color(0.58, 0.59, 0.67, 1.0)
const LANE_KEYS: PackedStringArray = [
	"MINIGAME_FEED_LEFT",
	"MINIGAME_FEED_CENTER",
	"MINIGAME_FEED_RIGHT",
]

var _config: Dictionary = {}
var _events: Array = []
var _event_index: int = 0
var _player_lane: int = 1
var _trends_collected: int = 0
var _trend_total: int = 0
var _active: bool = false
var _finish_emitted: bool = false

@onready var _event_timer: Timer = %EventTimer
@onready var _playfield: Control = %Playfield
@onready var _event_badge: Label = %EventBadge
@onready var _runner: Label = %Runner
@onready var _target_label: Label = %CurrentTargetLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _left_button: Button = %LeftButton
@onready var _right_button: Button = %RightButton
@onready var _skip_button: Button = %SkipButton
@onready var _lane_labels: Array[Label] = [%LeftLaneLabel, %CenterLaneLabel, %RightLaneLabel]


func _ready() -> void:
	for control: Control in [
		_event_badge,
		_target_label,
		_progress_label,
		_score_label,
		_instruction_label,
		_left_button,
		_right_button,
		_skip_button,
	]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for lane_label: Label in _lane_labels:
		lane_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false
	set_process(false)
	_left_button.pressed.connect(move_left)
	_right_button.pressed.connect(move_right)
	_skip_button.pressed.connect(skip)
	_event_timer.timeout.connect(_resolve_event)
	SettingsSystem.language_changed.connect(_on_language_changed)


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_instruction_label.text = tr("MINIGAME_FEED_INSTRUCTION")
	_left_button.text = tr("MINIGAME_LEFT_BUTTON")
	_right_button.text = tr("MINIGAME_RIGHT_BUTTON")
	_skip_button.text = tr("MINIGAME_SKIP")
	if not _active:
		return
	_show_event(false)
	_update_runner_position()


## Starts a fresh run from validated external configuration. Returns false and
## emits nothing for invalid data so CardScreen can safely resolve a zero-score
## fallback instead of presenting a broken challenge.
func start(config: Dictionary) -> bool:
	if config.is_empty() or not config.get("events", []) is Array:
		return false
	_config = config.duplicate(true)
	_events = _config["events"].duplicate(true)
	if _events.is_empty():
		return false
	_event_index = 0
	_player_lane = int(_config["lane_count"]) / 2
	_trends_collected = 0
	_trend_total = 0
	for event: Dictionary in _events:
		if String(event["kind"]) == "trend":
			_trend_total += 1
	_active = true
	_finish_emitted = false
	visible = true
	set_process(true)
	_on_language_changed(SettingsSystem.language_preference, StringName(TranslationServer.get_locale()))
	_update_runner_position()
	_show_event()
	_left_button.grab_focus()
	return true


## Moves one lane left. Safe at the boundary and while inactive.
func move_left() -> void:
	if not _active:
		return
	_player_lane = maxi(0, _player_lane - 1)
	_update_runner_position()


## Moves one lane right. Safe at the boundary and while inactive.
func move_right() -> void:
	if not _active:
		return
	_player_lane = mini(int(_config["lane_count"]) - 1, _player_lane + 1)
	_update_runner_position()


## Ends the challenge immediately with no reward. Duplicate calls are ignored.
func skip() -> void:
	_finish(0.0, true)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_LEFT or event.keycode == KEY_A:
		move_left()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
		move_right()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		skip()
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _active or _event_timer.wait_time <= 0.0:
		return
	var fraction: float = 1.0 - (_event_timer.time_left / _event_timer.wait_time)
	var top_y: float = 116.0
	var bottom_y: float = maxf(top_y, _playfield.size.y - 150.0)
	_event_badge.position.y = (top_y + bottom_y) * 0.5 if SettingsSystem.reduce_motion else lerpf(top_y, bottom_y, fraction)


func _show_event(restart_timer: bool = true) -> void:
	if _event_index >= _events.size():
		var score: float = float(_trends_collected) / float(maxi(1, _trend_total))
		_finish(score, false)
		return
	var event: Dictionary = _events[_event_index]
	var kind: String = String(event["kind"])
	_event_badge.text = tr("MINIGAME_FEED_TREND") if kind == "trend" else tr("MINIGAME_FEED_STRIKE")
	_event_badge.tooltip_text = tr("MINIGAME_FEED_TOOLTIP_TREND") if kind == "trend" else tr("MINIGAME_FEED_TOOLTIP_STRIKE")
	if kind == "trend":
		_target_label.text = tr("MINIGAME_FEED_TARGET_TREND")
		_target_label.add_theme_color_override("font_color", TREND_COLOR)
		_event_badge.add_theme_color_override("font_color", TREND_COLOR)
	else:
		_target_label.text = tr("MINIGAME_FEED_TARGET_STRIKE")
		_target_label.add_theme_color_override("font_color", STRIKE_COLOR)
		_event_badge.add_theme_color_override("font_color", STRIKE_COLOR)
	_event_badge.position.x = _lane_x(int(event["lane"]), _event_badge.size.x)
	_progress_label.text = tr("MINIGAME_FEED_PROGRESS") % [_event_index + 1, _events.size()]
	_score_label.text = tr("MINIGAME_FEED_SCORE") % [_trends_collected, _trend_total]
	if restart_timer:
		_event_timer.start(float(_config["event_duration_seconds"]))


func _resolve_event() -> void:
	if not _active or _event_index >= _events.size():
		return
	var event: Dictionary = _events[_event_index]
	var same_lane: bool = _player_lane == int(event["lane"])
	if String(event["kind"]) == "trend" and same_lane:
		_trends_collected += 1
	_event_index += 1
	_show_event()


func _update_runner_position() -> void:
	_runner.position.x = _lane_x(_player_lane, _runner.size.x)
	_runner.position.y = maxf(0.0, _playfield.size.y - 86.0)
	for lane: int in _lane_labels.size():
		var label: Label = _lane_labels[lane]
		var lane_name: String = tr(LANE_KEYS[lane])
		label.text = "[ %s ]" % lane_name if lane == _player_lane else lane_name
		label.add_theme_color_override(
			"font_color",
			ACTIVE_LANE_COLOR if lane == _player_lane else INACTIVE_LANE_COLOR
		)


func _lane_x(lane: int, node_width: float) -> float:
	var lane_width: float = _playfield.size.x / float(maxi(1, int(_config.get("lane_count", 3))))
	return lane_width * float(lane) + (lane_width - node_width) * 0.5


func _finish(score: float, abandoned: bool = false) -> void:
	if not _active or _finish_emitted:
		return
	_finish_emitted = true
	_active = false
	_event_timer.stop()
	set_process(false)
	visible = false
	finished.emit(clampf(score, 0.0, 1.0) if is_finite(score) else 0.0, abandoned)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _active:
			var partial: float = float(_trends_collected) / float(maxi(1, _trend_total))
			_finish(partial, false)
