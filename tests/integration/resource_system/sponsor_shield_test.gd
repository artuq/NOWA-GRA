## Integration tests for the Sponsor Network Shield (Story 008, DDR-0001 #6).
## Tests the full activation / tick / expiry / persistence / offline-sim
## lifecycle of the shield against the real ResourceManager and OfflineProgressSystem
## Autoload singletons.
##
## Pattern: snapshot ResourceManager._shield_remaining_seconds and Sponsors
## before each test; restore in after_test() to prevent cross-test state leakage.
## _process() is called directly (bypassing real frame time) to test ticking
## without awaiting wall-clock seconds.
## Story type: Integration. Evidence: this file. Gate: BLOCKING.
extends GdUnitTestSuite

var _snap_sponsors: float = 0.0
var _snap_shield: float = 0.0
var _snap_haters: float = 0.0
var _snap_morale: float = 0.0


func before_test() -> void:
	_snap_sponsors = ResourceManager.get_resource(&"Sponsors")
	_snap_shield = ResourceManager._shield_remaining_seconds
	_snap_haters = ResourceManager.get_resource(&"Haters")
	_snap_morale = ResourceManager.get_resource(&"Morale")
	# Start each test with a clean slate: enough Sponsors to test with, no
	# active shield.
	ResourceManager._shield_remaining_seconds = 0.0
	var delta: float = 20.0 - ResourceManager.get_resource(&"Sponsors")
	ResourceManager.apply_delta({&"Sponsors": delta})
	_stop_save_timers()


func after_test() -> void:
	ResourceManager._shield_remaining_seconds = _snap_shield
	var sponsors_delta: float = _snap_sponsors - ResourceManager.get_resource(&"Sponsors")
	ResourceManager.apply_delta({&"Sponsors": sponsors_delta})
	var haters_delta: float = _snap_haters - ResourceManager.get_resource(&"Haters")
	ResourceManager.apply_delta({&"Haters": haters_delta})
	var morale_delta: float = _snap_morale - ResourceManager.get_resource(&"Morale")
	ResourceManager.apply_delta({&"Morale": morale_delta})
	_stop_save_timers()


func _stop_save_timers() -> void:
	for child: Node in SaveSystem.get_children():
		if child is Timer:
			(child as Timer).stop()


## AC-1: Spending SHIELD_COST Sponsors activates the shield for SHIELD_DURATION seconds.
func test_activate_spends_sponsors_and_sets_timer() -> void:
	var sponsors_before: float = ResourceManager.get_resource(&"Sponsors")
	var emitted: Array[Array] = [[]]
	var on_changed := func(is_active: bool, remaining: float) -> void:
		emitted[0] = [is_active, remaining]
	ResourceManager.shield_changed.connect(on_changed)

	var ok: bool = ResourceManager.activate_sponsor_shield()

	ResourceManager.shield_changed.disconnect(on_changed)
	assert_bool(ok).is_true()
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(
		sponsors_before - float(ResourceManager.SHIELD_COST), 0.01
	)
	assert_float(ResourceManager._shield_remaining_seconds).is_equal_approx(
		ResourceManager.SHIELD_DURATION, 0.01
	)
	assert_bool(emitted[0].size() > 0 and emitted[0][0] == true).is_true()
	assert_float(emitted[0][1]).is_equal_approx(ResourceManager.SHIELD_DURATION, 0.01)


## AC-2: Activating while already active adds SHIELD_DURATION to remaining time (stacks).
func test_activate_while_active_stacks_duration() -> void:
	ResourceManager._shield_remaining_seconds = 100.0
	var emitted: Array[Array] = []
	var on_changed := func(is_active: bool, remaining: float) -> void:
		emitted.append([is_active, remaining])
	ResourceManager.shield_changed.connect(on_changed)

	var ok: bool = ResourceManager.activate_sponsor_shield()

	ResourceManager.shield_changed.disconnect(on_changed)
	assert_bool(ok).is_true()
	assert_float(ResourceManager._shield_remaining_seconds).is_equal_approx(
		100.0 + ResourceManager.SHIELD_DURATION, 0.01
	)
	assert_int(emitted.size()).is_equal(1)
	if not emitted.is_empty():
		assert_bool(emitted[0][0]).is_true()
		assert_float(emitted[0][1]).is_equal_approx(100.0 + ResourceManager.SHIELD_DURATION, 0.01)


## AC-3: While active, get_shield_effective_buffer() returns elevated buffer.
func test_effective_buffer_elevated_while_active() -> void:
	ResourceManager._shield_remaining_seconds = 10.0

	var buf: int = ResourceManager.get_shield_effective_buffer()

	assert_int(buf).is_equal(ResourceFormulas.M_BUFFER + ResourceManager.SHIELD_BUFFER_BONUS)


## AC-4 (regression): morale_drain_rate() with no second arg uses base M_BUFFER.
func test_morale_drain_rate_default_arg_unchanged() -> void:
	# At N=10, base buffer=3: excess = 7, rate = 0.15 * 7^1.3 ≈ 1.882
	var rate_no_arg: float = ResourceFormulas.morale_drain_rate(10)
	var rate_base: float = ResourceFormulas.morale_drain_rate(10, ResourceFormulas.M_BUFFER)

	assert_float(rate_no_arg).is_equal_approx(rate_base, 0.0001)


## AC-5 (rejection): activation rejected when Sponsors < SHIELD_COST.
func test_activate_rejected_when_sponsors_insufficient() -> void:
	ResourceManager.apply_delta({&"Sponsors": -ResourceManager.get_resource(&"Sponsors")})
	var ok: bool = ResourceManager.activate_sponsor_shield()

	assert_bool(ok).is_false()
	assert_float(ResourceManager._shield_remaining_seconds).is_equal_approx(0.0, 0.0001)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(0.0, 0.0001)


