## Rapid classification Skill Challenge. Each comment must be kept or removed;
## the node emits normalized accuracy while reward math stays in the card system.
class_name CommentModeration
extends Control

signal finished(score: float, abandoned: bool)

const MAX_SHUFFLE_ATTEMPTS: int = 8

var _config: Dictionary = {}
var _events: Array = []
var _event_index: int = 0
var _correct: int = 0
var _active: bool = false
var _accepting_input: bool = false
var _finish_emitted: bool = false
var _feedback_key: StringName = &""
var _session_rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _timer: Timer = %EventTimer
@onready var _advance_timer: Timer = %AdvanceTimer
@onready var _comment_label: Label = %CommentLabel
@onready var _progress_label: Label = %ProgressLabel
@onready var _score_label: Label = %ScoreLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _keep_button: Button = %KeepButton
@onready var _remove_button: Button = %RemoveButton
@onready var _skip_button: Button = %SkipButton


func _ready() -> void:
	for control: Control in [
		_comment_label,
		_progress_label,
		_score_label,
		_feedback_label,
		_keep_button,
		_remove_button,
		_skip_button,
	]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false
	_keep_button.pressed.connect(classify.bind("keep"))
	_remove_button.pressed.connect(classify.bind("remove"))
	_skip_button.pressed.connect(skip)
	_timer.timeout.connect(classify.bind("timeout"))
	_advance_timer.timeout.connect(_advance_to_next_event)
	SettingsSystem.language_changed.connect(_on_language_changed)


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_keep_button.text = tr("MINIGAME_MOD_KEEP")
	_remove_button.text = tr("MINIGAME_MOD_REMOVE")
	_skip_button.text = tr("MINIGAME_SKIP")
	if not _active or _event_index >= _events.size():
		return
	var event: Dictionary = _events[_event_index]
	var text_key: String = String(event.get("text_key", ""))
	var fallback: String = String(event.get("text", ""))
	var localized: String = tr(text_key) if not text_key.is_empty() else fallback
	_comment_label.text = "“%s”" % (fallback if localized == text_key else localized)
	_progress_label.text = tr("MINIGAME_MOD_PROGRESS") % [_event_index + 1, _events.size()]
	_score_label.text = tr("MINIGAME_MOD_SCORE") % _correct
	if _feedback_key != &"":
		_feedback_label.text = tr(_feedback_key)


## Starts one moderation session. Event order is freshly shuffled for every
## call while preserving the configured event set and its KEEP/REMOVE balance.
## Tests may inject [param shuffle_index_picker] (`upper_inclusive -> int`) to
## exercise exact permutations without depending on random seeds.
func start(config: Dictionary, shuffle_index_picker: Callable = Callable()) -> bool:
	if config.is_empty() or not config.get("events", []) is Array:
		return false
	_config = config.duplicate(true)
	if String(_config.get("event_order", "shuffle_nontrivial")) != "shuffle_nontrivial":
		return false
	var picker: Callable = shuffle_index_picker
	if not picker.is_valid():
		_session_rng.randomize()
		picker = _pick_session_index
	_events = build_session_events(_config["events"], picker)
	if _events.is_empty():
		return false
	_event_index = 0
	_correct = 0
	_active = true
	_accepting_input = true
	_finish_emitted = false
	_feedback_label.text = ""
	visible = true
	_on_language_changed(SettingsSystem.language_preference, StringName(TranslationServer.get_locale()))
	_show_event()
	_keep_button.grab_focus()
	return true


## Returns a deep-copied Fisher-Yates permutation of [param source_events].
## Strict KEEP/REMOVE alternation and a single grouped KEEP/REMOVE block are
## rejected as trivially learnable. The bounded fallback breaks either shape
## deterministically, so even an adversarial picker cannot restore the pattern.
static func build_session_events(source_events: Array, index_picker: Callable) -> Array:
	if source_events.size() < 2 or not index_picker.is_valid():
		return source_events.duplicate(true)
	var candidate: Array = []
	for _attempt: int in range(MAX_SHUFFLE_ATTEMPTS):
		candidate = source_events.duplicate(true)
		_fisher_yates(candidate, index_picker)
		if not _has_trivial_action_pattern(candidate):
			return candidate
	_break_trivial_action_pattern(candidate)
	return candidate


