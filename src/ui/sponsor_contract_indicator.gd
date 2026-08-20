## Compact, display-only Sponsor Contract status for the ActionScreen HUD.
##
## SponsorContractSystem owns the contract state and progression. This view
## performs no polling and never mutates gameplay state: it renders the latest
## snapshot received through contract_changed, plus the restored snapshot on
## scene entry. All pointer input passes through to the action screen below.
class_name SponsorContractIndicator
extends PanelContainer

const _PROGRESS_STATES: Array[StringName] = [&"campaign", &"recovery"]
const _DUE_STATES: Array[StringName] = [&"fallout_due", &"finale_due"]

@onready var _title_stage_label: Label = %ContractTitleStageLabel
@onready var _status_label: Label = %ContractStatusLabel
@onready var _progress_bar: ProgressBar = %ContractProgressBar

var _snapshot: Dictionary = {}


func _ready() -> void:
	_title_stage_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_status_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	SponsorContractSystem.contract_changed.connect(_on_contract_changed)
	SettingsSystem.language_changed.connect(_on_language_changed)
	_on_contract_changed(SponsorContractSystem.get_snapshot())


func _on_contract_changed(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	_refresh()


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_refresh()


func _refresh() -> void:
	var state: StringName = StringName(_snapshot.get("state", ""))
	var is_supported_active_state: bool = state in _PROGRESS_STATES or state in _DUE_STATES
	if not bool(_snapshot.get("active", false)) or not is_supported_active_state:
		hide()
		return

	var stage_number: int = maxi(1, int(_snapshot.get("stage_number", 1)))
	var stage_total: int = maxi(stage_number, int(_snapshot.get("stage_total", stage_number)))
	_title_stage_label.text = tr("SPONSOR_CONTRACT_TITLE_STAGE") % [stage_number, stage_total]

	if state in _DUE_STATES:
		_progress_bar.hide()
		_status_label.text = tr("SPONSOR_CONTRACT_DECISION_READY")
	else:
		var completed: int = maxi(0, int(_snapshot.get("actions_completed", 0)))
		var required: int = maxi(1, int(_snapshot.get("actions_required", 1)))
		completed = mini(completed, required)
		_progress_bar.max_value = required
		_progress_bar.value = completed
		_progress_bar.show()
		var progress_key: StringName = (
			&"SPONSOR_CONTRACT_CAMPAIGN_PROGRESS"
			if state == &"campaign"
			else &"SPONSOR_CONTRACT_RECOVERY_PROGRESS"
		)
		_status_label.text = tr(progress_key) % [completed, required]

	show()
