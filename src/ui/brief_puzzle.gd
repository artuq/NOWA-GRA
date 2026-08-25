## Optional, touch-first logic puzzle embedded in the sponsor callback card.
## The player reconstructs a contradictory campaign brief; reward calculation
## remains owned by DecisionCardSystem like every other Spotlight challenge.
class_name BriefPuzzle
extends Control

signal finished(score: float, abandoned: bool)

var _config: Dictionary = {}
var _events_by_id: Dictionary = {}
var _selection: Array[String] = []
var _attempts_used: int = 0
var _active: bool = false
var _finish_emitted: bool = false

@onready var _instruction_label: Label = %InstructionLabel
@onready var _selection_label: Label = %SelectionLabel
@onready var _feedback_label: Label = %FeedbackLabel
@onready var _clause_buttons: Array[Button] = [
	%ClauseButton0, %ClauseButton1, %ClauseButton2, %ClauseButton3,
]
@onready var _undo_button: Button = %UndoButton
@onready var _submit_button: Button = %SubmitButton
@onready var _skip_button: Button = %SkipButton


func _ready() -> void:
	for control: Control in [_instruction_label, _selection_label, _feedback_label, _undo_button, _submit_button, _skip_button]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for index: int in _clause_buttons.size():
		_clause_buttons[index].auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_clause_buttons[index].pressed.connect(_select_clause.bind(index))
	_undo_button.pressed.connect(undo)
	_submit_button.pressed.connect(submit)
	_skip_button.pressed.connect(skip)
	SettingsSystem.language_changed.connect(_on_language_changed)
	visible = false


func start(config: Dictionary) -> bool:
	if config.is_empty() or not config.get("events", []) is Array:
		return false
	var events: Array = config["events"]
	if events.size() != _clause_buttons.size():
		return false
	_config = config.duplicate(true)
	_events_by_id.clear()
	for index: int in events.size():
		var event: Dictionary = events[index]
		_events_by_id[String(event["id"])] = event
		_clause_buttons[index].set_meta(&"clause_id", String(event["id"]))
	_selection.clear()
	_attempts_used = 0
	_active = true
	_finish_emitted = false
	visible = true
	_on_language_changed(SettingsSystem.language_preference, StringName(TranslationServer.get_locale()))
	_refresh()
	_clause_buttons[0].grab_focus()
	return true


func _select_clause(index: int) -> void:
	if not _active or index < 0 or index >= _clause_buttons.size():
		return
	var clause_id: String = String(_clause_buttons[index].get_meta(&"clause_id", ""))
	if clause_id.is_empty() or clause_id in _selection:
		return
	_selection.append(clause_id)
	_feedback_label.text = ""
	_refresh()


func undo() -> void:
	if not _active or _selection.is_empty():
		return
	_selection.pop_back()
	_feedback_label.text = ""
	_refresh()


func submit() -> void:
	if not _active or _selection.size() != _clause_buttons.size():
		return
	var solution: Array = _config.get("solution", [])
	var correct: bool = true
	for index: int in solution.size():
		if _selection[index] != String(solution[index]):
			correct = false
			break
	if correct:
		var max_attempts: int = maxi(1, int(_config.get("max_attempts", 3)))
		var score: float = 1.0 - float(_attempts_used) / float(max_attempts)
		_finish(score, false)
		return
	_attempts_used += 1
	if _attempts_used >= int(_config.get("max_attempts", 3)):
		_finish(0.0, false)
		return
	_selection.clear()
	_feedback_label.text = tr("MINIGAME_BRIEF_WRONG") % [
		_attempts_used,
		int(_config.get("max_attempts", 3)),
	]
	_refresh(false)


func skip() -> void:
	_finish(0.0, true)


func _refresh(clear_feedback: bool = true) -> void:
	if clear_feedback:
		_feedback_label.text = ""
	var selected_labels: Array[String] = []
	for clause_id: String in _selection:
		selected_labels.append(_event_text(_events_by_id[clause_id]))
	_selection_label.text = tr("MINIGAME_BRIEF_SELECTION") % (
		tr("MINIGAME_BRIEF_EMPTY") if selected_labels.is_empty() else "  ›  ".join(selected_labels)
	)
	for button: Button in _clause_buttons:
		button.disabled = String(button.get_meta(&"clause_id", "")) in _selection
	_undo_button.disabled = _selection.is_empty()
	_submit_button.disabled = _selection.size() != _clause_buttons.size()


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_instruction_label.text = tr("MINIGAME_BRIEF_INSTRUCTION")
	_undo_button.text = tr("MINIGAME_BRIEF_UNDO")
	_submit_button.text = tr("MINIGAME_BRIEF_SUBMIT")
	_skip_button.text = tr("MINIGAME_SKIP")
	for button: Button in _clause_buttons:
		var clause_id: String = String(button.get_meta(&"clause_id", ""))
		if _events_by_id.has(clause_id):
			button.text = _event_text(_events_by_id[clause_id])
	if _active:
		_refresh(false)


func _event_text(event: Dictionary) -> String:
	var key: String = String(event.get("text_key", ""))
	var fallback: String = String(event.get("text", ""))
	var localized: String = tr(key) if not key.is_empty() else fallback
	return fallback if localized == key else localized


func _finish(score: float, abandoned: bool) -> void:
	if not _active or _finish_emitted:
		return
	_finish_emitted = true
	_active = false
	visible = false
	finished.emit(clampf(score, 0.0, 1.0) if is_finite(score) else 0.0, abandoned)
