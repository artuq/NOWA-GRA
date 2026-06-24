## Unit tests for HistoryFlagManager's Path Resolution Algorithm (Story 002,
## TR-hist-001). Covers all 6 acceptance criteria: zero/one/two-eligible
## cases, the margin's inclusive `>=` boundary (met and not met), an exact
## tie, and the `threshold_min` boundary's inclusive `>=` in the
## single-eligible branch (AC-6, added via QL-STORY-READY 2026-06-24).
##
## HistoryFlagManager is normally an Autoload singleton, but for test
## isolation each test instantiates a fresh instance directly from the script
## and adds it to the scene tree, then frees it on cleanup. No shared state
## between tests, no random seeds, no time-dependent assertions, no external
## I/O — per coding-standards.md.
##
## Per the story's explicit test-suite note, margin/threshold values are read
## from the Autoload's exposed constants (_MARGIN, _REGISTERED_PATHS) rather
## than hardcoded as bare literals, so future tuning changes don't silently
## invalidate this suite.
extends GdUnitTestSuite

const HistoryFlagManagerScript: GDScript = preload("res://src/core/history_flag_manager.gd")

var _hfm: Node
var _risky_path: Dictionary
var _safe_path: Dictionary
var _margin: int


func before_test() -> void:
	_hfm = HistoryFlagManagerScript.new()
	add_child(_hfm)
	_risky_path = HistoryFlagManagerScript._REGISTERED_PATHS[0]
	_safe_path = HistoryFlagManagerScript._REGISTERED_PATHS[1]
	_margin = HistoryFlagManagerScript._MARGIN


func after_test() -> void:
	# Guard against double-free if GdUnit4's own GC frees tree-added nodes
	# between stages (see resource_system/action_system tests' precedent).
	if is_instance_valid(_hfm):
		_hfm.queue_free()


## AC-1: neither counter reaches its threshold_min -> resolve_path_eligibility()
## returns null (zero eligible).
func test_resolve_path_eligibility_returns_null_when_zero_eligible() -> void:
	_hfm.increment_counter(_risky_path["counter"], _risky_path["threshold_min"] - 1)
	_hfm.increment_counter(_safe_path["counter"], 2)

	assert_object(_hfm.resolve_path_eligibility()).is_null()


## AC-2: exactly one counter clears its threshold_min -> returns that path's
## name. Edge case: the single-eligible branch must return immediately
## without needing the margin comparison.
func test_resolve_path_eligibility_returns_path_when_one_eligible() -> void:
	_hfm.increment_counter(_risky_path["counter"], _risky_path["threshold_min"] + 1)
	_hfm.increment_counter(_safe_path["counter"], 1)

	assert_str(_hfm.resolve_path_eligibility()).is_equal(_risky_path["path"])


## AC-3: two eligible, lead exactly meets _MARGIN -> returns the higher path.
## Edge case: this is the inclusive boundary case for the margin check — must
## use >=, not >.
func test_resolve_path_eligibility_returns_path_when_margin_exactly_met() -> void:
	_hfm.increment_counter(_risky_path["counter"], _risky_path["threshold_min"] + _margin)
	_hfm.increment_counter(_safe_path["counter"], _safe_path["threshold_min"])

	assert_str(_hfm.resolve_path_eligibility()).is_equal(_risky_path["path"])


## AC-4: two eligible, lead is one short of _MARGIN -> returns null. Edge
## case: pairs with AC-3 to lock the >= semantics precisely.
func test_resolve_path_eligibility_returns_null_when_margin_not_met() -> void:
	_hfm.increment_counter(_risky_path["counter"], _risky_path["threshold_min"] + _margin - 1)
	_hfm.increment_counter(_safe_path["counter"], _safe_path["threshold_min"])

	assert_object(_hfm.resolve_path_eligibility()).is_null()


## AC-5: two eligible, exact tie -> returns null. Edge case: both paths
## exactly tied at the threshold — must not arbitrarily pick one.
func test_resolve_path_eligibility_returns_null_on_exact_tie() -> void:
	_hfm.increment_counter(_risky_path["counter"], _risky_path["threshold_min"])
	_hfm.increment_counter(_safe_path["counter"], _safe_path["threshold_min"])

	assert_object(_hfm.resolve_path_eligibility()).is_null()


## AC-6 (added via QL-STORY-READY 2026-06-24): a counter sits exactly at its
## threshold_min, the other counter is zero (not eligible at all) -> returns
## the single eligible path. Confirms counter_above_threshold()'s inclusive
## >= applies correctly in the single-eligible branch, not just the margin
## branch (AC-3/AC-4 already lock >= for margin; this locks it for threshold).
func test_resolve_path_eligibility_returns_path_at_exact_threshold_boundary() -> void:
	_hfm.increment_counter(_risky_path["counter"], _risky_path["threshold_min"])

	assert_str(_hfm.resolve_path_eligibility()).is_equal(_risky_path["path"])
