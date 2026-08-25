## StaffPanel — the hiring surface for Team/Staff Management
## (design/gdd/team-staff-management.md UI Requirements,
## design/ux/staff-sponsor-ui.md), and ADR-0014's fourth coordinated panel.
##
## Three always-visible rows, one per role (never hidden at zero hires —
## same Locked/Muted-Slot convention as ActionGrid and ClassPathPanel): role
## name, what it does in concrete numbers, current count, the live effect
## multiplier, and a Hire button showing the next hire's exact Sponsors cost.
##
## Unaffordable is a DISABLED, still-visible button with an explanatory line
## (States table: "Przycisk disabled — widoczny, nie ukryty"), never a hidden
## control. Every value is pulled live from StaffSystem on refresh — nothing
## is cached (GDD Edge Cases: a future balance patch must apply immediately).
##
## Refreshes on: becoming visible, every successful hire, Sponsors changing
## (affordability can flip while the panel is open — a card resolving
## underneath grants Sponsors), and era reset (all counts drop to zero).
##
## close_requested from day one — the coordinator owns visibility (ADR-0014).
## Deliberately no class_name (headless global-class-cache convention shared
## with settings_screen.gd / bonuses_panel.gd).
extends Control

signal close_requested

## Display order + localization keys. Effect lines state the mechanic plainly,
## with no value judgment (art-bible §1 deadpan register).
const _ROWS: Array[Dictionary] = [
	{
		"role": &"troll",
		"name_key": &"META_STAFF_TROLL_NAME",
		"effect_key": &"META_STAFF_TROLL_EFFECT",
	},
	{
		"role": &"assistant",
		"name_key": &"META_STAFF_ASSISTANT_NAME",
		"effect_key": &"META_STAFF_ASSISTANT_EFFECT",
	},
	{
		"role": &"sponsor_manager",
		"name_key": &"META_STAFF_SPONSOR_MANAGER_NAME",
		"effect_key": &"META_STAFF_SPONSOR_MANAGER_EFFECT",
	},
]

@onready var _close_button: Button = %CloseButton
@onready var _sponsors_label: Label = %SponsorsLabel
@onready var _name_labels: Array[Label] = [%Row1NameLabel, %Row2NameLabel, %Row3NameLabel]
@onready var _effect_labels: Array[Label] = [%Row1EffectLabel, %Row2EffectLabel, %Row3EffectLabel]
@onready var _stat_labels: Array[Label] = [%Row1StatLabel, %Row2StatLabel, %Row3StatLabel]
@onready var _hire_buttons: Array[Button] = [%Row1HireButton, %Row2HireButton, %Row3HireButton]
@onready var _explanation_labels: Array[Label] = [
	%Row1ExplanationLabel, %Row2ExplanationLabel, %Row3ExplanationLabel,
]


func _ready() -> void:
	visible = false
	_sponsors_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for label: Label in _name_labels + _effect_labels + _stat_labels + _explanation_labels:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for button: Button in _hire_buttons:
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visibility_changed.connect(_on_visibility_changed)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	for i in _ROWS.size():
		_hire_buttons[i].pressed.connect(_on_hire_pressed.bind(i))
	StaffSystem.staff_hired.connect(_on_staff_changed)
	StaffSystem.staff_reset.connect(_on_staff_reset)
	# Affordability can flip while the panel sits open (a card resolving
	# underneath grants Sponsors), so track the resource too.
	ResourceManager.resource_changed.connect(_on_resource_changed)
	SettingsSystem.language_changed.connect(_on_language_changed)


func _on_visibility_changed() -> void:
	if visible:
		_refresh_all()


func _on_staff_changed(_role: StringName, _count: int) -> void:
	if visible:
		_refresh_all()


func _on_staff_reset() -> void:
	if visible:
		_refresh_all()


func _on_resource_changed(name: StringName, _new_value: float, _old: float) -> void:
	if visible and name == &"Sponsors":
		_refresh_all()


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	if visible:
		_refresh_all()


## Hire handler for row [param i]. StaffSystem.hire() re-checks affordability
## itself and rejects cleanly, so a stale enabled button can never overspend;
## the unconditional refresh afterwards re-syncs either way.
func _on_hire_pressed(i: int) -> void:
	StaffSystem.hire(_ROWS[i]["role"])
	_refresh_all()


func _refresh_all() -> void:
	var sponsors: int = int(ResourceManager.get_resource(&"Sponsors"))
	_sponsors_label.text = tr("META_STAFF_SPONSORS") % sponsors
	for i in _ROWS.size():
		var role: StringName = _ROWS[i]["role"]
		_name_labels[i].text = tr(_ROWS[i]["name_key"])
		_effect_labels[i].text = tr(_ROWS[i]["effect_key"])
		var count: int = StaffSystem.get_staff_count(role)
		var multiplier: float = StaffSystem.staff_multiplier(role, count)
		_stat_labels[i].text = tr("META_STAFF_STATS") % [count, _fmt(multiplier)]

		var cost: int = StaffSystem.get_next_hire_cost(role)
		var button: Button = _hire_buttons[i]
		var explanation: Label = _explanation_labels[i]
		button.text = tr("META_STAFF_HIRE") % cost
		if StaffSystem.can_hire(role):
			button.disabled = false
			explanation.visible = false
		else:
			button.disabled = true
			explanation.text = tr("META_STAFF_SHORTFALL") % (cost - sponsors)
			explanation.visible = true


## 1.0 -> "1", 1.75 -> "1.75", 2.07 -> "2.07" (trailing zeros trimmed).
func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.2f" % snappedf(value, 0.01)).rstrip("0").rstrip(".")
