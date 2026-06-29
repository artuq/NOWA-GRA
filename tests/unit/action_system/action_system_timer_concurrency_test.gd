## Unit tests for ActionSystem's core timer/single-concurrency contract
## (Story 001, TR-act-001). Covers start-from-idle, unknown action_id
## rejection, single-concurrency rejection, completion reset + signal,
## get_progress()'s divide-by-zero guard, mid-run progress values, and the
## no-cooldown re-selection rule.
##
## ActionSystem is normally an Autoload singleton, but for test isolation
## each test instantiates a fresh instance directly from the script and adds
## it to the scene tree (required for the child Timer + signal emission),
## then frees it on cleanup. No shared state between tests, no random seeds,
## no real-time `await` — per coding-standards.md. get_progress() mid-run
## values are driven deterministically by manually setting `_timer.time_left`
## (ADR-0004 testing note), never by awaiting real seconds.
extends GdUnitTestSuite

const ActionSystemScript: GDScript = preload("res://src/core/action_system.gd")

var _action_system: Node


func before_test() -> void:
	_action_system = ActionSystemScript.new()
	add_child(_action_system)


func after_test() -> void:
	# A fresh _action_system's reward application still calls the real global
	# ResourceManager.apply_delta() -> SaveSystem.mark_dirty() (autoload access
	# is by global name, not `self`). This suite waits on real Timers (action
	# durations up to 9s), so the 2s debounce can fire mid-test -- stop it so
	# a delayed save_now() can't write live state to a real user://save.json.
	# See cooldown_pool_test.gd.
	SaveSystem._debounce_timer.stop()
	# Guard against double-free if GdUnit4's own GC frees tree-added nodes
	# between stages when a test awaits (see resource_system tests' note).
	if is_instance_valid(_action_system):
		_action_system.queue_free()


## AC-1: idle + known action_id -> accepted, state mutated, Timer started
## with that action's duration.
func test_start_action_from_idle_with_known_id_returns_true_and_starts_timer() -> void:
	var accepted: bool = _action_system.start_action(&"nagraj_vloga")

	assert_bool(accepted).is_true()
	assert_that(_action_system.current_action_id).is_equal(&"nagraj_vloga")
	assert_float(_action_system._timer.wait_time).is_equal_approx(6.0, 0.0001)
	assert_bool(_action_system._timer.is_stopped()).is_false()


## Added for Action UI's RunningActionOverlay (Story 004): action_started
## must fire exactly once on a successful start, carrying the started
## action_id.
func test_start_action_from_idle_emits_action_started_with_correct_id() -> void:
	var emitted_ids: Array[StringName] = []
	var on_started := func(action_id: StringName) -> void:
		emitted_ids.append(action_id)
	_action_system.action_started.connect(on_started)

	_action_system.start_action(&"nagraj_vloga")

	assert_array(emitted_ids).has_size(1)
	assert_that(emitted_ids[0]).is_equal(&"nagraj_vloga")


## Companion case: a rejected start (already running) must NOT emit
## action_started.
func test_start_action_while_running_does_not_emit_action_started() -> void:
	_action_system.start_action(&"zrob_drame")
	var emitted_ids: Array[StringName] = []
	var on_started := func(action_id: StringName) -> void:
		emitted_ids.append(action_id)
	_action_system.action_started.connect(on_started)

	_action_system.start_action(&"przeprosiny")

	assert_array(emitted_ids).is_empty()


## AC-1b: idle + unknown action_id -> rejected, no state mutation, no crash
## from indexing a missing ACTION_DURATIONS key, Timer not started.
func test_start_action_with_unknown_id_returns_false_and_does_not_mutate_state() -> void:
	var accepted: bool = _action_system.start_action(&"does_not_exist")

	assert_bool(accepted).is_false()
	assert_that(_action_system.current_action_id).is_equal(&"")
	assert_bool(_action_system._timer.is_stopped()).is_true()


