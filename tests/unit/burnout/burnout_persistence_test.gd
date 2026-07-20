## Unit tests for BurnoutSystem's restore_state()/serialize_state() pair
## (Burnout & Challenge System, Story 004, TR-pcs-007, ADR-0013 persistence
## pseudocode + ADR-0003 boot protocol). Covers all 3 Acceptance Criteria from
## story-004-burnout-persistence.md's QA Test Cases:
## AC-1 (round-trip persistence of _card_pending == true), AC-2 (missing-key
## default to false, plus the explicit-true edge case), AC-3
## (_cringe_sustained_seconds never persists -- key absent from
## serialize_state()'s output, and a stray key in restore_state()'s input is
## ignored).
##
## BurnoutSystem is normally an Autoload singleton, but for test isolation
## each test instantiates a fresh instance directly from the script (never
## added to the scene tree) -- same "drive the method directly, not the
## engine loop" technique tests/unit/burnout/burnout_trigger_timer_test.gd
## already established for this exact class. restore_state()/serialize_state()
## touch no signals and no ResourceManager state, so unlike that sibling
## suite this one needs no Cringe backup/restore around itself.
extends GdUnitTestSuite

const BurnoutSystemScript: GDScript = preload("res://src/core/burnout_system.gd")

var _bs: Node


func before_test() -> void:
	_bs = BurnoutSystemScript.new()


func after_test() -> void:
	if is_instance_valid(_bs):
		_bs.free()


# --- AC-1: round-trip persistence of true ---

func test_ac1_round_trip_true_preserves_card_pending_on_fresh_instance() -> void:
	_bs._card_pending = true

	var saved: Dictionary = _bs.serialize_state()

	var fresh: Node = BurnoutSystemScript.new()
	fresh.restore_state(saved)

	assert_bool(fresh._card_pending).is_true()
	fresh.free()


# --- AC-2: missing-key default ---

func test_ac2_restore_state_empty_dictionary_defaults_card_pending_to_false() -> void:
	_bs.restore_state({})

	assert_bool(_bs._card_pending).is_false()


## Edge case (QA Test Cases AC-2): an explicit true value in the input
## Dictionary restores correctly too, not just the missing-key path.
func test_ac2_restore_state_explicit_true_restores_card_pending_true() -> void:
	_bs.restore_state({"_card_pending": true})

	assert_bool(_bs._card_pending).is_true()


# --- AC-3: _cringe_sustained_seconds never persists ---

func test_ac3_serialize_state_omits_cringe_sustained_seconds_key_entirely() -> void:
	_bs._cringe_sustained_seconds = 42.0

	var saved: Dictionary = _bs.serialize_state()

	assert_bool(saved.has("_cringe_sustained_seconds")).is_false()


## Edge case (QA Test Cases AC-3): a stray "_cringe_sustained_seconds" key in
## restore_state()'s input (e.g. a hand-edited save file) must be ignored --
## the field stays at its own declared 0.0 default, never reads that key.
func test_ac3_restore_state_ignores_stray_cringe_sustained_seconds_key() -> void:
	_bs.restore_state({"_card_pending": false, "_cringe_sustained_seconds": 999.0})

	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(0.0, 0.0001)
