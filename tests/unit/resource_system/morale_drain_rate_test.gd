## Unit tests for ResourceFormulas.morale_drain_rate() (Story 003,
## TR-res-001, Formula B). Covers all 5 acceptance criteria from
## production/epics/resource-system/story-003-morale-drain-rate.md:
##   1. Hatersi=10 -> rate (per-minute, not time-integrated)
##   2. Hatersi=20 -> unclamped rate, no flooring inside this function
##   3. Hatersi=0 -> rate=0
##   4. Hatersi=3 -> exact buffer boundary, rate=0
##   5. Buffer zone N=0,1,2,3 all -> rate=0 (per QA Test Cases section)
##
## NOTE on expected values: the story doc's prose examples (1.85 for N=10,
## 5.27 for N=20, 7.3 for N=25) do not match the locked formula/constants
## from design/registry/entities.yaml (N_buffer=3, M_drain_per_hater=0.15,
## M_drain_exp=1.3) when computed precisely:
##   N=10: 0.15 * 7^1.3   = 1.8824 (not 1.85)
##   N=20: 0.15 * 17^1.3  = 5.9659 (not 5.27)
##   N=25: 0.15 * 22^1.3  = 8.3414 (not 7.3)
## These are arithmetic slips in the story's hand-computed prose, not a
## different intended formula -- entities.yaml's expression and constants
## are authoritative and are reproduced exactly in ResourceFormulas. Tests
## below assert the mathematically correct values per the locked formula.
##
## No shared state between tests, no random seeds, no time-dependent
## assertions, no external I/O -- per coding-standards.md. ResourceFormulas
## is a stateless static utility (ADR-0006), so no setup/teardown of an
## instance is needed -- tests call its static function directly.
extends GdUnitTestSuite

const ResourceFormulas: GDScript = preload("res://src/core/resource_formulas.gd")


## AC1: Hatersi=10 returns the per-minute drain rate, computed exactly from
## the locked formula: 0.15 * (10-3)^1.3 = 0.15 * 7^1.3 = 1.8824.
func test_hatersi_ten_returns_correct_drain_rate() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(10)
	assert_float(rate).is_equal_approx(1.8824, 0.01)


## AC2: Hatersi=20 (well above buffer) returns its full unclamped rate:
## 0.15 * (20-3)^1.3 = 0.15 * 17^1.3 = 5.9659. This function must never
## floor against a hypothetical current Morale value -- that clamp belongs
## to apply_delta() (Story 001), not here.
func test_hatersi_twenty_returns_unclamped_drain_rate() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(20)
	assert_float(rate).is_equal_approx(5.9659, 0.01)


## QA plan edge case: Hatersi=25, 0.15 * (25-3)^1.3 = 0.15 * 22^1.3 = 8.3414.
func test_hatersi_twentyfive_returns_correct_drain_rate() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(25)
	assert_float(rate).is_equal_approx(8.3414, 0.01)


## AC3: Hatersi=0 is below the buffer -- drain rate must be exactly 0.
func test_hatersi_zero_returns_zero_drain() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(0)
	assert_float(rate).is_equal_approx(0.0, 0.0001)


## AC4: Hatersi=3 is the exact buffer boundary (N_buffer=3) -- the buffer is
## a hard cliff (max(0, N - N_buffer)), so the boundary value itself must
## drain exactly 0, not just values strictly below it.
func test_hatersi_three_exact_buffer_boundary_returns_zero_drain() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(3)
	assert_float(rate).is_equal_approx(0.0, 0.0001)


## AC5 (QA Test Cases): the full buffer zone N=0,1,2 (in addition to the
## N=0 and N=3 boundary cases above) must each independently drain 0 --
## confirms the buffer isn't just "off by one" correct at the edges.
func test_hatersi_one_within_buffer_returns_zero_drain() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(1)
	assert_float(rate).is_equal_approx(0.0, 0.0001)


func test_hatersi_two_within_buffer_returns_zero_drain() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(2)
	assert_float(rate).is_equal_approx(0.0, 0.0001)


## Out-of-contract input (negative Hatersi count) must still return a
## finite, non-NaN float -- safe by construction via max(0, ...), per the
## story's NaN-safety note. Value correctness is not asserted (out of
## contract).
func test_out_of_contract_negative_hatersi_returns_finite_value() -> void:
	var rate: float = ResourceFormulas.morale_drain_rate(-5)

	assert_bool(is_finite(rate)).is_true()
	assert_bool(is_nan(rate)).is_false()
	assert_float(rate).is_equal_approx(0.0, 0.0001)