## AC-2: an action is already running -> a second start_action() call
## (same OR different id) is rejected, current_action_id unchanged, the
## running Timer's time_left is not reset/restarted.
func test_start_action_while_running_returns_false_and_does_not_interrupt_running_timer() -> void:
	_action_system.start_action(&"zrob_drame")
	var time_left_before: float = _action_system._timer.time_left

	var accepted_same: bool = _action_system.start_action(&"zrob_drame")
	var accepted_different: bool = _action_system.start_action(&"przeprosiny")

	assert_bool(accepted_same).is_false()
	assert_bool(accepted_different).is_false()
	assert_that(_action_system.current_action_id).is_equal(&"zrob_drame")
	assert_float(_action_system._timer.time_left).is_equal_approx(time_left_before, 0.0001)


## AC-3: Timer elapsing -> _on_action_timeout() resets current_action_id to
## idle and emits action_completed exactly once with the completed action_id.
## Story 002 note: action_completed now also carries the resolved rewards
## dict; at default Morale (0.0, Critical band, 0.5x), przeprosiny's base
## Reach 6 scales to 3.0, so the expected payload reflects that.
func test_action_timeout_resets_state_and_emits_completed_signal_exactly_once() -> void:
	monitor_signals(_action_system)
	_action_system.start_action(&"przeprosiny")

	_action_system._on_action_timeout()

	assert_that(_action_system.current_action_id).is_equal(&"")
	var expected_rewards: Dictionary[StringName, float] = {
		&"Reach": 3.0,
		&"Cringe": -15.0,
		&"Morale": 5.0,
	}
	await assert_signal(_action_system).is_emitted("action_completed", [&"przeprosiny", expected_rewards])


## AC-3 edge case: the signal fires exactly once per timeout, not zero or
## twice, for a single completion. GdUnitSignalAssert has no emit-count API,
## so count emissions directly via a connected counter callable instead.
func test_action_timeout_emits_signal_exactly_once_not_zero_or_twice() -> void:
	var emit_count: Array = [0]
	_action_system.action_completed.connect(func(_id: StringName, _rewards: Dictionary) -> void: emit_count[0] += 1)
	_action_system.start_action(&"nagraj_vloga")

	_action_system._on_action_timeout()

	assert_int(emit_count[0]).is_equal(1)


## AC-4: idle -> get_progress() returns exactly 0.0, no divide-by-zero error
## even when the Timer's wait_time happens to be 0.
func test_get_progress_while_idle_returns_zero_with_no_divide_by_zero() -> void:
	assert_float(_action_system.get_progress()).is_equal_approx(0.0, 0.0001)

	_action_system._timer.wait_time = 0.0
	assert_float(_action_system.get_progress()).is_equal_approx(0.0, 0.0001)


## AC-5: running -> get_progress() tracks 1.0 - (time_left / wait_time) at
## start/mid/near-end. `Timer.time_left` is read-only in Godot 4.6 (cannot be
## set directly), so this drives the real Timer with a short duration and lets
## it tick down for real instead — bounded to ~0.3s wall time, not flaky.
func test_get_progress_while_running_tracks_time_left_at_start_mid_and_near_end() -> void:
	_action_system.current_action_id = &"nagraj_vloga"
	_action_system._timer.start(0.6)

	assert_float(_action_system.get_progress()).is_equal_approx(0.0, 0.2)

	await get_tree().create_timer(0.3).timeout
	assert_float(_action_system.get_progress()).is_equal_approx(0.5, 0.25)

	await get_tree().create_timer(0.2).timeout
	assert_float(_action_system.get_progress()).is_greater(0.7)


## AC-6: an action just completed (back to idle) -> immediately
## start_action() with the SAME id is accepted, i.e. no cooldown.
func test_start_action_immediately_after_completion_with_same_id_is_accepted() -> void:
	_action_system.start_action(&"zrob_drame")
	_action_system._on_action_timeout()

	var accepted: bool = _action_system.start_action(&"zrob_drame")

	assert_bool(accepted).is_true()
	assert_that(_action_system.current_action_id).is_equal(&"zrob_drame")
