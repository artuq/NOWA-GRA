## Integration tests for ActionSystem's queue and auto-repeat behaviour
## (Action System Story 003). Covers all 7 QA acceptance criteria:
##
##   AC-1  queued action auto-starts after current action completes
##   AC-2  queue cap (QUEUE_CAP = 10) prevents adding beyond limit
##   AC-3  Decision Card presentation suspends auto-dequeue
##   AC-4  card_resolved lifts card suspension and auto-dequeues
##   AC-5  Morale Critical suspends auto-dequeue
##   AC-6  clear_queue() empties the array without stopping the running action
##   AC-7  single-action (no queue) regression — idle start still works
##
## Test isolation strategy mirrors action_system_reward_resolution_test.gd:
##   - A fresh ActionSystem instance (not the Autoload) is created per test so
##     its _queue / suspend flags never leak across tests.
##   - The fresh instance's _ready() connects to the real DecisionCardSystem
##     and ResourceManager Autoloads, so we emit signals on those to drive the
##     instance under test.
##   - ResourceManager state is snapshot/restored in before_test/after_test.
##   - _on_action_timeout() is called directly (bypasses the real Timer, which
##     would require awaiting real wall-clock time — deterministic per
##     coding-standards.md).
##   - Connections added in before_test are disconnected in after_test to
##     prevent cross-test leakage.
##   - SaveSystem._debounce_timer.stop() is called in after_test to prevent a
##     delayed save_now() firing mid-suite (same fix as reward_resolution_test).
extends GdUnitTestSuite

const ActionSystemScript: GDScript = preload("res://src/core/action_system.gd")

var _action_system: Node
var _snapshot: Dictionary[StringName, float] = {}


func before_test() -> void:
	_snapshot[&"Reach"] = ResourceManager.get_resource(&"Reach")
	_snapshot[&"Cringe"] = ResourceManager.get_resource(&"Cringe")
	_snapshot[&"Morale"] = ResourceManager.get_resource(&"Morale")
	_action_system = ActionSystemScript.new()
	add_child(_action_system)


func after_test() -> void:
	if is_instance_valid(_action_system):
		# Disconnect this instance's Autoload subscriptions before freeing it.
		# queue_free() defers actual node removal to the end of the frame, so
		# without an explicit disconnect these connections (and the instance's
		# still-running Timer) can fire during a later test in the same suite
		# run and pollute its assertions (cross-test signal leak).
		DecisionCardSystem.card_presented.disconnect(_action_system._on_card_presented)
		DecisionCardSystem.card_resolved.disconnect(_action_system._on_card_resolved)
		ResourceManager.resource_changed.disconnect(_action_system._on_resource_changed)
		_action_system._timer.stop()
		_action_system.queue_free()
	# Restore ResourceManager to pre-test state.
	var restore: Dictionary[StringName, float] = {}
	for key: StringName in _snapshot:
		restore[key] = _snapshot[key] - ResourceManager.get_resource(key)
	ResourceManager.apply_delta(restore)
	# Stop the save debounce timer so it can't fire mid-suite.
	SaveSystem._debounce_timer.stop()


## Sets [param resource_name] on the real ResourceManager Autoload to exactly
## [param value] via a computed apply_delta() call — the same helper pattern
## used in action_system_reward_resolution_test.gd.
func _set_resource(resource_name: StringName, value: float) -> void:
	var delta: float = value - ResourceManager.get_resource(resource_name)
	ResourceManager.apply_delta({resource_name: delta})


## AC-1: given action A running and action B queued, when A resolves, B starts
## automatically without any player tap.
func test_queued_action_starts_automatically_after_current_completes() -> void:
	# ResourceManager defaults Morale to 0.0, which is already in the Critical
	# band (< E_LOW_THRESHOLD = 15.0) and would suspend the queue on its own.
	# Set a normal Morale baseline so this test isolates the auto-dequeue
	# behaviour from the morale-suspend behaviour (covered separately by
	# test_morale_critical_suspends_queue).
	_set_resource(&"Morale", 100.0)

	# Start action A.
	var started_a: bool = _action_system.start_action(&"nagraj_vloga")
	assert_bool(started_a).is_true()
	assert_that(_action_system.current_action_id).is_equal(&"nagraj_vloga")

	# Queue action B while A is running — start_action returns true (enqueued).
	var queued_b: bool = _action_system.start_action(&"zrob_drame")
	assert_bool(queued_b).is_true()
	assert_int(_action_system._queue.size()).is_equal(1)
	assert_that(_action_system._queue[0]).is_equal(&"zrob_drame")

	# Resolve A by calling _on_action_timeout() directly (no real timer wait).
	_action_system._on_action_timeout()

	# B should have auto-started: current_action_id is now B, queue is empty.
	assert_that(_action_system.current_action_id).is_equal(&"zrob_drame")
	assert_int(_action_system._queue.size()).is_equal(0)


