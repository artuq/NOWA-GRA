## Integration tests closing 3 BLOCKING gaps found in code review (2026-07-14,
## qa-tester) on Story 003 (META_BONUS Grant Magnitude + Variety Bonus,
## TR-pcs-002, ADR-0012 §3): `tests/unit/prestige/prestige_formulas_grant_test.gd`
## proves `PrestigeFormulas`' math correct in isolation, but nothing exercised
## `PrestigeSystem.on_burnout_accepted()`'s REAL wiring of that math -- the
## variety-bonus cross-type check (`_check_variety_bonus()`) was only ever
## reproduced by a hand-written mock in the unit suite, never invoked; the
## per-type scoping of `first_burnout_bonus_used[type]` was entirely
## untested; and no test drove a real `ClassPathSystem` path through
## `on_burnout_accepted()` end-to-end and checked `meta_bonus_totals`.
##
## Extended for Story 004 (META_BONUS Stacking/Caps + Bonus Type Selection,
## TR-pcs-002, ADR-0012 §3): two further tests cover AC-6 (all four totals
## already at cap, grant fully absorbed, transition still completes) and
## AC-8/AC-9 (no active path -> no grant, totals AND first_burnout flags
## unchanged, reset still proceeds) — both require the real Autoload wiring
## this file already exercises, not just `PrestigeFormulas` in isolation. See
## `tests/unit/prestige/prestige_formulas_stacking_test.gd` for this story's
## pure-formula-level coverage of the remaining ACs.
##
## Milestone leakage note (same accepted precedent as
## class_path_core_test.gd/prestige_orchestration_test.gd's own header
## comments): `HistoryFlagManager` milestones are a one-way ratchet --
## `restore_state()` only ever ADDS milestones, never removes any, so
## `prestige.first_burnout_used.{type}`/`prestige.variety_bonus_used` set by
## this suite (or any earlier suite in the same run) persist for the rest of
## the process. Tests below are written to be correct regardless of prior
## milestone state -- see each test's own comment for how it stays
## leakage-tolerant instead of assuming a clean slate.
extends GdUnitTestSuite

const _ALL_PATHS: Array[StringName] = [
	&"pato_streamer", &"guru_celebryta", &"ekspert_niszowy", &"biznesmen_contentu",
]
const _PATH_COUNTERS: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"pato_streamer_choices_count",
	&"guru_celebryta": &"guru_celebryta_choices_count",
	&"ekspert_niszowy": &"ekspert_niszowy_choices_count",
	&"biznesmen_contentu": &"biznesmen_contentu_choices_count",
}
const _BONUS_TYPE_BY_PATH: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"META_REACH_MULT",
	&"guru_celebryta": &"META_SPONSOR_MULT",
	&"ekspert_niszowy": &"META_HATERS_RESIST",
	&"biznesmen_contentu": &"META_SPONSOR_FLOOR",
}

var _era_count_snapshot: int
var _meta_totals_snapshot: Dictionary


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	for path_id: StringName in _ALL_PATHS:
		HistoryFlagManager.reset_counter(_PATH_COUNTERS[path_id])
	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func after_test() -> void:
	for path_id: StringName in _ALL_PATHS:
		HistoryFlagManager.reset_counter(_PATH_COUNTERS[path_id])
	ClassPathSystem.reset_era_state()
	PrestigeSystem.restore_state({
		"era_count": _era_count_snapshot,
		"meta_bonus_totals": _meta_totals_snapshot,
	})
	SaveSystem._autosave_suppressed = false
	SaveSystem._debounce_timer.stop()


## Drives [param path_id] to Tier 1 (5 resolved cards * 4.0 affiliation each
## = 20.0, the Tier-1 threshold) via the real HistoryFlagManager counter +
## ClassPathSystem._on_card_resolved(), same technique as
## prestige_orchestration_test.gd's _drive_pato_to_tier_3(), generalized to
## all 4 paths.
func _drive_path_to_tier_1(path_id: StringName) -> void:
	for i: int in 5:
		HistoryFlagManager.increment_counter(_PATH_COUNTERS[path_id])
		ClassPathSystem._on_card_resolved(&"", path_id, &"")


