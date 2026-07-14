## Interaction test for ClassPathPanel (Story class-path-full/005). Uses
## GdUnit4's scene_runner() to instantiate the real scene headlessly and
## assert on its rendered node/label state -- the standing evidence method
## for UI-type stories in this project (docs/tech-debt-register.md,
## 2026-06-24 entry, "Action UI, Story 002"), since no human is available in
## this session to actually look at a running scene. See
## production/qa/evidence/class-path-panel-evidence.md for the accompanying
## honest note that this is scene_runner()-verified structure, not a human
## visual pass.
##
## ClassPathPanel reads/writes the REAL ClassPathSystem Autoload (same as
## class_path_signature_card_test.gd -- DecisionCardSystem-adjacent code
## reads the real singleton by name, and this panel is instanced as a scene
## child rather than a detached script instance), so every test seeds the
## real Autoload directly via its private _card_contribution field + a
## _recalculate_total_affiliation() call (same technique as
## class_path_tiebreak_test.gd's _seed_affiliation / class_path_signature_card_test.gd's
## _seed_singleton_affiliation) and fully restores it in after_test().
extends GdUnitTestSuite

var _cps_snapshot: Dictionary = {}
var _resource_snapshot: Dictionary = {}


func before_test() -> void:
	_cps_snapshot = ClassPathSystem.serialize_state()
	_resource_snapshot = ResourceManager.serialize_state()


func after_test() -> void:
	# Full wipe first -- restore_state() alone would leave any path key this
	# test added (and the snapshot didn't have) stuck at its test value (same
	# precedent as class_path_signature_card_test.gd).
	ClassPathSystem.reset_era_state()
	ClassPathSystem.restore_state(_cps_snapshot)
	ResourceManager.restore_state(_resource_snapshot)
	# ClassPathSystem/ResourceManager writes above mark the real SaveSystem
	# dirty -- stop its debounce timer so a delayed save_now() can't fire
	# mid-suite (same precedent as the other class-path suites).
	SaveSystem._debounce_timer.stop()


## Pushes the REAL ClassPathSystem singleton's card_contribution for
## [param path_id] to [param value] and re-derives the total affiliation.
func _seed_affiliation(path_id: StringName, value: float) -> void:
	ClassPathSystem._card_contribution[path_id] = value
	ClassPathSystem._recalculate_total_affiliation(path_id)


func _seed_resource(resource_id: StringName, value: float) -> void:
	ResourceManager.apply_delta({resource_id: value - ResourceManager.get_resource(resource_id)})


## Forbidden Anti-Pillar words (Core Rule 8) -- case-insensitive. "moral" is
## checked with "morale" stripped first, since the Morale resource's own
## English name legitimately contains "moral" as a substring and must not
## false-positive this check.
const _FORBIDDEN_WORDS: Array[String] = ["dobry", "zly", "zły", "good", "evil", "moral"]


func _assert_no_moral_framing(text: String) -> void:
	var lowered: String = text.to_lower().replace("morale", "")
	for word: String in _FORBIDDEN_WORDS:
		assert_bool(lowered.contains(word)).override_failure_message(
			"UI text '%s' contains forbidden Anti-Pillar word '%s'" % [text, word]
		).is_false()


# --- AC-2: all 4 paths visible simultaneously, none hidden ---

func test_panel_shows_all_four_paths_simultaneously_and_legible() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true  # trigger the visibility_changed resync

	var expected_names: Array[String] = ["Trash Streamer", "Guru Celeb", "Niche Expert", "Content Mogul"]
	var name_labels: Array[Label] = []
	for i in 4:
		var row_num: int = i + 1
		var name_label: Label = panel.find_child("Row%dNameLabel" % row_num) as Label
		var tier_label: Label = panel.find_child("Row%dTierLabel" % row_num) as Label
		var bar: ProgressBar = panel.find_child("Row%dAffiliationBar" % row_num) as ProgressBar
		assert_object(name_label).is_not_null()
		assert_str(name_label.text).is_equal(expected_names[i])
		assert_object(tier_label).is_not_null()
		assert_str(tier_label.text).is_not_equal("")
		assert_object(bar).is_not_null()
		assert_bool(name_label.visible).is_true()
		name_labels.append(name_label)

	# qa-tester suggestion (code review 2026-07-14): confirm co-presence, not
	# just 4 independently-found nodes -- all 4 must be visible AT ONCE in the
	# same panel instance (AC-2's "simultaneously"), not merely each
	# individually reachable in isolation.
	for label in name_labels:
		assert_bool(label.visible).override_failure_message(
			"all 4 path rows must remain visible simultaneously -- found one hidden while checking the others"
		).is_true()