## AC-2: when the queue is full (QUEUE_CAP items), start_action returns false
## and the queue size does not exceed the cap.
func test_queue_cap_prevents_adding_beyond_limit() -> void:
	# Start one action so subsequent calls enqueue.
	_action_system.start_action(&"nagraj_vloga")

	# Fill the queue to QUEUE_CAP.
	for _i in _action_system.QUEUE_CAP:
		_action_system.start_action(&"przeprosiny")

	assert_int(_action_system._queue.size()).is_equal(_action_system.QUEUE_CAP)

	# One more attempt must return false and leave the size unchanged.
	var over_cap: bool = _action_system.start_action(&"przeprosiny")
	assert_bool(over_cap).is_false()
	assert_int(_action_system._queue.size()).is_equal(_action_system.QUEUE_CAP)


## AC-3: when a Decision Card is presented while a queued action is waiting,
## resolving the running action does NOT auto-start the next queued action.
func test_decision_card_suspends_queue() -> void:
	_action_system.start_action(&"nagraj_vloga")
	_action_system.start_action(&"zrob_drame")

	# Simulate card presentation — emit on the real Autoload so the instance's
	# _ready() connection fires.
	DecisionCardSystem.card_presented.emit({})

	assert_bool(_action_system._suspended_by_card).is_true()

	# Resolve the running action.
	_action_system._on_action_timeout()

	# Queue still has zrob_drame — it must NOT have auto-started.
	assert_that(_action_system.current_action_id).is_equal(&"")
	assert_int(_action_system._queue.size()).is_equal(1)

	# Clean up: lift suspension via card_resolved so the signal is balanced.
	DecisionCardSystem.card_resolved.emit(&"", &"", &"")


## AC-4: after the Decision Card is resolved, card suspension lifts and the
## next queued action starts automatically.
func test_suspend_clears_on_card_resolved() -> void:
	# See test_queued_action_starts_automatically_after_current_completes:
	# default Morale (0.0) is in the Critical band and would suspend the
	# queue independently of the card suspend under test here.
	_set_resource(&"Morale", 100.0)

	_action_system.start_action(&"nagraj_vloga")
	_action_system.start_action(&"zrob_drame")

	# Present a card — suspends the queue.
	DecisionCardSystem.card_presented.emit({})

	# Resolve the running action while suspended — B should NOT start yet.
	_action_system._on_action_timeout()
	assert_that(_action_system.current_action_id).is_equal(&"")

	# Resolve the card — suspension lifts and B should auto-start.
	DecisionCardSystem.card_resolved.emit(&"", &"", &"")

	assert_that(_action_system.current_action_id).is_equal(&"zrob_drame")
	assert_int(_action_system._queue.size()).is_equal(0)


## Regression: lifting card suspension while the current action is still
## running must not pop and re-enqueue the queue head. That would silently
## rotate FIFO order (B,C -> C,B) now that the UI permits normal queue input.
func test_card_resolved_before_active_action_finishes_preserves_fifo_order() -> void:
	_set_resource(&"Morale", 100.0)
	_action_system.start_action(&"nagraj_vloga")
	_action_system.start_action(&"zrob_drame")
	_action_system.start_action(&"przeprosiny")
	DecisionCardSystem.card_presented.emit({})

	DecisionCardSystem.card_resolved.emit(&"", &"", &"")

	assert_that(_action_system.current_action_id).is_equal(&"nagraj_vloga")
	assert_array(_action_system._queue).is_equal([&"zrob_drame", &"przeprosiny"])