# --- Gap 1: end-to-end wiring, real active path -> real meta_bonus_totals ---

## Regression for a BLOCKING code-review finding: nothing previously called
## the real on_burnout_accepted() with a real active ClassPathSystem path and
## checked meta_bonus_totals afterward -- PrestigeFormulas was proven correct
## in isolation, but not that PrestigeSystem actually calls it with the right
## arguments (tier before reset, correct bonus_type-per-path mapping,
## _apply_grant() actually mutating meta_bonus_totals).
##
## Leakage-tolerant: reads the REAL is_first state live before acting, uses
## that same value as PrestigeFormulas' oracle input, instead of assuming a
## clean milestone slate.
func test_on_burnout_accepted_wires_real_grant_into_meta_bonus_totals() -> void:
	_drive_path_to_tier_1(&"pato_streamer")
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(1)

	var was_first: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_REACH_MULT")
	var total_before: float = PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")
	var expected_grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, was_first)

	PrestigeSystem.on_burnout_accepted()

	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")).override_failure_message(
		"on_burnout_accepted() must apply PrestigeFormulas.grant_magnitude()'s exact result to meta_bonus_totals"
	).is_equal_approx(total_before + expected_grant, 0.0001)
	# The milestone must now be set regardless of prior state -- confirms the
	# real _first_burnout_pending()/set_milestone() call path actually ran.
	assert_bool(HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_REACH_MULT")).is_true()


# --- Gap 2: per-type first_burnout_bonus_used isolation ---

## Regression for a BLOCKING code-review finding: no test proved a first
## burnout on one type leaves a DIFFERENT type's first-burnout eligibility
## unaffected -- a bug in _first_burnout_pending()'s per-type key
## construction (e.g. accidentally sharing one flag across all 4 types)
## would silently deny every type after the first burnout of any kind, with
## zero prior coverage to catch it.
##
## Leakage-tolerant: captures guru_celebryta's pending-state BEFORE touching
## pato_streamer, then asserts it is UNCHANGED after -- correct regardless of
## what any earlier test/run already did to either flag.
func test_first_burnout_flag_is_scoped_per_type_not_shared() -> void:
	var guru_pending_before: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_SPONSOR_MULT")

	_drive_path_to_tier_1(&"pato_streamer")
	PrestigeSystem.on_burnout_accepted()
	assert_bool(HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_REACH_MULT")).is_true()

	var guru_pending_after: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_SPONSOR_MULT")
	assert_bool(guru_pending_after).override_failure_message(
		"a first-burnout grant on META_REACH_MULT must never consume META_SPONSOR_MULT's own first-burnout flag -- they are per-type, not shared"
	).is_equal(guru_pending_before)


# --- Gap 3: _check_variety_bonus() real method, cross-type trigger ---

## Regression for a BLOCKING code-review finding: the unit suite's AC-9/10/11
## tests exercised a hand-written _mock_check_variety_bonus() that
## REPRODUCES prestige_system.gd's real logic, never the real method itself
## -- a typo in the real loop/threshold logic would have zero coverage to
## catch it. This test drives all 4 paths to Tier 1 across 4 real
## on_burnout_accepted() calls (each era resets the other paths, so each
## path must be re-driven in its own era) and checks the REAL
## _check_variety_bonus(), invoked only via the real on_burnout_accepted().
##
## Leakage-tolerant: if `prestige.variety_bonus_used` was already set by an
## earlier test/run (fires at most once ever, by design), this test only
## asserts the milestone stays true and all 4 totals stay nonzero -- it does
## not re-assert the exact +variety_bonus_increment() magnitude in that case,
## since Core Rule 4c's "at most once per save" contract means a second
## opportunity genuinely produces no additional grant.
func test_check_variety_bonus_real_method_fires_when_all_four_types_go_nonzero() -> void:
	var variety_used_before: bool = HistoryFlagManager.has_milestone(&"prestige.variety_bonus_used")
	var totals_before_last_grant: Dictionary[StringName, float] = {}

	for i: int in _ALL_PATHS.size():
		var path_id: StringName = _ALL_PATHS[i]
		_drive_path_to_tier_1(path_id)
		if i == _ALL_PATHS.size() - 1:
			# Snapshot immediately before the grant that makes the 4th type
			# nonzero -- this is the exact cycle Core Rule 4c describes.
			for p: StringName in _ALL_PATHS:
				totals_before_last_grant[_BONUS_TYPE_BY_PATH[p]] = PrestigeSystem.get_meta_bonus_total(_BONUS_TYPE_BY_PATH[p])
		PrestigeSystem.on_burnout_accepted()

	assert_bool(HistoryFlagManager.has_milestone(&"prestige.variety_bonus_used")).override_failure_message(
		"the real _check_variety_bonus(), invoked only via on_burnout_accepted(), must have set the milestone once all 4 types went nonzero"
	).is_true()

	for path_id: StringName in _ALL_PATHS:
		var bonus_type: StringName = _BONUS_TYPE_BY_PATH[path_id]
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).override_failure_message(
			"type %s must be nonzero after all 4 paths have granted at least once" % bonus_type
		).is_greater(0.0)

	if not variety_used_before:
		# First time this ever fired in this process -- the 4th type's total
		# must include BOTH its own tier-1 grant AND the flat variety
		# increment on top (F1b), since both apply in the same
		# on_burnout_accepted() call per Core Rule 4c.
		var fourth_type: StringName = _BONUS_TYPE_BY_PATH[_ALL_PATHS[3]]
		var variety_increment: float = PrestigeFormulas.variety_bonus_increment(fourth_type)
		assert_float(PrestigeSystem.get_meta_bonus_total(fourth_type)).override_failure_message(
			"the 4th type's total must reflect its own grant plus the variety bonus increment stacked on top in the same cycle"
		).is_greater(totals_before_last_grant[fourth_type] + variety_increment * 0.5)


# --- Story 004 AC-6: all four totals already at cap -> grant fully absorbed, reset still proceeds ---

## Regression coverage for Story 004 (META_BONUS Stacking/Caps, TR-pcs-002)
## AC-6: mocks all-4-totals-at-cap state via restore_state() (the technique
## this story's own QA Test Cases section prescribes -- "mocked
## all-4-totals-at-cap state"), then drives a real active path through the
## real on_burnout_accepted() and asserts BOTH halves in one test, per the
## AC's own wording: era_count increments / era_transitioned fires exactly
## once (the reset half) AND every total remains exactly at its cap (the
## absorption half) -- proving PrestigeFormulas.apply_stacking_and_cap(),
## wired through _apply_grant()/_check_variety_bonus(), never softlocks the
## transition even when every type has zero room left to grant into.
func test_on_burnout_accepted_with_all_totals_at_cap_absorbs_grant_and_still_transitions() -> void:
	var capped_totals: Dictionary = {
		"META_REACH_MULT": PrestigeFormulas.META_BONUS_MAX[&"META_REACH_MULT"],
		"META_SPONSOR_MULT": PrestigeFormulas.META_BONUS_MAX[&"META_SPONSOR_MULT"],
		"META_HATERS_RESIST": PrestigeFormulas.META_BONUS_MAX[&"META_HATERS_RESIST"],
		"META_SPONSOR_FLOOR": PrestigeFormulas.META_BONUS_MAX[&"META_SPONSOR_FLOOR"],
	}
	PrestigeSystem.restore_state({"era_count": PrestigeSystem.era_count, "meta_bonus_totals": capped_totals})
	_drive_path_to_tier_1(&"pato_streamer")

	# Array, not a plain int/bool -- GDScript lambdas capture outer locals BY
	# VALUE, same pattern as prestige_orchestration_test.gd's signal-spy tests.
	var emissions: Array = []
	var spy: Callable = func() -> void: emissions.append(true)
	PrestigeSystem.era_transitioned.connect(spy)

	var era_before: int = PrestigeSystem.era_count
	PrestigeSystem.on_burnout_accepted()

	PrestigeSystem.era_transitioned.disconnect(spy)

	assert_int(emissions.size()).override_failure_message(
		"era_transitioned must still fire exactly once even when the grant is fully absorbed by the cap"
	).is_equal(1)
	assert_int(PrestigeSystem.era_count).override_failure_message(
		"era_count must still increment even when the grant is fully absorbed -- the transition is Cringe-driven, not reward-driven"
	).is_equal(era_before + 1)

	for path_id: StringName in _ALL_PATHS:
		var bonus_type: StringName = _BONUS_TYPE_BY_PATH[path_id]
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).override_failure_message(
			"type %s must remain exactly at its cap -- the grant must be fully absorbed with no overshoot" % bonus_type
		).is_equal_approx(PrestigeFormulas.META_BONUS_MAX[bonus_type], 0.0001)


