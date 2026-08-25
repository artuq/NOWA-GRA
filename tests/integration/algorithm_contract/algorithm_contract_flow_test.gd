extends GdUnitTestSuite

const PANEL_SCENE: String = "res://scenes/action_screen/away_plan_panel.tscn"
const REPORT_SCENE: String = "res://scenes/offline_report/offline_report.tscn"

var _resources_before: Dictionary = {}
var _algorithm_before: Dictionary = {}


func before_test() -> void:
	_resources_before = ResourceManager.serialize_state()
	_algorithm_before = AlgorithmContractSystem.serialize_state()
	AlgorithmContractSystem.reset_for_new_game()


func after_test() -> void:
	ResourceManager.restore_state(_resources_before)
	AlgorithmContractSystem.restore_state(_algorithm_before)
	OfflineProgressSystem.last_simulation_result.clear()
	for child: Node in SaveSystem.get_children():
		if child is Timer:
			(child as Timer).stop()


func test_away_plan_panel_arms_selected_versioned_contract() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PANEL_SCENE)
	var panel: Control = runner.scene()
	panel.visible = true
	panel._select(&"business")
	panel._confirm_selection()
	assert_that(AlgorithmContractSystem.get_armed_contract_id()).is_equal(&"business")
	assert_int(int(AlgorithmContractSystem.armed_contract["revision"])).is_equal(1)
	assert_float(AlgorithmContractSystem.armed_contract["terms"]["sponsors_per_hour"]).is_equal_approx(1.5, 0.001)


func test_boot_routes_qualifying_contract_to_staged_report_without_mutation() -> void:
	var contract: Dictionary = AlgorithmContractSystem.get_contract_definition(&"detox")
	var controller: BootController = BootController.new()
	controller.scene_changes_enabled = false
	var routes: Array[String] = []
	controller.route_requested.connect(func(path: String) -> void: routes.append(path))
	controller.boot_with({
		"resources": {"Reach": 500.0, "Cringe": 50.0, "Haters": 20.0, "Morale": 50.0, "Sponsors": 4.0},
		"algorithm_contract": {"armed_contract": contract, "business_remainder_units": 250, "contract_credits": 0, "stored_rung": 1},
	}, 3600)
	assert_array(routes).contains_exactly([BootController.OFFLINE_REPORT_SCENE])
	assert_int(AlgorithmContractSystem.state).is_equal(AlgorithmContractSystem.State.RETURN_PENDING)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(500.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Haters")).is_equal_approx(20.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(50.0, 0.001)
	assert_int(AlgorithmContractSystem.contract_credits).is_equal(0)
	controller.free()


func test_contract_report_blocks_background_and_shows_comparison() -> void:
	assert_bool(AlgorithmContractSystem.arm_contract(&"drama")).is_true()
	var context: Dictionary = OfflineProgressSystem.capture_context()
	var staged: Dictionary = AlgorithmContractSystem.stage_return(3600, context)
	OfflineProgressSystem.last_simulation_result = staged
	OfflineProgressSystem.last_simulation_result["final_H"] = staged["chosen"]["final_H"]
	OfflineProgressSystem.last_simulation_result["final_M"] = staged["chosen"]["final_M"]
	OfflineProgressSystem.last_simulation_result["total_Z_gained"] = staged["chosen"]["total_Z_gained"]
	OfflineProgressSystem.last_simulation_result["h0"] = context["Haters"]
	OfflineProgressSystem.last_simulation_result["m0"] = context["Morale"]
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var report: Button = runner.scene()
	var swaps: Array[String] = []
	report.scene_swap_requested.connect(func(path: String) -> void: swaps.append(path))
	report.emit_signal("pressed")
	assert_array(swaps).is_empty()
	assert_bool((report.find_child("ContractLabel") as Label).visible).is_true()
	assert_str((report.find_child("AttributionLabel") as Label).text).contains("+4")
	assert_str((report.find_child("ContinueButton") as Button).text).is_equal(tr("ALGORITHM_REPORT_CONFIRM"))


func test_new_controls_meet_44_pixel_touch_target_minimum() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PANEL_SCENE)
	var panel: Control = runner.scene()
	for name: String in ["CloseButton", "NeutralChoice", "DramaChoice", "BusinessChoice", "DetoxChoice", "ConfirmButton"]:
		var button: Button = panel.find_child(name, true, false) as Button
		assert_float(button.size.y).is_greater_equal(44.0)


func test_polish_copy_wraps_inside_720_pixel_panel_without_horizontal_overflow() -> void:
	var previous_locale: String = TranslationServer.get_locale()
	TranslationServer.set_locale("pl")
	var runner: GdUnitSceneRunner = scene_runner(PANEL_SCENE)
	var panel: Control = runner.scene()
	panel.visible = true
	var layout: Control = panel.find_child("Layout", true, false) as Control
	assert_float(layout.position.x).is_greater_equal(0.0)
	assert_float(layout.position.x + layout.size.x).is_less_equal(panel.size.x + 0.01)
	for name: String in ["NeutralChoice", "DramaChoice", "BusinessChoice", "DetoxChoice"]:
		var button: Button = panel.find_child(name, true, false) as Button
		var label: Label = button.get_child(0) as Label
		assert_float(button.position.x + button.size.x).is_less_equal(panel.size.x + 0.01)
		assert_float(label.size.x).is_less_equal(button.size.x)
	TranslationServer.set_locale(previous_locale)
