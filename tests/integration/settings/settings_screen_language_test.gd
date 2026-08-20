## Interaction coverage for the language selector in the real Settings modal.
## Uses the established scene_runner() UI seam so node wiring, touch-target
## sizing, metadata, and SettingsSystem integration are all exercised together.
extends GdUnitTestSuite

const SETTINGS_SCENE: String = "res://scenes/settings_screen/settings_screen.tscn"

var _preference_snapshot: StringName
var _confirmed_snapshot: bool
var _locale_snapshot: String


func before_test() -> void:
	_preference_snapshot = SettingsSystem.language_preference
	_confirmed_snapshot = SettingsSystem.language_choice_confirmed
	_locale_snapshot = TranslationServer.get_locale()


func after_test() -> void:
	SettingsSystem.language_preference = _preference_snapshot
	SettingsSystem.language_choice_confirmed = _confirmed_snapshot
	TranslationServer.set_locale(_locale_snapshot)
	SaveSystem._debounce_timer.stop()


func test_language_selector_lists_three_choices_and_reflects_saved_preference() -> void:
	SettingsSystem.language_preference = SettingsSystem.LANGUAGE_PL
	TranslationServer.set_locale("pl_PL")
	var runner: GdUnitSceneRunner = scene_runner(SETTINGS_SCENE)
	var selector: OptionButton = runner.scene().find_child("LanguageSelect") as OptionButton

	assert_int(selector.item_count).is_equal(3)
	assert_int(selector.selected).is_equal(2)
	assert_str(String(selector.get_item_metadata(0))).is_equal("system")
	assert_str(String(selector.get_item_metadata(1))).is_equal("en")
	assert_str(String(selector.get_item_metadata(2))).is_equal("pl")
	assert_float(selector.custom_minimum_size.y).is_greater_equal(44.0)
	assert_str(selector.tooltip_text).is_not_empty()


func test_language_selection_updates_preference_and_effective_locale() -> void:
	SettingsSystem.language_preference = SettingsSystem.LANGUAGE_PL
	TranslationServer.set_locale("pl_PL")
	var runner: GdUnitSceneRunner = scene_runner(SETTINGS_SCENE)

	runner.invoke("_on_language_selected", 1)

	assert_str(String(SettingsSystem.language_preference)).is_equal("en")
	assert_str(TranslationServer.get_locale()).is_equal("en")
	var selector: OptionButton = runner.scene().find_child("LanguageSelect") as OptionButton
	assert_int(selector.selected).is_equal(1)
