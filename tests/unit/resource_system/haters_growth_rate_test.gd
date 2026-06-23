## Unit tests for ResourceFormulas.haters_growth_rate() (Story 002,
## TR-res-001, Formula A). Covers all 5 acceptance criteria from
## production/epics/resource-system/story-002-haters-growth-rate.md:
##   1. Cringe=10 vs Cringe=80 comparison (±0.001), strictly greater at 80
##   2. Cringe=100 sustained across repeated calls, rate stays at 1.02
##      (±0.001), no cap/decay
##   3. Cringe=0 floor case, exactly H_base = 0.02 (±0.0001)
##   4. Cringe=50 midpoint, exactly 0.27 (±0.001), pins the H_exp=2.0 curve
##   5. Out-of-contract input (C=-10, C=150): finite float, no crash, no
##      NaN/Infinity — value correctness NOT asserted (out of contract)
##
## No shared state between tests, no random seeds, no time-dependent
## assertions, no external I/O — per coding-standards.md. ResourceFormulas
## is a stateless static utility (ADR-0006), so no setup/teardown of an
## instance is needed — tests call its static function directly.
extends GdUnitTestSuite

const ResourceFormulas: GDScript = preload("res://src/core/resource_formulas.gd")


## AC1: Cringe=80 produces strictly greater Hatersi growth than Cringe=10,
## matching the GDD's worked values: H_rate(10)=0.03, H_rate(80)=0.66.
func test_higher_cringe_produces_strictly_greater_growth_rate() -> void:
	var rate_low: float = ResourceFormulas.haters_growth_rate(10.0)
	var rate_high: float = ResourceFormulas.haters_growth_rate(80.0)

	assert_float(rate_low).is_equal_approx(0.03, 0.001)
	assert_float(rate_high).is_equal_approx(0.66, 0.001)
	assert_float(rate_high).is_greater(rate_low)


## AC2: Cringe held at 100 for a sustained sequence of calls (simulating
## 50+ minutes of offline/live evaluation) always returns the same maxed
## rate — no cap, no decay across repeated calls.
func test_sustained_max_cringe_keeps_rate_at_max_with_no_cap_or_decay() -> void:
	const SUSTAINED_CALLS: int = 50

	for i in range(SUSTAINED_CALLS):
		var rate: float = ResourceFormulas.haters_growth_rate(100.0)
		assert_float(rate).is_equal_approx(1.02, 0.001)


## AC3: Cringe=0 is the floor case — result must equal H_base exactly.
func test_zero_cringe_returns_h_base_floor_exactly() -> void:
	var rate: float = ResourceFormulas.haters_growth_rate(0.0)
	assert_float(rate).is_equal_approx(0.02, 0.0001)


## AC4: Cringe=50 (midpoint) pins the H_exp=2.0 curve shape at an interior
## point, not just the endpoints: 0.02 + 0.5^2.0 * 1.0 = 0.27.
func test_midpoint_cringe_pins_curve_shape_at_interior_point() -> void:
	var rate: float = ResourceFormulas.haters_growth_rate(50.0)
	assert_float(rate).is_equal_approx(0.27, 0.001)


## AC5: Out-of-contract input below the valid range (C=-10) must still
## return a finite float — no crash, no NaN/Infinity. Value correctness is
## explicitly NOT asserted here (out of contract; ResourceManager already
## clamps Cringe to [0,100] before any caller reaches this function).
func test_out_of_contract_negative_cringe_returns_finite_value() -> void:
	var rate: float = ResourceFormulas.haters_growth_rate(-10.0)

	assert_bool(is_finite(rate)).is_true()
	assert_bool(is_nan(rate)).is_false()


## AC5: Out-of-contract input above the valid range (C=150) must still
## return a finite float — no crash, no NaN/Infinity. Value correctness is
## explicitly NOT asserted here (out of contract).
func test_out_of_contract_excessive_cringe_returns_finite_value() -> void:
	var rate: float = ResourceFormulas.haters_growth_rate(150.0)

	assert_bool(is_finite(rate)).is_true()
	assert_bool(is_nan(rate)).is_false()
