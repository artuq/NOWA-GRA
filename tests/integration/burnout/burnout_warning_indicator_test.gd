## Tests for the BurnoutWarningIndicator (burnout-warning-hud-indicator.md
## spec) + the meta-loop telegraph line (playtest 12-3 fix): countdown math,
## both hide triggers, and the banked-bonus preview on both the indicator and
## the Wypalenie card itself.
##
## Handlers are invoked DIRECTLY (not via real singleton signal emission) so
## no other Autoload listener fires side effects mid-test — emitting a real
## card_resolved with the Wypalenie id would run a full era transition.
## reduce_motion is forced true per-test so show/hide is synchronous (no
## tween awaits); restored after.
extends GdUnitTestSuite

const INDICATOR_SCENE: String = "res://scenes/action_screen/burnout_warning_indicator.tscn"
const CARD_SCREEN_SCENE: String = "res://scenes/card_screen/card_screen.tscn"

var _reduce_motion_before: bool
var _cps_snapshot: Dictionary = {}
var _locale_snapshot: String = ""


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	_reduce_motion_before = SettingsSystem.reduce_motion
	SettingsSystem.reduce_motion = true
	_cps_snapshot = ClassPathSystem.serialize_state()


func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)
	SettingsSystem.reduce_motion = _reduce_motion_before
	ClassPathSystem.reset_era_state()
	ClassPathSystem.restore_state(_cps_snapshot)
	SaveSystem._debounce_timer.stop()


func _seed_active_path(path_id: StringName, tier: int) -> void:
	ClassPathSystem._active_path = path_id
	ClassPathSystem._current_tier[path_id] = tier


## AC (spec): hidden by default; warning shows it with the correct fill
## ratio (seconds / 120s window) and a textual seconds label.
func test_warning_shows_countdown() -> void:
	var runner: GdUnitSceneRunner = scene_runner(INDICATOR_SCENE)
	var s: Control = runner.scene()
	assert_bool(s.visible).is_false()

	s._on_warning_changed(true, 60.0)

	assert_bool(s.visible).is_true()
	assert_float((s.find_child("CountdownBar", true, false) as ProgressBar).value).is_equal_approx(0.5, 0.001)
	assert_str((s.find_child("SecondsRemainingLabel", true, false) as Label).text).is_equal("60s")


## AC (spec): burnout_warning_changed(false, ...) hides it.
func test_hides_when_warning_cancels() -> void:
	var runner: GdUnitSceneRunner = scene_runner(INDICATOR_SCENE)
	var s: Control = runner.scene()
	s._on_warning_changed(true, 30.0)
	assert_bool(s.visible).is_true()
	s._on_warning_changed(false, 0.0)
	assert_bool(s.visible).is_false()


## AC (spec, verified finding): ANY card presentation hides it — card
## injection resets the sustain counter with NO false emission.
func test_hides_on_card_presented() -> void:
	var runner: GdUnitSceneRunner = scene_runner(INDICATOR_SCENE)
	var s: Control = runner.scene()
	s._on_warning_changed(true, 10.0)
	assert_bool(s.visible).is_true()
	s._on_card_presented({"id": "any_card"})
	assert_bool(s.visible).is_false()


## AC (telegraph): with an active path, the preview names the banked bonus
## with a concrete number; with none, it says accepting banks nothing.
func test_bank_preview_line() -> void:
	var runner: GdUnitSceneRunner = scene_runner(INDICATOR_SCENE)
	var s: Control = runner.scene()
	var preview: Label = s.find_child("BankPreviewLabel", true, false)

	_seed_active_path(&"pato_streamer", 3)
	s._on_warning_changed(true, 90.0)
	assert_str(preview.text).contains("% Reach")
	assert_str(preview.text).contains("permanent")

	# No-path case: preview key must invalidate on hide, then recompute.
	s._on_warning_changed(false, 0.0)
	ClassPathSystem.reset_era_state()
	s._on_warning_changed(true, 90.0)
	assert_str(preview.text).contains("banks nothing")


func test_visible_preview_refreshes_after_polish_language_change() -> void:
	var runner: GdUnitSceneRunner = scene_runner(INDICATOR_SCENE)
	var s: Control = runner.scene()
	_seed_active_path(&"pato_streamer", 3)
	s._on_warning_changed(true, 90.0)

	TranslationServer.set_locale("pl_PL")
	SettingsSystem.language_changed.emit(&"pl", &"pl_PL")
	await get_tree().process_frame

	var preview: Label = s.find_child("BankPreviewLabel", true, false)
	assert_str(preview.text).contains("Wypalenie nadchodzi")
	assert_str(preview.text).contains("na stałe")

	TranslationServer.set_locale("en")
	SettingsSystem.language_changed.emit(&"en", &"en")
	await get_tree().process_frame
	assert_str(preview.text).contains("Burnout ahead")
	assert_str(preview.text).contains("% Reach")


## AC (telegraph): the Wypalenie card's situation text itself carries the
## stake line — the same projected number the Challenge Selection recap will
## later confirm via get_last_grant().
func test_wypalenie_card_carries_stake_line() -> void:
	_seed_active_path(&"pato_streamer", 3)
	var runner: GdUnitSceneRunner = scene_runner(CARD_SCREEN_SCENE)
	var cs: Control = runner.scene()
	var card: Dictionary = CardContentDatabase.get_card("final_burnout")
	assert_bool(card.is_empty()).is_false()

	cs._on_card_presented(card)

	var situation: Label = cs.find_child("SituationLabel", true, false)
	assert_str(situation.text).contains("Accepting banks +")
	assert_str(situation.text).contains("% Reach")
	# Static card copy (the shared Dictionary!) must remain unmutated — the
	# stake line lives only in the rendered label.
	assert_bool(String(card["text"]).contains("Accepting banks")).is_false()


## AC (telegraph): a non-Wypalenie card gets NO stake line.
func test_regular_card_has_no_stake_line() -> void:
	var runner: GdUnitSceneRunner = scene_runner(CARD_SCREEN_SCENE)
	var cs: Control = runner.scene()
	cs._on_card_presented(CardContentDatabase.get_card("exposed_friend"))
	var situation: Label = cs.find_child("SituationLabel", true, false)
	assert_bool(situation.text.contains("Accepting banks")).is_false()
