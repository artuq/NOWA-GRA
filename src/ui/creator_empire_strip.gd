extends PanelContainer

signal away_plan_requested

@onready var _title: Label = %EmpireTitle
@onready var _progress: Label = %EmpireProgress
@onready var _plan: Label = %AwayPlanStatus
@onready var _set_button: Button = %SetPlanButton
@onready var _cancel_button: Button = %CancelPlanButton


func _ready() -> void:
	for control: Control in [_title, _progress, _plan, _set_button, _cancel_button]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_set_button.pressed.connect(func() -> void: away_plan_requested.emit())
	_cancel_button.pressed.connect(func() -> void:
		AlgorithmContractSystem.cancel_contract()
		_refresh()
	)
	AlgorithmContractSystem.contract_changed.connect(func(_id: StringName) -> void: _refresh())
	AlgorithmContractSystem.ladder_changed.connect(func(_old: int, _new: int) -> void: _refresh())
	SettingsSystem.language_changed.connect(func(_pref: StringName, _locale: StringName) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var status: Dictionary = AlgorithmContractSystem.get_ladder_status()
	var current: Dictionary = status.get("current", {})
	_title.text = tr("ALGORITHM_EMPIRE_CURRENT") % [int(status.get("rung", 1)), tr(String(current.get("title_key", "CREATOR_EMPIRE_RUNG_1")))]
	var next: Dictionary = status.get("next", {})
	if next.is_empty():
		_progress.text = tr("ALGORITHM_EMPIRE_COMPLETE")
	else:
		_progress.text = tr("ALGORITHM_EMPIRE_NEXT") % [
			tr(String(next["title_key"])),
			int(status["eras"]), int(next["eras"]),
			int(status["mastery"]), int(next["mastery"]),
			int(status["contracts"]), int(next["contracts"]),
		]
	var contract_id: StringName = AlgorithmContractSystem.get_armed_contract_id()
	var armed: bool = contract_id != &""
	_plan.text = tr("ALGORITHM_PLAN_ACTIVE") % _contract_name(contract_id) if armed else tr("ALGORITHM_PLAN_NEUTRAL")
	_set_button.text = tr("ALGORITHM_PLAN_CHANGE") if armed else tr("ALGORITHM_PLAN_SET")
	_cancel_button.text = tr("ALGORITHM_PLAN_CANCEL")
	_cancel_button.visible = armed


func _contract_name(contract_id: StringName) -> String:
	var definition: Dictionary = AlgorithmContractSystem.get_contract_definition(contract_id)
	return tr(String(definition.get("name_key", "ALGORITHM_PLAN_NEUTRAL_NAME")))
