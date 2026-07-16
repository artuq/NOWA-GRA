## Unit tests for Prestige/Checkpoint Story 009 ("Misconfiguration Guard +
## Save Migration", TR-pcs-005, ADR-0012 §3/§6). Covers all 3 acceptance
## criteria in story-009-misconfig-guard-save-migration.md:
##
##   AC-1: a misconfigured BASE_INCREMENT[type] clamps grant_magnitude()'s
##         output to 0.0, no exception, a config warning is logged
##   AC-2: a clamped zero grant never reduces the running total (Core Rule 5)
##   AC-3: a save predating this system (no `prestige` key) defaults
##         era_count/meta_bonus_totals/meta-persistent flags safely
##
## AC-1/AC-2 target PrestigeFormulas — a stateless static utility, no
## Autoload, no setup/teardown state (same precedent as
## prestige_formulas_grant_test.gd/prestige_formulas_stacking_test.gd).
##
## AC-3 targets the real PrestigeSystem Autoload's restore_state() — already
## implemented by Story 001 and, per this story's own Implementation Notes,
## found to already satisfy this AC in full (data.get(key, default) on both
## era_count and meta_bonus_totals, same pattern OnboardingGate/SettingsSystem
## already established). No production change was needed for AC-3; this
## suite's job is to prove that claim, not to drive new behavior. Since
## PrestigeSystem is a live Autoload singleton (ADR-0001, no dependency
## injection by design), each AC-3 test snapshots and restores real state
## around itself — same before_test()/after_test() technique
## prestige_grant_wiring_test.gd and prestige_defer_test.gd already use.
extends GdUnitTestSuite

## Preloaded (not the bare class_name) so the suite parses even before the
## editor has rescanned the global class cache — headless CI/CLI safety, same
## precedent as this directory's other PrestigeFormulas unit suites.
const PrestigeFormulas: GDScript = preload("res://src/core/prestige_formulas.gd")

const _ALL_BONUS_TYPES: Array[StringName] = [
	&"META_REACH_MULT", &"META_SPONSOR_MULT", &"META_HATERS_RESIST", &"META_SPONSOR_FLOOR",
]

var _era_count_snapshot: int
var _meta_totals_snapshot: Dictionary


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()


func after_test() -> void:
	PrestigeSystem.restore_state({
		"era_count": _era_count_snapshot,
		"meta_bonus_totals": _meta_totals_snapshot,
	})


# --- AC-1: misconfigured BASE_INCREMENT clamps to 0.0, warns, no exception ---

## Given: BASE_INCREMENT[type] is misconfigured negative (-0.02, GDD's own
## example value) -- simulated via _clamp_grant()'s explicit base_increment
## parameter, since the real BASE_INCREMENT is a const Dictionary Godot 4.6.3
## refuses to mutate at runtime (verified: "Cannot assign a new value to a
## constant" parse error, both from inside PrestigeFormulas and from an
## external caller) -- there is no seam to actually corrupt the real table,
## by design.
func test_ac1_negative_base_increment_clamps_to_zero_and_warns() -> void:
	var probe: Callable = func() -> void:
		var result: float = PrestigeFormulas._clamp_grant(&"META_REACH_MULT", -0.05, -0.02)
		assert_float(result).is_equal_approx(0.0, 0.0001)
	assert_error(probe).is_push_warning(any_string())


## Edge case named in this story's QA Test Cases: BASE_INCREMENT = 0 exactly
## must also clamp to 0.0 and warn -- not divide-by-zero or any other
## degenerate behavior (grant_magnitude()'s formula has no division at all,
## but the guard's own `<= 0.0` check must still catch the boundary, not just
## strictly-negative values).
func test_ac1_zero_base_increment_clamps_to_zero_and_warns() -> void:
	var probe: Callable = func() -> void:
		var result: float = PrestigeFormulas._clamp_grant(&"META_SPONSOR_MULT", 0.0, 0.0)
		assert_float(result).is_equal_approx(0.0, 0.0001)
	assert_error(probe).is_push_warning(any_string())


## Defensive belt-and-braces branch: base_increment itself is positive (not
## misconfigured) but the pre-clamp raw value is somehow still negative --
## this should be unreachable through the real grant_magnitude() call graph
## (every other F1 factor is non-negative by construction), but _clamp_grant()
## must still catch and clamp it, since it has no way to know WHY raw went
## negative, only that it did.
func test_ac1_positive_base_increment_but_negative_raw_still_clamps_and_warns() -> void:
	var probe: Callable = func() -> void:
		var result: float = PrestigeFormulas._clamp_grant(&"META_HATERS_RESIST", -0.01, 0.015)
		assert_float(result).is_equal_approx(0.0, 0.0001)
	assert_error(probe).is_push_warning(any_string())


