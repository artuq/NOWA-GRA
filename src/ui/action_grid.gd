## ActionGrid is one of 3 sibling Control-node zones under the ActionScreen
## root scene (ADR-0007). Renders the 6-slot action grid (3 unlocked + 3
## locked), wires each unlocked button's `pressed` signal directly to
## `ActionSystem.start_action()`, and disables/re-enables all 6 buttons on
## action start/completion.
##
## No `_process()` in this zone -- RunningActionOverlay is the sole
## `_process()`-using zone, per ADR-0007.
##
## Performance: event-driven only (button `pressed` signals + the
## `action_completed` connection) -- no per-frame cost.
##
## Usage: instanced as a child of ActionScreen (res://scenes/action_screen/action_screen.tscn).
class_name ActionGrid
extends Control

## Display names for the 3 currently-unlocked actions, keyed by action_id.
## TECH DEBT (same class as ActionSystem's ACTION_DURATIONS/ACTION_REWARDS,
## see that file's header comment): hardcoded here because no localization
## system or external display-name registry exists yet. Candidate for
## extraction to a shared data resource once one exists.
const ACTION_DISPLAY_NAMES: Dictionary[StringName, String] = {
	&"nagraj_vloga": "Nagraj vloga",
	&"zrob_drame": "Zrób dramę",
	&"przeprosiny": "Przeproś w internecie",
}

## The 3 unlocked action slots, in display order.
const UNLOCKED_ACTION_IDS: Array[StringName] = [&"nagraj_vloga", &"zrob_drame", &"przeprosiny"]

@onready var _slot_buttons: Array[Button] = [
	%Slot1Button, %Slot2Button, %Slot3Button, %Slot4Button, %Slot5Button, %Slot6Button,
]

func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed)
	_configure_unlocked_slots()
	_configure_locked_slots()


## Wires the first 3 slots to the 3 currently-unlocked actions: label text,
## enabled state, and the pressed -> start_action() connection.
func _configure_unlocked_slots() -> void:
	for i in UNLOCKED_ACTION_IDS.size():
		var action_id: StringName = UNLOCKED_ACTION_IDS[i]
		var button: Button = _slot_buttons[i]
		button.text = _button_label(action_id)
		button.disabled = false
		button.pressed.connect(_on_unlocked_button_pressed.bind(action_id))


## Wires the last 3 slots as locked, generic placeholders -- no source of
## truth exists yet for real unlock_threshold values (per this story's Out
## of Scope), so these are disabled-by-default placeholders, never tappable.
func _configure_locked_slots() -> void:
	for i in range(UNLOCKED_ACTION_IDS.size(), _slot_buttons.size()):
		var button: Button = _slot_buttons[i]
		button.text = "🔒"
		button.disabled = true
		# No pressed connection at all -- a disabled button never fires
		# pressed, so no redundant guard is needed in a handler.


## Builds the button label per action-ui.md's anatomy rule: name, duration,
## and reward values, e.g. "Zrób dramę\n9s — +10Z, +20C, -3M". Reward values
## are formatted via ActionUIFormatting.format_number(), with an explicit
## "+" prefix added for non-negative deltas (format_number only prefixes
## "-" for negative values, per its own contract).
func _button_label(action_id: StringName) -> String:
	var name: String = ACTION_DISPLAY_NAMES.get(action_id, String(action_id))
	var duration: float = ActionSystem.ACTION_DURATIONS[action_id]
	var rewards: Dictionary = ActionSystem.ACTION_REWARDS[action_id]
	var reach_str: String = _signed_number(rewards[&"Reach"])
	var cringe_str: String = _signed_number(rewards[&"Cringe"])
	var morale_str: String = _signed_number(rewards[&"Morale"])
	return "%s\n%ds — %sZ, %sC, %sM" % [name, int(duration), reach_str, cringe_str, morale_str]


## Formats [param value] via ActionUIFormatting.format_number(), adding an
## explicit "+" prefix for non-negative values (format_number's own sign
## handling only ever prefixes "-", never "+").
func _signed_number(value: float) -> String:
	var formatted: String = ActionUIFormatting.format_number(value)
	return formatted if value < 0.0 else "+%s" % formatted


func _on_unlocked_button_pressed(action_id: StringName) -> void:
	var started: bool = ActionSystem.start_action(action_id)
	if started:
		_set_all_slots_disabled(true)


func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	# Only the unlocked slots are touched -- locked slots were disabled once
	# at _ready() and are never re-enabled here, avoiding an enable-then-
	# re-disable churn on slots that should never change state in this story.
	for i in UNLOCKED_ACTION_IDS.size():
		_slot_buttons[i].disabled = false


func _set_all_slots_disabled(disabled: bool) -> void:
	for button: Button in _slot_buttons:
		button.disabled = disabled
