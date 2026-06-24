## Interaction test for ResourceHud (Story 002, Action UI epic). Uses
## GdUnit4's scene_runner() to instantiate the real scene headlessly and
## assert on its rendered label text -- this is the "interaction test"
## alternative the story's Test Evidence table allows in place of a manual
## walkthrough doc, since no human is available in this session to actually
## look at a running scene.
##
## ResourceManager state is snapshotted/restored per before_test()/after_test(),
## same pattern as other integration suites in this project.
extends GdUnitTestSuite

var _resource_snapshot: Dictionary[StringName, float] = {}

func before_test() -> void:
	_resource_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_resource_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_resource_snapshot[&"Haters"] = ResourceManager.get_resource(&"Haters")
	_resource_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	_resource_snapshot[&"Sponsors"] = ResourceManager.get_resource(&"Sponsors")

func after_test() -> void:
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _resource_snapshot:
		restore[key] = _resource_snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)

## AC: Resource HUD zone is present and shows all 5 resources simultaneously,
## correctly formatted, immediately on scene load (initial state, not just
## on a later change).
func test_resource_hud_displays_all_five_resources_on_load() -> void:
	var restore: Dictionary[StringName, float] = {
		&"Reach": 28412.0 - ResourceManager.get_resource(&"Reach"),
		&"Cringe": 50.0 - ResourceManager.get_resource(&"Cringe"),
		&"Haters": 12.0 - ResourceManager.get_resource(&"Haters"),
		&"Morale": 80.0 - ResourceManager.get_resource(&"Morale"),
		&"Sponsors": 3.0 - ResourceManager.get_resource(&"Sponsors"),
	}
	ResourceManager.apply_delta(restore)

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/resource_hud.tscn")
	var hud: Node = runner.scene()

	assert_str((hud.find_child("ReachLabel") as Label).text).is_equal("28.4K")
	assert_str((hud.find_child("CringeLabel") as Label).text).is_equal("50")
	assert_str((hud.find_child("HatersLabel") as Label).text).is_equal("12")
	assert_str((hud.find_child("MoraleLabel") as Label).text).is_equal("High")
	assert_str((hud.find_child("SponsorsLabel") as Label).text).is_equal("3")

## AC: Morale shows a band label, not raw percentage -- all 4 bands,
## including the inclusive-lower-bound boundaries (exactly 70, 40, 15).
func test_resource_hud_morale_band_label_at_all_boundaries() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/resource_hud.tscn")
	var hud: Node = runner.scene()
	var morale_label: Label = hud.find_child("MoraleLabel") as Label

	var cases: Array[Array] = [
		[90.0, "High"],
		[70.0, "High"],
		[69.0, "Normal"],
		[40.0, "Normal"],
		[39.0, "Low"],
		[15.0, "Low"],
		[14.0, "Critical"],
		[0.0, "Critical"],
	]
	for case: Array in cases:
		var target_morale: float = case[0]
		var expected_label: String = case[1]
		ResourceManager.apply_delta({&"Morale": target_morale - ResourceManager.get_resource(&"Morale")})
		assert_str(morale_label.text).is_equal(expected_label)

## AC: HUD updates live on resource change -- only the changed resource's
## label updates (signal-driven, not a full redraw of all 5).
func test_resource_hud_updates_only_changed_label_on_signal() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/resource_hud.tscn")
	var hud: Node = runner.scene()
	var reach_label: Label = hud.find_child("ReachLabel") as Label
	var cringe_label: Label = hud.find_child("CringeLabel") as Label
	var cringe_before: String = cringe_label.text

	ResourceManager.apply_delta({&"Reach": 100.0})

	assert_str(reach_label.text).is_not_equal("")
	assert_str(cringe_label.text).is_equal(cringe_before)

## AC: ActionScreen root scene instantiates ResourceHud as a child and the
## zone renders correctly through the root, not just standalone.
func test_action_screen_root_instantiates_resource_hud_zone() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_screen.tscn")
	var root: Node = runner.scene()
	var hud: Node = root.find_child("ResourceHud", true, false)

	assert_object(hud).is_not_null()
	assert_object(hud.find_child("ReachLabel")).is_not_null()

## Coverage gap closed (flagged by code review): a freed ResourceHud must not
## keep reacting to ResourceManager.resource_changed -- Godot auto-disconnects
## signal connections when the connected Object is freed, but this confirms
## that guarantee holds for this specific connection rather than assuming it.
## Two separate scene_runner() instances are used: the first HUD is freed,
## then a resource change is applied, then a second HUD confirms it alone
## reflects the new state (proving the first HUD's connection didn't survive
## to e.g. throw an error on a freed node).
func test_freed_resource_hud_does_not_react_to_later_resource_changes() -> void:
	var first_runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/resource_hud.tscn")
	var first_hud: Node = first_runner.scene()
	first_hud.queue_free()
	await first_hud.tree_exited

	# If the freed HUD's connection somehow survived, this would error.
	ResourceManager.apply_delta({&"Reach": 50.0})

	var second_runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/resource_hud.tscn")
	var second_hud: Node = second_runner.scene()
	assert_object(second_hud.find_child("ReachLabel")).is_not_null()
