## Tests for BonusesPanel (design/ux/meta-bonus-visibility.md): humanized
## values per type, empty state (all rows visible at zero), MAX marker,
## era count, and the fresh-grant diff. PrestigeSystem's persisted state is
## snapshotted/restored around every test.
extends GdUnitTestSuite

const PANEL_SCENE: String = "res://scenes/action_screen/bonuses_panel.tscn"

var _prestige_snapshot: Dictionary = {}


func before_test() -> void:
	_prestige_snapshot = PrestigeSystem.serialize_state()
	PrestigeSystem.meta_bonus_totals.clear()
	PrestigeSystem.era_count = 0


func after_test() -> void:
	PrestigeSystem.meta_bonus_totals.clear()
	PrestigeSystem.restore_state(_prestige_snapshot)
	SaveSystem._debounce_timer.stop()


func _open(runner: GdUnitSceneRunner) -> Control:
	var s: Control = runner.scene()
	s.visible = true
	return s


## AC: empty state — 0 eras, all four rows visible with zero values, no MAX.
func test_empty_state_shows_all_rows_at_zero() -> void:
	var s: Control = _open(scene_runner(PANEL_SCENE))
	assert_str((s.find_child("EraCountLabel", true, false) as Label).text).is_equal("Eras completed: 0")
	for i in [1, 2, 3]:
		assert_str((s.find_child("Row%dValueLabel" % i, true, false) as Label).text).is_equal("+0%")
	assert_str((s.find_child("Row4ValueLabel", true, false) as Label).text).is_equal("+0")
	for i in [1, 2, 3, 4]:
		assert_bool((s.find_child("Row%dMaxLabel" % i, true, false) as Label).visible).is_false()
		assert_bool((s.find_child("Row%d" % i, true, false) as Control).visible).is_true()


## AC: values humanized per type — percent for the 3 multipliers, flat for
## the Sponsor floor; progress bars track total/cap.
func test_values_formatted_per_type() -> void:
	PrestigeSystem.meta_bonus_totals[&"META_REACH_MULT"] = 0.107
	PrestigeSystem.meta_bonus_totals[&"META_SPONSOR_FLOOR"] = 3.0
	PrestigeSystem.era_count = 3
	var s: Control = _open(scene_runner(PANEL_SCENE))
	assert_str((s.find_child("EraCountLabel", true, false) as Label).text).is_equal("Eras completed: 3")
	assert_str((s.find_child("Row1ValueLabel", true, false) as Label).text).is_equal("+10.7%")
	assert_str((s.find_child("Row4ValueLabel", true, false) as Label).text).is_equal("+3")
	var bar: ProgressBar = s.find_child("Row1ProgressBar", true, false)
	assert_float(bar.max_value).is_equal_approx(PrestigeFormulas.META_BONUS_MAX[&"META_REACH_MULT"], 0.0001)
	assert_float(bar.value).is_equal_approx(0.107, 0.0001)


## AC: capped type shows the textual MAX marker (never color-only).
func test_capped_type_shows_max_marker() -> void:
	PrestigeSystem.meta_bonus_totals[&"META_REACH_MULT"] = PrestigeFormulas.META_BONUS_MAX[&"META_REACH_MULT"]
	var s: Control = _open(scene_runner(PANEL_SCENE))
	assert_bool((s.find_child("Row1MaxLabel", true, false) as Label).visible).is_true()
	assert_bool((s.find_child("Row2MaxLabel", true, false) as Label).visible).is_false()


## AC: fresh-grant diff — a type granted since the panel was last closed is
## flagged (and pulses on open); unchanged types are not.
func test_fresh_grant_diff() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PANEL_SCENE)
	var s: Control = runner.scene()
	# _ready cached zeros. Simulate a grant landing while the panel is closed:
	PrestigeSystem.meta_bonus_totals[&"META_SPONSOR_MULT"] = 0.025
	var fresh: Array[StringName] = s._compute_fresh_types()
	assert_array(fresh).contains_exactly([&"META_SPONSOR_MULT"])
	# Opening pulses exactly the fresh row (opacity-only, self_modulate > 1).
	s.visible = true
	assert_float((s.find_child("Row2", true, false) as Control).self_modulate.a).is_greater(1.0)
	assert_float((s.find_child("Row1", true, false) as Control).self_modulate.a).is_equal_approx(1.0, 0.0001)
	# Closing commits the diff base — reopening pulses nothing.
	s.visible = false
	assert_array(s._compute_fresh_types()).is_empty()
