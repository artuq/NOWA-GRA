## Integration tests for PrestigeSystem._sweep_era_local_flags() (Story 007,
## "Flag Classification Sweep", TR-pcs-004, ADR-0012 §5, GDD Core Rule 7).
##
## Exercises the REAL ResourceManager/HistoryFlagManager/ClassPathSystem/
## PrestigeSystem Autoload singletons, not mocks -- same established
## precedent as this suite's siblings (prestige_orchestration_test.gd,
## prestige_grant_wiring_test.gd's own header comments; none of these
## Autoloads support dependency injection by design, ADR-0001). Each test
## backs up and restores real state around itself.
##
## Known, explicitly out-of-scope gap (see prestige_system.gd's own header
## comment for the full rationale): _sweep_era_local_flags() does NOT clear
## "active Challenge flags". ChallengeSystem does not exist yet (TR-pcs-007,
## no ADR -- already flagged as an open gap in ADR-0012's own Status line),
## the quick-spec's HistoryFlagManager.set_flag() is not a real method on
## this codebase's HistoryFlagManager, and HistoryFlagManager's real
## milestone API is an intentional one-way ratchet with no unset mechanism
## -- there is no concrete flag set for this sweep to clear yet, and no
## clear-by-prefix API to invent one against a naming convention alone. This
## suite does not fabricate a passing assertion for that half of AC-1; it is
## deferred to whichever future story implements ChallengeSystem for real,
## same precedent as Story 001's ChallengeSystem.get_combined_meta_multiplier()
## stub.
extends GdUnitTestSuite

const _PATO_COUNTER: StringName = &"pato_streamer_choices_count"
const _ALL_RESOURCE_KEYS: Array[StringName] = [&"Cringe", &"Morale", &"Haters", &"Reach", &"Sponsors"]
const _ALL_BONUS_TYPES: Array[StringName] = [
	&"META_REACH_MULT", &"META_SPONSOR_MULT", &"META_HATERS_RESIST", &"META_SPONSOR_FLOOR",
]

var _era_count_snapshot: int
var _meta_totals_snapshot: Dictionary
var _resource_snapshot: Dictionary


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	_resource_snapshot = {}
	for key: StringName in _ALL_RESOURCE_KEYS:
		_resource_snapshot[key] = ResourceManager.get_resource(key)
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	PrestigeSystem._deferred_this_era = false
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func after_test() -> void:
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	PrestigeSystem._deferred_this_era = false
	PrestigeSystem.restore_state({
		"era_count": _era_count_snapshot,
		"meta_bonus_totals": _meta_totals_snapshot,
	})
	for key: StringName in _ALL_RESOURCE_KEYS:
		_set_resource(key, _resource_snapshot[key])
	SaveSystem._autosave_suppressed = false
	SaveSystem._debounce_timer.stop()


func _set_resource(key: StringName, value: float) -> void:
	ResourceManager.apply_delta({key: value - ResourceManager.get_resource(key)})


## Drives the REAL ClassPathSystem to Tier 3 for pato_streamer: 15 resolved
## cards * 4.0 affiliation each = 60.0, the Tier-3 threshold -- same
## technique as prestige_orchestration_test.gd's _drive_pato_to_tier_3().
func _drive_pato_to_tier_3() -> void:
	for i: int in 15:
		HistoryFlagManager.increment_counter(_PATO_COUNTER)
		ClassPathSystem._on_card_resolved(&"", &"pato_streamer", &"")


# --- AC-1: era-local flags cleared ---

## GIVEN concrete era-local state (all 5 resources nonzero, pato_streamer
## affiliation/tier at Tier 3, its counter at a nonzero value,
## _deferred_this_era=true), WHEN the flag sweep completes (via the real
## on_burnout_accepted()), THEN all 5 resources are at era-start defaults,
## Class Path affiliation/tier are zeroed, the counter is 0, and
## _deferred_this_era=false. The challenge-flag portion of this AC is out of
## scope -- see this file's header comment.
func test_ac1_era_local_state_cleared_to_defaults() -> void:
	for key: StringName in _ALL_RESOURCE_KEYS:
		_set_resource(key, 42.0)
	_drive_pato_to_tier_3()
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(3)
	assert_float(ClassPathSystem.get_affiliation(&"pato_streamer")).is_equal_approx(60.0, 0.0001)
	assert_int(HistoryFlagManager.get_counter(_PATO_COUNTER)).is_equal(15)
	PrestigeSystem._deferred_this_era = true

	PrestigeSystem.on_burnout_accepted()

	assert_float(ResourceManager.get_resource(&"Cringe")).override_failure_message(
		"Cringe must reset to its era-start default (0.0)"
	).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Morale")).override_failure_message(
		"Morale must reset to its era-start default (100.0)"
	).is_equal(100.0)
	assert_float(ResourceManager.get_resource(&"Haters")).override_failure_message(
		"Haters must reset to its era-start default (0.0)"
	).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Reach")).override_failure_message(
		"Reach must reset to its era-start default (0.0)"
	).is_equal(0.0)
	# Sponsors: pato_streamer grants META_REACH_MULT, not META_SPONSOR_FLOOR,
	# so no active override applies this era -- Sponsors lands at the sweep's
	# own default (0.0). AC-3 below covers the override case separately.
	assert_float(ResourceManager.get_resource(&"Sponsors")).override_failure_message(
		"Sponsors must reset to its era-start default (0.0) when no META_SPONSOR_FLOOR override applies"
	).is_equal(0.0)

	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).override_failure_message(
		"Class Path tier must be zeroed -- already covered by reset_era_state(), not this sweep, but must still hold after the full sequence"
	).is_equal(0)
	assert_float(ClassPathSystem.get_affiliation(&"pato_streamer")).is_equal_approx(0.0, 0.0001)
	assert_int(HistoryFlagManager.get_counter(_PATO_COUNTER)).override_failure_message(
		"pato_streamer_choices_count must reset to 0"
	).is_equal(0)

	assert_bool(PrestigeSystem._deferred_this_era).override_failure_message(
		"_deferred_this_era must be cleared to false by the sweep"
	).is_false()


