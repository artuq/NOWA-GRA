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

## Display order + copy. Effect lines state the mechanic plainly, no value
## judgment (art-bible §1 deadpan register).
const _ROWS: Array[Dictionary] = [
	{
		"role": &"troll",
		"name": "Trolls",
		"effect": "Multiplies how fast Haters grow",
	},
	{
		"role": &"assistant",
		"name": "Assistants",
		"effect": "Multiplies offline progress (offline only)",
	},
	{
		"role": &"sponsor_manager",
		"name": "Sponsor Managers",
		"effect": "Multiplies Sponsors paid by sponsor cards",
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
	visibility_changed.connect(_on_visibility_changed)
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	for i in _ROWS.size():
		_name_labels[i].text = _ROWS[i]["name"]
		_effect_labels[i].text = _ROWS[i]["effect"]
		_hire_buttons[i].pressed.connect(_on_hire_pressed.bind(i))
	StaffSystem.staff_hired.connect(_on_staff_changed)
	StaffSystem.staff_reset.connect(_on_staff_reset)
	# Affordability can flip while the panel sits open (a card resolving
	# underneath grants Sponsors), so track the resource too.
	ResourceManager.resource_changed.connect(_on_resource_changed)


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


## Hire handler for row [param i]. StaffSystem.hire() re-checks affordability
## itself and rejects cleanly, so a stale enabled button can never overspend;
## the unconditional refresh afterwards re-syncs either way.
func _on_hire_pressed(i: int) -> void:
	StaffSystem.hire(_ROWS[i]["role"])
	_refresh_all()


func _refresh_all() -> void:
	var sponsors: int = int(ResourceManager.get_resource(&"Sponsors"))
	_sponsors_label.text = "Sponsors: %d" % sponsors
	for i in _ROWS.size():
		var role: StringName = _ROWS[i]["role"]
		var count: int = StaffSystem.get_staff_count(role)
		var multiplier: float = StaffSystem.staff_multiplier(role, count)
		_stat_labels[i].text = "Hired: %d   Effect: ×%s" % [count, _fmt(multiplier)]

		var cost: int = StaffSystem.get_next_hire_cost(role)
		var button: Button = _hire_buttons[i]
		var explanation: Label = _explanation_labels[i]
		button.text = "Hire — %d Sponsors" % cost
		if StaffSystem.can_hire(role):
			button.disabled = false
			explanation.visible = false
		else:
			button.disabled = true
			explanation.text = "Need %d more Sponsors" % (cost - sponsors)
			explanation.visible = true


## 1.0 -> "1", 1.75 -> "1.75", 2.07 -> "2.07" (trailing zeros trimmed).
func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return ("%.2f" % snappedf(value, 0.01)).rstrip("0").rstrip(".")
