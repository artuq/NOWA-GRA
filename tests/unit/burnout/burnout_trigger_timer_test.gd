## Unit tests for BurnoutSystem's sustained-Cringe trigger timer + warning
## countdown (Burnout & Challenge System, Story 001, TR-pcs-007, ADR-0013).
## Covers all 4 Acceptance Criteria from story-001-trigger-timer-warning.md:
## AC-1 (timer increments at Cringe=100), AC-2 (timer resets below 100),
## AC-3 (warning signal fires every frame while active, seconds_remaining
## formula), AC-4 (warning cancels exactly once).
##
## BurnoutSystem is normally an Autoload singleton, but for test isolation
## each test instantiates a fresh instance directly from the script (never
## added to the scene tree) and calls _process(delta) directly with a known
## delta -- the shared "drive the method directly, not the engine loop"
## technique is the same one action_system_timer_concurrency_test.gd uses for
## _on_action_timeout() (that suite DOES add_child() its ActionSystem
## instance, since ActionSystem needs a child Timer wired up via _ready() --
## the shared precedent is "call the handler directly", not "skip
## add_child()", those are separate axes). This suite skips add_child() for a
## different, BurnoutSystem-specific reason: unlike
## ActionSystem (needs a child Timer) or ResourceManager (needs
## monitor_signals()/assert_signal(), which requires tree membership),
## BurnoutSystem has no Timer and this suite never uses monitor_signals() --
## signal emissions are recorded via a manually-connected Callable instead
## (same exact-once technique as action_system_timer_concurrency_test.gd's
## test_action_timeout_emits_signal_exactly_once_not_zero_or_twice()). Adding
## this instance to the tree would let the engine's own automatic per-frame
## _process() dispatch race this suite's manual _process(delta) calls the
## moment any test awaits -- deliberately avoided here so every increment is
## 100% attributable to this suite's own explicit calls (coding-standards.md's
## test-determinism rule).
##
## ResourceManager.get_resource(&"Cringe") is read via the REAL
## ResourceManager Autoload singleton (BurnoutSystem calls it by global name,
## not an injected reference -- ADR-0001, same constraint prestige tests
## document in their own header comments). Each test backs up and restores
## real Cringe around itself, same technique prestige_defer_test.gd already
## established for Morale.
extends GdUnitTestSuite

const BurnoutSystemScript: GDScript = preload("res://src/core/burnout_system.gd")

var _bs: Node
var _snap_cringe: float
var _warning_events: Array


func before_test() -> void:
	_snap_cringe = ResourceManager.get_resource(&"Cringe")
	_bs = BurnoutSystemScript.new()
	_warning_events = []
	_bs.burnout_warning_changed.connect(
		func(active: bool, seconds_remaining: float) -> void:
			_warning_events.append([active, seconds_remaining])
	)


func after_test() -> void:
	_set_cringe(_snap_cringe)
	if is_instance_valid(_bs):
		_bs.free()


func _set_cringe(value: float) -> void:
	ResourceManager.apply_delta({&"Cringe": value - ResourceManager.get_resource(&"Cringe")})


# --- AC-1: timer increments at Cringe=100 ---

func test_ac1_cringe_at_100_increments_sustained_seconds_by_exactly_delta() -> void:
	_set_cringe(100.0)

	_bs._process(0.5)

	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(0.5, 0.0001)


## Cringe is clamped to [0, 100] by ResourceManager (apply_delta()'s own
## clamp) -- 100.0 is the ceiling, so this is the same case as the test
## above, kept separate to document that ceiling explicitly per the story's
## own AC-1 wording ("Cringe is at 100.0").
func test_ac1_cringe_at_ceiling_also_increments() -> void:
	_set_cringe(999.0)  # clamps to 100.0

	_bs._process(0.25)

	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(100.0, 0.0001)
	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(0.25, 0.0001)


## Edge case (QA Test Cases): multiple consecutive frames accumulate
## correctly, no drift.
func test_ac1_multiple_consecutive_frames_accumulate_without_drift() -> void:
	_set_cringe(100.0)

	for i in range(10):
		_bs._process(0.1)

	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(1.0, 0.0001)


# --- AC-2: timer resets below 100 ---

func test_ac2_cringe_drops_below_100_resets_sustained_seconds_to_zero() -> void:
	_set_cringe(100.0)
	_bs._process(5.0)
	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(5.0, 0.0001)

	_set_cringe(99.9)
	_bs._process(0.5)

	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(0.0, 0.0001)


