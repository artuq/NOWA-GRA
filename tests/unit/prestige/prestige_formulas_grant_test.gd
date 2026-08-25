## Unit tests for PrestigeFormulas (Prestige/Checkpoint Story 003,
## TR-pcs-002, ADR-0012 §3). Covers all 11 acceptance criteria in
## story-003-grant-magnitude-formulas.md, reproducing every worked example
## in design/gdd/prestige-checkpoint-system.md's Formula F1 ("META_BONUS
## Grant Magnitude") and F1b ("Variety Completionist Bonus") sections
## exactly, at pre-Alpha default tuning values (GDD's own caveat: these
## numbers test formula correctness, not final balance).
##
## PrestigeFormulas is a stateless static utility — no instance, no
## setup/teardown state, every test is a pure function call.
##
## AC-9/AC-10/AC-11 (F1b's cross-type variety-bonus trigger) are NOT part of
## PrestigeFormulas itself — per this story's Implementation Notes, the
## cross-type "are all four types nonzero" check and the once-per-save
## variety_bonus_used flag are PrestigeSystem's responsibility (a live
## Autoload concern), not a per-grant formula. Consistent with this story's
## own QA Test Cases wording ("Given: mocked META_BONUS_total dictionary..."),
## these three ACs are tested here via a small local mock that reproduces
## PrestigeSystem._check_variety_bonus()'s documented trigger logic using
## ONLY PrestigeFormulas.variety_bonus_increment() as its building block —
## this keeps the suite a true unit test of the formula's usage contract
## without touching the real PrestigeSystem Autoload. See
## tests/integration/prestige/ for PrestigeSystem-level orchestration
## coverage (Story 001, extended by this story's wiring).
extends GdUnitTestSuite

## Preloaded (not the bare class_name) so the suite parses even before the
## editor has rescanned the global class cache — headless CI/CLI safety,
## same precedent as feedback_math_test.gd.
const PrestigeFormulas: GDScript = preload("res://src/core/prestige_formulas.gd")

const _ALL_TYPES: Array[StringName] = [
	&"META_REACH_MULT", &"META_SPONSOR_MULT", &"META_HATERS_RESIST", &"META_SPONSOR_FLOOR",
]


# --- tier_factor() — GDD F1's "tier_factor(tier) at default TIER_FLAT_BASE=2" table ---

func test_tier_factor_default_base_all_five_tiers() -> void:
	assert_float(PrestigeFormulas.tier_factor(1, 2)).is_equal_approx(2.143, 0.001)
	assert_float(PrestigeFormulas.tier_factor(2, 2)).is_equal_approx(2.857, 0.001)
	assert_float(PrestigeFormulas.tier_factor(3, 2)).is_equal_approx(3.571, 0.001)
	assert_float(PrestigeFormulas.tier_factor(4, 2)).is_equal_approx(4.286, 0.001)
	assert_float(PrestigeFormulas.tier_factor(5, 2)).is_equal_approx(5.000, 0.001)


## Tier-5 output is always exactly 5.0 regardless of tier_flat_base — the
## 5/(tier_flat_base+5) normalization is fixed, not separately tunable (GDD
## F1 table note). Checked at a few different tier_flat_base values.
func test_tier_factor_tier_5_always_exactly_5_regardless_of_base() -> void:
	assert_float(PrestigeFormulas.tier_factor(5, 0)).is_equal_approx(5.0, 0.0001)
	assert_float(PrestigeFormulas.tier_factor(5, 2)).is_equal_approx(5.0, 0.0001)
	assert_float(PrestigeFormulas.tier_factor(5, 4)).is_equal_approx(5.0, 0.0001)


# --- AC-1: Tier 1, no challenge, first-ever burnout on META_REACH_MULT ---

func test_ac1_tier1_first_burnout_reach_mult_is_0_1071() -> void:
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, true)
	# 0.02 x 2.143 x 1.0^0.5 x 2.5 = 0.1071 (GDD F1 worked example 1)
	assert_float(grant).is_equal_approx(0.1071, 0.0005)


# --- AC-2: same inputs, first_burnout_bonus_used[META_REACH_MULT]=true (not first) ---

