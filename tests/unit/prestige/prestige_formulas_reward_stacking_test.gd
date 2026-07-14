## Unit tests for PrestigeFormulas' F3a-d final-reward-stacking application
## points (Prestige/Checkpoint Story 005, TR-pcs-002, ADR-0012 §3). Covers
## all 8 acceptance criteria in
## story-005-final-reward-stacking.md, reproducing every worked example in
## design/gdd/prestige-checkpoint-system.md's Formula F3a-d sections exactly.
##
## PrestigeFormulas is a stateless static utility — no instance, no
## setup/teardown state, every test is a pure function call.
##
## AC-4's `class_path_sponsor_multiplier` argument is a MOCKED float, not a
## real `ClassPathSystem.get_active_sponsor_multiplier()` (ADR-0010 §5a) call
## — that call site's wiring at card resolution is a separate Class Path
## System epic concern, explicitly out of scope for this story (per the
## story's own Out of Scope section and QA Test Cases wording).
##
## AC-8's offline/online Haters-resistance parity check is reproduced via a
## local mock of `OfflineProgressSystem.simulate_offline()`'s Haters-accrual
## step (built only from `ResourceFormulas.haters_growth_rate()` and
## `PrestigeFormulas.haters_rate_final()`), NOT the real Autoload method —
## same "local reproduction, no live Autoload" precedent already established
## by prestige_formulas_grant_test.gd's AC-9/10/11 variety-bonus mock and
## prestige_formulas_stacking_test.gd's header comment. Wiring
## `PrestigeSystem.get_meta_bonus_total(&"META_HATERS_RESIST")` into the real
## `OfflineProgressSystem.simulate_offline()` (and into `ActionSystem`, which
## currently has no live Haters-rate call site at all) is flagged as a
## follow-up decision, not performed by this story — see this story's
## implementation report.
extends GdUnitTestSuite

## Preloaded (not the bare class_name) so the suite parses even before the
## editor has rescanned the global class cache — headless CI/CLI safety,
## same precedent as prestige_formulas_grant_test.gd /
## prestige_formulas_stacking_test.gd.
const PrestigeFormulas: GDScript = preload("res://src/core/prestige_formulas.gd")
const ResourceFormulas: GDScript = preload("res://src/core/resource_formulas.gd")


# --- AC-1: Reach stacking, all four multiplicative layers active ---

## GDD's own worked example: zrob_drame (base 10), Mult(M)=1.00,
## class_path_multiplier=1.30, challenge_modifier=1.0,
## META_REACH_MULT_total=0.3873 -> final_reach=18
## (max(1, round(10 x 1.00 x 1.30 x 1.0 x 1.3873))).
func test_ac1_reach_stacking_all_layers_active_is_18() -> void:
	var result: int = PrestigeFormulas.final_reach(10.0, 1.00, 1.30, 1.0, 0.3873)
	assert_int(result).is_equal(18)


# --- AC-2: same action, different Morale/challenge/meta values ---

## Same action, Mult(M)=0.90, challenge_modifier=0.5,
## META_REACH_MULT_total=0.0429 -> final_reach=6
## (max(1, round(10 x 0.90 x 1.30 x 0.5 x 1.0429))).
func test_ac2_reach_stacking_lower_morale_and_challenge_is_6() -> void:
	var result: int = PrestigeFormulas.final_reach(10.0, 0.90, 1.30, 0.5, 0.0429)
	assert_int(result).is_equal(6)


# --- AC-3: floor-of-1 edge case — raw product rounds to 0 ---

## A base-5 action, Mult(M)=0.50, class_path_multiplier=1.0,
## challenge_modifier=0.05, META_REACH_MULT_total=0.0 -> raw product is
## 5 x 0.50 x 1.0 x 0.05 x 1.0 = 0.125, which rounds to 0 -- the max(1, ...)
## floor must trigger, producing final_reach=1 (a completed action never
## grants zero Reach). This is the critical edge case per this story's own
## QA Test Cases callout.
func test_ac3_reach_floor_of_1_triggers_when_raw_product_rounds_to_0() -> void:
	var result: int = PrestigeFormulas.final_reach(5.0, 0.50, 1.0, 0.05, 0.0)
	assert_int(result).is_equal(1)


## Sanity check: the floor only ever raises a sub-1 result to exactly 1 --
## it never raises an already-valid result above its own rounded value.
func test_ac3_reach_floor_does_not_affect_already_valid_results() -> void:
	var result: int = PrestigeFormulas.final_reach(10.0, 1.00, 1.30, 1.0, 0.3873)
	assert_int(result).is_equal(18)
	assert_int(result).is_greater(1)


# --- AC-4: Sponsor stacking, mocked class_path_sponsor_multiplier ---

## base_sponsors_roll=3, class_path_sponsor_multiplier=1.20 (MOCKED --
## get_active_sponsor_multiplier()'s real call-site wiring at card
## resolution is out of scope, ADR-0010 §5a), META_SPONSOR_MULT_total=0.50
## -> final_sponsors=5 (round(3 x 1.20 x 1.50)).
func test_ac4_sponsor_stacking_mocked_class_path_multiplier_is_5() -> void:
	var mocked_class_path_sponsor_multiplier: float = 1.20
	var result: int = PrestigeFormulas.final_sponsors(3.0, mocked_class_path_sponsor_multiplier, 0.50)
	assert_int(result).is_equal(5)