## AC-5: when Morale is in the Critical band (< E_LOW_THRESHOLD = 15.0),
## the queue is suspended and the next queued action does not auto-start
## when the running action resolves.
func test_morale_critical_suspends_queue() -> void:
	_action_system.start_action(&"nagraj_vloga")
	_action_system.start_action(&"zrob_drame")

	# Drop Morale into Critical band — this fires resource_changed on ResourceManager,
	# which the instance's _on_resource_changed() picks up via its _ready() connection.
	_set_resource(&"Morale", 10.0)

	assert_bool(_action_system._suspended_by_morale).is_true()

	# Resolve the running action — B should NOT auto-start.
	_action_system._on_action_timeout()

	assert_that(_action_system.current_action_id).is_equal(&"")
	assert_int(_action_system._queue.size()).is_equal(1)


## Regression: ResourceManager.apply_delta() emits resource_changed
## synchronously, which can reentrantly lift `_suspended_by_morale` and call
## `_try_dequeue()` from inside `_on_action_timeout()`'s own resolution work
## -- before that call has emitted `action_completed` for the action that
## just finished. Without the `_resolving` guard, the queued action's
## `action_started` would fire before the resolving action's own
## `action_completed`, an inverted order that breaks
## running_action_overlay.gd (it would hide itself for the new action's
## entire duration -- code-review finding, 2026-06-30).
func test_morale_recovery_during_resolution_preserves_signal_order() -> void:
	# Critical band -- queue starts suspended by morale.
	_set_resource(&"Morale", 12.0)
	assert_bool(_action_system._suspended_by_morale).is_true()

	# przeprosiny's reward includes Morale +5.0, which will cross the 15.0
	# threshold and lift the suspend mid-resolution.
	_action_system.start_action(&"przeprosiny")
	_action_system.start_action(&"nagraj_vloga")

	var emission_order: Array[String] = []
	_action_system.action_completed.connect(
		func(_id: StringName, _rewards: Dictionary) -> void: emission_order.append("completed")
	)
	_action_system.action_started.connect(
		func(_id: StringName) -> void: emission_order.append("started")
	)

	_action_system._on_action_timeout()

	assert_array(emission_order).is_equal(["completed", "started"])
	assert_that(_action_system.current_action_id).is_equal(&"nagraj_vloga")
	assert_int(_action_system._queue.size()).is_equal(0)


## AC-6: clear_queue() empties the array while the running action continues
## unaffected.
func test_clear_queue_empties_array() -> void:
	_action_system.start_action(&"nagraj_vloga")
	_action_system.start_action(&"zrob_drame")
	_action_system.start_action(&"przeprosiny")
	_action_system.start_action(&"nagraj_vloga")

	assert_int(_action_system._queue.size()).is_equal(3)

	# Clear while nagraj_vloga is still running.
	_action_system.clear_queue()

	assert_int(_action_system._queue.size()).is_equal(0)
	# The running action is unaffected.
	assert_that(_action_system.current_action_id).is_equal(&"nagraj_vloga")


## Public queue reads return a typed copy so recreated presentation can rebuild
## itself without gaining mutation access to ActionSystem's owned array.
func test_queue_snapshot_is_a_copy_and_cannot_mutate_owned_queue() -> void:
	_action_system.start_action(&"nagraj_vloga")
	_action_system.start_action(&"zrob_drame")
	_action_system.start_action(&"przeprosiny")

	var snapshot: Array[StringName] = _action_system.get_queue_snapshot()
	snapshot.clear()

	assert_int(_action_system.get_queue_size()).is_equal(2)
	assert_array(_action_system._queue).is_equal([&"zrob_drame", &"przeprosiny"])


## AC-7 regression: single-action tap while idle must start the action
## immediately, with no queueing, identical to pre-Story-003 behaviour.
func test_single_action_no_queue_regression() -> void:
	assert_that(_action_system.current_action_id).is_equal(&"")
	assert_int(_action_system._queue.size()).is_equal(0)

	var started: bool = _action_system.start_action(&"przeprosiny")

	assert_bool(started).is_true()
	assert_that(_action_system.current_action_id).is_equal(&"przeprosiny")
	# Nothing was placed in the queue — idle start goes straight to running.
	assert_int(_action_system._queue.size()).is_equal(0)