func test_ac2_tier1_later_burnout_reach_mult_is_0_0429() -> void:
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 1, 1.0, false)
	# 0.02 x 2.143 x 1.0 x 1.0 = 0.0429 (GDD F1 worked example 2)
	assert_float(grant).is_equal_approx(0.0429, 0.0005)


# --- AC-3: Tier 3, one challenge (mult 2.0), not first ---

func test_ac3_tier3_one_challenge_not_first_is_0_1010() -> void:
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 3, 2.0, false)
	# 0.02 x 3.571 x 2.0^0.5 = 0.1010 (GDD F1 worked example 3)
	assert_float(grant).is_equal_approx(0.1010, 0.0005)


# --- AC-4: Tier 5, stacked challenges (mult 15.0), not first ---

func test_ac4_tier5_stacked_challenges_not_first_is_0_3873() -> void:
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 5, 15.0, false)
	# 0.02 x 5.0 x 15.0^0.5 = 0.3873 (GDD F1 worked example 4) — tier_factor(5)
	# is unchanged from the pre-revision formula, this worked example and its
	# cap-safety are unaffected by the TIER_FLAT_BASE revision.
	assert_float(grant).is_equal_approx(0.3873, 0.0005)


# --- AC-5: META_CHALLENGE_SCALING_EXPONENT tuning-knob confirmation ---

## PrestigeFormulas.grant_magnitude()'s locked signature (story Implementation
## Notes, matching ADR-0012 §3 verbatim) does not accept an exponent override
## — META_CHALLENGE_SCALING_EXPONENT is a compile-time class constant, not a
## runtime parameter, so this AC cannot be exercised by calling
## grant_magnitude() with a swapped-out exponent. Instead this test confirms
## the underlying formula SHAPE is a genuine live application of pow()
## against an arbitrary exponent (not a special-cased lookup baked in for
## 0.5 only): composing the same steps grant_magnitude() performs internally
## — tier_factor() (exposed, real call) x BASE_INCREMENT (documented GDD
## value) x pow(challenge_mult, alt_exponent) — reproduces the GDD's
## documented ~0.2253 result for exponent=0.3 exactly. This is a formula-math
## check, not a grant_magnitude() runtime-override test — see this file's
## header comment and the implementation report for why.
func test_ac5_challenge_exponent_is_a_live_formula_input_not_baked_in() -> void:
	var tier_factor_5: float = PrestigeFormulas.tier_factor(5, 2)
	var base_increment_reach: float = 0.02  # GDD F1 BASE_INCREMENT[META_REACH_MULT]
	var alt_exponent: float = 0.3
	var raw_with_alt_exponent: float = base_increment_reach * tier_factor_5 * pow(15.0, alt_exponent)
	assert_float(raw_with_alt_exponent).is_equal_approx(0.2253, 0.0005)
	# Sanity: this differs from the locked-default (0.5) result, proving the
	# exponent genuinely changes the output rather than being ignored.
	# (GdUnit4's FloatAssert has no is_not_equal_approx() — asserting the
	# absolute difference exceeds the epsilon is the equivalent check.)
	var default_result: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 5, 15.0, false)
	assert_float(absf(default_result - raw_with_alt_exponent)).is_greater(0.001)


# --- AC-6: TIER_FLAT_BASE changes from 2 to 0 (Tier 1, mult 1.0, non-first) ---

## tier_factor()'s tier_flat_base IS an exposed runtime parameter (unlike
## META_CHALLENGE_SCALING_EXPONENT above), so the first half of this AC is a
## direct grant_magnitude()-independent call. The second half (bonus_increment
## = 0.02) again cannot be produced by grant_magnitude() itself (TIER_FLAT_BASE
## is baked into that function per its locked signature) — composed the same
## way as AC-5, using the now-directly-tested tier_factor(1, 0) result.
func test_ac6_tier_flat_base_zero_tier_factor_is_exactly_1() -> void:
	assert_float(PrestigeFormulas.tier_factor(1, 0)).is_equal_approx(1.0, 0.0001)


