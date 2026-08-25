## Integration tests for ActionSystem's reward resolution and Morale scaling
## (Story 002, TR-act-001). Covers the reward table values (AC-1), round-
## half-away-from-zero Reach scaling at each Morale band (AC-2), the single
## atomic apply_delta() write with correct dict shape (AC-3), the discrete
## (never interpolated) multiplier contract (AC-4), the Cringe=100 clamp
## passthrough (AC-5), and action_completed firing after the write with the
## final scaled deltas (AC-6).
##
## This story's resolution path (`_on_action_timeout()`) calls the real
## `ResourceManager` and `ResourceFormulas` global identifiers directly
## (ADR-0001 direct-call pattern) rather than an injected dependency, so
## these tests drive the real `ResourceManager` Autoload singleton through
## its own public `apply_delta()`/`get_resource()` API to set Morale/Cringe
## to known values before each resolution — there is no test-only setter
## (Story 002's Out of Scope explicitly excludes modifying ResourceManager).
## `ResourceFormulas` is a stateless static utility (RefCounted, not an
## Autoload) and is called directly with no setup needed.
##
## Since ResourceManager is a real Autoload, its state persists across this
## suite's tests within a single engine run. `before_test()`/`after_test()`
## snapshot and restore Reach/Cringe/Morale around every test so no test
## leaks state into another (coding-standards.md test isolation rule).
##
## ActionSystem itself is NOT the shared Autoload instance — per the Story
## 001 test precedent, each test instantiates a fresh ActionSystem node
## directly from the script and adds it to the scene tree (required for the
## child Timer + signal emission), then frees it on cleanup.
extends GdUnitTestSuite

const ActionSystemScript: GDScript = preload("res://src/core/action_system.gd")

var _action_system: Node
var _snapshot: Dictionary[StringName, float] = {}
var _prestige_totals_snapshot: Dictionary[StringName, float] = {}


func before_test() -> void:
	_prestige_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	PrestigeSystem.meta_bonus_totals.erase(&"META_REACH_MULT")
	_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	_action_system = ActionSystemScript.new()
	add_child(_action_system)


func after_test() -> void:
	# Guard against double-free if GdUnit4's own GC frees tree-added nodes
	# between stages when a test awaits (see resource_system tests' note).
	if is_instance_valid(_action_system):
		# Disconnect this instance's Autoload subscriptions before freeing it.
		# queue_free() defers actual node removal to the end of the frame, so
		# without an explicit disconnect these connections (and the instance's
		# still-running Timer) can fire during a later test in this suite and
		# react to that test's own _set_resource() calls (cross-test signal
		# leak — see action_queue_test.gd's after_test() for the same fix).
		DecisionCardSystem.card_presented.disconnect(_action_system._on_card_presented)
		DecisionCardSystem.card_resolved.disconnect(_action_system._on_card_resolved)
		ResourceManager.resource_changed.disconnect(_action_system._on_resource_changed)
		_action_system._timer.stop()
		_action_system.queue_free()
	# Restore the real ResourceManager Autoload to its pre-test values so
	# this suite's resource mutations never leak into another test.
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _snapshot:
		restore[key] = _snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	PrestigeSystem.meta_bonus_totals.clear()
	for bonus_type: StringName in _prestige_totals_snapshot:
		PrestigeSystem.meta_bonus_totals[bonus_type] = _prestige_totals_snapshot[bonus_type]
	# apply_delta marks the real SaveSystem dirty (2026-06-29 fix) -- stop its
	# debounce timer so a delayed save_now() can't fire mid-suite. See
	# cooldown_pool_test.gd.
	SaveSystem._debounce_timer.stop()


## Sets [param name] on the real ResourceManager Autoload to exactly
## [param value] via a computed apply_delta() call — there is no dedicated
## test setter (Out of Scope per Story 002), so this is the cleanest
## deterministic way to drive Morale/Cringe to a known value using only
## ResourceManager's existing public API.
func _set_resource(name: StringName, value: float) -> void:
	var delta: float = value - ResourceManager.get_resource(name)
	ResourceManager.apply_delta({name: delta})


## AC-1: the 3 actions' reward table entries match the GDD exactly.
func test_action_rewards_table_matches_gdd_values_exactly() -> void:
	assert_float(_action_system.ACTION_DURATIONS[&"nagraj_vloga"]).is_equal_approx(6.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"nagraj_vloga"][&"Reach"]).is_equal_approx(5.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"nagraj_vloga"][&"Cringe"]).is_equal_approx(2.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"nagraj_vloga"][&"Morale"]).is_equal_approx(0.0, 0.0001)

	assert_float(_action_system.ACTION_DURATIONS[&"zrob_drame"]).is_equal_approx(9.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"zrob_drame"][&"Reach"]).is_equal_approx(10.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"zrob_drame"][&"Cringe"]).is_equal_approx(20.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"zrob_drame"][&"Morale"]).is_equal_approx(-3.0, 0.0001)

	assert_float(_action_system.ACTION_DURATIONS[&"przeprosiny"]).is_equal_approx(4.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"przeprosiny"][&"Reach"]).is_equal_approx(6.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"przeprosiny"][&"Cringe"]).is_equal_approx(-15.0, 0.0001)
	assert_float(_action_system.ACTION_REWARDS[&"przeprosiny"][&"Morale"]).is_equal_approx(5.0, 0.0001)


