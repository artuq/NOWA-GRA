## Regression tests for SaveSystem.mark_dirty() call-site wiring (found missing
## entirely during manual playtesting, 2026-06-29: zero call sites existed
## outside save_system.gd itself, so save.json was never written during normal
## play and nothing survived a restart). ADR-0002 designed this wiring
## explicitly ("[Game state mutation] -> SaveSystem.mark_dirty()") but it was
## never implemented until now.
##
## Targets the real SaveSystem Autoload singleton (the mutation methods under
## test hardcode the global `SaveSystem` name, not an injectable instance) --
## asserts only that its debounce timer starts running, not the full 2s+ file
## write (that mechanism has its own coverage in save_debounce_test.gd). The
## timer is force-stopped before and after each test so this suite never
## leaves a pending write that could fire mid-suite or pollute user://.
extends GdUnitTestSuite

var _reach_snapshot: float

func before_test() -> void:
	SaveSystem._debounce_timer.stop()
	_reach_snapshot = ResourceManager.get_resource(&"Reach")

func after_test() -> void:
	SaveSystem._debounce_timer.stop()
	ResourceManager.apply_delta({&"Reach": _reach_snapshot - ResourceManager.get_resource(&"Reach")})

## AC: ResourceManager.apply_delta (the sole write path -- Action System
## rewards, Decision Card resolutions, and BootController's offline-sim apply
## all funnel through this one method) marks the save dirty.
func test_apply_delta_marks_dirty() -> void:
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_true()
	ResourceManager.apply_delta({&"Reach": 1.0})
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()

## AC: an empty deltas dict (a legitimate no-op call, e.g. a zero-elapsed
## offline sim) does NOT mark dirty -- no real mutation occurred.
func test_apply_delta_with_empty_dict_does_not_mark_dirty() -> void:
	ResourceManager.apply_delta({})
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_true()

## AC: HistoryFlagManager.set_milestone marks dirty (Decision Card resolutions
## that set a milestone must persist it).
func test_set_milestone_marks_dirty() -> void:
	var flag: StringName = &"test.mark_dirty_wiring.milestone"
	var had_flag: bool = HistoryFlagManager.has_milestone(flag)
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_true()

	HistoryFlagManager.set_milestone(flag)

	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()
	if not had_flag:
		# No unset API exists (by design, see set_milestone's doc comment) --
		# this test-created flag is harmless and permanent, consistent with
		# every other milestone test in this codebase.
		pass

## AC: HistoryFlagManager.increment_counter marks dirty.
func test_increment_counter_marks_dirty() -> void:
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_true()
	HistoryFlagManager.increment_counter(&"test_mark_dirty_wiring_counter", 1)
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_false()

## AC: a rejected increment_counter call (negative amount, the module's only
## validation) does NOT mark dirty -- no mutation occurred.
func test_increment_counter_with_negative_amount_does_not_mark_dirty() -> void:
	HistoryFlagManager.increment_counter(&"test_mark_dirty_wiring_counter", -1)
	assert_bool(SaveSystem._debounce_timer.is_stopped()).is_true()
