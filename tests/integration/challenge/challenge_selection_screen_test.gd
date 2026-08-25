## Integration tests for ChallengeSelectionScreen (design/ux/challenge-
## selection-screen.md, ADR-0018). Uses GdUnit4's scene_runner() to
## instantiate the real scene headlessly, same established method as every
## other UI story in this project (action_grid_interaction_test.gd
## precedent). Card toggles are driven via runner.invoke() calling
## _on_card_toggled() directly (same "call the real handler" technique as
## action_grid_interaction_test.gd's runner.invoke("_on_unlocked_button_
## pressed", ...)) rather than simulated mouse events, since the ACs being
## tested are about selection-state logic, not raw input routing.
##
## ChallengeSystem's active selection and PrestigeSystem's meta_bonus_totals/
## _last_grant are real Autoload state -- snapshotted and restored per test,
## same precedent as prestige_grant_wiring_test.gd.
extends GdUnitTestSuite

const _SCENE_PATH: String = "res://scenes/challenge_selection/challenge_selection.tscn"

var _challenge_snapshot: Array[StringName]
var _last_grant_snapshot: Dictionary
var _locale_snapshot: String = ""


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_challenge_snapshot = ChallengeSystem.get_active_challenge_ids()
	_last_grant_snapshot = PrestigeSystem.get_last_grant().duplicate()
	ChallengeSystem.clear_active_challenges()


func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)
	ChallengeSystem.select_challenges(_challenge_snapshot)
	PrestigeSystem.restore_state({
		"era_count": PrestigeSystem.era_count,
		"meta_bonus_totals": PrestigeSystem.meta_bonus_totals,
		"_last_grant": {
			"granted": _last_grant_snapshot["granted"],
			"type": String(_last_grant_snapshot["type"]),
			"amount": _last_grant_snapshot["amount"],
		},
	})


func _card(runner: GdUnitSceneRunner, index: int) -> Button:
	return runner.scene().find_child("ChallengeCard%d" % index) as Button


## Toggles [param index]'s card ON via the real handler, mirroring what Godot
## does before emitting `toggled`: flips button_pressed first, then invokes
## the connected handler.
func _toggle_on(runner: GdUnitSceneRunner, index: int) -> void:
	var card: Button = _card(runner, index)
	card.button_pressed = true
	runner.invoke("_on_card_toggled", true, card)


# --- 0 selected + Confirm: combined_meta_multiplier = 1.0, works identically ---

func test_zero_selected_confirm_uses_multiplier_1_and_emits_swap() -> void:
	var runner: GdUnitSceneRunner = scene_runner(_SCENE_PATH)
	var screen: Control = runner.scene()

	# GDScript lambdas capture outer locals by value, not by reference -- a
	# plain `var swap_path: String` written inside the lambda below would
	# mutate an invisible copy, never the outer variable (found the hard way:
	# an earlier draft asserted against an always-empty string that still
	# printed as if it matched, since the failure report shows the expected
	# value on both sides for an empty actual). The fix is the standard
	# GDScript idiom: capture a single mutable container (Dictionary) instead
	# -- writing to its keys IS visible outside, since the container
	# reference itself, not its contents, is what gets captured.
	var captured: Dictionary = {"path": "", "ids": []}
	screen.scene_swap_requested.connect(func(path: String, ids: Array[StringName]) -> void:
		captured["path"] = path
		captured["ids"] = ids
	)

	assert_str((screen.find_child("CombinedMultiplierLabel") as Label).text).contains("1.0")

	runner.invoke("_on_confirm_pressed")

	assert_str(captured["path"]).is_equal(screen.main_scene_path)
	assert_array(captured["ids"]).is_empty()
	assert_array(ChallengeSystem.get_active_challenge_ids()).is_empty()


# --- Two selected (2.0, 2.5) -> CombinedMultiplierLabel shows 5.0 immediately ---

func test_two_selected_combined_multiplier_shows_5_0_immediately() -> void:
	var runner: GdUnitSceneRunner = scene_runner(_SCENE_PATH)
	var screen: Control = runner.scene()

	_toggle_on(runner, 0)  # brak_duszy, meta_bonus_multiplier 2.0
	_toggle_on(runner, 1)  # drama_bez_granic, meta_bonus_multiplier 2.5

	assert_str((screen.find_child("CombinedMultiplierLabel") as Label).text).override_failure_message(
		"two cards with 2.0 and 2.5 meta_bonus_multiplier must combine multiplicatively to 5.0"
	).contains("5.0")
	assert_str((screen.find_child("SelectionCountLabel") as Label).text).is_equal("2/3")