static func _fisher_yates(events: Array, index_picker: Callable) -> void:
	for index: int in range(events.size() - 1, 0, -1):
		var picked: int = clampi(int(index_picker.call(index)), 0, index)
		var held: Variant = events[index]
		events[index] = events[picked]
		events[picked] = held


static func _has_trivial_action_pattern(events: Array) -> bool:
	if events.size() < 3:
		return false
	var transitions: int = 0
	for index: int in range(1, events.size()):
		var current: String = String(events[index].get("correct_action", ""))
		var previous: String = String(events[index - 1].get("correct_action", ""))
		if current != previous:
			transitions += 1
	return transitions <= 1 or transitions == events.size() - 1


static func _break_trivial_action_pattern(events: Array) -> void:
	if events.size() < 3:
		return
	var transitions: int = 0
	for index: int in range(1, events.size()):
		if String(events[index].get("correct_action", "")) != String(events[index - 1].get("correct_action", "")):
			transitions += 1
	if transitions == events.size() - 1:
		var held: Variant = events[1]
		events[1] = events[2]
		events[2] = held
		return
	if transitions > 1:
		return
	var first_action: String = String(events[0].get("correct_action", ""))
	for boundary: int in range(1, events.size()):
		if String(events[boundary].get("correct_action", "")) == first_action:
			continue
		var left_index: int = 1 if boundary > 1 else 0
		var held: Variant = events[left_index]
		events[left_index] = events[boundary]
		events[boundary] = held
		return


func _pick_session_index(upper_inclusive: int) -> int:
	return _session_rng.randi_range(0, upper_inclusive)


func classify(action: String) -> void:
	if not _active or not _accepting_input or _event_index >= _events.size():
		return
	_timer.stop()
	_accepting_input = false
	var is_correct: bool = action == String(_events[_event_index].get("correct_action", ""))
	if is_correct:
		_correct += 1
	_feedback_key = (
		&"MINIGAME_MOD_CORRECT"
		if is_correct
		else (&"MINIGAME_MOD_MISSED" if action == "timeout" else &"MINIGAME_MOD_WRONG")
	)
	_feedback_label.text = tr(_feedback_key)
	_score_label.text = tr("MINIGAME_MOD_SCORE") % _correct
	_keep_button.disabled = true
	_remove_button.disabled = true
	_advance_timer.start(float(_config.get("feedback_pause_seconds", 0.0)))


func _advance_to_next_event() -> void:
	if not _active:
		return
	_event_index += 1
	_show_event()


func skip() -> void:
	_finish(0.0, true)


func _show_event() -> void:
	if _event_index >= _events.size():
		_finish(float(_correct) / float(maxi(1, _events.size())), false)
		return
	var event: Dictionary = _events[_event_index]
	var text_key: String = String(event.get("text_key", ""))
	var fallback: String = String(event.get("text", ""))
	var comment_text: String = tr(text_key) if not text_key.is_empty() else fallback
	if comment_text == text_key:
		comment_text = fallback
	_comment_label.text = "“%s”" % comment_text
	_progress_label.text = tr("MINIGAME_MOD_PROGRESS") % [_event_index + 1, _events.size()]
	_score_label.text = tr("MINIGAME_MOD_SCORE") % _correct
	_feedback_key = &""
	_feedback_label.text = ""
	_accepting_input = true
	_keep_button.disabled = false
	_remove_button.disabled = false
	_timer.start(float(_config["event_duration_seconds"]))


func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_LEFT or event.keycode == KEY_A:
		classify("remove")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_RIGHT or event.keycode == KEY_D:
		classify("keep")
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		skip()
		get_viewport().set_input_as_handled()


func _finish(score: float, abandoned: bool) -> void:
	if not _active or _finish_emitted:
		return
	_finish_emitted = true
	_active = false
	_accepting_input = false
	_timer.stop()
	_advance_timer.stop()
	visible = false
	finished.emit(clampf(score, 0.0, 1.0) if is_finite(score) else 0.0, abandoned)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _active:
			_finish(float(_correct) / float(maxi(1, _events.size())), false)
