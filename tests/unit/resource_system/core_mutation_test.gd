## Unit tests for ResourceManager's core mutation/clamping contract (Story 001,
## TR-res-001). Covers atomicity, signal notification, Cringe/Morale clamping
## at both floor and ceiling, unbounded resources, and the "no hidden
## escalation on sustained clean path" regression test required by qa-lead's
## QL-STORY-READY review.
##
## ResourceManager is normally an Autoload singleton, but for test isolation
## each test instantiates a fresh instance directly from the script and adds
## it to the scene tree (required for signal emission/monitoring), then frees
## it on cleanup. No shared state between tests, no random seeds, no
## time-dependent assertions, no external I/O — per coding-standards.md.
extends GdUnitTestSuite

const ResourceManagerScript: GDScript = preload("res://src/core/resource_manager.gd")

var _rm: Node


func before_test() -> void:
	_rm = ResourceManagerScript.new()
	add_child(_rm)


func after_test() -> void:
	# GdUnit4's own GC can free tree-added nodes between stages when a test
	# awaits (e.g. assert_signal) — guard against double-free (found running
	# tests for real for the first time, 2026-06-23).
	if is_instance_valid(_rm):
		_rm.queue_free()


## AC: action completes → all three values update atomically, no partial
## write; resource_changed fires once per key with correct old/new values.
func test_atomic_multi_key_delta_updates_all_keys_and_emits_signal() -> void:
	monitor_signals(_rm)

	var delta: Dictionary[StringName, float] = {&"Reach": 25.0, &"Cringe": -10.0, &"Morale": 5.0}
	_rm.apply_delta(delta)

	assert_float(_rm.get_resource(&"Reach")).is_equal_approx(25.0, 0.0001)
	assert_float(_rm.get_resource(&"Cringe")).is_equal_approx(0.0, 0.0001)
	# Morale default is 100.0 (2026-07-28 fix); +5 clamps at the ceiling.
	assert_float(_rm.get_resource(&"Morale")).is_equal_approx(100.0, 0.0001)

	await assert_signal(_rm).is_emitted("resource_changed", [&"Reach", 25.0, 0.0])
	await assert_signal(_rm).is_emitted("resource_changed", [&"Cringe", 0.0, 0.0])
	await assert_signal(_rm).is_emitted("resource_changed", [&"Morale", 100.0, 100.0])


## Edge case: zero delta is a no-op on value, but the signal still fires.
func test_zero_delta_is_noop_on_value_but_signal_still_fires() -> void:
	monitor_signals(_rm)

	var delta: Dictionary[StringName, float] = {&"Reach": 0.0}
	_rm.apply_delta(delta)

	assert_float(_rm.get_resource(&"Reach")).is_equal_approx(0.0, 0.0001)
	await assert_signal(_rm).is_emitted("resource_changed", [&"Reach", 0.0, 0.0])


## AC: Cringe=0, safe action (negative delta) → Cringe stays exactly 0, never
## negative.
func test_cringe_floor_clamps_to_zero_never_negative() -> void:
	var delta_a: Dictionary[StringName, float] = {&"Cringe": 0.0}
	_rm.apply_delta(delta_a)
	assert_float(_rm.get_resource(&"Cringe")).is_equal_approx(0.0, 0.0001)

	var delta_b: Dictionary[StringName, float] = {&"Cringe": -15.0}
	_rm.apply_delta(delta_b)

	assert_float(_rm.get_resource(&"Cringe")).is_equal_approx(0.0, 0.0001)


## AC: Morale=0, drain due (negative delta) → Morale stays exactly 0, never
## negative. Morale now starts at 100.0 (2026-07-28 default fix), so the
## zero baseline this AC is about is established explicitly first.
func test_morale_floor_clamps_to_zero_never_negative() -> void:
	var to_zero: Dictionary[StringName, float] = {&"Morale": -_rm.get_resource(&"Morale")}
	_rm.apply_delta(to_zero)
	assert_float(_rm.get_resource(&"Morale")).is_equal_approx(0.0, 0.0001)

	var delta_b: Dictionary[StringName, float] = {&"Morale": -42.0}
	_rm.apply_delta(delta_b)

	assert_float(_rm.get_resource(&"Morale")).is_equal_approx(0.0, 0.0001)


## AC (upgraded per qa-lead QL-STORY-READY review): a sustained sequence of
## Cringe-reducing actions raises no exception and never drives Morale or
## Haters out of valid bounds at ANY point in the sequence — not just at the
## end. This is a regression guard against a future caller introducing a
## hidden escalation/penalty side effect elsewhere in the loop; it is not
## sufficient evidence on its own that ResourceManager itself adds no such
## branch (see story doc's secondary code-inspection check).
func test_sustained_clean_path_sequence_never_corrupts_bounded_resources() -> void:
	const ITERATIONS: int = 20
	var expected_haters: float = 0.0

	for i in range(ITERATIONS):
		# A bare {} literal is untyped in Godot 4.4+ and is rejected by
		# apply_delta()'s typed Dictionary[StringName, float] parameter —
		# must declare a typed local first (found running tests for real
		# for the first time, 2026-06-23).
		var delta: Dictionary[StringName, float] = {&"Cringe": -5.0, &"Morale": 1.0, &"Haters": 2.0}
		_rm.apply_delta(delta)
		expected_haters += 2.0

		var morale: float = _rm.get_resource(&"Morale")
		var haters: float = _rm.get_resource(&"Haters")
		var cringe: float = _rm.get_resource(&"Cringe")

		assert_bool(is_nan(morale)).is_false()
		assert_bool(is_nan(haters)).is_false()
		assert_bool(is_nan(cringe)).is_false()

		assert_float(morale).is_between(0.0, 100.0)
		assert_float(cringe).is_between(0.0, 100.0)
		# Haters is unbounded but deterministic here — track the running expected
		# value (was previously a tautological `haters >= 0.0 or true` assertion
		# that tested nothing; flagged by qa-tester's code-review pass).
		assert_float(haters).is_equal_approx(expected_haters, 0.0001)


## AC: Reach/Haters are intentionally unbounded — large deltas must not be
## clamped, unlike Cringe/Morale.
func test_unbounded_resources_are_never_clamped() -> void:
	var delta: Dictionary[StringName, float] = {&"Reach": 100000.0, &"Haters": -100000.0}
	_rm.apply_delta(delta)

	assert_float(_rm.get_resource(&"Reach")).is_equal_approx(100000.0, 0.0001)
	assert_float(_rm.get_resource(&"Haters")).is_equal_approx(-100000.0, 0.0001)


## AC: Cringe ceiling — a delta pushing Cringe above 100 clamps to exactly
## 100, never exceeding it.
func test_cringe_ceiling_clamps_to_one_hundred_never_exceeds() -> void:
	var delta_a: Dictionary[StringName, float] = {&"Cringe": 95.0}
	_rm.apply_delta(delta_a)
	assert_float(_rm.get_resource(&"Cringe")).is_equal_approx(95.0, 0.0001)

	var delta_b: Dictionary[StringName, float] = {&"Cringe": 20.0}
	_rm.apply_delta(delta_b)

	assert_float(_rm.get_resource(&"Cringe")).is_equal_approx(100.0, 0.0001)
