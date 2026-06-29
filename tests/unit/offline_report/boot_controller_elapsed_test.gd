## Unit tests for BootController.compute_elapsed_seconds (Story 003 gap, flagged
## by qa-tester: the real elapsed-time computation that _ready() performs from
## SaveSystem.load_save() + Time.get_unix_time_from_system() was previously
## bypassed entirely by the boot_with() test seam and had zero coverage). Pure
## static function — explicit (data, now) args, no clock/Autoload dependency.
extends GdUnitTestSuite

## AC: first session (no "last_saved_at" key) falls back to `now` itself,
## yielding elapsed=0 -- the correct "nothing to report" case.
func test_missing_last_saved_at_falls_back_to_now_yielding_zero() -> void:
	var now: float = 1782755391.0
	assert_int(BootController.compute_elapsed_seconds({}, now)).is_equal(0)

## AC: a real gap between last_saved_at and now computes the correct elapsed.
func test_computes_elapsed_from_last_saved_at() -> void:
	var now: float = 1782755391.0
	var data: Dictionary = {"last_saved_at": now - 7200.0}  # 2 hours ago
	assert_int(BootController.compute_elapsed_seconds(data, now)).is_equal(7200)

## AC: truncates toward zero via int() (sub-second precision is irrelevant to
## the second-granularity threshold/cap logic downstream).
func test_truncates_fractional_seconds() -> void:
	var now: float = 1000.9
	var data: Dictionary = {"last_saved_at": 0.4}
	assert_int(BootController.compute_elapsed_seconds(data, now)).is_equal(1000)