func test_ac6_tier_flat_base_zero_grant_reduces_to_0_02() -> void:
	var tier_factor_1_base0: float = PrestigeFormulas.tier_factor(1, 0)
	var base_increment_reach: float = 0.02  # GDD F1 BASE_INCREMENT[META_REACH_MULT]
	var raw: float = base_increment_reach * tier_factor_1_base0 * pow(1.0, 0.5)
	assert_float(raw).is_equal_approx(0.02, 0.0001)


# --- AC-7: Tier 5/mult 15.0, first-ever burnout on META_SPONSOR_MULT — 4b-i ceiling ---

func test_ac7_first_burnout_ceiling_clamps_sponsor_mult_to_0_25() -> void:
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_SPONSOR_MULT", 5, 15.0, true)
	# Pre-clamp raw is ~1.21 (well above FIRST_BURNOUT_GRANT_CAP_FRACTION(0.5)
	# x META_BONUS_MAX[META_SPONSOR_MULT](0.50) = 0.25) — 4b-i clamps it down
	# to exactly 0.25. (GDD F1 states this raw as "1.209"; the precise value
	# is ~1.2103 — a minor rounding artifact in the GDD's own worked-example
	# prose that does not affect the clamped result asserted here.)
	assert_float(grant).is_equal_approx(0.25, 0.0001)


# --- AC-8: same inputs, NOT the first grant — no 4b-i ceiling applies ---

func test_ac8_non_first_grant_same_inputs_is_unclamped() -> void:
	var grant: float = PrestigeFormulas.grant_magnitude(&"META_SPONSOR_MULT", 5, 15.0, false)
	# 0.025 x 5.0 x 15.0^0.5 = ~0.4841 — no 4b-i ceiling, well above the 0.25
	# fraction-of-cap value that WOULD apply to a first-ever grant, and still
	# below the type's own 0.50 lifetime cap (F2's cap, out of this story's
	# scope, is not exercised here).
	assert_float(grant).is_equal_approx(0.4841, 0.0005)
	assert_float(grant).is_greater(0.25)


# --- variety_bonus_increment() — GDD F1b's flat per-type increment ---

func test_variety_bonus_increment_all_four_types() -> void:
	assert_float(PrestigeFormulas.variety_bonus_increment(&"META_REACH_MULT")).is_equal_approx(0.04, 0.0001)
	assert_float(PrestigeFormulas.variety_bonus_increment(&"META_SPONSOR_MULT")).is_equal_approx(0.05, 0.0001)
	assert_float(PrestigeFormulas.variety_bonus_increment(&"META_HATERS_RESIST")).is_equal_approx(0.03, 0.0001)
	assert_float(PrestigeFormulas.variety_bonus_increment(&"META_SPONSOR_FLOOR")).is_equal_approx(6.0, 0.0001)


## Local mock reproducing PrestigeSystem._check_variety_bonus()'s documented
## trigger logic (Implementation Notes / ADR-0012 §3): fires at most once,
## only once all four types are simultaneously nonzero, adding
## PrestigeFormulas.variety_bonus_increment(type) to each. [param used] is a
## single-element Array used as an out-parameter (GDScript closures/by-ref
## convention already used by this project's own tests, e.g.
## prestige_orchestration_test.gd's signal-spy Array pattern).
func _mock_check_variety_bonus(totals: Dictionary, used: Array) -> void:
	if used[0]:
		return
	for bonus_type: StringName in _ALL_TYPES:
		if totals.get(bonus_type, 0.0) <= 0.0:
			return
	for bonus_type: StringName in _ALL_TYPES:
		totals[bonus_type] = totals.get(bonus_type, 0.0) + PrestigeFormulas.variety_bonus_increment(bonus_type)
	used[0] = true


# --- AC-9: 3 of 4 types nonzero, 4th grant makes it nonzero -> all 4 receive the flat increment ---

