## Integration tests for SettingsSystem's persistence: SaveSystem.save_now()'s
## payload and BootController wiring. Mirrors onboarding_persistence_test.gd's
## save/boot pattern (backup-and-restore the real save file; boot_with() as
## the public test seam for the full boot sequence).
extends GdUnitTestSuite

const SaveSystemScript: GDScript = preload("res://src/core/save_system.gd")

var _reduce_motion_snapshot: bool


func before_test() -> void:
	_reduce_motion_snapshot = SettingsSystem.reduce_motion


func after_test() -> void:
	SettingsSystem.reduce_motion = _reduce_motion_snapshot
	SaveSystem._debounce_timer.stop()


## AC: SaveSystem.save_now()'s payload contains a "settings" key matching
## SettingsSystem.serialize_state()'s shape.
func test_save_now_payload_contains_settings_key() -> void:
	SettingsSystem.reduce_motion = true

	var had_save_file: bool = FileAccess.file_exists(SaveSystemScript.SAVE_PATH)
	var backup: String = ""
	if had_save_file:
		var f: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.READ)
		backup = f.get_as_text()
		f.close()

	SaveSystem.save_now()
	var f2: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.READ)
	var written: Dictionary = JSON.parse_string(f2.get_as_text())
	f2.close()

	assert_bool(written.has("settings")).is_true()
	assert_bool(written["settings"]["reduce_motion"]).is_true()

	# Restore the real save file to its prior state (or remove it if it didn't
	# exist), matching save_core_test.gd's established backup/restore pattern.
	if had_save_file:
		var restore_f: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.WRITE)
		restore_f.store_string(backup)
		restore_f.close()
	else:
		DirAccess.remove_absolute(SaveSystemScript.SAVE_PATH)


## AC: BootController wiring -- boot_with() calls SettingsSystem.restore_state()
## with the "settings" sub-dict from the save Dictionary.
func test_boot_controller_restores_settings() -> void:
	var bc: Node = preload("res://src/core/boot_controller.gd").new()
	add_child(bc)
	var data: Dictionary = {
		"settings": {"reduce_motion": true},
	}

	bc.boot_with(data, 0)

	assert_bool(SettingsSystem.reduce_motion).is_true()
	bc.queue_free()


## AC: a save Dictionary with no "settings" key (older save format / first
## session) falls back to the false default, no crash.
func test_boot_controller_handles_missing_settings_key() -> void:
	var bc: Node = preload("res://src/core/boot_controller.gd").new()
	add_child(bc)

	bc.boot_with({}, 0)

	assert_bool(SettingsSystem.reduce_motion).is_false()
	bc.queue_free()
