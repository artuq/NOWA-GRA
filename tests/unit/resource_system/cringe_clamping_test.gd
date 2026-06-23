## Unit tests for Cringe's near-ceiling/near-floor "soft brake" clamp behavior
## (Story 006, GDD Formula E). This formula is implemented generically inside
## ResourceManager.apply_delta() (Story 001) — there is no separate
## ResourceFormulas function for it. This story exists purely to give Formula
## E its own explicit, isolated test coverage, since it's referenced by name
## in the GDD and economy-designer flagged it as an intentional design
## mechanism, not an incidental side effect of generic clamping.
##
## No new production code is added or modified by this story. See
## production/epics/resource-system/story-006-cringe-clamping.md.
##
## ResourceManager is normally an Autoload singleton, but for test isolation
## each test instantiates a fresh instance directly from the script and adds
## it to the scene tree, then frees it on cleanup. No shared state between
## tests, no random seeds, no time-dependent assertions, no external I/O —
## per coding-standards.md.
extends GdUnitTestSuite

const ResourceManagerScript: GDScript = preload("res://src/core/resource_manager.gd")

var _rm: Node


func before_test() -> void:
	_rm = ResourceManagerScript.new()
	add_child(_rm)


func after_test() -> void:
	# GdUnit4's own GC can free tree-added nodes between stages when a test
	# awaits — guard against double-free (see core_mutation_test.gd, 2026-06-23).
	if is_instance_valid(_rm):
		_rm.queue_free()


## AC 1 (ceiling soft-brake case): Cringe=95, nominal delta=+20 →
## actual change = clamp(115,0,100)-95 = 5, not 20.
func test_ceiling_soft_brake_dampens_actual_change_to_five() -> void:
	var setup_delta: Dictionary[StringName, float] = {&"Cringe": 95.0}
	_rm.apply_delta(setup_delta)
	var before: float = _rm.get_resource(&"Cringe")

	var action_delta: Dictionary[StringName, float] = {&"Cringe": 20.0}
	_rm.apply_delta(action_delta)
	var after: float = _rm.get_resource(&"Cringe")

	assert_float(before).is_equal_approx(95.0, 0.0001)
	assert_float(after).is_equal_approx(100.0, 0.0001)
	assert_float(after - before).is_equal_approx(5.0, 0.0001)


## AC 2 (floor case, symmetric to AC 1): Cringe=0, nominal delta=-15 →
## actual change = clamp(-15,0,100)-0 = 0.
func test_floor_case_dampens_actual_change_to_zero() -> void:
	# Cringe already defaults to 0.0; apply a zero delta first to make the
	# starting state explicit/readable rather than relying on the default.
	var setup_delta: Dictionary[StringName, float] = {&"Cringe": 0.0}
	_rm.apply_delta(setup_delta)
	var before: float = _rm.get_resource(&"Cringe")

	var action_delta: Dictionary[StringName, float] = {&"Cringe": -15.0}
	_rm.apply_delta(action_delta)
	var after: float = _rm.get_resource(&"Cringe")

	assert_float(before).is_equal_approx(0.0, 0.0001)
	assert_float(after).is_equal_approx(0.0, 0.0001)
	assert_float(after - before).is_equal_approx(0.0, 0.0001)


## AC 3 (sanity check, no clamping): Cringe=50, nominal delta=+20 →
## actual change = clamp(70,0,100)-50 = 20 exactly. Confirms the clamp does
## not dampen deltas that stay well within [0, 100].
func test_mid_range_delta_is_not_dampened() -> void:
	var setup_delta: Dictionary[StringName, float] = {&"Cringe": 50.0}
	_rm.apply_delta(setup_delta)
	var before: float = _rm.get_resource(&"Cringe")

	var action_delta: Dictionary[StringName, float] = {&"Cringe": 20.0}
	_rm.apply_delta(action_delta)
	var after: float = _rm.get_resource(&"Cringe")

	assert_float(before).is_equal_approx(50.0, 0.0001)
	assert_float(after).is_equal_approx(70.0, 0.0001)
	assert_float(after - before).is_equal_approx(20.0, 0.0001)


