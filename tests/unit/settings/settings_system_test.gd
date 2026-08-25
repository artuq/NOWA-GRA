## Unit tests for SettingsSystem (Settings/Accessibility, reduce-motion story).
## Same shape as onboarding_gate_state_test.gd: fresh, untracked instances for
## serialize_state()/restore_state() round-trips (a fresh instance never
## touches the real Autoload's own `reduce_motion` field). set_reduce_motion()
## calls the real SaveSystem.mark_dirty() even on a fresh instance (Autoloads
## are singletons regardless of which instance calls into them) -- after_test()
## stops the real debounce timer so a stray save can't fire later in the suite
## run, matching the established pattern (onboarding_persistence_test.gd).
extends GdUnitTestSuite

const SettingsSystemScript: GDScript = preload("res://src/core/settings_system.gd")

var _locale_snapshot: String


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()


func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)
	SaveSystem._debounce_timer.stop()


func test_default_reduce_motion_is_false() -> void:
	var settings: Node = SettingsSystemScript.new()
	assert_bool(settings.reduce_motion).is_false()
	settings.free()


func test_default_language_preference_is_system() -> void:
	var settings: Node = SettingsSystemScript.new()
	assert_str(String(settings.language_preference)).is_equal("system")
	assert_bool(settings.language_choice_confirmed).is_false()
	settings.free()


func test_set_reduce_motion_updates_field_both_directions() -> void:
	var settings: Node = SettingsSystemScript.new()
	settings.set_reduce_motion(true)
	assert_bool(settings.reduce_motion).is_true()
	settings.set_reduce_motion(false)
	assert_bool(settings.reduce_motion).is_false()
	settings.free()


func test_set_reduce_motion_marks_save_dirty() -> void:
	SaveSystem._debounce_timer.stop()
	var settings: Node = SettingsSystemScript.new()
	settings.set_reduce_motion(true)
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()
	settings.free()


func test_resolve_locale_honors_explicit_preference_independent_of_system() -> void:
	assert_str(String(SettingsSystemScript.resolve_locale("en", "pl"))).is_equal("en")
	assert_str(String(SettingsSystemScript.resolve_locale("pl", "en"))).is_equal("pl_PL")


func test_resolve_locale_maps_polish_system_locale_to_polish() -> void:
	assert_str(String(SettingsSystemScript.resolve_locale("system", "pl"))).is_equal("pl_PL")
	assert_str(String(SettingsSystemScript.resolve_locale("system", "pl_PL"))).is_equal("pl_PL")
	assert_str(String(SettingsSystemScript.resolve_locale("system", "pl-PL"))).is_equal("pl_PL")


func test_resolve_locale_maps_other_system_locale_to_english_fallback() -> void:
	assert_str(String(SettingsSystemScript.resolve_locale("system", "de"))).is_equal("en")
	assert_str(String(SettingsSystemScript.resolve_locale("system", "en_US"))).is_equal("en")


func test_resolve_locale_treats_unknown_preference_as_system() -> void:
	assert_str(String(SettingsSystemScript.resolve_locale("corrupt", "pl"))).is_equal("pl_PL")
	assert_str(String(SettingsSystemScript.resolve_locale("corrupt", "fr"))).is_equal("en")


func test_set_language_preference_applies_locale_and_marks_save_dirty() -> void:
	SaveSystem._debounce_timer.stop()
	var settings: Node = SettingsSystemScript.new()
	settings.set_language_preference("pl")

	assert_str(String(settings.language_preference)).is_equal("pl")
	assert_str(TranslationServer.get_locale()).is_equal("pl_PL")
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()
	settings.free()


func test_set_language_preference_emits_preference_and_resolved_locale() -> void:
	var settings: Node = SettingsSystemScript.new()
	var emissions: Array[Array] = []
	settings.language_changed.connect(
		func(preference: StringName, locale: StringName) -> void:
			emissions.append([preference, locale])
	)

	settings.set_language_preference("pl")

	assert_int(emissions.size()).is_equal(1)
	assert_str(String(emissions[0][0])).is_equal("pl")
	assert_str(String(emissions[0][1])).is_equal("pl_PL")
	settings.free()


func test_serialize_state_shape() -> void:
	var settings: Node = SettingsSystemScript.new()
	settings.set_reduce_motion(true)
	settings.set_language_preference("pl")
	var snapshot: Dictionary = settings.serialize_state()
	assert_bool(snapshot.has("reduce_motion")).is_true()
	assert_bool(snapshot["reduce_motion"]).is_true()
	assert_bool(snapshot.has("language_preference")).is_true()
	assert_str(snapshot["language_preference"]).is_equal("pl")
	assert_bool(snapshot.has("language_choice_confirmed")).is_true()
	assert_bool(snapshot["language_choice_confirmed"]).is_true()
	settings.free()


func test_restore_state_round_trips_true() -> void:
	var settings: Node = SettingsSystemScript.new()
	settings.set_reduce_motion(true)
	settings.set_language_preference("pl")
	var snapshot: Dictionary = settings.serialize_state()

	var restored: Node = SettingsSystemScript.new()
	restored.restore_state(snapshot)

	assert_bool(restored.reduce_motion).is_true()
	assert_str(String(restored.language_preference)).is_equal("pl")
	assert_bool(restored.language_choice_confirmed).is_true()
	assert_str(TranslationServer.get_locale()).is_equal("pl_PL")
	settings.free()
	restored.free()


func test_restore_state_round_trips_false() -> void:
	var settings: Node = SettingsSystemScript.new()
	var snapshot: Dictionary = settings.serialize_state()

	var restored: Node = SettingsSystemScript.new()
	restored.restore_state(snapshot)

	assert_bool(restored.reduce_motion).is_false()
	settings.free()
	restored.free()


## AC: a missing/corrupted key falls back to the false default, never crashes
## -- matching SaveSystem's own "missing key -> default" contract.
func test_restore_state_missing_key_falls_back_to_false() -> void:
	var settings: Node = SettingsSystemScript.new()
	settings.restore_state({})
	assert_bool(settings.reduce_motion).is_false()
	assert_str(String(settings.language_preference)).is_equal("system")
	assert_bool(settings.language_choice_confirmed).is_false()
	settings.free()


func test_restore_state_sanitizes_unknown_language_preference() -> void:
	var settings: Node = SettingsSystemScript.new()
	settings.restore_state({"language_preference": "unsupported"})
	assert_str(String(settings.language_preference)).is_equal("system")
	settings.free()