## Regression: a normal, correctly-configured positive input must NOT warn
## and must NOT be altered by the clamp -- the guard is silent and inert on
## the happy path, matching every one of the four currently-tuned
## BASE_INCREMENT defaults.
func test_ac1_normal_positive_input_no_warning_and_unclamped() -> void:
	var probe: Callable = func() -> void:
		var result: float = PrestigeFormulas._clamp_grant(&"META_REACH_MULT", 0.1071, 0.02)
		assert_float(result).is_equal_approx(0.1071, 0.0001)
	assert_error(probe).is_success()


## No exception thrown for any of the AC-1 misconfigured inputs above (a bad
## config value degrades gracefully, GDD's own framing) -- confirmed
## implicitly by every test above running to completion and asserting a
## value, but stated explicitly here per this story's own AC-1 wording ("no
## exception").
func test_ac1_misconfigured_inputs_never_throw() -> void:
	assert_float(PrestigeFormulas._clamp_grant(&"META_REACH_MULT", -0.05, -0.02)).is_equal_approx(0.0, 0.0001)
	assert_float(PrestigeFormulas._clamp_grant(&"META_SPONSOR_MULT", 0.0, 0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(PrestigeFormulas._clamp_grant(&"META_SPONSOR_FLOOR", -100.0, -3.0)).is_equal_approx(0.0, 0.0001)


## Confirms the misconfiguration guard's wiring into grant_magnitude() itself
## did not perturb Story 003's F1 math -- reproduces
## prestige_formulas_grant_test.gd's own AC-1 worked example exactly (Tier 1,
## no challenge, first-ever burnout on META_REACH_MULT) against the real,
## always-positive BASE_INCREMENT table.
func test_ac1_real_grant_magnitude_unaffected_by_the_guard_on_valid_input() -> void:
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, true)
	assert_float(grant).is_equal_approx(0.1071, 0.0005)


# --- AC-2: a clamped zero grant does not reduce the running total (Core Rule 5) ---

## Given: a nonzero pre-existing total, below its cap, then a misconfigured
## grant that _clamp_grant() has already reduced to 0.0 (AC-1's own output)
## is applied via apply_stacking_and_cap() -- the total must be byte-for-byte
## unchanged, not merely "not reduced by much".
func test_ac2_clamped_zero_grant_leaves_below_cap_total_unchanged() -> void:
	var current_total: float = 0.30
	var cap: float = PrestigeFormulas.META_BONUS_MAX[&"META_HATERS_RESIST"]
	var clamped_grant: float = PrestigeFormulas._clamp_grant(&"META_HATERS_RESIST", -0.01, -0.015)
	assert_float(clamped_grant).is_equal_approx(0.0, 0.0001)

	var result: float = PrestigeFormulas.apply_stacking_and_cap(&"META_HATERS_RESIST", current_total, clamped_grant, cap)
	assert_float(result).is_equal_approx(current_total, 0.0001)


## Same guarantee at the cap boundary: a total already sitting exactly at its
## cap, receiving a clamped-zero grant, must remain exactly at the cap -- not
## reduced, not overshot.
func test_ac2_clamped_zero_grant_leaves_at_cap_total_unchanged() -> void:
	var cap: float = PrestigeFormulas.META_BONUS_MAX[&"META_SPONSOR_FLOOR"]
	var clamped_grant: float = PrestigeFormulas._clamp_grant(&"META_SPONSOR_FLOOR", -5.0, -3.0)
	assert_float(clamped_grant).is_equal_approx(0.0, 0.0001)

	var result: float = PrestigeFormulas.apply_stacking_and_cap(&"META_SPONSOR_FLOOR", cap, clamped_grant, cap)
	assert_float(result).is_equal_approx(cap, 0.0001)


## End-to-end composition check across all four bonus types: for each type, a
## misconfigured BASE_INCREMENT (simulated via _clamp_grant()'s explicit
## parameter, same technique as AC-1) always resolves to a 0.0 grant that
## apply_stacking_and_cap() then absorbs with zero effect on an arbitrary
## nonzero running total -- proving the two functions compose correctly for
## the misconfiguration scenario this story exists to guard against, not just
## in isolation.
func test_ac2_misconfiguration_guard_composes_with_stacking_cap_across_all_types() -> void:
	var arbitrary_totals: Dictionary[StringName, float] = {
		&"META_REACH_MULT": 0.25,
		&"META_SPONSOR_MULT": 0.10,
		&"META_HATERS_RESIST": 0.05,
		&"META_SPONSOR_FLOOR": 42.0,
	}
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		var current_total: float = arbitrary_totals[bonus_type]
		var cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
		var clamped_grant: float = PrestigeFormulas._clamp_grant(bonus_type, -1.0, -0.5)
		var result: float = PrestigeFormulas.apply_stacking_and_cap(bonus_type, current_total, clamped_grant, cap)
		assert_float(result).override_failure_message(
			"a clamped-zero grant on %s must never reduce its running total (Core Rule 5)" % bonus_type
		).is_equal_approx(current_total, 0.0001)


# --- AC-3: save predating this system (no `prestige` key) -- default-on-missing-key ---

## Given: a save Dictionary with no `prestige`/`era_count`/`meta_bonus_totals`
## keys at all (data == {}, the true first-session/legacy-save case). When:
## PrestigeSystem.restore_state({}) runs. Then: era_count == 0, all 4
## META_BONUS_total[type] == 0.0.
func test_ac3_missing_prestige_key_defaults_era_count_and_all_totals_to_zero() -> void:
	PrestigeSystem.restore_state({})

	assert_int(PrestigeSystem.get_era_count()).is_equal(0)
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).override_failure_message(
			"%s must default to 0.0 when meta_bonus_totals is entirely absent from the save" % bonus_type
		).is_equal_approx(0.0, 0.0001)


