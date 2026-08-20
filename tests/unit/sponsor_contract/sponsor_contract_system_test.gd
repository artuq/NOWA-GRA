extends GdUnitTestSuite

const SponsorContractSystemScript: GDScript = preload(
	"res://src/core/sponsor_contract_system.gd"
)

const _TEST_CONFIG: Dictionary = {
	"schema_version": 1,
	"opening_card_id": "brand_deal_choice",
	"campaign_actions_required": 4,
	"fallout_cards": {
		"a": "sponsor_contract_mega_fallout",
		"b": "sponsor_contract_indie_fallout",
	},
	"recovery_actions_required": 2,
	"finale_card_id": "sponsor_contract_finale",
	"callback_offline_seconds_required": 300,
	"callback_cards": {
		"honest_report": "sponsor_contract_callback_honest",
		"sell_legend": "sponsor_contract_callback_legend",
	},
}


func _new_system() -> Node:
	var system: Node = SponsorContractSystemScript.new()
	assert_bool(system.configure(_TEST_CONFIG)).is_true()
	return system


func test_brand_choice_starts_one_shot_campaign_and_remembers_branch() -> void:
	var system: Node = _new_system()
	system.process_card_resolved(&"brand_deal_choice", &"a")
	var snapshot: Dictionary = system.get_snapshot()
	assert_str(snapshot["state"]).is_equal("campaign")
	assert_str(snapshot["opening_choice"]).is_equal("a")
	assert_int(snapshot["actions_required"]).is_equal(4)
	assert_int(snapshot["stage_number"]).is_equal(2)
	system.free()


func test_campaign_actions_schedule_branch_specific_fallout_card() -> void:
	var system: Node = _new_system()
	system.process_card_resolved(&"brand_deal_choice", &"a")
	for index: int in 4:
		system.process_action_completed()
		if index < 3:
			assert_bool(system.has_due_card()).is_false()
	assert_bool(system.has_due_card()).is_true()
	assert_str(String(system.get_due_card_id())).is_equal("sponsor_contract_mega_fallout")
	system.free()


func test_indie_branch_schedules_indie_fallout() -> void:
	var system: Node = _new_system()
	system.process_card_resolved(&"brand_deal_choice", &"b")
	for _index: int in 4:
		system.process_action_completed()
	assert_str(String(system.get_due_card_id())).is_equal("sponsor_contract_indie_fallout")
	system.free()


func test_fallout_choice_is_remembered_then_recovery_schedules_finale() -> void:
	var system: Node = _new_system()
	system.process_card_resolved(&"brand_deal_choice", &"a")
	for _index: int in 4:
		system.process_action_completed()
	system.process_card_resolved(&"sponsor_contract_mega_fallout", &"show_receipts")
	assert_str(system.get_snapshot()["state"]).is_equal("recovery")
	assert_str(system.get_snapshot()["fallout_choice"]).is_equal("show_receipts")
	system.process_action_completed()
	assert_bool(system.has_due_card()).is_false()
	system.process_action_completed()
	assert_str(String(system.get_due_card_id())).is_equal("sponsor_contract_finale")
	system.free()


func test_finale_completes_contract_and_prevents_restart() -> void:
	var system: Node = _new_system()
	system.restore_state({"state": "finale_due", "opening_choice": "b", "fallout_choice": "fix_shipping"})
	system.process_card_resolved(&"sponsor_contract_finale", &"sell_legend")
	assert_str(system.get_snapshot()["state"]).is_equal("completed")
	assert_str(system.get_snapshot()["final_choice"]).is_equal("sell_legend")
	assert_bool(system.has_due_card()).is_false()
	system.process_card_resolved(&"brand_deal_choice", &"a")
	assert_str(system.get_snapshot()["state"]).is_equal("completed")
	system.free()


func test_short_offline_return_does_not_arm_callback() -> void:
	var system: Node = _new_system()
	system.restore_state({"state": "completed", "opening_choice": "b", "final_choice": "sell_legend"})
	system.process_offline_elapsed(299)
	assert_str(system.get_snapshot()["state"]).is_equal("completed")
	assert_bool(system.has_due_card()).is_false()
	system.free()


func test_real_offline_return_arms_branch_specific_callback_once() -> void:
	var system: Node = _new_system()
	system.restore_state({"state": "completed", "opening_choice": "b", "final_choice": "sell_legend"})
	system.process_offline_elapsed(300)
	assert_str(system.get_snapshot()["state"]).is_equal("callback_due")
	assert_str(String(system.get_due_card_id())).is_equal("sponsor_contract_callback_legend")
	system.process_card_resolved(&"sponsor_contract_callback_legend", &"forward_brief")
	assert_str(system.get_snapshot()["state"]).is_equal("closed")
	assert_bool(system.has_due_card()).is_false()
	system.process_offline_elapsed(99_999)
	assert_str(system.get_snapshot()["state"]).is_equal("closed")
	system.free()


func test_serialize_restore_round_trip_keeps_progress_and_choices() -> void:
	var source: Node = _new_system()
	source.process_card_resolved(&"brand_deal_choice", &"b")
	source.process_action_completed()
	source.process_action_completed()
	var saved: Dictionary = source.serialize_state()
	var restored: Node = _new_system()
	restored.restore_state(saved)
	assert_dict(restored.serialize_state()).is_equal(saved)
	assert_int(restored.get_snapshot()["actions_completed"]).is_equal(2)
	source.free()
	restored.free()


func test_corrupt_restore_falls_back_to_not_started() -> void:
	var system: Node = _new_system()
	system.restore_state({"state": "invented", "actions_completed": 999, "opening_choice": "x"})
	var snapshot: Dictionary = system.get_snapshot()
	assert_str(snapshot["state"]).is_equal("not_started")
	assert_int(snapshot["actions_completed"]).is_equal(0)
	assert_bool(snapshot["active"]).is_false()
	system.free()