## AC-2 zero-affiliation case: a path with no progress must still be visible
## (Core Rule 1 -- muted, never hidden).
func test_panel_shows_zero_affiliation_path_not_hidden() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true

	var row4: Node = panel.find_child("Row4", true, false)
	assert_object(row4).is_not_null()
	assert_bool((row4 as CanvasItem).visible).is_true()
	var bar: ProgressBar = panel.find_child("Row4AffiliationBar") as ProgressBar
	assert_float(bar.value).is_equal_approx(0.0, 0.001)


# --- AC-1: ambiguous state shows gap text on both tied paths, no active multiplier elsewhere ---

func test_ambiguous_state_shows_gap_on_both_tied_paths() -> void:
	_seed_affiliation(&"pato_streamer", 45.0)   # Tier 2
	_seed_affiliation(&"guru_celebryta", 42.0)  # Tier 2, diff 3.0 < margin(5.0) -> ambiguous
	assert_that(ClassPathSystem.get_active_path()).is_equal(&"")
	assert_float(ClassPathSystem.get_ambiguous_gap()).is_equal_approx(3.0, 0.001)

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true

	var row1_status: Label = panel.find_child("Row1StatusLabel") as Label  # pato_streamer
	var row2_status: Label = panel.find_child("Row2StatusLabel") as Label  # guru_celebryta
	assert_str(row1_status.text).is_equal("Ambiguous — keep investing to commit. (gap: 3.0)")
	assert_str(row2_status.text).is_equal("Ambiguous — keep investing to commit. (gap: 3.0)")

	# Neither ambiguous row claims an active-tier bonus.
	assert_bool(row1_status.text.contains("Active")).is_false()
	assert_bool(row2_status.text.contains("Active")).is_false()

	# The two untied paths (Tier 0) show no ambiguous text either.
	var row3_status: Label = panel.find_child("Row3StatusLabel") as Label
	var row4_status: Label = panel.find_child("Row4StatusLabel") as Label
	assert_bool(row3_status.text.contains("Ambiguous")).is_false()
	assert_bool(row4_status.text.contains("Ambiguous")).is_false()


func test_resolved_active_path_shows_active_status_not_ambiguous() -> void:
	_seed_affiliation(&"pato_streamer", 45.0)
	_seed_affiliation(&"guru_celebryta", 20.0)  # diff 25.0 >= margin -> resolved
	assert_that(ClassPathSystem.get_active_path()).is_equal(&"pato_streamer")

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true

	var row1_status: Label = panel.find_child("Row1StatusLabel") as Label
	var row2_status: Label = panel.find_child("Row2StatusLabel") as Label
	assert_str(row1_status.text).is_equal("Active — Tier 2 bonus in effect")
	assert_str(row2_status.text).is_equal("Tier 1 (secondary — bonus inactive while another path is active)")


# --- AC-4: disabled Invest control when card_contribution == 0 ---

func test_invest_button_disabled_with_explanation_when_card_contribution_zero() -> void:
	assert_bool(ClassPathSystem.can_invest(&"pato_streamer")).is_false()

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true

	var button: Button = panel.find_child("Row1InvestButton") as Button
	var explanation: Label = panel.find_child("Row1InvestExplanationLabel") as Label
	assert_bool(button.disabled).override_failure_message(
		"Invest button must render visually disabled, not merely non-functional"
	).is_true()
	assert_bool(explanation.visible).is_true()
	assert_str(explanation.text).is_equal("Make a Trash Streamer choice first")


func test_invest_button_enabled_when_card_contribution_positive() -> void:
	_seed_affiliation(&"pato_streamer", 20.0)  # Tier 1, card_contribution > 0
	assert_bool(ClassPathSystem.can_invest(&"pato_streamer")).is_true()

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true

	var button: Button = panel.find_child("Row1InvestButton") as Button
	var explanation: Label = panel.find_child("Row1InvestExplanationLabel") as Label
	assert_bool(button.disabled).is_false()
	assert_bool(explanation.visible).is_false()
	assert_str(button.text).is_equal("Invest 10 Cringe (+1.0 affiliation)")


