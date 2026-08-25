## Compact ActionScreen control for the Sponsor Shield resource sink.
##
## ResourceManager owns all cost, stacking, timing, and buffer rules. This UI
## reconstructs state on ready, reacts to Sponsors/shield notifications, and
## forwards button presses to activate_sponsor_shield(). It never duplicates
## or mutates gameplay constants.
extends PanelContainer

@onready var _status_label: Label = %ShieldStatusLabel
@onready var _cost_label: Label = %ShieldCostLabel
@onready var _shortfall_label: Label = %ShieldShortfallLabel
@onready var _action_button: Button = %ShieldActionButton


func _ready() -> void:
	_status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_cost_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_shortfall_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_action_button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_action_button.pressed.connect(_on_action_pressed)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	ResourceManager.shield_changed.connect(_on_shield_changed)
	SettingsSystem.language_changed.connect(_on_language_changed)
	_refresh()


func _process(_delta: float) -> void:
	# ResourceManager owns elapsed time; this process only refreshes presentation.
	_refresh()


func _on_action_pressed() -> void:
	ResourceManager.activate_sponsor_shield()
	# Rejection emits no signal, while a successful call does. Refresh in both
	# cases so the command surface always reconciles immediately.
	_refresh()


func _on_resource_changed(name: StringName, _new_value: float, _old_value: float) -> void:
	if name == &"Sponsors":
		_refresh()


func _on_shield_changed(_is_active: bool, _remaining_seconds: float) -> void:
	_refresh()


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_refresh()


func _refresh() -> void:
	var remaining: float = ResourceManager.get_shield_remaining_seconds()
	var active: bool = remaining > 0.0
	var sponsors: int = int(ResourceManager.get_resource(&"Sponsors"))
	var missing: int = maxi(0, ResourceManager.SHIELD_COST - sponsors)

	_cost_label.text = tr("META_SHIELD_COST") % ResourceManager.SHIELD_COST
	if active:
		_status_label.text = tr("META_SHIELD_ACTIVE") % _format_remaining(remaining)
		_action_button.text = tr("META_SHIELD_ADD")
	else:
		_status_label.text = tr("META_SHIELD_INACTIVE")
		_action_button.text = tr("META_SHIELD_ACTIVATE")

	_action_button.disabled = missing > 0
	_shortfall_label.visible = missing > 0
	_shortfall_label.text = tr("META_SHIELD_SHORTFALL") % missing if missing > 0 else ""
	set_process(active)


## Formats a positive countdown using ceil so the UI never advertises expiry
## before ResourceManager reaches zero. A fixed H:MM:SS shape remains stable
## when additive stacking crosses an hour.
static func _format_remaining(remaining_seconds: float) -> String:
	var total_seconds: int = maxi(0, int(ceil(remaining_seconds)))
	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60
	return "%d:%02d:%02d" % [hours, minutes, seconds]
