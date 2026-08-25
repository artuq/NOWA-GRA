extends GdUnitTestSuite

const SaveSystemScript: GDScript = preload("res://src/core/save_system.gd")

var _contract_snapshot: Dictionary
var _had_save: bool
var _save_backup: String


func before_test() -> void:
	_contract_snapshot = SponsorContractSystem.serialize_state()
	_had_save = FileAccess.file_exists(SaveSystemScript.SAVE_PATH)
	_save_backup = ""
	if _had_save:
		var file: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.READ)
		_save_backup = file.get_as_text()
		file.close()
		DirAccess.remove_absolute(SaveSystemScript.SAVE_PATH)


func after_test() -> void:
	SponsorContractSystem.restore_state(_contract_snapshot)
	if FileAccess.file_exists(SaveSystemScript.SAVE_PATH):
		DirAccess.remove_absolute(SaveSystemScript.SAVE_PATH)
	if _had_save:
		var file: FileAccess = FileAccess.open(SaveSystemScript.SAVE_PATH, FileAccess.WRITE)
		file.store_string(_save_backup)
		file.close()
	SaveSystem._debounce_timer.stop()


func test_full_snapshot_contains_round_trippable_sponsor_contract_block() -> void:
	SponsorContractSystem.restore_state({
		"state": "recovery",
		"opening_choice": "b",
		"fallout_choice": "fix_shipping",
		"actions_completed": 1,
	})
	SaveSystem.save_now()

	var data: Dictionary = SaveSystem.load_save()
	assert_bool(data.has("sponsor_contract")).is_true()
	assert_str(data["sponsor_contract"]["state"]).is_equal("recovery")
	assert_str(data["sponsor_contract"]["opening_choice"]).is_equal("b")
	assert_str(data["sponsor_contract"]["fallout_choice"]).is_equal("fix_shipping")
	assert_int(int(data["sponsor_contract"]["actions_completed"])).is_equal(1)

	SponsorContractSystem.reset_for_new_game()
	SponsorContractSystem.restore_state(data["sponsor_contract"])
	var restored: Dictionary = SponsorContractSystem.serialize_state()
	assert_str(restored["state"]).is_equal("recovery")
	assert_str(restored["opening_choice"]).is_equal("b")
	assert_str(restored["fallout_choice"]).is_equal("fix_shipping")
	assert_int(restored["actions_completed"]).is_equal(1)
