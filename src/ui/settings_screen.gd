## SettingsScreen is a compact preferences modal: one "Reduce Motion" toggle,
## a persisted System/English/Polski language selector, and a Close button.
## Instanced as a sibling under ActionScreen's root
## (scenes/action_screen/action_screen.tscn), alongside CardScreen -- same
## modal shell convention (full-rect Control, mouse_filter = STOP while
## visible; invisible = no input at all, so the Action UI beneath stays fully
## interactive when this is closed).
##
## Opened by ActionScreen's SettingsButton wiring via a plain
## `visible = true` flip on this node (not a custom method call) -- kept
## deliberately untyped from the caller's side, so ActionScreen never needs a
## static type reference to this class (avoids a real, previously-hit
## headless-CLI risk: a freshly added class_name script isn't guaranteed to be
## in the global class cache yet -- see card_screen.gd's FeedbackMath preload
## comment for the same concern in a different spot). This modal instead
## self-manages via its own visibility_changed signal, matching CardScreen's
## "owns its own visibility" philosophy.
##
## Owns no state itself: the toggle reads/writes through SettingsSystem
## (ADR-0001 peer-module pattern, same shape as OnboardingGate) --
## set_reduce_motion() persists the change (marks SaveSystem dirty); this
## script never mutates SettingsSystem.reduce_motion directly.
class_name SettingsScreen
extends Control

## ADR-0014: emitted when the Close button is tapped — the MainNavCoordinator
## (action_screen.gd) consumes this and owns the actual visible flip.
signal close_requested

const _LANGUAGE_OPTION_KEYS: Array[StringName] = [
	&"UI_SETTINGS_LANGUAGE_SYSTEM",
	&"UI_SETTINGS_LANGUAGE_ENGLISH",
	&"UI_SETTINGS_LANGUAGE_POLISH",
]

const _LANGUAGE_OPTION_VALUES: Array[StringName] = [
	SettingsSystem.LANGUAGE_SYSTEM,
	SettingsSystem.LANGUAGE_EN,
	SettingsSystem.LANGUAGE_PL,
]

@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _language_select: OptionButton = %LanguageSelect
@onready var _close_button: Button = %CloseButton
@onready var _title_label: Label = %TitleLabel
@onready var _language_label: Label = %LanguageLabel
@onready var _reduce_motion_label: Label = %ReduceMotionLabel


func _ready() -> void:
	for control: Control in [
		_title_label,
		_language_label,
		_reduce_motion_label,
		_close_button,
	]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_language_select.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visible = false
	visibility_changed.connect(_on_visibility_changed)
	_reduce_motion_toggle.toggled.connect(SettingsSystem.set_reduce_motion)
	_language_select.item_selected.connect(_on_language_selected)
	SettingsSystem.language_changed.connect(_on_language_changed)
	_close_button.pressed.connect(_on_close_pressed)
	_refresh_static_copy()
	_refresh_language_options()


## Syncs the toggle to the current persisted value every time this modal
## becomes visible -- keeps the "toggle reflects SettingsSystem.reduce_motion"
## invariant explicit and correct rather than merely assumed, even though
## SettingsSystem.set_reduce_motion() is currently the only writer and this
## toggle the only caller (no other path can change the value while closed).
func _on_visibility_changed() -> void:
	if visible:
		_reduce_motion_toggle.button_pressed = SettingsSystem.reduce_motion
		_refresh_language_options()


func _on_language_selected(index: int) -> void:
	if index < 0 or index >= _language_select.item_count:
		return
	var preference: StringName = StringName(_language_select.get_item_metadata(index))
	SettingsSystem.set_language_preference(preference)


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_refresh_static_copy()
	_refresh_language_options()


func _refresh_language_options() -> void:
	_language_select.clear()
	for index: int in _LANGUAGE_OPTION_VALUES.size():
		_language_select.add_item(tr(_LANGUAGE_OPTION_KEYS[index]))
		_language_select.set_item_metadata(index, _LANGUAGE_OPTION_VALUES[index])

	var selected_index: int = _LANGUAGE_OPTION_VALUES.find(
		SettingsSystem.language_preference
	)
	_language_select.select(maxi(selected_index, 0))
	_language_select.tooltip_text = tr(&"UI_SETTINGS_LANGUAGE_HINT")


func _refresh_static_copy() -> void:
	_title_label.text = tr(&"UI_SETTINGS_TITLE")
	_language_label.text = tr(&"UI_SETTINGS_LANGUAGE")
	_reduce_motion_label.text = tr(&"UI_SETTINGS_REDUCE_MOTION")
	_close_button.text = tr(&"UI_SETTINGS_CLOSE")


func _on_close_pressed() -> void:
	# ADR-0014: the coordinator owns visibility — this panel only REQUESTS
	# closing (was `visible = false`, the documented bypass bug).
	close_requested.emit()
