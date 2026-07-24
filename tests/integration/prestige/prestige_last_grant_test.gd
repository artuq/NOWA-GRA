## Integration test for the core guarantee ADR-0017 exists to provide:
## get_last_grant() immediately after a real on_burnout_accepted() call
## returns a result equal to what compute_next_grant() would have returned
## immediately before that call (preview/real consistency) -- the ADR's own
## Validation Criteria, verbatim. Also covers the "no active path" recap case
## (Challenge Selection Screen's No Bonus Granted state) and persistence
## across serialize_state()/restore_state().
extends GdUnitTestSuite

const _PATH_COUNTERS: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"pato_streamer_choices_count",
	&"guru_celebryta": &"guru_celebryta_choices_count",
	&"ekspert_niszowy": &"ekspert_niszowy_choices_count",
	&"biznesmen_contentu": &"biznesmen_contentu_choices_count",
}

var _era_count_snapshot: int
var _meta_totals_snapshot: Dictionary
var _last_grant_snapshot: Dictionary


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	_last_grant_snapshot = PrestigeSystem.get_last_grant().duplicate()
	HistoryFlagManager.reset_counter(&"pato_streamer_choices_count")
	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func after_test() -> void:
	HistoryFlagManager.reset_counter(&"pato_streamer_choices_count")
	ClassPathSystem.reset_era_state()
	PrestigeSystem.restore_state({
		"era_count": _era_count_snapshot,
		"meta_bonus_totals": _meta_totals_snapshot,
		"_last_grant": {
			"granted": _last_grant_snapshot["granted"],
			"type": String(_last_grant_snapshot["type"]),
			"amount": _last_grant_snapshot["amount"],
		},
	})
	SaveSystem._autosave_suppressed = false
	SaveSystem._debounce_timer.stop()


func _drive_path_to_tier_1(path_id: StringName) -> void:
	for i: int in 5:
		HistoryFlagManager.increment_counter(_PATH_COUNTERS[path_id])
		ClassPathSystem._on_card_resolved(&"", path_id, &"")


## The core ADR-0017 guarantee: get_last_grant() after a real burnout matches
## what compute_next_grant() would have said immediately before it, using the
## same pre-reset path_id/tier a real caller would capture.
func test_get_last_grant_matches_preview_taken_immediately_before() -> void:
	_drive_path_to_tier_1(&"pato_streamer")
	var path_id: StringName = ClassPathSystem.get_active_path()
	var tier: int = ClassPathSystem.get_tier(path_id)
	var preview: Dictionary = PrestigeSystem.compute_next_grant(path_id, tier)

	PrestigeSystem.on_burnout_accepted()

	var last_grant: Dictionary = PrestigeSystem.get_last_grant()
	assert_dict(last_grant).override_failure_message(
		"get_last_grant() must exactly match the preview taken immediately before on_burnout_accepted()"
	).is_equal(preview)


## No active path -> get_last_grant() reports granted: false, not an
## approximated/inferred zero (Challenge Selection Screen's No Bonus Granted
## state depends on this being an explicit flag).
func test_no_active_path_burnout_last_grant_is_granted_false() -> void:
	ClassPathSystem.reset_era_state()  # ensure no active path
	assert_str(String(ClassPathSystem.get_active_path())).is_equal("")

	PrestigeSystem.on_burnout_accepted()

	var last_grant: Dictionary = PrestigeSystem.get_last_grant()
	assert_bool(last_grant["granted"]).is_false()


## Persists across serialize_state()/restore_state() -- if the app closes
## between era_transitioned firing and the Challenge Selection screen being
## confirmed, the recap must still be correct on the next boot.
func test_last_grant_survives_serialize_and_restore_round_trip() -> void:
	_drive_path_to_tier_1(&"pato_streamer")
	PrestigeSystem.on_burnout_accepted()
	var before: Dictionary = PrestigeSystem.get_last_grant()

	var serialized: Dictionary = PrestigeSystem.serialize_state()
	PrestigeSystem._last_grant = {"granted": false, "type": &"", "amount": 0.0}  # simulate a fresh load
	PrestigeSystem.restore_state(serialized)

	assert_dict(PrestigeSystem.get_last_grant()).is_equal(before)
