extends Control

signal close_requested

const IDS: Array[StringName] = [&"", &"drama", &"business", &"detox"]

@onready var _close_button: Button = %CloseButton
@onready var _intro: Label = %IntroLabel
@onready var _choices: Array[Button] = [%NeutralChoice, %DramaChoice, %BusinessChoice, %DetoxChoice]
@onready var _choice_labels: Array[Label] = [%NeutralChoiceLabel, %DramaChoiceLabel, %BusinessChoiceLabel, %DetoxChoiceLabel]
@onready var _confirm: Button = %ConfirmButton
@onready var _preview: Label = %PreviewLabel
var _selected: StringName = &""


func _ready() -> void:
	visible = false
	for control: Control in [_intro, _confirm, _preview] + _choices + _choice_labels:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	for i: int in IDS.size():
		_choices[i].pressed.connect(_select.bind(IDS[i]))
	_confirm.pressed.connect(_confirm_selection)
	visibility_changed.connect(_on_visibility_changed)
	SettingsSystem.language_changed.connect(func(_pref: StringName, _locale: StringName) -> void:
		if visible: _refresh()
	)


func _on_visibility_changed() -> void:
	if not visible:
		return
	_selected = AlgorithmContractSystem.get_armed_contract_id()
	_refresh()
	_choices[IDS.find(_selected)].grab_focus()


func _select(contract_id: StringName) -> void:
	_selected = contract_id
	_refresh()


func _confirm_selection() -> void:
	if _selected == &"":
		if AlgorithmContractSystem.state == AlgorithmContractSystem.State.ARMED:
			AlgorithmContractSystem.cancel_contract()
	else:
		AlgorithmContractSystem.arm_contract(_selected)
	close_requested.emit()


func _refresh() -> void:
	_intro.text = tr("ALGORITHM_PLAN_INTRO")
	_choice_labels[0].text = _row_text("ALGORITHM_PLAN_NEUTRAL_NAME", "ALGORITHM_PLAN_NEUTRAL_DESC", _selected == &"")
	for i: int in range(1, IDS.size()):
		var definition: Dictionary = AlgorithmContractSystem.get_contract_definition(IDS[i])
		_choice_labels[i].text = _row_text(String(definition["name_key"]), String(definition["description_key"]), _selected == IDS[i])
		_choices[i].button_pressed = _selected == IDS[i]
	_choices[0].button_pressed = _selected == &""
	var previous: StringName = AlgorithmContractSystem.get_armed_contract_id()
	if _selected == &"":
		_confirm.text = tr("ALGORITHM_PLAN_CONTINUE_NEUTRAL") if previous == &"" else tr("ALGORITHM_PLAN_CANCEL")
	else:
		_confirm.text = tr("ALGORITHM_PLAN_ARM") if previous == &"" else tr("ALGORITHM_PLAN_REPLACE")
	_refresh_preview()


func _refresh_preview() -> void:
	var context: Dictionary = OfflineProgressSystem.capture_context()
	var neutral: Dictionary = OfflineProgressSystem.simulate_from_context(context, 3600)
	var chosen: Dictionary = neutral
	if _selected != &"":
		chosen = OfflineProgressSystem.simulate_contract_from_context(
			context, 3600, AlgorithmContractSystem.get_contract_definition(_selected),
			AlgorithmContractSystem.business_remainder_units
		)
	var final: Dictionary = chosen.get("final", context)
	var neutral_final: Dictionary = neutral.get("final", context)
	_preview.text = tr("ALGORITHM_PLAN_PREVIEW") % [
		_signed(float(final.get("Reach", context["Reach"])) - float(context["Reach"])),
		_signed(float(final.get("Haters", context["Haters"])) - float(context["Haters"])),
		_signed(float(final.get("Morale", context["Morale"])) - float(context["Morale"])),
		_signed(float(final.get("Sponsors", context["Sponsors"])) - float(context["Sponsors"])),
		_signed(float(final.get("Reach", 0.0)) - float(neutral_final.get("Reach", 0.0))),
	]


func _signed(value: float) -> String:
	return "%+d" % int(roundf(value))


func _row_text(name_key: String, desc_key: String, selected: bool) -> String:
	return "%s %s\n%s" % ["✓" if selected else "○", tr(name_key), tr(desc_key)]
