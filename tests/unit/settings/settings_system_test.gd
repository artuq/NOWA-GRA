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


func after_test() -> void:
	SaveSystem._debounce_timer.stop()


func test_default_reduce_motion_is_false() -> void:
	var settings: Node = SettingsSystemScript.new()
	assert_bool(settings.reduce_motion).is_false()
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


func test_serialize_state_shape() -> void:
	var settings: Node = SettingsSystemScript.new()
	settings.set_reduce_motion(true)
	var snapshot: Dictionary = settings.serialize_state()
	assert_bool(snapshot.has("reduce_motion")).is_true()
	assert_bool(snapshot["reduce_motion"]).is_true()
	settings.free()


func test_restore_state_round_trips_true() -> void:
	var settings: Node = SettingsSystemScript.new()
	settings.set_reduce_motion(true)
	var snapshot: Dictionary = settings.serialize_state()

	var restored: Node = SettingsSystemScript.new()
	restored.restore_state(snapshot)

	assert_bool(restored.reduce_motion).is_true()
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
	settings.free()
