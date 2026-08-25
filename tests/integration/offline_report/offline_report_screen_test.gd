## Interaction tests for OfflineReportScreen (Story 002, Offline Report Screen
## epic). Stubs OfflineProgressSystem.last_simulation_result, then instances the
## real scene via scene_runner and asserts the rendered strings + the single-fire
## dismiss latch (the standing UI-evidence method).
##
## OfflineProgressSystem is an Autoload; last_simulation_result is reset around
## each test so a stub doesn't leak.
extends GdUnitTestSuite

const REPORT_SCENE: String = "res://scenes/offline_report/offline_report.tscn"

var _locale_snapshot: String


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")

func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)
	OfflineProgressSystem.last_simulation_result = {}

func _stub(result: Dictionary) -> void:
	OfflineProgressSystem.last_simulation_result = result

## AC: headline number, ΔHaters, duration, no-capped — rendered from the result.
func test_renders_hero_number_haters_and_duration() -> void:
	_stub({
		"total_Z_gained": 1500000.0,
		"final_H": 394.0, "h0": 5.0,
		"final_M": 80.0, "m0": 80.0,
		"capped": false, "elapsed_seconds": 85620,
	})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()

	assert_str((s.find_child("HeroNumberLabel") as Label).text).is_equal("+%s" % ActionUIFormatting.format_number(1500000.0))
	assert_str((s.find_child("HatersLabel") as Label).text).is_equal("Haters: +389")
	assert_str((s.find_child("DurationLabel") as Label).text).is_equal("You were away for 23 hours.")
	assert_bool((s.find_child("CappedLabel") as Label).visible).is_false()

## AC: ΔHaters of 0 still shown as "+0" (not hidden), and the Morale band change
## indicator appears only when the band shifted.
func test_zero_haters_delta_and_morale_band_change_indicator() -> void:
	_stub({
		"total_Z_gained": 0.0,
		"final_H": 10.0, "h0": 10.0,        # equal -> "+0"
		"final_M": 10.0, "m0": 80.0,        # High -> Critical : indicator
		"capped": false, "elapsed_seconds": 600,
	})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()

	assert_str((s.find_child("HatersLabel") as Label).text).is_equal("Haters: +0")
	assert_str((s.find_child("MoraleLabel") as Label).text).is_equal("Morale: Critical (was High)")
	# total_Z_gained 0 still renders a headline, no special-casing.
	assert_str((s.find_child("HeroNumberLabel") as Label).text).is_equal("+0")

## AC: Morale band unchanged -> only the current band, no "(was ...)" indicator.
func test_morale_band_unchanged_no_indicator() -> void:
	_stub({"total_Z_gained": 100.0, "final_H": 0.0, "h0": 0.0, "final_M": 80.0, "m0": 75.0, "capped": false, "elapsed_seconds": 300})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()
	# 80 and 75 are both "High" (>= 70) -> no indicator.
	assert_str((s.find_child("MoraleLabel") as Label).text).is_equal("Morale: High")

## AC (gap closed, flagged by code review): a negative ΔHaters (final_H < h0,
## a real case -- a card resolution or other event could lower Haters offline)
## renders with the minus sign, not just the positive-delta happy path.
func test_negative_haters_delta_shows_minus_sign() -> void:
	_stub({"total_Z_gained": 0.0, "final_H": 5.0, "h0": 20.0, "final_M": 50.0, "m0": 50.0, "capped": false, "elapsed_seconds": 300})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()
	assert_str((s.find_child("HatersLabel") as Label).text).is_equal("Haters: -15")

