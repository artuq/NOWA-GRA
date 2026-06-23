## Unit tests for ResourceFormulas.action_effectiveness_multiplier() (Story
## 004, TR-res-001, Formula C). Covers all 3 acceptance criteria from
## production/epics/resource-system/story-004-effectiveness-multiplier.md,
## including the paired boundary values (per qa-lead's QL-STORY-READY
## review) that guard against an off-by-one band-width bug going undetected:
##   1. Morale=35 (Low band) -> 0.75
##   2. Morale=0 (Critical band floor) -> 0.5
##   3. Boundaries 70/40/15 are inclusive-lower, tested paired with the
##      value just below each: 70/69, 40/39, 15/14, plus M=100 (top of the
##      Full band).
##
## Discrete lookup, no interpolation -- exact equality is expected and
## asserted (not approximate), since each band returns a fixed constant.
##
## No shared state between tests, no random seeds, no time-dependent
## assertions, no external I/O -- per coding-standards.md. ResourceFormulas
## is a stateless static utility (ADR-0006), so no setup/teardown of an
## instance is needed -- tests call its static function directly.
extends GdUnitTestSuite

const ResourceFormulas: GDScript = preload("res://src/core/resource_formulas.gd")


## AC1: Morale=35 falls in the Low band (15 <= M < 40) -> multiplier 0.75.
func test_morale_thirtyfive_returns_low_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(35.0)
	assert_float(mult).is_equal(0.75)


## AC2: Morale=0 is the Critical band floor (0 <= M < 15) -> multiplier 0.5.
func test_morale_zero_returns_critical_band_floor_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(0.0)
	assert_float(mult).is_equal(0.5)


## AC3 (paired boundary, Full/Normal split at M=70): the boundary value
## itself belongs to the higher (Full) band.
func test_morale_seventy_exact_boundary_returns_full_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(70.0)
	assert_float(mult).is_equal(1.0)


## AC3 (paired boundary): one below 70 must still resolve to the Normal
## band, confirming the band doesn't start too early.
func test_morale_sixtynine_returns_normal_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(69.0)
	assert_float(mult).is_equal(0.9)


## AC3 (paired boundary, Normal/Low split at M=40): the boundary value
## itself belongs to the higher (Normal) band.
func test_morale_forty_exact_boundary_returns_normal_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(40.0)
	assert_float(mult).is_equal(0.9)


## AC3 (paired boundary): one below 40 must still resolve to the Low band.
func test_morale_thirtynine_returns_low_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(39.0)
	assert_float(mult).is_equal(0.75)


## AC3 (paired boundary, Low/Critical split at M=15): the boundary value
## itself belongs to the higher (Low) band.
func test_morale_fifteen_exact_boundary_returns_low_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(15.0)
	assert_float(mult).is_equal(0.75)


## AC3 (paired boundary): one below 15 must still resolve to the Critical
## band.
func test_morale_fourteen_returns_critical_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(14.0)
	assert_float(mult).is_equal(0.5)


## AC3 (top edge): Morale=100 is the top of the Full band (70 <= M <= 100,
## inclusive on both ends) -> confirms the upper edge of the highest band.
func test_morale_one_hundred_returns_full_band_multiplier() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(100.0)
	assert_float(mult).is_equal(1.0)


## Out-of-contract input (per qa-tester's code-review pass): negative Morale
## falls through to the Critical band since there's no lower-bound guard.
## This locks in the implicit behavior, not a contract guarantee.
func test_out_of_contract_negative_morale_falls_through_to_critical_band() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(-10.0)
	assert_float(mult).is_equal(0.5)


## Out-of-contract input: Morale above 100 has no upper-bound guard either,
## so it stays in the Full band. Locks in the implicit behavior.
func test_out_of_contract_excessive_morale_stays_in_full_band() -> void:
	var mult: float = ResourceFormulas.action_effectiveness_multiplier(150.0)
	assert_float(mult).is_equal(1.0)


## Purity/idempotency check: repeated, interleaved calls with different
## inputs return consistent results -- confirms no hidden state leaks
## between calls, per ADR-0006's stateless-utility invariant.
func test_repeated_interleaved_calls_are_idempotent() -> void:
	assert_float(ResourceFormulas.action_effectiveness_multiplier(35.0)).is_equal(0.75)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(70.0)).is_equal(1.0)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(35.0)).is_equal(0.75)
