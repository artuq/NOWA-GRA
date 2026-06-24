## Unit tests for HistoryFlagManager's core milestone/counter contract (Story
## 001, TR-hist-001). Covers all 10 acceptance criteria: milestone set/query/
## idempotency, counter increment/accumulation/zero-noop/negative-rejection/
## default, and counter_above_threshold()'s inclusive boundary at both the
## true and false case.
##
## HistoryFlagManager is normally an Autoload singleton, but for test
## isolation each test instantiates a fresh instance directly from the script
## and adds it to the scene tree, then frees it on cleanup. No shared state
## between tests, no random seeds, no time-dependent assertions, no external
## I/O — per coding-standards.md.
##
## Not automatable as runtime tests (per the story's QA Test Cases section —
## verified via API-surface/code review instead, e.g.
## `grep -n "unset_milestone\|decrement" src/core/history_flag_manager.gd`
## returns nothing): no API exists to unset a milestone or decrement a
## counter; counter overflow is unreachable in practice (64-bit int) and is a
## closed, not deferred, design decision.
extends GdUnitTestSuite

const HistoryFlagManagerScript: GDScript = preload("res://src/core/history_flag_manager.gd")

var _hfm: Node


func before_test() -> void:
	_hfm = HistoryFlagManagerScript.new()
	add_child(_hfm)


func after_test() -> void:
	# Guard against double-free if GdUnit4's own GC frees tree-added nodes
	# between stages (see resource_system/action_system tests' precedent).
	if is_instance_valid(_hfm):
		_hfm.queue_free()


## AC-1: milestone never set -> set_milestone() -> has_milestone() returns
## true. Edge case: milestone name never seen before (no pre-existing key).
func test_set_milestone_on_unset_milestone_then_has_milestone_returns_true() -> void:
	_hfm.set_milestone(&"card.exposed_friend.chosen")

	assert_bool(_hfm.has_milestone(&"card.exposed_friend.chosen")).is_true()


## AC-2: a milestone never written -> has_milestone() returns false, no
## error. Edge case: querying immediately after instantiation, before any
## write.
func test_has_milestone_never_written_returns_false_with_no_error() -> void:
	assert_bool(_hfm.has_milestone(&"card.never_seen")).is_false()


## AC-3: a milestone already true -> set_milestone() called again (and
## again) -> state unchanged, no error, no side effect. Edge case: call it
## 3+ times in a row to confirm no toggling on later calls.
func test_set_milestone_called_twice_is_idempotent() -> void:
	_hfm.set_milestone(&"card.exposed_friend.chosen")
	_hfm.set_milestone(&"card.exposed_friend.chosen")
	_hfm.set_milestone(&"card.exposed_friend.chosen")

	assert_bool(_hfm.has_milestone(&"card.exposed_friend.chosen")).is_true()


## AC-4: counter never written (defaults to 0) -> increment_counter(..., 1)
## -> get_counter() returns 1. Edge case: counter name never seen before.
func test_increment_counter_from_default_then_get_counter_returns_one() -> void:
	_hfm.increment_counter(&"risky_choices_count", 1)

	assert_int(_hfm.get_counter(&"risky_choices_count")).is_equal(1)


## AC-5: counter = 3 -> increment_counter(..., 4) -> counter = 7. Edge case:
## multiple sequential increments compound correctly.
func test_increment_counter_accumulates_across_calls() -> void:
	_hfm.increment_counter(&"risky_choices_count", 3)
	_hfm.increment_counter(&"risky_choices_count", 4)

	assert_int(_hfm.get_counter(&"risky_choices_count")).is_equal(7)


## AC-6: counter = 5 -> increment_counter(..., 0) -> counter remains 5
## (no-op). Edge case: confirm no error and no spurious write.
func test_increment_counter_zero_amount_is_noop() -> void:
	_hfm.increment_counter(&"risky_choices_count", 5)
	_hfm.increment_counter(&"risky_choices_count", 0)

	assert_int(_hfm.get_counter(&"risky_choices_count")).is_equal(5)


## AC-7: counter = 5 -> increment_counter(..., -1) -> call rejected, counter
## remains 5. Edge case: confirms the amount >= 0 contract — the one
## validation this module performs.
func test_increment_counter_negative_amount_is_rejected_counter_unchanged() -> void:
	_hfm.increment_counter(&"risky_choices_count", 5)
	_hfm.increment_counter(&"risky_choices_count", -1)

	assert_int(_hfm.get_counter(&"risky_choices_count")).is_equal(5)


## AC-8: a counter never written -> get_counter() returns 0. Edge case:
## querying immediately after instantiation, before any write.
func test_get_counter_never_written_returns_zero() -> void:
	assert_int(_hfm.get_counter(&"never_written_count")).is_equal(0)


## AC-9: counter = 5 -> counter_above_threshold(..., 5) -> returns true
## (inclusive >=, despite the method name). Edge case: exact equality is the
## boundary being tested, not an approximation.
func test_counter_above_threshold_inclusive_boundary_true_case() -> void:
	_hfm.increment_counter(&"risky_choices_count", 5)

	assert_bool(_hfm.counter_above_threshold(&"risky_choices_count", 5)).is_true()


## AC-10: counter = 4 -> counter_above_threshold(..., 5) -> returns false.
## Edge case: one below threshold is the boundary being tested.
func test_counter_above_threshold_inclusive_boundary_false_case() -> void:
	_hfm.increment_counter(&"risky_choices_count", 4)

	assert_bool(_hfm.counter_above_threshold(&"risky_choices_count", 5)).is_false()