## AC-6: Timer ticks down in _process(); emits shield_changed(false, 0) on expiry.
func test_timer_ticks_and_emits_expiry() -> void:
	ResourceManager._shield_remaining_seconds = 0.1
	var expired: Array[bool] = [false]
	var expiry_remaining: Array[float] = [-1.0]
	var on_expired := func(is_active: bool, remaining: float) -> void:
		if not is_active:
			expired[0] = true
			expiry_remaining[0] = remaining
	ResourceManager.shield_changed.connect(on_expired)

	ResourceManager._process(0.2)

	ResourceManager.shield_changed.disconnect(on_expired)
	assert_float(ResourceManager._shield_remaining_seconds).is_equal_approx(0.0, 0.0001)
	assert_bool(expired[0]).is_true()
	assert_float(expiry_remaining[0]).is_equal_approx(0.0, 0.0001)


## AC-7: Shield state persists across serialize_state / restore_state round-trip.
func test_shield_state_survives_save_restore() -> void:
	ResourceManager._shield_remaining_seconds = 150.0

	var saved: Dictionary = ResourceManager.serialize_state()
	ResourceManager._shield_remaining_seconds = 0.0
	ResourceManager.restore_state(saved)

	assert_float(ResourceManager._shield_remaining_seconds).is_equal_approx(150.0, 0.01)


## AC-8: Offline sim uses 2-segment drain when shield covers part of offline delta.
## Given shield_remaining=60s, offline_delta=300s, Haters=10 (after drain curve).
## Shielded 60s use buffer=8; unshielded 240s use buffer=3.
## Morale after shielded segment must be higher than if shield were absent for all 300s.
func test_offline_sim_two_segment_drain() -> void:
	ResourceManager._shield_remaining_seconds = 60.0
	# Set up a fixed resource state for the sim
	var haters_delta: float = 10.0 - ResourceManager.get_resource(&"Haters")
	ResourceManager.apply_delta({&"Haters": haters_delta})
	var morale_delta: float = 80.0 - ResourceManager.get_resource(&"Morale")
	ResourceManager.apply_delta({&"Morale": morale_delta})
	_stop_save_timers()

	var result_shielded: Dictionary = OfflineProgressSystem.simulate_offline(300)

	# simulate_offline reads ResourceManager at start but does NOT mutate it —
	# Haters and Morale are still at their pre-sim values. Reset only the shield
	# so the second sim runs from an identical resource baseline without it.
	ResourceManager._shield_remaining_seconds = 0.0
	_stop_save_timers()

	var result_unshielded: Dictionary = OfflineProgressSystem.simulate_offline(300)

	# Shielded sim should result in higher final Morale (less drain during
	# the first 60s where buffer=8 instead of 3 reduces excess Haters drain).
	assert_float(result_shielded["final_M"]).is_greater(result_unshielded["final_M"])


## Package 2 AC: wall-clock/offline shield consumption can advance the timer
## without depending on a rendered frame. A partial elapsed duration leaves
## the exact remainder and does not emit a false expiry.
func test_elapse_sponsor_shield_partial_preserves_remainder_without_expiry() -> void:
	ResourceManager._shield_remaining_seconds = 300.0
	assert_bool(ResourceManager.has_method("elapse_sponsor_shield")).is_true()
	if not ResourceManager.has_method("elapse_sponsor_shield"):
		return
	var emissions: Array[Array] = []
	var on_changed := func(is_active: bool, remaining: float) -> void:
		emissions.append([is_active, remaining])
	ResourceManager.shield_changed.connect(on_changed)

	ResourceManager.elapse_sponsor_shield(120.0)

	ResourceManager.shield_changed.disconnect(on_changed)
	assert_float(ResourceManager.get_shield_remaining_seconds()).is_equal_approx(180.0, 0.0001)
	assert_array(emissions).is_empty()


## Package 2 AC: elapsed time clamps at zero and emits exactly one inactive
## transition. Further elapsed calls while inactive remain silent.
func test_elapse_sponsor_shield_expiry_clamps_and_emits_once() -> void:
	ResourceManager._shield_remaining_seconds = 60.0
	assert_bool(ResourceManager.has_method("elapse_sponsor_shield")).is_true()
	if not ResourceManager.has_method("elapse_sponsor_shield"):
		return
	var emissions: Array[Array] = []
	var on_changed := func(is_active: bool, remaining: float) -> void:
		emissions.append([is_active, remaining])
	ResourceManager.shield_changed.connect(on_changed)

	ResourceManager.elapse_sponsor_shield(90.0)
	ResourceManager.elapse_sponsor_shield(10.0)

	ResourceManager.shield_changed.disconnect(on_changed)
	assert_float(ResourceManager.get_shield_remaining_seconds()).is_equal_approx(0.0, 0.0001)
	assert_int(emissions.size()).is_equal(1)
	assert_bool(emissions[0][0]).is_false()
	assert_float(emissions[0][1]).is_equal_approx(0.0, 0.0001)


## Package 2 AC: elapsed time operates on the full additive stack rather than
## a single activation duration.
func test_elapse_sponsor_shield_consumes_from_stacked_duration() -> void:
	ResourceManager._shield_remaining_seconds = ResourceManager.SHIELD_DURATION * 2.0
	assert_bool(ResourceManager.has_method("elapse_sponsor_shield")).is_true()
	if not ResourceManager.has_method("elapse_sponsor_shield"):
		return

	ResourceManager.elapse_sponsor_shield(ResourceManager.SHIELD_DURATION + 45.0)

	assert_float(ResourceManager.get_shield_remaining_seconds()).is_equal_approx(
		ResourceManager.SHIELD_DURATION - 45.0,
		0.0001
	)
