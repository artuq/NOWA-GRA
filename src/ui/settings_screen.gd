## SettingsScreen is a minimal accessibility settings modal: one "Reduce
## Motion" toggle (art-bible.md Section 7 MANDATE, TR-juice reduce-motion
## rule) and a Close button. Instanced as a sibling under ActionScreen's root
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

@onready var _reduce_motion_toggle: CheckButton = %ReduceMotionToggle
@onready var _close_button: Button = %CloseButton


func _ready() -> void:
	visible = false
	visibility_changed.connect(_on_visibility_changed)
	_reduce_motion_toggle.toggled.connect(SettingsSystem.set_reduce_motion)
	_close_button.pressed.connect(_on_close_pressed)


## Syncs the toggle to the current persisted value every time this modal
## becomes visible -- keeps the "toggle reflects SettingsSystem.reduce_motion"
## invariant explicit and correct rather than merely assumed, even though
## SettingsSystem.set_reduce_motion() is currently the only writer and this
## toggle the only caller (no other path can change the value while closed).
func _on_visibility_changed() -> void:
	if visible:
		_reduce_motion_toggle.button_pressed = SettingsSystem.reduce_motion


func _on_close_pressed() -> void:
	# ADR-0014: the coordinator owns visibility — this panel only REQUESTS
	# closing (was `visible = false`, the documented bypass bug).
	close_requested.emit()