## No active path (multiplier=1.0) and no META_SPONSOR_MULT grant yet
## (total=0.0) reduces final_sponsors() to the unmodified base roll,
## rounded -- confirms both multiplicative layers are true no-ops at their
## respective identity values.
func test_ac4_sponsor_stacking_no_op_at_identity_multipliers() -> void:
	var result: int = PrestigeFormulas.final_sponsors(3.0, 1.0, 0.0)
	assert_int(result).is_equal(3)


# --- AC-5: Haters resistance multiplier ---

## C=80 (H_rate(C)=0.66, per ResourceFormulas.haters_growth_rate()'s own
## Formula A) and META_HATERS_RESIST_total=0.30 -> H_rate_final=0.462
## (0.66 x 0.70).
func test_ac5_haters_resistance_at_C80_resist_030_is_0_462() -> void:
	var h_rate: float = ResourceFormulas.haters_growth_rate(80.0)
	assert_float(h_rate).is_equal_approx(0.66, 0.005)

	var result: float = PrestigeFormulas.haters_rate_final(h_rate, 0.30)
	assert_float(result).is_equal_approx(0.462, 0.005)


## Edge case named in this story's QA Test Cases: META_HATERS_RESIST_total=0.0
## is a no-op, matching the unmodified H_rate(C) exactly.
func test_ac5_haters_resistance_zero_total_is_a_no_op() -> void:
	var h_rate: float = ResourceFormulas.haters_growth_rate(80.0)
	var result: float = PrestigeFormulas.haters_rate_final(h_rate, 0.0)
	assert_float(result).is_equal_approx(h_rate, 0.0001)


# --- AC-6/AC-7: Sponsor era-start floor override ---

## META_SPONSOR_FLOOR_total=9.0 at the moment era-start resource reset runs
## -> Sponsors is set to 9, overriding the default 0.
func test_ac6_sponsor_floor_override_active_sets_9() -> void:
	var result: float = PrestigeFormulas.sponsors_era_start_override(9.0)
	assert_float(result).is_equal_approx(9.0, 0.0001)


## META_SPONSOR_FLOOR_total=0.0 -> Sponsors is 0, unchanged from default.
func test_ac7_sponsor_floor_override_zero_stays_0() -> void:
	var result: float = PrestigeFormulas.sponsors_era_start_override(0.0)
	assert_float(result).is_equal_approx(0.0, 0.0001)


# --- AC-8: F3c online/offline Haters-resistance parity ---

## Local reproduction of OfflineProgressSystem.simulate_offline()'s
## Haters-accrual step ONLY (Hatersi growth via ResourceFormulas.
## haters_growth_rate(), then PrestigeFormulas.haters_rate_final() layered
## on top) -- same fixed-step-loop shape as the real method, built solely
## from already-covered static functions, no live Autoload. Returns total
## Hatersi accrued (not the running total) over [param elapsed_seconds] at a
## fixed Cringe, mirroring simulate_offline()'s "Cringe_fixed held constant
## for the whole call" contract.
func _mock_offline_haters_accrual(cringe_fixed: float, meta_haters_resist_total: float,
		elapsed_seconds: int) -> float:
	var accrued: float = 0.0
	var remaining: int = elapsed_seconds
	while remaining > 0:
		var dt: int = mini(60, remaining)
		var dt_minutes: float = dt / 60.0
		var base_rate: float = ResourceFormulas.haters_growth_rate(cringe_fixed)
		var final_rate: float = PrestigeFormulas.haters_rate_final(base_rate, meta_haters_resist_total)
		accrued += final_rate * dt_minutes
		remaining -= dt
	return accrued


## META_HATERS_RESIST_total=0.30 vs 0.0 over an identical elapsed window
## (1 hour, matching simulate_offline()'s own 60s step size) -- the 0.30
## case's accrual must be exactly 0.70x the 0.0 case's, proving resistance
## applies identically online and offline (F3c, intentional divergence from
## Class Path/Challenge's offline-exclusion pattern).
func test_ac8_offline_haters_accrual_resisted_is_exactly_0_70x_unresisted() -> void:
	var cringe_fixed: float = 80.0
	var elapsed_seconds: int = 3600

	var unresisted: float = _mock_offline_haters_accrual(cringe_fixed, 0.0, elapsed_seconds)
	var resisted: float = _mock_offline_haters_accrual(cringe_fixed, 0.30, elapsed_seconds)

	assert_float(unresisted).is_greater(0.0)
	assert_float(resisted).is_equal_approx(unresisted * 0.70, 0.0001)


## Sanity check on the ratio itself, independent of the two accrual totals
## computed above -- confirms the 0.70x relationship holds as a general
## property of haters_rate_final(), not an artifact of one specific
## cringe_fixed/elapsed_seconds combination.
func test_ac8_haters_rate_final_ratio_is_exactly_1_minus_resistance() -> void:
	var base_rate: float = ResourceFormulas.haters_growth_rate(50.0)
	var unresisted: float = PrestigeFormulas.haters_rate_final(base_rate, 0.0)
	var resisted: float = PrestigeFormulas.haters_rate_final(base_rate, 0.30)
	assert_float(resisted).is_equal_approx(unresisted * 0.70, 0.0001)
