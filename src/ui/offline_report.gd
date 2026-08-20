## OfflineReportScreen is the standalone full-screen scene shown once at cold
## start when the player has been away >= MIN_REPORT_THRESHOLD_SECONDS — the
## "what did I miss?" reward moment (Pillar 4). It reads the offline simulation
## result from OfflineProgressSystem.last_simulation_result (populated by
## BootController, ADR-0003/0009), renders a hero Reach number + secondary stats
## in a dry, factual, no-judgment tone, and dismisses (tap anywhere OR the
## "Continue!" button) via a scene swap to the main scene.
##
## Not a modal (contrast Card UI / ADR-0008): at boot there is no gameplay scene
## beneath to preserve, so a full scene swap is the lifecycle (ADR-0009). The
## root is a full-rect Button — tap-anywhere dismiss — with the report content as
## its children and an explicit "Continue!" Button affordance.
##
## No _process(): the screen is static and fully event-driven.
class_name OfflineReportScreen
extends Button

## Emitted right before the scene swap, carrying the target path -- a test seam
## so tests can count real dismiss side effects instead of only inspecting the
## _dismissing guard bool (code-review finding, 2026-06-29).
signal scene_swap_requested(path: String)

## Scene swapped to on dismiss. A var (not a const) so tests can point it at a
## harmless existing scene; production keeps the default (built by Story 003).
var main_scene_path: String = "res://scenes/main/main.tscn"

## Latches on the first dismiss so rapid multi-taps (button + background, mixed)
## fire the scene swap exactly once (GDD multi-tap edge case). A pure UI concern,
## so it lives on the screen, not on any Autoload.
var _dismissing: bool = false

@onready var _headline_label: Label = %HeadlineLabel
@onready var _hero_number_label: Label = %HeroNumberLabel
@onready var _hero_sub_label: Label = %HeroSubLabel
@onready var _haters_label: Label = %HatersLabel
@onready var _morale_label: Label = %MoraleLabel
@onready var _duration_label: Label = %DurationLabel
@onready var _capped_label: Label = %CappedLabel
@onready var _continue_button: Button = %ContinueButton
@onready var _contract_label: Label = %ContractLabel
@onready var _total_label: Label = %TotalLabel
@onready var _attribution_label: Label = %AttributionLabel
@onready var _empire_label: Label = %EmpireLabel
@onready var _save_status: Label = %SaveStatusLabel
@onready var _post_actions: VBoxContainer = %PostActions
@onready var _repeat_button: Button = %RepeatButton
@onready var _choose_button: Button = %ChooseButton
@onready var _neutral_button: Button = %NeutralButton
var _is_contract_report: bool = false
var _commit_started: bool = false

func _ready() -> void:
	for control: Control in [
		_headline_label,
		_hero_sub_label,
		_haters_label,
		_morale_label,
		_duration_label,
		_capped_label,
		_continue_button,
		_contract_label,
		_total_label,
		_attribution_label,
		_empire_label,
		_save_status,
		_repeat_button,
		_choose_button,
		_neutral_button,
	]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_render(OfflineProgressSystem.last_simulation_result)
	SettingsSystem.language_changed.connect(_on_language_changed)
	# Tap anywhere (root Button) OR the explicit affordance both dismiss once.
	# Preserve the original neutral report's direct dismiss wiring. _dismiss()
	# itself refuses contract reports, while the second handler owns Confirm.
	pressed.connect(_dismiss)
	_continue_button.pressed.connect(_dismiss)
	_continue_button.pressed.connect(_on_primary_pressed)
	_repeat_button.pressed.connect(_repeat_contract)
	_choose_button.pressed.connect(_choose_another)
	_neutral_button.pressed.connect(_continue_neutral)


## Fills the report from the transient simulation payload. Missing keys fall back
## to safe neutral values (e.g. no baseline -> zero delta) so the screen never
## errors — BootController is the contract owner for the full payload.
func _render(r: Dictionary) -> void:
	_is_contract_report = bool(r.get("contract_return", false))
	# Set scene-literal copy explicitly so an already-open report refreshes
	# immediately on a runtime locale change (not only on scene instantiation).
	_headline_label.text = tr("UI_OFFLINE_HEADLINE")
	_hero_sub_label.text = tr("UI_OFFLINE_REACH_EARNED")
	_capped_label.text = tr("UI_OFFLINE_CAP_NOTE")
	_continue_button.text = tr("UI_OFFLINE_CONTINUE")
	if _is_contract_report:
		_render_contract(r)
	else:
		_contract_label.visible = false
		_total_label.visible = false
		_attribution_label.visible = false
		_empire_label.visible = false

	var total_z: float = r.get("total_Z_gained", 0.0)
	_hero_number_label.text = "+%s" % ActionUIFormatting.format_number(total_z)

	# ΔHatersi: final_H - h0, shown signed and never hidden (GDD: "+0" if equal).
	var final_h: float = r.get("final_H", 0.0)
	var h0: float = r.get("h0", final_h)
	_haters_label.text = tr("OFFLINE_HATERS_DELTA") % int(roundf(final_h - h0))

	# Morale: current band, with a "(was X)" indicator only if the band shifted.
	var final_m: float = r.get("final_M", 0.0)
	var m0: float = r.get("m0", final_m)
	var current_band: String = ResourceFormulas.morale_band_label(final_m)
	var initial_band: String = ResourceFormulas.morale_band_label(m0)
	if current_band != initial_band:
		_morale_label.text = tr("OFFLINE_MORALE_CHANGED") % [
			_localized_morale_band(current_band),
			_localized_morale_band(initial_band),
		]
	else:
		_morale_label.text = tr("OFFLINE_MORALE") % _localized_morale_band(current_band)

	var elapsed: int = int(r.get("elapsed_seconds", 0))
	_duration_label.text = tr("OFFLINE_AWAY_DURATION") % OfflineReportFormatting.format_duration(elapsed)
	if _is_contract_report:
		_duration_label.text = tr("ALGORITHM_REPORT_DURATION") % [
			OfflineReportFormatting.format_duration(elapsed),
			OfflineReportFormatting.format_duration(int(r.get("counted_seconds", elapsed))),
		]

	# Capped message only when the break exceeded the 24h cap.
	_capped_label.visible = bool(r.get("capped", false))
	if _is_contract_report and not _commit_started:
		_continue_button.text = tr("ALGORITHM_REPORT_CONFIRM")