## Edge case (QA Test Cases, AC-1): a resource already sitting exactly at its
## era-start default must not error and must remain at that default -- the
## sweep is idempotent, not a "must actually change" assertion.
func test_ac1_edge_resource_already_at_default_is_idempotent() -> void:
	_set_resource(&"Cringe", 0.0)
	_set_resource(&"Morale", 100.0)
	_set_resource(&"Haters", 0.0)
	_set_resource(&"Reach", 0.0)
	_set_resource(&"Sponsors", 0.0)

	PrestigeSystem.on_burnout_accepted()

	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal(100.0)
	assert_float(ResourceManager.get_resource(&"Haters")).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal(0.0)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal(0.0)


# --- AC-2: meta-persistent flags preserved ---

## GIVEN the same kind of transition, THEN era_count increments (via Story
## 001's own step, not this sweep), all four META_BONUS_total[type] reflect
## only the grant machinery's own math (i.e. the sweep never resets/zeroes
## them), pato_streamer's best_tier milestone and burnout_accepted_era_N are
## set and preserved, and first_burnout_bonus_used/variety_bonus_used are
## preserved at whatever value this transition left them.
func test_ac2_meta_persistent_state_preserved_through_the_sweep() -> void:
	_drive_pato_to_tier_3()
	var era_before: int = PrestigeSystem.era_count
	var was_first: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_REACH_MULT")
	var expected_grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 3, 1.0, was_first)
	var total_before: float = PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")

	# Forces the other three types to exactly 0.0 immediately before the
	# transition -- guarantees _check_variety_bonus()'s "all four nonzero"
	# precondition (Core Rule 4c) cannot possibly fire on THIS call, making
	# this test's "other types unaffected by the sweep" assertions
	# deterministic regardless of what any earlier test in this run already
	# granted (same leakage concern prestige_grant_wiring_test.gd's own header
	# comment documents). This isolates the sweep's own contract (never
	# touches meta_bonus_totals) from Story 003/004's separate variety-bonus
	# machinery, which is not this story's concern.
	PrestigeSystem.restore_state({
		"era_count": era_before,
		"meta_bonus_totals": {
			"META_REACH_MULT": total_before,
			"META_SPONSOR_MULT": 0.0,
			"META_HATERS_RESIST": 0.0,
			"META_SPONSOR_FLOOR": 0.0,
		},
	})

	PrestigeSystem.on_burnout_accepted()

	assert_int(PrestigeSystem.era_count).override_failure_message(
		"era_count must be incremented and preserved (Story 001's own step)"
	).is_equal(era_before + 1)

	# The sweep must not have zeroed/altered META_REACH_MULT_total beyond what
	# the grant machinery itself (Story 003/004, already tested elsewhere)
	# produced -- proving the sweep never touches meta_bonus_totals.
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")).override_failure_message(
		"the sweep must never reset/alter meta_bonus_totals -- the final value must equal current_total + this era's own grant, nothing more, nothing less"
	).is_equal_approx(total_before + expected_grant, 0.0001)
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		if bonus_type == &"META_REACH_MULT":
			continue
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).override_failure_message(
			"type %s must remain exactly 0.0 -- forced to 0.0 immediately before the transition, and this transition only grants META_REACH_MULT (variety bonus cannot fire, see this test's setup comment) -- the sweep must not zero-or-otherwise touch a meta-persistent total" % bonus_type
		).is_equal_approx(0.0, 0.0001)

	assert_bool(HistoryFlagManager.has_milestone(StringName("class_path.pato_streamer.best_tier.3"))).override_failure_message(
		"pato_streamer's best_tier milestone (written by reset_era_state(), ADR-0010) must survive the sweep"
	).is_true()
	assert_bool(HistoryFlagManager.has_milestone(StringName("burnout_accepted_era_" + str(era_before + 1)))).override_failure_message(
		"burnout_accepted_era_N (N = the just-completed era) must be set by on_burnout_accepted() itself (after era_count += 1) and preserved by the sweep -- same meta-persistent milestone pattern as Choice B's burnout_deferred_era_N (prestige_defer_test.gd's own AC-3)"
	).is_true()

	# first_burnout_bonus_used[META_REACH_MULT]: preserved (set true by this
	# era's grant if it wasn't already) -- the sweep must not unset it.
	# variety_bonus_used is deliberately not asserted here: this test's own
	# setup forces the other three types to exactly 0.0 specifically so
	# _check_variety_bonus() cannot fire on this call (see setup comment
	# above), so this test has no basis to assert that milestone's value
	# either way -- it is covered by prestige_grant_wiring_test.gd instead.
	assert_bool(HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_REACH_MULT")).override_failure_message(
		"first_burnout_bonus_used[META_REACH_MULT] must be true after this era's grant consumed it (or already was true) -- the sweep must not unset it"
	).is_true()


