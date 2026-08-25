## Unit tests for PrestigeFormulas.apply_stacking_and_cap() (Prestige/
## Checkpoint Story 004, TR-pcs-002, ADR-0012 §3). Covers the 7 of
## story-004-stacking-caps-type-selection.md's 9 acceptance criteria that are
## pure-formula-level: AC-1/AC-2 (additive stacking below/at cap), AC-3
## (independent per-type totals), AC-4/AC-5 (cap holds under repeated
## grants), AC-7 (bonus-type-to-cap mapping correctness).
##
## AC-6 ("all four totals already at cap, Choice A still resolves normally
## with the grant fully absorbed") and AC-8/AC-9 ("no active path -> no
## grant, all totals AND all first_burnout_bonus_used[type] flags unchanged,
## era still resets") are NOT covered here — both require driving the real
## `PrestigeSystem.on_burnout_accepted()` end-to-end (era_count increment,
## era_transitioned signal, HistoryFlagManager milestone state), none of
## which `PrestigeFormulas` (a stateless static utility with no Autoload
## access) can observe or influence. Same precedent as
## prestige_formulas_grant_test.gd's header comment for its own AC-9/10/11.
## See tests/integration/prestige/prestige_grant_wiring_test.gd for AC-6/
## AC-8/AC-9 coverage.
extends GdUnitTestSuite

## Preloaded (not the bare class_name) so the suite parses even before the
## editor has rescanned the global class cache — headless CI/CLI safety,
## same precedent as prestige_formulas_grant_test.gd.
const PrestigeFormulas: GDScript = preload("res://src/core/prestige_formulas.gd")

## Path -> bonus-type mapping (Core Rule 3 / this story's Implementation
## Notes). Deliberately a local copy, not a reference into
## PrestigeSystem._BONUS_TYPE_BY_PATH — that mapping's correctness is
## PrestigeSystem's own concern (already satisfied by Story 003, per this
## story's Context section) and is exercised end-to-end by
## prestige_grant_wiring_test.gd. This suite only verifies the mapping
## PrestigeFormulas.apply_stacking_and_cap()'s callers rely on: that each
## path's bonus type has its own entry in META_BONUS_MAX and that stacking/
## capping never crosses between types.
const _BONUS_TYPE_BY_PATH: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"META_REACH_MULT",
	&"guru_celebryta": &"META_SPONSOR_MULT",
	&"ekspert_niszowy": &"META_HATERS_RESIST",
	&"biznesmen_contentu": &"META_SPONSOR_FLOOR",
}


# --- AC-1: grant overshoots the cap -> clamps exactly, absorbing the excess ---

## GDD's own worked example: META_REACH_MULT_total_prev=0.4944, a further
## grant of 0.1010 (Tier-3/one-challenge worked example from Story 003's F1
## suite) pushes the naive sum to 0.5954 — well past the 0.50 cap — so the
## clamp must land on exactly 0.50, absorbing 0.0954 with no effect.
func test_ac1_grant_overshooting_cap_clamps_exactly_no_overshoot() -> void:
	var result: float = PrestigeFormulas.apply_stacking_and_cap(&"META_REACH_MULT", 0.4944, 0.1010, 0.50)
	assert_float(result).is_equal_approx(0.50, 0.0001)


## Edge case named in this story's QA Test Cases: a grant that lands EXACTLY
## on the cap must neither absorb anything (it wasn't overshooting) nor
## overshoot past it — the boundary itself is inclusive.
func test_ac1_grant_landing_exactly_on_cap_is_unclamped_boundary() -> void:
	var result: float = PrestigeFormulas.apply_stacking_and_cap(&"META_HATERS_RESIST", 0.30, 0.10, 0.40)
	assert_float(result).is_equal_approx(0.40, 0.0001)


# --- AC-2: two grants across separate eras, both below cap, stack additively ---

## GDD's own worked example: starting at total=0.0, a first-ever grant of
## 0.1071 (Story 003's AC-1 worked example) followed by a later
## Tier-5-stacked-challenge grant of 0.3873 (Story 003's AC-4 worked
## example) must sum to exactly 0.4944 — still below the 0.50 cap, so no
## absorption at either step.
func test_ac2_two_below_cap_grants_stack_additively_across_eras() -> void:
	var after_first: float = PrestigeFormulas.apply_stacking_and_cap(&"META_REACH_MULT", 0.0, 0.1071, 0.50)
	assert_float(after_first).is_equal_approx(0.1071, 0.0005)

	var after_second: float = PrestigeFormulas.apply_stacking_and_cap(&"META_REACH_MULT", after_first, 0.3873, 0.50)
	assert_float(after_second).is_equal_approx(0.4944, 0.0005)


# --- AC-3: independent per-type totals — no cross-type leakage ---