# --- Story 004 AC-8/AC-9: no active path -> no grant, totals AND first-burnout flags unchanged, reset still proceeds ---

## Regression coverage for Story 004 AC-8 (all four totals unchanged, era
## still resets) and AC-9 (a zero-reward burnout never consumes a
## first-burnout flag that was never spent) -- both require driving the real
## on_burnout_accepted() with ClassPathSystem.get_active_path() == "" and
## inspecting real Autoload state (era_count, HistoryFlagManager milestones),
## none of which prestige_formulas_stacking_test.gd's PrestigeFormulas-only
## unit tests can exercise (see that file's header comment). before_test()
## already leaves no active path (ClassPathSystem.reset_era_state()), same
## precondition prestige_orchestration_test.gd's own Story 001
## no-active-path test relies on.
##
## Leakage-tolerant: captures every total AND every first_burnout milestone's
## state BEFORE the no-path resolution, and asserts byte-for-byte equality
## after -- correct regardless of what any earlier test in this run already
## granted/set (same technique this file's other tests already use).
func test_on_burnout_accepted_no_active_path_grants_nothing_and_still_resets() -> void:
	assert_that(ClassPathSystem.get_active_path()).is_equal(&"")

	var totals_before: Dictionary = {}
	var flags_before: Dictionary = {}
	for path_id: StringName in _ALL_PATHS:
		var bonus_type: StringName = _BONUS_TYPE_BY_PATH[path_id]
		totals_before[bonus_type] = PrestigeSystem.get_meta_bonus_total(bonus_type)
		flags_before[bonus_type] = HistoryFlagManager.has_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))
	var era_before: int = PrestigeSystem.era_count

	PrestigeSystem.on_burnout_accepted()

	assert_int(PrestigeSystem.era_count).override_failure_message(
		"a zero-reward burnout (no active path) must still increment era_count -- the reset is Cringe-driven, not reward-driven"
	).is_equal(era_before + 1)

	for path_id: StringName in _ALL_PATHS:
		var bonus_type: StringName = _BONUS_TYPE_BY_PATH[path_id]
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).override_failure_message(
			"type %s must be unchanged when no active path exists to grant a bonus" % bonus_type
		).is_equal_approx(totals_before[bonus_type], 0.0001)
		assert_bool(HistoryFlagManager.has_milestone(StringName("prestige.first_burnout_used." + String(bonus_type)))).override_failure_message(
			"a zero-reward burnout must never consume first_burnout_bonus_used[%s] -- it was never spent" % bonus_type
		).is_equal(flags_before[bonus_type])
