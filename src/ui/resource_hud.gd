## ResourceHud is one of 3 sibling Control-node zones under the ActionScreen
## root scene (ADR-0007). Displays all 5 resources as rounded "pill" panels
## (icon + value), reacting to ResourceManager.resource_changed -- never
## polls, never reads all 5 resources every frame.
##
## Redesigned 2026-06-25 per Art Director review: light-mode "Gamified
## Analytics" dashboard aesthetic (design/art/art-bible-stub.md), replacing
## the initial dark/flat/text-only HUD. Icons are emoji placeholders until
## real pixel-art sprites exist -- swapping them later does not require
## redesigning this layout.
##
## Morale is shown as its band label (High/Normal/Low/Critical), not the raw
## percentage, per action-ui.md's Resource HUD rule. Band boundaries are read
## directly from ResourceFormulas' constants (E_FULL_THRESHOLD,
## E_HIGH_THRESHOLD, E_LOW_THRESHOLD) rather than duplicated here, to avoid
## drift between the formula's bands and this HUD's displayed band.
##
## Performance: signal-driven, O(1) work per resource_changed emission (one
## label update + one Tween) -- no per-frame cost, unlike RunningActionOverlay
## (the only zone using _process(), per ADR-0007).
##
## Usage: instanced as a child of ActionScreen (res://scenes/action_screen/action_screen.tscn).
class_name ResourceHud
extends Control

@onready var _reach_label: Label = %ReachValueLabel
@onready var _cringe_label: Label = %CringeValueLabel
@onready var _haters_label: Label = %HatersValueLabel
@onready var _morale_label: Label = %MoraleValueLabel
@onready var _sponsors_label: Label = %SponsorsValueLabel

@onready var _reach_pill: Control = %ReachPill
@onready var _cringe_pill: Control = %CringePill
@onready var _haters_pill: Control = %HatersPill
@onready var _morale_pill: Control = %MoralePill
@onready var _sponsors_pill: Control = %SponsorsPill

func _ready() -> void:
	ResourceManager.resource_changed.connect(_on_resource_changed)
	# Populate initial state -- resource_changed only fires on subsequent
	# changes, not on this HUD's own _ready(). No pop animation on initial load.
	_update_label(&"Reach", ResourceManager.get_resource(&"Reach"))
	_update_label(&"Cringe", ResourceManager.get_resource(&"Cringe"))
	_update_label(&"Haters", ResourceManager.get_resource(&"Haters"))
	_update_label(&"Morale", ResourceManager.get_resource(&"Morale"))
	_update_label(&"Sponsors", ResourceManager.get_resource(&"Sponsors"))


func _on_resource_changed(name: StringName, new_value: float, _old_value: float) -> void:
	_update_label(name, new_value)
	_pop(_pill_for(name))


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


func _pill_for(name: StringName) -> Control:
	match name:
		&"Reach":
			return _reach_pill
		&"Cringe":
			return _cringe_pill
		&"Haters":
			return _haters_pill
		&"Morale":
			return _morale_pill
		&"Sponsors":
			return _sponsors_pill
		_:
			return null


## Brief scale-punch (~1.0 -> 1.3 -> 1.0, ~200ms) on the pill when its value
## changes -- a small, locally-scoped piece of the eventual Juice/Feedback
## System (Vertical Slice tier), not a substitute for it. Sets pivot_offset
## to the pill's own size/2 each call so the punch scales from its center
## regardless of layout position.
func _pop(pill: Control) -> void:
	if pill == null:
		return
	pill.pivot_offset = pill.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(pill, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(pill, "scale", Vector2(1.0, 1.0), 0.1)


## Maps a raw Morale value to its band label. Delegates to the shared
## ResourceFormulas.morale_band_label (single source of truth, also used by the
## Offline Report Screen) so the band boundaries are never duplicated.
func _morale_band_label(morale: float) -> String:
	return ResourceFormulas.morale_band_label(morale)
