## Legibility tests for ClassPathPanel's per-tier bonus lines (Pillar 1 fix,
## playtest 12-3 — "Tier N active" now renders the actual numbers). Same
## real-Autoload seeding + snapshot/restore convention as
## class_path_panel_interaction_test.gd.
extends GdUnitTestSuite

const PANEL_SCENE: String = "res://scenes/action_screen/class_path_panel.tscn"

var _cps_snapshot: Dictionary = {}


func before_test() -> void:
	_cps_snapshot = ClassPathSystem.serialize_state()


func after_test() -> void:
	ClassPathSystem.reset_era_state()
	ClassPathSystem.restore_state(_cps_snapshot)
	SaveSystem._debounce_timer.stop()


func _seed_tier(path_id: StringName, tier: int, active: bool) -> void:
	ClassPathSystem._current_tier[path_id] = tier
	ClassPathSystem._affiliation[path_id] = ClassPathSystem.TIER_THRESHOLDS[tier] if tier > 0 else 0.0
	if active:
		ClassPathSystem._active_path = path_id


func _bonus_label(runner: GdUnitSceneRunner, row: int) -> Label:
	var s: Control = runner.scene()
	s.visible = true  # triggers _refresh_all via visibility_changed
	return s.find_child("Row%dBonusLabel" % row, true, false) as Label


## AC: unlocked tiers render with concrete values, next tier teased.
## pato (row 1) at T2: both mult lines + the T3 interlock teaser.
func test_unlocked_tiers_show_numbers_and_teaser() -> void:
	_seed_tier(&"pato_streamer", 2, true)
	var runner: GdUnitSceneRunner = scene_runner(PANEL_SCENE)
	var label: Label = _bonus_label(runner, 1)
	assert_bool(label.visible).is_true()
	assert_str(label.text).contains("T1: Make Drama Reach ×1.3")
	assert_str(label.text).contains("T2: Make Drama Reach ×1.6")
	assert_str(label.text).contains("Next T3: Make Drama also +1 Sponsors")


## AC: a Tier-0 path still teases T1 (ladder visible before first threshold).
func test_tier_zero_path_teases_t1() -> void:
	var runner: GdUnitSceneRunner = scene_runner(PANEL_SCENE)
	var label: Label = _bonus_label(runner, 4)  # biznesmen, untouched = T0
	assert_bool(label.visible).is_true()
	assert_str(label.text).contains("Next T1: Record a Collab Reach ×1.2")
	assert_bool(label.text.contains("T0")).is_false()


## AC: T5 rows show the signature effects with values and the signature-card
## marker, no teaser beyond T5.
func test_t5_signature_lines() -> void:
	_seed_tier(&"ekspert_niszowy", 5, true)
	var runner: GdUnitSceneRunner = scene_runner(PANEL_SCENE)
	var label: Label = _bonus_label(runner, 3)
	assert_str(label.text).contains("Haters growth ×0.5")
	assert_str(label.text).contains("Offline Morale floor 40")
	assert_str(label.text).contains("signature card")
	assert_bool(label.text.contains("Next")).is_false()