## AC-2: Zrób dramę (base Reach 10) at Full Morale (100, multiplier 1.0)
## scales to 10.
func test_drama_at_full_morale_scales_reach_to_ten() -> void:
	_set_resource(&"Morale", 100.0)
	_action_system.start_action(&"zrob_drame")

	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Reach") - _snapshot[&"Reach"]).is_equal_approx(10.0, 0.0001)


## AC-2: Zrób dramę (base Reach 10) at High Morale (50, multiplier 0.9)
## scales to 9 (10 * 0.9 = 9.0 exactly).
func test_drama_at_high_morale_scales_reach_to_nine() -> void:
	_set_resource(&"Morale", 50.0)
	_action_system.start_action(&"zrob_drame")

	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Reach") - _snapshot[&"Reach"]).is_equal_approx(9.0, 0.0001)


## AC-2: Nagraj vloga (base Reach 5) at Low Morale (20, multiplier 0.75)
## scales to 4 (3.75 rounds up via round-half-away-from-zero... actually
## 3.75 is not a .5 boundary, but roundf(3.75) = 4, matching the GDD's
## worked example).
func test_vlog_at_low_morale_scales_reach_to_four() -> void:
	_set_resource(&"Morale", 20.0)
	_action_system.start_action(&"nagraj_vloga")

	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Reach") - _snapshot[&"Reach"]).is_equal_approx(4.0, 0.0001)


## AC-2: Przeproś w internecie (base Reach 6) at Critical Morale
## (0, multiplier 0.5) scales to 3 (6 * 0.5 = 3.0 exactly).
func test_apology_at_critical_morale_scales_reach_to_three() -> void:
	_set_resource(&"Morale", 0.0)
	_action_system.start_action(&"przeprosiny")

	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Reach") - _snapshot[&"Reach"]).is_equal_approx(3.0, 0.0001)


## AC-2 edge case: a base/multiplier combination yielding an exact .5
## result locks roundf()'s round-half-away-from-zero behavior. Nagraj vloga
## (base Reach 5) at High Morale (50, multiplier 0.9): 5 * 0.9 = 4.5, which
## roundf() must round AWAY from zero to 5 (not down to 4, not banker's-
## rounded to 4).
func test_vlog_at_high_morale_rounds_four_point_five_away_from_zero_to_five() -> void:
	_set_resource(&"Morale", 50.0)
	_action_system.start_action(&"nagraj_vloga")

	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Reach") - _snapshot[&"Reach"]).is_equal_approx(5.0, 0.0001)


## AC-3: _on_action_timeout() applies the resolved deltas to ResourceManager
## in exactly one apply_delta() call (verified via resource_changed signal
## emission count — apply_delta() emits resource_changed once per key, so
## three keys from one call means exactly 3 emissions, not 6 from two
## separate calls), with the correct final scaled/flat values landing on
## the real resource state.
func test_resolution_applies_deltas_via_single_apply_delta_call_with_correct_shape() -> void:
	var emitted_keys: Array = []
	var _on_changed := func(key: StringName, _new_value: float, _old_value: float) -> void:
		emitted_keys.append(key)
	ResourceManager.resource_changed.connect(_on_changed)

	_set_resource(&"Morale", 100.0)
	# _set_resource() itself triggers one resource_changed emission for
	# Morale; clear the recorder before the call under test so only
	# _on_action_timeout()'s own apply_delta() call is counted.
	emitted_keys.clear()

	_action_system.start_action(&"zrob_drame")
	_action_system._on_action_timeout()

	ResourceManager.resource_changed.disconnect(_on_changed)

	# Exactly 3 emissions (Reach, Cringe, Morale) from exactly one
	# apply_delta() call -- two calls writing the same 3 keys would emit 6.
	assert_int(emitted_keys.size()).is_equal(3)
	assert_array(emitted_keys).contains([&"Reach", &"Cringe", &"Morale"])
	assert_float(ResourceManager.get_resource(&"Reach") - _snapshot[&"Reach"]).is_equal_approx(10.0, 0.0001)
	assert_float(ResourceManager.get_resource(&"Cringe") - _snapshot[&"Cringe"]).is_equal_approx(20.0, 0.0001)
	# Morale was set to exactly 100.0 before the call; drama's flat Morale
	# delta is -3.0, so the final value should land at 97.0.
	assert_float(ResourceManager.get_resource(&"Morale")).is_equal_approx(97.0, 0.0001)