# --- 3/3 selected, 4th toggle attempt rejected ---

func test_at_cap_fourth_toggle_attempt_is_rejected() -> void:
	var runner: GdUnitSceneRunner = scene_runner(_SCENE_PATH)

	_toggle_on(runner, 0)
	_toggle_on(runner, 1)
	_toggle_on(runner, 2)
	assert_int(ChallengeSystem.CHALLENGE_MAX_ACTIVE).is_equal(3)

	var fourth: Button = _card(runner, 3)
	fourth.button_pressed = true  # what Godot would do before emitting toggled
	runner.invoke("_on_card_toggled", true, fourth)

	assert_bool(fourth.button_pressed).override_failure_message(
		"a 4th selection attempt at cap must be reverted, not accepted"
	).is_false()
	assert_str(fourth.tooltip_text).is_not_empty()


# --- MetaBonusGrantedLabel matches PrestigeSystem.get_last_grant() exactly ---

func test_meta_bonus_granted_label_matches_get_last_grant_exactly() -> void:
	PrestigeSystem.restore_state({
		"era_count": PrestigeSystem.era_count,
		"meta_bonus_totals": PrestigeSystem.meta_bonus_totals,
		"_last_grant": {"granted": true, "type": "META_REACH_MULT", "amount": 0.0107},
	})
	var runner: GdUnitSceneRunner = scene_runner(_SCENE_PATH)
	var label: Label = runner.scene().find_child("MetaBonusGrantedLabel") as Label
	assert_str(label.text).contains("1.1")  # 0.0107 * 100 rounded to 1 decimal


## No Bonus Granted state: previous era ended without an active path ->
## "Brak bonusu tej ery" equivalent, never blank, never a misleading 0%.
func test_no_bonus_granted_shows_explicit_no_bonus_state() -> void:
	PrestigeSystem.restore_state({
		"era_count": PrestigeSystem.era_count,
		"meta_bonus_totals": PrestigeSystem.meta_bonus_totals,
		"_last_grant": {"granted": false, "type": "", "amount": 0.0},
	})
	var runner: GdUnitSceneRunner = scene_runner(_SCENE_PATH)
	var label: Label = runner.scene().find_child("MetaBonusGrantedLabel") as Label
	assert_str(label.text).override_failure_message(
		"no-active-path burnout must show an explicit no-bonus message, never blank or '0%'"
	).is_equal("No bonus this era.")
	assert_str(label.text).not_contains("0%")


func test_open_screen_refreshes_dynamic_copy_after_polish_language_change() -> void:
	var runner: GdUnitSceneRunner = scene_runner(_SCENE_PATH)
	_toggle_on(runner, 0)
	TranslationServer.set_locale("pl_PL")
	SettingsSystem.language_changed.emit(&"pl", &"pl_PL")
	await get_tree().process_frame

	var screen: Control = runner.scene()
	assert_str((screen.find_child("EraSummaryLabel") as Label).text).contains("Era")
	assert_str((screen.find_child("MetaBonusGrantedLabel") as Label).text).contains("bez nowego bonusu")
	assert_str(_card(runner, 0).text).contains("Influencer bez duszy")
	assert_str((screen.find_child("CombinedMultiplierLabel") as Label).text).contains("Łączny mnożnik")
	assert_bool(_card(runner, 0).button_pressed).is_true()

	TranslationServer.set_locale("en")
	SettingsSystem.language_changed.emit(&"en", &"en")
	await get_tree().process_frame
	assert_str(_card(runner, 0).text).contains("Soulless Influencer")
	assert_str((screen.find_child("CombinedMultiplierLabel") as Label).text).contains("Combined multiplier")
	assert_bool(_card(runner, 0).button_pressed).is_true()


# --- Selection is written via ChallengeSystem.select_challenges() on Confirm ---

func test_confirm_writes_selection_to_challenge_system() -> void:
	var runner: GdUnitSceneRunner = scene_runner(_SCENE_PATH)
	_toggle_on(runner, 0)

	runner.invoke("_on_confirm_pressed")

	var active: Array[StringName] = ChallengeSystem.get_active_challenge_ids()
	assert_int(active.size()).is_equal(1)
	assert_str(String(active[0])).is_equal("brak_duszy")