## Bonus test (qa-lead, /story-readiness, non-blocking): Cringe already at
## the ceiling (100), nominal delta=+5 → actual change = 0. Confirms the
## already-maxed case stays maxed rather than producing any drift.
func test_already_at_ceiling_stays_maxed() -> void:
	var setup_delta: Dictionary[StringName, float] = {&"Cringe": 100.0}
	_rm.apply_delta(setup_delta)
	var before: float = _rm.get_resource(&"Cringe")

	var action_delta: Dictionary[StringName, float] = {&"Cringe": 5.0}
	_rm.apply_delta(action_delta)
	var after: float = _rm.get_resource(&"Cringe")

	assert_float(before).is_equal_approx(100.0, 0.0001)
	assert_float(after).is_equal_approx(100.0, 0.0001)
	assert_float(after - before).is_equal_approx(0.0, 0.0001)


## Bonus test (qa-lead, /story-readiness, non-blocking): zero-delta no-op.
## Cringe=50, nominal delta=0 → actual change = 0.
func test_zero_delta_is_noop() -> void:
	var setup_delta: Dictionary[StringName, float] = {&"Cringe": 50.0}
	_rm.apply_delta(setup_delta)
	var before: float = _rm.get_resource(&"Cringe")

	var action_delta: Dictionary[StringName, float] = {&"Cringe": 0.0}
	_rm.apply_delta(action_delta)
	var after: float = _rm.get_resource(&"Cringe")

	assert_float(before).is_equal_approx(50.0, 0.0001)
	assert_float(after).is_equal_approx(50.0, 0.0001)
	assert_float(after - before).is_equal_approx(0.0, 0.0001)


## Bonus test (qa-lead, /story-done QL-TEST-COVERAGE, non-blocking): a large
## negative overshoot from near the ceiling. Cringe=95, delta=-200 →
## actual change = clamp(-105,0,100)-95 = -95 (floors at 0, not at -105).
## Confirms large-magnitude deltas are clamped correctly, not just deltas
## that land just past a boundary.
func test_large_negative_overshoot_near_ceiling_clamps_to_floor() -> void:
	var setup_delta: Dictionary[StringName, float] = {&"Cringe": 95.0}
	_rm.apply_delta(setup_delta)
	var before: float = _rm.get_resource(&"Cringe")

	var action_delta: Dictionary[StringName, float] = {&"Cringe": -200.0}
	_rm.apply_delta(action_delta)
	var after: float = _rm.get_resource(&"Cringe")

	assert_float(before).is_equal_approx(95.0, 0.0001)
	assert_float(after).is_equal_approx(0.0, 0.0001)
	assert_float(after - before).is_equal_approx(-95.0, 0.0001)


## Bonus test (qa-lead, /story-done QL-TEST-COVERAGE, non-blocking): a
## multi-key delta in a single apply_delta() call, confirming Cringe's clamp
## doesn't interact with or get affected by other keys mutating in the same
## call (cross-key independence).
func test_multi_key_delta_clamps_cringe_independently_of_other_keys() -> void:
	var setup_delta: Dictionary[StringName, float] = {&"Cringe": 95.0}
	_rm.apply_delta(setup_delta)

	var action_delta: Dictionary[StringName, float] = {&"Cringe": 20.0, &"Reach": 50.0, &"Morale": 5.0}
	_rm.apply_delta(action_delta)

	assert_float(_rm.get_resource(&"Cringe")).is_equal_approx(100.0, 0.0001)
	assert_float(_rm.get_resource(&"Reach")).is_equal_approx(50.0, 0.0001)
	assert_float(_rm.get_resource(&"Morale")).is_equal_approx(5.0, 0.0001)
