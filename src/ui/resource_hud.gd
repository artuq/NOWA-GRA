## ResourceHud is one of 3 sibling Control-node zones under the ActionScreen
## root scene (ADR-0007). Displays all 5 resources, reacting to
## ResourceManager.resource_changed -- never polls, never reads all 5
## resources every frame.
##
## Morale is shown as its band label (High/Normal/Low/Critical), not the raw
## percentage, per action-ui.md's Resource HUD rule. Band boundaries are read
## directly from ResourceFormulas' constants (E_FULL_THRESHOLD,
## E_HIGH_THRESHOLD, E_LOW_THRESHOLD) rather than duplicated here, to avoid
## drift between the formula's bands and this HUD's displayed band.
##
## Performance: signal-driven, O(1) work per resource_changed emission (one
## label update) -- no per-frame cost, unlike RunningActionOverlay (the only
## zone using _process(), per ADR-0007).
##
## Usage: instanced as a child of ActionScreen (res://scenes/action_screen/action_screen.tscn).
class_name ResourceHud
extends Control

@onready var _reach_label: Label = %ReachLabel
@onready var _cringe_label: Label = %CringeLabel
@onready var _haters_label: Label = %HatersLabel
@onready var _morale_label: Label = %MoraleLabel
@onready var _sponsors_label: Label = %SponsorsLabel

func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	# Populate initial state -- resource_changed only fires on subsequent
	# changes, not on this HUD's own _ready().
	_update_label(&"Reach", ResourceManager.get_resource(&"Reach"))
	_update_label(&"Cringe", ResourceManager.get_resource(&"Cringe"))
	_update_label(&"Haters", ResourceManager.get_resource(&"Haters"))
	_update_label(&"Morale", ResourceManager.get_resource(&"Morale"))
	_update_label(&"Sponsors", ResourceManager.get_resource(&"Sponsors"))


func _on_resource_changed(name: StringName, new_value: float, _old_value: float) -> void:
	_update_label(name, new_value)


## Fixed a real readability defect (caught by user testing the actual scene,
## 2026-06-25): bare formatted numbers with no identifying label are
## unreadable when shown side by side ("19 20 0 Critical 0" -- no way to
## tell which value is which resource). Each label now shows its English
## display name as a prefix -- the game's UI language is English (per user
## correction 2026-06-25); the existing Polish action/card content elsewhere
## in the project is a separate, deliberate follow-up, not addressed here.
func _update_label(name: StringName, value: float) -> void:
	match name:
		&"Reach":
			_reach_label.text = "Reach: %s" % ActionUIFormatting.format_number(value)
		&"Cringe":
			_cringe_label.text = "Cringe: %s" % ActionUIFormatting.format_number(value)
		&"Haters":
			_haters_label.text = "Haters: %s" % ActionUIFormatting.format_number(value)
		&"Morale":
			_morale_label.text = "Morale: %s" % _morale_band_label(value)
		&"Sponsors":
			_sponsors_label.text = "Sponsors: %s" % ActionUIFormatting.format_number(value)


## Maps a raw Morale value to its band label, per resource-system.md's
## Formula C bands -- reads ResourceFormulas' existing threshold constants
## directly rather than redeclaring the boundary numbers here.
func _morale_band_label(morale: float) -> String:
	if morale >= ResourceFormulas.E_FULL_THRESHOLD:
		return "High"
	elif morale >= ResourceFormulas.E_HIGH_THRESHOLD:
		return "Normal"
	elif morale >= ResourceFormulas.E_LOW_THRESHOLD:
		return "Low"
	else:
		return "Critical"