## Edge case named in this story's QA Test Cases: partial data where
## era_count IS present but meta_bonus_totals is missing -- each field must
## default INDEPENDENTLY. era_count must take the saved value (not fall back
## to 0 just because a sibling key is missing), while meta_bonus_totals must
## still default to all-zero.
func test_ac3_partial_data_era_count_present_totals_missing_defaults_independently() -> void:
	PrestigeSystem.restore_state({"era_count": 7})

	assert_int(PrestigeSystem.get_era_count()).override_failure_message(
		"era_count must take the saved value even when meta_bonus_totals is missing from the same Dictionary"
	).is_equal(7)
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).override_failure_message(
			"%s must still default to 0.0 when only meta_bonus_totals (not era_count) is missing" % bonus_type
		).is_equal_approx(0.0, 0.0001)


## Symmetric edge case: meta_bonus_totals IS present but era_count is
## missing -- era_count must default to 0 while the totals take their saved
## values, proving the independence holds in both directions, not just one.
func test_ac3_partial_data_totals_present_era_count_missing_defaults_independently() -> void:
	PrestigeSystem.restore_state({
		"meta_bonus_totals": {
			"META_REACH_MULT": 0.24,
			"META_SPONSOR_MULT": 0.20,
			"META_HATERS_RESIST": 0.13,
			"META_SPONSOR_FLOOR": 14.57,
		},
	})

	assert_int(PrestigeSystem.get_era_count()).override_failure_message(
		"era_count must default to 0 when absent, even though meta_bonus_totals is present in the same Dictionary"
	).is_equal(0)
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")).is_equal_approx(0.24, 0.0005)
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_SPONSOR_MULT")).is_equal_approx(0.20, 0.0005)
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_HATERS_RESIST")).is_equal_approx(0.13, 0.0005)
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_SPONSOR_FLOOR")).is_equal_approx(14.57, 0.005)


## "No meta-persistent burnout flags exist" (this AC's third clause): per
## ADR-0012 §6, the four first_burnout_bonus_used[type] flags are
## HistoryFlagManager milestones ("prestige.first_burnout_used.{type}"),
## restored through HistoryFlagManager's own existing restore path -- NOT
## something PrestigeSystem.restore_state() sets or clears. Proves that
## restore_state({}) (the missing-`prestige`-key/legacy-save case) never
## calls HistoryFlagManager.set_milestone() on any of the four real flag
## names -- a buggy restore_state() that unconditionally fabricated these
## flags would fail this test.
##
## Leakage-tolerant (same technique as prestige_grant_wiring_test.gd's own
## "Milestone leakage note"): HistoryFlagManager milestones are a one-way
## ratchet shared across the whole test process, so other suites in this same
## run (e.g. prestige_grant_wiring_test.gd) may have already legitimately set
## some of these flags via the real on_burnout_accepted(). Snapshotting each
## flag's has_milestone() value BEFORE the call and asserting it is UNCHANGED
## after -- not asserting an absolute false -- makes this test correct
## regardless of suite execution order or prior milestone state.
func test_ac3_restore_state_does_not_set_any_burnout_flags() -> void:
	var flags_before: Dictionary = {}
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		flags_before[bonus_type] = HistoryFlagManager.has_milestone(
			StringName("prestige.first_burnout_used." + String(bonus_type))
		)

	PrestigeSystem.restore_state({})

	for bonus_type: StringName in _ALL_BONUS_TYPES:
		assert_bool(HistoryFlagManager.has_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))).override_failure_message(
			"restore_state({}) (missing `prestige` key / legacy save) must never set prestige.first_burnout_used.%s -- it must not retroactively fabricate burnout-flag history" % bonus_type
		).is_equal(flags_before[bonus_type])
