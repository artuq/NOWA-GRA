## Unit tests for StaffSystem's two formulas (design/gdd/team-staff-
## management.md F1/F2), asserted against the GDD's own worked examples.
## Both are static + argument-driven, so no instance or scene is needed.
extends GdUnitTestSuite

const StaffSystemScript: GDScript = preload("res://src/core/staff_system.gd")


## F1 worked example (troll, GDD): n=0 -> 1.0; n=1 -> 1.30; n=4 -> 1.75
## (exact midpoint by construction); n=10 -> 2.07; n=50 -> 2.39.
func test_f1_troll_worked_example() -> void:
	assert_float(StaffSystemScript.staff_multiplier(&"troll", 0)).is_equal_approx(1.0, 0.0001)
	assert_float(StaffSystemScript.staff_multiplier(&"troll", 1)).is_equal_approx(1.30, 0.005)
	assert_float(StaffSystemScript.staff_multiplier(&"troll", 4)).is_equal_approx(1.75, 0.0001)
	assert_float(StaffSystemScript.staff_multiplier(&"troll", 10)).is_equal_approx(2.07, 0.005)
	assert_float(StaffSystemScript.staff_multiplier(&"troll", 50)).is_equal_approx(2.39, 0.005)


## F1 contract: exactly 1.0 at n=0 for every role, strictly increasing, and
## never reaching MAX_MULTIPLIER for any finite n (output range is half-open).
func test_f1_bounds_and_monotonicity_for_all_roles() -> void:
	for role: StringName in StaffSystemScript.ROLES:
		var ceiling: float = StaffSystemScript.MAX_MULTIPLIER[role]
		assert_float(StaffSystemScript.staff_multiplier(role, 0)).is_equal_approx(1.0, 0.0001)
		var previous: float = 1.0
		for n: int in [1, 2, 5, 10, 100, 10000]:
			var current: float = StaffSystemScript.staff_multiplier(role, n)
			assert_float(current).is_greater(previous)
			assert_float(current).is_less(ceiling)
			previous = current
		# Half-point definition: at n == STAFF_HALF_POINT the multiplier sits
		# exactly halfway through its bonus range.
		var half_n: int = int(StaffSystemScript.STAFF_HALF_POINT[role])
		assert_float(StaffSystemScript.staff_multiplier(role, half_n)).is_equal_approx(
			1.0 + (ceiling - 1.0) * 0.5, 0.0001
		)


## F2 worked examples (GDD): troll n=0->4, n=1->6.4, n=4->26.2, n=8->171.8;
## sponsor_manager n=0->6, n=1->10.2, n=4->50.1, n=8->418.6. The LOCKED
## rounding rule is ceil(), never round-down — so 6.4 bills as 7, not 6.
func test_f2_worked_examples_use_ceil() -> void:
	assert_int(StaffSystemScript.hire_cost(&"troll", 0)).is_equal(4)
	assert_int(StaffSystemScript.hire_cost(&"troll", 1)).is_equal(7)  # 6.4 -> ceil
	assert_int(StaffSystemScript.hire_cost(&"troll", 4)).is_equal(27)  # 26.2 -> ceil
	assert_int(StaffSystemScript.hire_cost(&"troll", 8)).is_equal(172)  # 171.8 -> ceil
	assert_int(StaffSystemScript.hire_cost(&"sponsor_manager", 0)).is_equal(6)
	assert_int(StaffSystemScript.hire_cost(&"sponsor_manager", 1)).is_equal(11)  # 10.2 -> ceil
	assert_int(StaffSystemScript.hire_cost(&"sponsor_manager", 4)).is_equal(51)  # 50.1 -> ceil


## F2 contract: strictly increasing in n for every role (the escalating sink
## is the whole point — GDD Formula 2 Output Range).
func test_f2_strictly_increasing() -> void:
	for role: StringName in StaffSystemScript.ROLES:
		var previous: int = 0
		for n: int in range(0, 12):
			var cost: int = StaffSystemScript.hire_cost(role, n)
			assert_int(cost).is_greater(previous)
			previous = cost


## Unknown roles resolve to neutral values, never crash (same defensive
## contract as ClassPathSystem's unregistered-path lookups).
func test_unknown_role_is_neutral() -> void:
	assert_float(StaffSystemScript.staff_multiplier(&"not_a_role", 5)).is_equal_approx(1.0, 0.0001)
	assert_int(StaffSystemScript.hire_cost(&"not_a_role", 3)).is_equal(0)