## GDD-documented second disabled case (F3 clamp cap) -- not itself one of
## this story's 5 required ACs, but a cheap pure-read extra per the GDD's
## own Invest control spec.
func test_invest_button_disabled_when_affiliation_at_full_cap() -> void:
	_seed_affiliation(&"pato_streamer", 100.0)  # Tier 5, at F3 clamp ceiling
	assert_float(ClassPathSystem.get_affiliation(&"pato_streamer")).is_equal_approx(100.0, 0.001)

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true

	var button: Button = panel.find_child("Row1InvestButton") as Button
	var explanation: Label = panel.find_child("Row1InvestExplanationLabel") as Label
	assert_bool(button.disabled).is_true()
	assert_bool(explanation.visible).is_true()
	assert_str(explanation.text).is_equal("Fully invested this era")


## Invest button press actually spends the resource and grants +1.0
## affiliation -- confirms the button is wired to the real invest() call, not
## just cosmetically enabled.
func test_invest_button_press_spends_resource_and_grants_affiliation() -> void:
	_seed_affiliation(&"pato_streamer", 20.0)
	_seed_resource(&"Cringe", 100.0)
	var affiliation_before: float = ClassPathSystem.get_affiliation(&"pato_streamer")

	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel: Node = runner.scene()
	panel.visible = true

	var button: Button = panel.find_child("Row1InvestButton") as Button
	runner.invoke("_on_invest_pressed", 0)

	assert_float(ClassPathSystem.get_affiliation(&"pato_streamer")).is_equal_approx(affiliation_before + 1.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(90.0, 0.001)
	var bar: ProgressBar = panel.find_child("Row1AffiliationBar") as ProgressBar
	assert_float(bar.value).is_equal_approx(affiliation_before + 1.0, 0.001)
	assert_object(button).is_not_null()


# --- AC-3: HUD indicator still holds across all 4 paths (confirmation, not a rebuild) ---

func test_hud_indicator_absent_before_tier1_present_after_for_all_four_paths() -> void:
	var path_ids: Array[StringName] = [
		&"pato_streamer", &"guru_celebryta", &"ekspert_niszowy", &"biznesmen_contentu",
	]
	for path_id: StringName in path_ids:
		ClassPathSystem.reset_era_state()
		var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_hud_indicator.tscn")
		var hud: Node = runner.scene()
		assert_bool((hud as CanvasItem).visible).override_failure_message(
			"HUD indicator must be hidden before any path reaches Tier 1"
		).is_false()

		_seed_affiliation(path_id, 20.0)  # Tier 1
		assert_bool((hud as CanvasItem).visible).override_failure_message(
			"HUD indicator must appear once %s reaches Tier 1" % path_id
		).is_true()
	ClassPathSystem.reset_era_state()


# --- AC-5: no moral-framing text anywhere in the panel ---

func test_no_moral_framing_text_in_panel_across_representative_states() -> void:
	# State 1: fresh/zero-affiliation for all paths.
	var runner1: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel1: Node = runner1.scene()
	panel1.visible = true
	_assert_all_panel_labels_clean(panel1)

	# State 2: ambiguous tie.
	_seed_affiliation(&"pato_streamer", 45.0)
	_seed_affiliation(&"guru_celebryta", 42.0)
	var runner2: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel2: Node = runner2.scene()
	panel2.visible = true
	_assert_all_panel_labels_clean(panel2)

	# State 3: resolved active path + disabled/enabled Invest controls mixed.
	ClassPathSystem.reset_era_state()
	_seed_affiliation(&"ekspert_niszowy", 100.0)  # Tier 5, at cap -- exercises "Fully invested" text
	var runner3: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/class_path_panel.tscn")
	var panel3: Node = runner3.scene()
	panel3.visible = true
	_assert_all_panel_labels_clean(panel3)


func _assert_all_panel_labels_clean(panel: Node) -> void:
	for i in 4:
		var row_num: int = i + 1
		var labels: Array[String] = [
			"Row%dNameLabel" % row_num,
			"Row%dTierLabel" % row_num,
			"Row%dAffiliationValueLabel" % row_num,
			"Row%dStatusLabel" % row_num,
			"Row%dInvestExplanationLabel" % row_num,
		]
		for label_name: String in labels:
			var label: Label = panel.find_child(label_name) as Label
			_assert_no_moral_framing(label.text)
		var button: Button = panel.find_child("Row%dInvestButton" % row_num) as Button
		_assert_no_moral_framing(button.text)