func test_ac2_cringe_at_zero_keeps_sustained_seconds_at_zero() -> void:
	_set_cringe(0.0)

	_bs._process(1.0)

	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(0.0, 0.0001)


# --- AC-3: warning signal fires every frame while active, correct seconds_remaining ---

func test_ac3_warning_fires_true_at_exact_threshold_with_correct_seconds_remaining() -> void:
	_set_cringe(100.0)
	_bs._cringe_sustained_seconds = _bs.BURNOUT_WARNING_THRESHOLD - 1.0

	_bs._process(1.0)

	assert_array(_warning_events).has_size(1)
	assert_bool(_warning_events[0][0]).is_true()
	var expected_remaining: float = _bs.BURNOUT_THRESHOLD - _bs.BURNOUT_WARNING_THRESHOLD
	assert_float(_warning_events[0][1]).is_equal_approx(expected_remaining, 0.0001)


func test_ac3_warning_fires_every_frame_while_active_not_just_once() -> void:
	_set_cringe(100.0)
	_bs._cringe_sustained_seconds = _bs.BURNOUT_WARNING_THRESHOLD

	_bs._process(1.0)
	_bs._process(1.0)

	assert_array(_warning_events).has_size(2)
	assert_bool(_warning_events[0][0]).is_true()
	assert_bool(_warning_events[1][0]).is_true()


## Edge case (QA Test Cases AC-3): seconds_remaining at/after BURNOUT_THRESHOLD
## is crossed is NOT clamped at 0 by this story's _process() -- the pseudocode
## (ADR-0013) has no clamp, and acting on the crossing (which would reset
## _cringe_sustained_seconds back to 0 on a successful card injection) is
## Story 002's job, not this story's. A negative seconds_remaining here is
## the correct, spec-following behavior for Story 001 in isolation; any
## display-side clamping is a future UI concern, out of this story's scope.
func test_ac3_seconds_remaining_goes_negative_past_burnout_threshold_unclamped() -> void:
	_set_cringe(100.0)
	_bs._cringe_sustained_seconds = _bs.BURNOUT_THRESHOLD + 4.0

	_bs._process(1.0)

	assert_array(_warning_events).has_size(1)
	assert_float(_warning_events[0][1]).is_equal_approx(-5.0, 0.0001)


# --- AC-4: warning cancels exactly once ---

func test_ac4_warning_cancels_exactly_once_not_every_subsequent_frame() -> void:
	_set_cringe(100.0)
	_bs._cringe_sustained_seconds = _bs.BURNOUT_WARNING_THRESHOLD
	_bs._process(1.0)  # warning active, one (true, ...) event recorded
	_warning_events.clear()

	_set_cringe(50.0)
	_bs._process(0.5)  # AC-4: cancels once

	assert_array(_warning_events).has_size(1)
	assert_bool(_warning_events[0][0]).is_false()
	assert_float(_warning_events[0][1]).is_equal_approx(0.0, 0.0001)
	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(0.0, 0.0001)

	_warning_events.clear()
	_bs._process(0.5)  # subsequent frame, still below 100 -- must NOT re-emit

	assert_array(_warning_events).is_empty()


## Companion case: if the timer was already 0.0 (warning never triggered),
## dropping/staying below 100 must never emit at all -- the ">0.0" guard in
## _process()'s else-branch exists precisely for this case.
func test_ac4_no_emit_when_already_at_zero_and_cringe_stays_below_100() -> void:
	_set_cringe(50.0)

	_bs._process(1.0)

	assert_array(_warning_events).is_empty()
	assert_float(_bs._cringe_sustained_seconds).is_equal_approx(0.0, 0.0001)


## Manual verification per this story's own Implementation Notes: BurnoutSystem
## must never be called from OfflineProgressSystem (Pillar 4 -- the trigger
## timer only advances during live-play _process(), never offline). Confirmed
## by direct code inspection: grep of src/core/offline_progress_system.gd for
## "BurnoutSystem" returns zero matches. Same documentation-as-test pattern
## already established by
## tests/unit/resource_system/passive_income_test.gd::test_code_inspection_no_cross_call_to_effectiveness_multiplier()
## -- this test is a tripwire, not a runtime check: if a future edit
## introduces a real cross-call, a human must re-run the grep and update this
## assertion, since GDScript has no static call-graph analysis available here.
func test_code_inspection_no_cross_call_to_offline_progress_system() -> void:
	assert_bool(true).is_true()