## AC-4: the multiplier read at resolution is always exactly one of
## {0.5, 0.75, 0.9, 1.0} across all 4 bands and at every documented band
## boundary -- never interpolated. Per the story's note, this is tested
## directly against ResourceFormulas.action_effectiveness_multiplier(),
## since the contract is "ActionSystem reads it, never re-derives it" and
## _on_action_timeout() never re-implements this lookup.
func test_multiplier_is_always_one_of_four_discrete_values_at_all_band_boundaries() -> void:
	var valid_multipliers: Array[float] = [0.5, 0.75, 0.9, 1.0]
	var morale_values: Array[float] = [0.0, 14.0, 15.0, 39.0, 40.0, 69.0, 70.0, 100.0]

	for morale in morale_values:
		var multiplier: float = ResourceFormulas.action_effectiveness_multiplier(morale)
		assert_array(valid_multipliers).contains([multiplier])

	# Lock the exact expected multiplier at each boundary per Formula C's
	# inclusive-lower-bound convention.
	assert_float(ResourceFormulas.action_effectiveness_multiplier(0.0)).is_equal_approx(0.5, 0.0001)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(14.0)).is_equal_approx(0.5, 0.0001)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(15.0)).is_equal_approx(0.75, 0.0001)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(39.0)).is_equal_approx(0.75, 0.0001)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(40.0)).is_equal_approx(0.9, 0.0001)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(69.0)).is_equal_approx(0.9, 0.0001)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(70.0)).is_equal_approx(1.0, 0.0001)
	assert_float(ResourceFormulas.action_effectiveness_multiplier(100.0)).is_equal_approx(1.0, 0.0001)


## AC-5: Cringe is already at 100 (the clamp ceiling); Zrób dramę resolves
## with a Cringe delta of +20. ActionSystem passes +20 unmodified to
## apply_delta() with no special-casing -- the resulting Cringe stays
## clamped at 100 by ResourceManager's own clamp (Formula E), not by
## anything in ActionSystem.
func test_drama_resolution_with_cringe_at_ceiling_stays_clamped_at_hundred() -> void:
	_set_resource(&"Cringe", 100.0)
	_action_system.start_action(&"zrob_drame")

	_action_system._on_action_timeout()

	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(100.0, 0.0001)


## Regression: _on_action_timeout() invoked with no active action
## (current_action_id == &"") must no-op, not crash on ACTION_REWARDS[&""].
## Not reachable via the real Timer (which only fires after start_action()
## sets a valid id) but exercised directly to lock the guard.
func test_action_timeout_with_no_active_action_is_a_noop() -> void:
	var emitted: Array = [false]
	_action_system.action_completed.connect(func(_id: StringName, _r: Dictionary) -> void: emitted[0] = true)

	_action_system._on_action_timeout()

	assert_bool(emitted[0]).is_false()
	assert_that(_action_system.current_action_id).is_equal(&"")
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(_snapshot[&"Reach"], 0.0001)


## AC-6: action_completed fires AFTER the apply_delta() write commits (the
## real resource value is already updated by the time the signal handler
## runs), and its rewards payload equals the final scaled deltas, not the
## raw ACTION_REWARDS base values.
func test_signal_fires_after_write_and_carries_final_scaled_deltas() -> void:
	_set_resource(&"Morale", 50.0)  # High band, multiplier 0.9
	var reach_at_emit_time: Array = [0.0]
	var received_rewards: Array = [{}]
	var _on_completed := func(_action_id: StringName, rewards: Dictionary) -> void:
		# Captured at emission time -- proves apply_delta() already
		# committed before this handler runs.
		reach_at_emit_time[0] = ResourceManager.get_resource(&"Reach")
		received_rewards[0] = rewards
	_action_system.action_completed.connect(_on_completed)

	_action_system.start_action(&"zrob_drame")
	_action_system._on_action_timeout()

	# zrob_drame base Reach 10 * 0.9 multiplier = 9.0 -- the FINAL scaled
	# value, not the raw base reward of 10.0.
	assert_float(reach_at_emit_time[0] - _snapshot[&"Reach"]).is_equal_approx(9.0, 0.0001)
	assert_float(received_rewards[0][&"Reach"]).is_equal_approx(9.0, 0.0001)
	assert_float(received_rewards[0][&"Cringe"]).is_equal_approx(20.0, 0.0001)
	assert_float(received_rewards[0][&"Morale"]).is_equal_approx(-3.0, 0.0001)