func _render_contract(r: Dictionary) -> void:
	var contract: Dictionary = r.get("contract", {})
	var chosen: Dictionary = r.get("chosen", {}).get("final", {})
	var deltas: Dictionary = r.get("resource_deltas", {})
	var attribution: Dictionary = r.get("attribution", {})
	_contract_label.visible = true
	_total_label.visible = true
	_attribution_label.visible = true
	_empire_label.visible = true
	_contract_label.text = tr("ALGORITHM_REPORT_CONTRACT") % tr(String(contract.get("name_key", "")))
	_total_label.text = tr("ALGORITHM_REPORT_TOTAL") % [
		_signed(float(deltas.get("Reach", 0.0))),
		_signed(float(deltas.get("Haters", 0.0))),
		_signed(float(deltas.get("Morale", 0.0))),
		_signed(float(deltas.get("Sponsors", 0.0))),
	]
	_attribution_label.text = tr("ALGORITHM_REPORT_ATTRIBUTION") % [
		_signed(float(attribution.get("Reach", 0.0))),
		_signed(float(attribution.get("Haters", 0.0))),
		_signed(float(attribution.get("Morale", 0.0))),
		_signed(float(attribution.get("Sponsors", 0.0))),
	]
	_empire_label.text = tr("ALGORITHM_REPORT_EMPIRE") % [
		int(r.get("credits_before", 0)), int(r.get("credits_after", 0)),
		int(r.get("rung_before", 1)), int(r.get("rung_after", 1)),
	]
	var crossed: Array = r.get("crossed_title_keys", [])
	if not crossed.is_empty():
		var names: PackedStringArray = []
		for title_key: Variant in crossed:
			names.append(tr(String(title_key)))
		_empire_label.text += "\n" + tr("ALGORITHM_REPORT_TITLES") % ", ".join(names)
	if StringName(contract.get("id", "")) == &"business":
		_empire_label.text += "\n" + tr("ALGORITHM_REPORT_CARRY") % int(r.get("business_remainder_after", 0))


func _signed(value: float) -> String:
	var rounded: int = int(roundf(value))
	return "%+d" % rounded


func _localized_morale_band(band: String) -> String:
	return tr("MORALE_%s" % band.to_upper())


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_render(OfflineProgressSystem.last_simulation_result)


## Single-fire dismiss → swap to the main gameplay scene. The latch makes every
## tap after the first a no-op for the rest of this screen's life.
func _dismiss() -> void:
	if _is_contract_report or _dismissing:
		return
	_dismissing = true
	scene_swap_requested.emit(main_scene_path)
	get_tree().change_scene_to_file(main_scene_path)


func _on_background_pressed() -> void:
	if not _is_contract_report:
		_dismiss()


func _on_primary_pressed() -> void:
	if not _is_contract_report:
		_dismiss()
		return
	if _commit_started and AlgorithmContractSystem.state != AlgorithmContractSystem.State.COMMITTING:
		return
	_commit_started = true
	_continue_button.disabled = true
	_save_status.visible = true
	_save_status.text = tr("ALGORITHM_REPORT_SAVING")
	var saved: bool = AlgorithmContractSystem.commit_staged_return()
	if saved:
		_save_status.text = tr("ALGORITHM_REPORT_SAVED")
		_continue_button.visible = false
		_post_actions.visible = true
		var last: Dictionary = AlgorithmContractSystem.last_contract
		_repeat_button.text = tr("ALGORITHM_REPORT_REPEAT") % tr(String(last.get("name_key", "")))
		_choose_button.text = tr("ALGORITHM_REPORT_CHOOSE")
		_neutral_button.text = tr("ALGORITHM_REPORT_NEUTRAL")
		_repeat_button.grab_focus()
	else:
		_save_status.text = tr("ALGORITHM_REPORT_SAVE_FAILED")
		_continue_button.text = tr("ALGORITHM_REPORT_RETRY")
		_continue_button.disabled = false
		_continue_button.grab_focus()


func _repeat_contract() -> void:
	AlgorithmContractSystem.repeat_last_contract()
	_leave_contract_report()


func _choose_another() -> void:
	AlgorithmContractSystem.open_away_plan_on_main = true
	_leave_contract_report()


func _continue_neutral() -> void:
	_leave_contract_report()


func _leave_contract_report() -> void:
	if _dismissing:
		return
	_dismissing = true
	scene_swap_requested.emit(main_scene_path)
	get_tree().change_scene_to_file(main_scene_path)