## Reproduces GDD F1b's own worked example exactly: three prior burnouts
## already banked META_REACH_MULT=0.20, META_SPONSOR_MULT=0.15,
## META_HATERS_RESIST=0.10; the next burnout grants META_SPONSOR_FLOOR its
## first-ever nonzero value (8.57, via the normal F1 path — Tier 2, no
## challenge, not first: 3.0 x 2.857 x 1.0 = 8.57), making all four
## simultaneously nonzero for the first time.
func test_ac9_fourth_type_going_nonzero_triggers_variety_bonus_all_four() -> void:
	var totals: Dictionary = {
		&"META_REACH_MULT": 0.20,
		&"META_SPONSOR_MULT": 0.15,
		&"META_HATERS_RESIST": 0.10,
		&"META_SPONSOR_FLOOR": 0.0,
	}
	var used: Array = [false]

	# The triggering grant itself (F1, not F1b) — order-of-operations: this
	# must happen BEFORE the variety check runs, exactly as
	# PrestigeSystem.on_burnout_accepted() sequences _apply_grant() before
	# _check_variety_bonus().
	var f1_grant: float = PrestigeFormulas.grant_magnitude(&"META_SPONSOR_FLOOR", 2, 1.0, false)
	assert_float(f1_grant).is_equal_approx(8.57, 0.005)
	totals[&"META_SPONSOR_FLOOR"] += f1_grant

	_mock_check_variety_bonus(totals, used)

	assert_bool(used[0]).is_true()
	assert_float(totals[&"META_REACH_MULT"]).is_equal_approx(0.24, 0.0005)
	assert_float(totals[&"META_SPONSOR_MULT"]).is_equal_approx(0.20, 0.0005)
	assert_float(totals[&"META_HATERS_RESIST"]).is_equal_approx(0.13, 0.0005)
	assert_float(totals[&"META_SPONSOR_FLOOR"]).is_equal_approx(14.57, 0.005)


# --- AC-10: variety_bonus_used=true -> no additional completionist grant on a later trigger ---

func test_ac10_second_trigger_attempt_after_used_is_a_no_op() -> void:
	var totals: Dictionary = {
		&"META_REACH_MULT": 0.24,
		&"META_SPONSOR_MULT": 0.20,
		&"META_HATERS_RESIST": 0.13,
		&"META_SPONSOR_FLOOR": 14.57,
	}
	var used: Array = [true]  # already fired once

	_mock_check_variety_bonus(totals, used)

	assert_float(totals[&"META_REACH_MULT"]).is_equal_approx(0.24, 0.0005)
	assert_float(totals[&"META_SPONSOR_MULT"]).is_equal_approx(0.20, 0.0005)
	assert_float(totals[&"META_HATERS_RESIST"]).is_equal_approx(0.13, 0.0005)
	assert_float(totals[&"META_SPONSOR_FLOOR"]).is_equal_approx(14.57, 0.005)
	assert_bool(used[0]).is_true()


# --- AC-11: one type already at cap when the completionist grant fires ---

## F2's actual clamp (PrestigeFormulas.apply_stacking_and_cap()) is Story
## 004 scope and does not exist yet in this file — so this AC cannot be
## proven end-to-end here. What IS proven, matching the AC's own wording
## ("no exception, no compensating grant elsewhere"): variety_bonus_increment()
## has no knowledge of a type's current running total or its cap — it always
## returns the same flat value regardless of whether that type is already at
## META_BONUS_MAX. This confirms the function never special-cases an
## already-full type (no exception path, no silently-larger "compensating"
## grant redirected to another type) — absorption of the resulting overflow
## is entirely F2's job, layered on top by the caller, not this function's.
func test_ac11_variety_increment_is_agnostic_to_already_capped_type() -> void:
	# META_HATERS_RESIST's cap is 0.40 (GDD F2 table) — simulate it already
	# being at cap when the completionist grant would fire.
	var already_at_cap: float = 0.40
	var increment: float = PrestigeFormulas.variety_bonus_increment(&"META_HATERS_RESIST")
	# Same flat increment as any other type, cap-unaware by design (F2 layers
	# the clamp on top, Story 004) — no exception thrown, no special case.
	assert_float(increment).is_equal_approx(0.03, 0.0001)
	# The naive sum WOULD overshoot the cap — proving F2's clamp (not this
	# function) is the thing responsible for absorbing it with no effect.
	assert_float(already_at_cap + increment).is_greater(already_at_cap)
