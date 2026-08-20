## Focused integration contract for the compact Sponsor Contract HUD strip.
## The view is a non-interactive, signal-driven projection of
## SponsorContractSystem snapshots and owns no progression state.
extends GdUnitTestSuite

const INDICATOR_SCENE: String = "res://scenes/action_screen/sponsor_contract_indicator.tscn"

var _locale_snapshot: String


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)


func _indicator() -> Control:
	var runner: GdUnitSceneRunner = scene_runner(INDICATOR_SCENE)
	return runner.scene() as Control


func _campaign_snapshot() -> Dictionary:
	return {
		"state": "campaign",
		"active": true,
		"actions_completed": 1,
		"actions_required": 3,
		"due_card_id": "",
		"stage_number": 2,
		"stage_total": 3,
	}


func test_inactive_snapshot_hides_indicator() -> void:
	var indicator: Control = _indicator()
	indicator._on_contract_changed({"state": "not_started", "active": false})

	assert_bool(indicator.visible).is_false()


func test_campaign_snapshot_shows_stage_copy_and_exact_progress() -> void:
	var indicator: Control = _indicator()
	SponsorContractSystem.contract_changed.emit(_campaign_snapshot())
	var title: Label = indicator.find_child("ContractTitleStageLabel", true, false) as Label
	var status: Label = indicator.find_child("ContractStatusLabel", true, false) as Label
	var progress: ProgressBar = indicator.find_child("ContractProgressBar", true, false) as ProgressBar

	assert_bool(indicator.visible).is_true()
	assert_str(title.text).is_equal("SPONSOR CONTRACT • STAGE 2/3")
	assert_str(status.text).is_equal("Campaign actions: 1 / 3")
	assert_bool(progress.visible).is_true()
	assert_float(progress.max_value).is_equal(3.0)
	assert_float(progress.value).is_equal(1.0)
	assert_bool(indicator.is_processing()).is_false()


func test_due_snapshot_replaces_progress_with_next_card_message() -> void:
	var indicator: Control = _indicator()
	indicator._on_contract_changed({
		"state": "fallout_due",
		"active": true,
		"actions_completed": 3,
		"actions_required": 3,
		"due_card_id": "sponsor_contract_mega_fallout",
		"stage_number": 2,
		"stage_total": 3,
	})
	var status: Label = indicator.find_child("ContractStatusLabel", true, false) as Label
	var progress: ProgressBar = indicator.find_child("ContractProgressBar", true, false) as ProgressBar

	assert_str(status.text).is_equal("Decision ready — next card")
	assert_bool(progress.visible).is_false()


func test_runtime_polish_switch_rebuilds_visible_copy() -> void:
	var runner: GdUnitSceneRunner = scene_runner(INDICATOR_SCENE)
	var indicator: Control = runner.scene() as Control
	indicator._on_contract_changed(_campaign_snapshot())

	TranslationServer.set_locale("pl_PL")
	runner.invoke("_on_language_changed", &"pl", &"pl_PL")

	assert_str(
		(indicator.find_child("ContractTitleStageLabel", true, false) as Label).text
	).is_equal("KONTRAKT SPONSORSKI • ETAP 2/3")
	assert_str(
		(indicator.find_child("ContractStatusLabel", true, false) as Label).text
	).is_equal("Akcje kampanii: 1 / 3")


func test_entire_indicator_tree_ignores_pointer_input() -> void:
	var indicator: Control = _indicator()
	var pending: Array[Node] = [indicator]

	while not pending.is_empty():
		var current: Node = pending.pop_back()
		if current is Control:
			assert_int((current as Control).mouse_filter).override_failure_message(
				"%s may intercept ActionScreen taps" % current.get_path()
			).is_equal(Control.MOUSE_FILTER_IGNORE)
		pending.append_array(current.get_children())


func test_action_screen_places_indicator_between_burnout_warning_and_spacer() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_screen.tscn")
	var root: Node = runner.scene()
	var layout: VBoxContainer = root.get_node("MainLayout") as VBoxContainer
	var burnout: Control = layout.get_node("BurnoutWarningIndicator") as Control
	var indicator: Control = layout.get_node("SponsorContractIndicator") as Control
	var spacer: Control = layout.get_node("MiddleSpacer") as Control

	assert_object(indicator).is_not_null()
	assert_int(indicator.get_index()).is_equal(burnout.get_index() + 1)
	assert_int(spacer.get_index()).is_equal(indicator.get_index() + 1)
	assert_float(indicator.custom_minimum_size.y).is_less_equal(72.0)
