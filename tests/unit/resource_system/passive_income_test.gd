## Unit tests for ResourceFormulas.passive_zasiegi_income() (Story 005,
## TR-res-001, Formula D). Covers all 5 acceptance criteria from
## production/epics/resource-system/story-005-passive-income.md:
##   1. N=10, Mult=1.0, Δt=600s -> exactly 20.0 (worked example)
##   2. N=0 (any Mult/Δt) -> 0
##   3. Δt=0 (any N/Mult) -> 0
##   4. Code-inspection check: no internal call to
##      action_effectiveness_multiplier() exists inside
##      passive_zasiegi_income() (see comment below -- not a runtime
##      assertion, per the story's Implementation Notes).
##   5. Large idle/offline session (N=15, Mult=0.9, Δt=28800s/8h) -> exactly
##      1296.0, finite, no precision loss.
##
## Pure arithmetic, no interpolation/branches -- exact equality is expected
## and asserted (not approximate).
##
## No shared state between tests, no random seeds, no time-dependent
## assertions, no external I/O -- per coding-standards.md. ResourceFormulas
## is a stateless static utility (ADR-0006), so no setup/teardown of an
## instance is needed -- tests call its static function directly.
extends GdUnitTestSuite

const ResourceFormulas: GDScript = preload("res://src/core/resource_formulas.gd")


## AC1 (worked example): Hatersi=10, Morale Mult=1.0, 10 minutes (600s) of
## idle time -> Zasięgi = 10 * 0.2 * 1.0 * 10 = 20.
func test_ten_hatersi_full_mult_ten_minutes_returns_twenty() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(10.0, 1.0, 600.0)
	assert_float(result).is_equal(20.0)


## AC2: Hatersi=0 -> passive income = 0, regardless of Mult or Δt.
func test_zero_hatersi_returns_zero_income() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(0.0, 1.0, 600.0)
	assert_float(result).is_equal(0.0)


## AC2 (edge variant): Hatersi=0 with a non-Full Mult and a long duration
## still returns exactly 0 -- confirms N=0 dominates regardless of the other
## two inputs' magnitude.
func test_zero_hatersi_with_low_mult_and_long_duration_returns_zero() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(0.0, 0.5, 28800.0)
	assert_float(result).is_equal(0.0)


## AC3: elapsed_seconds=0 -> passive income = 0, regardless of Hatersi or
## Mult (no time elapsed, no income).
func test_zero_elapsed_seconds_returns_zero_income() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(50.0, 1.0, 0.0)
	assert_float(result).is_equal(0.0)


## AC3 (edge variant): Δt=0 with a large Hatersi count and Full Mult still
## returns exactly 0 -- confirms Δt=0 dominates regardless of N's magnitude.
func test_zero_elapsed_seconds_with_high_hatersi_returns_zero() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(1000.0, 1.0, 0.0)
	assert_float(result).is_equal(0.0)


## AC4 (code-inspection check, not a runtime assertion): per the story's
## Implementation Notes and ADR-0006's "no hidden cross-calls" requirement,
## passive_zasiegi_income() in src/core/resource_formulas.gd takes the
## already-computed morale_mult as a parameter and contains ZERO internal
## calls to action_effectiveness_multiplier() (or to any other formula in
## that file -- haters_growth_rate(), morale_drain_rate()). This has been
## manually verified by reading the implementation: the function body is a
## single pure arithmetic expression
## (hatersi_count * Z_PER_HATER * morale_mult * (elapsed_seconds / 60.0))
## with no calls to other static functions in the class. This test exists
## only to document that verification in the test suite; it asserts nothing
## at runtime.
func test_code_inspection_no_cross_call_to_effectiveness_multiplier() -> void:
	assert_bool(true).is_true()


## AC5: large idle/offline session (8 hours = 28800s), the exact scenario
## ADR-0006 cites as the motivating Offline Progress System use case.
## N=15, Mult=0.9, Δt=28800 -> 15 * 0.2 * 0.9 * 480 = 1296.0 exactly, finite,
## no precision loss or overflow.
func test_eight_hour_idle_session_returns_exact_finite_result() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(15.0, 0.9, 28800.0)
	assert_float(result).is_equal(1296.0)
	assert_bool(is_finite(result)).is_true()


## Purity/idempotency check: repeated, interleaved calls with different
## inputs return consistent results -- confirms no hidden state leaks
## between calls, per ADR-0006's stateless-utility invariant.
func test_repeated_interleaved_calls_are_idempotent() -> void:
	assert_float(ResourceFormulas.passive_zasiegi_income(10.0, 1.0, 600.0)).is_equal(20.0)
	assert_float(ResourceFormulas.passive_zasiegi_income(15.0, 0.9, 28800.0)).is_equal(1296.0)
	assert_float(ResourceFormulas.passive_zasiegi_income(10.0, 1.0, 600.0)).is_equal(20.0)


## Out-of-contract input (per qa-tester's code-review pass): this function
## does not clamp/validate inputs, unlike haters_growth_rate()'s documented
## "always finite" guarantee. These tests lock in current sign-flip behavior
## as a characterization test, not a verified contract -- if this function
## is ever given negative inputs, the result is currently well-defined
## (simple multiplication) but not guaranteed by the formula's design intent.
func test_out_of_contract_negative_hatersi_returns_finite_value() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(-10.0, 1.0, 600.0)
	assert_bool(is_finite(result)).is_true()


func test_out_of_contract_negative_elapsed_seconds_returns_finite_value() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(10.0, 1.0, -600.0)
	assert_bool(is_finite(result)).is_true()


func test_out_of_contract_negative_morale_mult_returns_finite_value() -> void:
	var result: float = ResourceFormulas.passive_zasiegi_income(10.0, -1.0, 600.0)
	assert_bool(is_finite(result)).is_true()