# --- AC-3 (load-bearing): sweep-then-override ordering, spy-verified ---

## GIVEN META_SPONSOR_FLOOR_total=9.0 at the moment the sweep runs, WHEN both
## the flag sweep and F3d's override resolve together, THEN Sponsors ends at
## 9 (F3d's override), not 0 (the sweep's own default) -- and, critically,
## the ORDER is proven directly: a spy on the REAL ResourceManager.
## resource_changed signal captures every Sponsors write in the order it
## actually happened. The sweep's default write (new_value == 0.0) must be
## observed strictly before F3d's override write (new_value == 9.0) -- an
## implementation that special-cased Sponsors out of the sweep's default
## write (making only the end-state assertion pass) would fail this test,
## because it would never produce the first (0.0) emission at all.
func test_ac3_sweep_default_write_observed_before_f3d_override_write() -> void:
	PrestigeSystem.restore_state({
		"era_count": PrestigeSystem.era_count,
		"meta_bonus_totals": {"META_SPONSOR_FLOOR": 9.0},
	})
	_set_resource(&"Sponsors", 50.0)

	# Array, not a plain Dictionary/int -- GDScript lambdas capture outer
	# locals BY VALUE, same pattern as prestige_orchestration_test.gd's own
	# signal-spy tests (an Array is a reference type, so appends inside the
	# closure propagate back out to this function's scope).
	var sponsors_writes: Array = []
	var spy: Callable = func(res_name: StringName, new_value: float, _old_value: float) -> void:
		if res_name == &"Sponsors":
			sponsors_writes.append(new_value)
	ResourceManager.resource_changed.connect(spy)

	PrestigeSystem.on_burnout_accepted()

	ResourceManager.resource_changed.disconnect(spy)

	assert_int(sponsors_writes.size()).override_failure_message(
		"Sponsors must be written exactly twice in one accepted burnout: the sweep's own default, then F3d's override, as two independently observable resource_changed emissions"
	).is_equal(2)
	assert_float(sponsors_writes[0]).override_failure_message(
		"the FIRST Sponsors write observed must be the sweep's own default (0.0) -- this is the call-order proof, not just the final value"
	).is_equal(0.0)
	assert_float(sponsors_writes[1]).override_failure_message(
		"the SECOND Sponsors write observed must be F3d's override (9.0), strictly after the sweep's default"
	).is_equal(9.0)
	assert_float(ResourceManager.get_resource(&"Sponsors")).override_failure_message(
		"Sponsors must end at F3d's override value (9), not the sweep's own default (0)"
	).is_equal(9.0)


## Supplementary coverage for the QA Test Cases' documented edge case:
## META_SPONSOR_FLOOR_total=0.0 makes the sweep's default (0) and F3d's
## override (0) coincide, so this case ALONE cannot distinguish correct
## ordering from a broken implementation (the story's own QA notes are
## explicit that AC-3 must not substitute this case as "equivalent
## coverage"). Kept here only as defense-in-depth, proving TWO writes still
## occur even when their values are indistinguishable -- i.e. the code path
## is genuinely exercised in both branches of sponsors_era_start_override(),
## not short-circuited when the override would be a no-op.
func test_ac3_edge_zero_floor_still_produces_two_writes_but_cannot_alone_prove_order() -> void:
	PrestigeSystem.restore_state({
		"era_count": PrestigeSystem.era_count,
		"meta_bonus_totals": {"META_SPONSOR_FLOOR": 0.0},
	})
	_set_resource(&"Sponsors", 50.0)

	var sponsors_writes: Array = []
	var spy: Callable = func(res_name: StringName, new_value: float, _old_value: float) -> void:
		if res_name == &"Sponsors":
			sponsors_writes.append(new_value)
	ResourceManager.resource_changed.connect(spy)

	PrestigeSystem.on_burnout_accepted()

	ResourceManager.resource_changed.disconnect(spy)

	assert_int(sponsors_writes.size()).override_failure_message(
		"both the sweep's default write and F3d's override write must still occur even when META_SPONSOR_FLOOR_total is 0.0 -- the override call site must not be skipped just because its result happens to coincide with the sweep's own default"
	).is_equal(2)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal(0.0)
