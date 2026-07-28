## Tests for StaffPanel (design/gdd/team-staff-management.md UI Requirements):
## all three rows always visible, live counts/effects/costs, and the
## affordability gate rendering a DISABLED-but-visible Hire button with an
## explanation (States table) rather than hiding the control.
extends GdUnitTestSuite

const PANEL_SCENE: String = "res://scenes/action_screen/staff_panel.tscn"

var _sponsors_before: float


func before_test() -> void:
	SaveSystem._debounce_timer.stop()
	_sponsors_before = ResourceManager.get_resource(&"Sponsors")
	StaffSystem.reset_era_state()


func after_test() -> void:
	StaffSystem.reset_era_state()
	ResourceManager.apply_delta({&"Sponsors": _sponsors_before - ResourceManager.get_resource(&"Sponsors")})
	SaveSystem._debounce_timer.stop()


func _set_sponsors(value: float) -> void:
	ResourceManager.apply_delta({&"Sponsors": value - ResourceManager.get_resource(&"Sponsors")})


func _open(runner: GdUnitSceneRunner) -> Control:
	var s: Control = runner.scene()
	s.visible = true
	return s


## AC: all three rows render with their role name and the next hire's exact
## cost, at zero hires — nothing hidden, nothing gated away.
func test_all_rows_visible_with_costs_at_zero_hires() -> void:
	_set_sponsors(0.0)
	var s: Control = _open(scene_runner(PANEL_SCENE))
	assert_str((s.find_child("Row1NameLabel", true, false) as Label).text).is_equal("Trolls")
	assert_str((s.find_child("Row2NameLabel", true, false) as Label).text).is_equal("Assistants")
	assert_str((s.find_child("Row3NameLabel", true, false) as Label).text).is_equal("Sponsor Managers")
	assert_str((s.find_child("Row1HireButton", true, false) as Button).text).contains("4 Sponsors")
	assert_str((s.find_child("Row2HireButton", true, false) as Button).text).contains("5 Sponsors")
	assert_str((s.find_child("Row3HireButton", true, false) as Button).text).contains("6 Sponsors")
	for i in [1, 2, 3]:
		assert_str((s.find_child("Row%dStatLabel" % i, true, false) as Label).text).contains("Hired: 0")


## AC (States table): unaffordable = disabled BUT VISIBLE button plus an
## explanatory line; affordable = enabled, no explanation.
func test_affordability_gate_disables_without_hiding() -> void:
	_set_sponsors(0.0)
	var s: Control = _open(scene_runner(PANEL_SCENE))
	var button: Button = s.find_child("Row1HireButton", true, false)
	var explanation: Label = s.find_child("Row1ExplanationLabel", true, false)
	assert_bool(button.visible).is_true()
	assert_bool(button.disabled).is_true()
	assert_bool(explanation.visible).is_true()
	assert_str(explanation.text).contains("4 more Sponsors")

	_set_sponsors(10.0)
	assert_bool(button.disabled).is_false()
	assert_bool(explanation.visible).is_false()


## AC: hiring through the panel spends Sponsors, bumps the count, and
## re-renders the escalated next cost and the new effect multiplier.
func test_hire_updates_count_effect_and_next_cost() -> void:
	_set_sponsors(50.0)
	var s: Control = _open(scene_runner(PANEL_SCENE))

	s._on_hire_pressed(0)  # Trolls

	assert_int(StaffSystem.get_staff_count(&"troll")).is_equal(1)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(46.0, 0.0001)
	var stat: Label = s.find_child("Row1StatLabel", true, false)
	assert_str(stat.text).contains("Hired: 1")
	assert_str(stat.text).contains("1.3")  # F1 troll n=1
	assert_str((s.find_child("Row1HireButton", true, false) as Button).text).contains("7 Sponsors")


## AC: the panel requests closing rather than hiding itself (ADR-0014's
## day-one contract for every new panel).
func test_close_button_emits_close_requested() -> void:
	var s: Control = _open(scene_runner(PANEL_SCENE))
	var emitted: Array[bool] = []
	s.close_requested.connect(func() -> void: emitted.append(true))

	(s.find_child("CloseButton", true, false) as Button).pressed.emit()

	assert_array(emitted).has_size(1)
	assert_bool(s.visible).is_true()  # visibility stays the coordinator's job