## Simulates a player accepting burnout once on pato_streamer
## (META_REACH_MULT) and once, in a different era, on guru_celebryta
## (META_SPONSOR_MULT) — both totals must hold their own nonzero values
## simultaneously, and applying a grant to one type must never be visible on
## the other's total (they are separate Dictionary entries, but this proves
## apply_stacking_and_cap() itself never conflates its [param bonus_type]
## argument with any shared/global state).
func test_ac3_independent_per_type_totals_no_cross_leakage() -> void:
	var totals: Dictionary[StringName, float] = {}

	var reach_grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, true)
	totals[&"META_REACH_MULT"] = PrestigeFormulas.apply_stacking_and_cap(
		&"META_REACH_MULT", totals.get(&"META_REACH_MULT", 0.0), reach_grant, PrestigeFormulas.META_BONUS_MAX[&"META_REACH_MULT"]
	)

	var sponsor_grant: float = PrestigeFormulas.grant_magnitude(&"META_SPONSOR_MULT", 1, 1.0, true)
	totals[&"META_SPONSOR_MULT"] = PrestigeFormulas.apply_stacking_and_cap(
		&"META_SPONSOR_MULT", totals.get(&"META_SPONSOR_MULT", 0.0), sponsor_grant, PrestigeFormulas.META_BONUS_MAX[&"META_SPONSOR_MULT"]
	)

	assert_float(totals[&"META_REACH_MULT"]).override_failure_message(
		"META_REACH_MULT must hold only its own grant, unaffected by the META_SPONSOR_MULT grant applied after it"
	).is_equal_approx(reach_grant, 0.0001)
	assert_float(totals[&"META_SPONSOR_MULT"]).override_failure_message(
		"META_SPONSOR_MULT must hold only its own grant, unaffected by the META_REACH_MULT grant applied before it"
	).is_equal_approx(sponsor_grant, 0.0001)
	# Neither total "multiplies into" the other (story wording) — both are
	# independently nonzero and each equals only its own grant (asserted
	# above), never a product or sum involving the other type's grant.
	assert_float(totals[&"META_REACH_MULT"]).is_greater(0.0)
	assert_float(totals[&"META_SPONSOR_MULT"]).is_greater(0.0)


# --- AC-4/AC-5: a type already at its cap absorbs any further grant with zero effect ---

func test_ac4_haters_resist_already_at_cap_absorbs_further_grant() -> void:
	var cap: float = PrestigeFormulas.META_BONUS_MAX[&"META_HATERS_RESIST"]  # 0.40
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_HATERS_RESIST", 3, 1.0, false)
	var result: float = PrestigeFormulas.apply_stacking_and_cap(&"META_HATERS_RESIST", cap, grant, cap)
	assert_float(result).is_equal_approx(cap, 0.0001)


func test_ac5_sponsor_mult_already_at_cap_absorbs_further_grant() -> void:
	var cap: float = PrestigeFormulas.META_BONUS_MAX[&"META_SPONSOR_MULT"]  # 0.50
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_SPONSOR_MULT", 5, 1.0, false)
	var result: float = PrestigeFormulas.apply_stacking_and_cap(&"META_SPONSOR_MULT", cap, grant, cap)
	assert_float(result).is_equal_approx(cap, 0.0001)


## Repeated grants on an already-capped type must never creep upward, even
## by float rounding error, across multiple successive applications.
func test_repeated_grants_on_capped_type_never_creep_upward() -> void:
	var cap: float = PrestigeFormulas.META_BONUS_MAX[&"META_SPONSOR_FLOOR"]  # 100.0
	var running: float = cap
	for i: int in 5:
		running = PrestigeFormulas.apply_stacking_and_cap(&"META_SPONSOR_FLOOR", running, 25.0, cap)
	assert_float(running).is_equal_approx(cap, 0.0001)


# --- AC-7: each path's mapped bonus type has its own cap; stacking never targets the wrong one ---

## Verifies the per-type cap table this story's clamp relies on has exactly
## one entry per Class Path's mapped bonus type (Core Rule 3 — the mapping
## itself is Story 003's already-covered PrestigeSystem._BONUS_TYPE_BY_PATH,
## not duplicated here), and that apply_stacking_and_cap() clamps each type
## at ITS OWN cap, never another type's.
func test_ac7_each_paths_bonus_type_clamps_at_its_own_cap_only() -> void:
	for path_id: StringName in _BONUS_TYPE_BY_PATH:
		var bonus_type: StringName = _BONUS_TYPE_BY_PATH[path_id]
		assert_bool(PrestigeFormulas.META_BONUS_MAX.has(bonus_type)).override_failure_message(
			"path %s's mapped bonus type %s must have its own META_BONUS_MAX entry" % [path_id, bonus_type]
		).is_true()

		var own_cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
		var result: float = PrestigeFormulas.apply_stacking_and_cap(bonus_type, 0.0, own_cap + 999.0, own_cap)
		assert_float(result).override_failure_message(
			"a grant to %s must clamp at %s's own cap (%f), never another type's" % [bonus_type, bonus_type, own_cap]
		).is_equal_approx(own_cap, 0.0001)


## The 4 mapped bonus types' caps are deliberately non-uniform (F2 table) —
## confirms this suite isn't accidentally passing because all four caps
## happen to be equal.
func test_ac7_the_four_mapped_bonus_types_have_distinct_non_uniform_caps() -> void:
	var caps: Array[float] = []
	for path_id: StringName in _BONUS_TYPE_BY_PATH:
		caps.append(PrestigeFormulas.META_BONUS_MAX[_BONUS_TYPE_BY_PATH[path_id]])
	# META_SPONSOR_FLOOR's cap (100.0) is on an entirely different scale from
	# the three multiplier types (0.40-0.50) — proves the table is genuinely
	# per-type, not a single shared constant.
	assert_float(caps.max()).is_greater(caps.min())