## AC (gap closed, flagged by code review): an empty/partial result dict never
## errors -- _render's documented "safe neutral fallback" contract. Missing h0/m0
## fall back to final_H/final_M (zero delta, no band-change); missing
## total_Z_gained/elapsed_seconds/capped fall back to 0/0/false.
func test_missing_keys_fall_back_safely() -> void:
	_stub({})  # completely empty -- BootController contract violated, must not crash
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()
	assert_str((s.find_child("HeroNumberLabel") as Label).text).is_equal("+0")
	assert_str((s.find_child("HatersLabel") as Label).text).is_equal("Haters: +0")
	assert_str((s.find_child("DurationLabel") as Label).text).is_equal("You were away for 0 minutes.")
	assert_bool((s.find_child("CappedLabel") as Label).visible).is_false()

## AC: capped=true shows the capped message.
func test_capped_message_shown_when_capped() -> void:
	_stub({"total_Z_gained": 5.0, "final_H": 0.0, "h0": 0.0, "final_M": 50.0, "m0": 50.0, "capped": true, "elapsed_seconds": 86400})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()
	assert_bool((s.find_child("CappedLabel") as Label).visible).is_true()
	assert_str((s.find_child("DurationLabel") as Label).text).is_equal("You were away for 24 hours.")


## Switching the same report payload to Polish changes copy and plural forms,
## while every source number stays untouched.
func test_polish_report_renders_localized_copy_and_duration() -> void:
	_stub({
		"total_Z_gained": 1250.0,
		"final_H": 12.0, "h0": 7.0,
		"final_M": 5.0, "m0": 80.0,
		"capped": false, "elapsed_seconds": 7200,
	})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()
	TranslationServer.set_locale("pl_PL")
	runner.invoke("_on_language_changed", &"pl", &"pl_PL")

	assert_str((s.find_child("HeadlineLabel") as Label).text).is_equal(
		"Twoje imperium pracowało bez ciebie."
	)
	assert_str((s.find_child("HatersLabel") as Label).text).is_equal("Hejterzy: +5")
	assert_str((s.find_child("MoraleLabel") as Label).text).is_equal(
		"Morale: Krytyczne (wcześniej Wysokie)"
	)
	assert_str((s.find_child("DurationLabel") as Label).text).is_equal(
		"Nie było cię przez 2 godziny."
	)

## AC: single-fire dismiss — the scene swap actually happens exactly once, not
## just the guard bool flipping. main_scene_path is retargeted at the report
## scene itself (harmless, exists) so we can drive a real change_scene_to_file
## and count it via the tree's "tree_changed"-adjacent signal: simplest reliable
## counter is the current_scene identity changing. We assert via a call-count
## spy instead, by overriding the swap through a counted wrapper.
func test_dismiss_swaps_scene_exactly_once() -> void:
	_stub({"total_Z_gained": 0.0, "final_H": 0.0, "h0": 0.0, "final_M": 50.0, "m0": 50.0, "capped": false, "elapsed_seconds": 300})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Node = runner.scene()
	s.main_scene_path = REPORT_SCENE  # harmless valid target
	var swap_count: Array[int] = [0]
	s.scene_swap_requested.connect(func(_path: String) -> void: swap_count[0] += 1)

	s._dismiss()
	s._dismiss()  # second tap: guarded no-op, must not swap again
	s._dismiss()  # third tap, same

	assert_int(swap_count[0]).is_equal(1)

## AC: both the root Button (tap-anywhere) and the Continue Button drive dismiss.
func test_root_button_and_continue_button_both_dismiss() -> void:
	_stub({"total_Z_gained": 0.0, "final_H": 0.0, "h0": 0.0, "final_M": 50.0, "m0": 50.0, "capped": false, "elapsed_seconds": 300})
	var runner: GdUnitSceneRunner = scene_runner(REPORT_SCENE)
	var s: Button = runner.scene() as Button
	s.main_scene_path = REPORT_SCENE
	# The root is a Button and its pressed signal is connected to dismiss; the
	# Continue button shares the same handler.
	assert_bool(s.pressed.is_connected(s._dismiss)).is_true()
	assert_bool((s.find_child("ContinueButton") as Button).pressed.is_connected(s._dismiss)).is_true()
