## Tests for PrestigeSystem.on_burnout_deferred() (Story 006, "Choice B
## (Defer) — Morale Floor, No Grant", TR-pcs-001, ADR-0012 §2 -- Defer is the
## path NOT taken through on_burnout_accepted()).
##
## Filed under tests/unit/prestige/ per this story's own Test Evidence
## requirement, but -- like this suite's tests/integration/prestige/ siblings
## -- exercises the REAL ResourceManager/HistoryFlagManager/ClassPathSystem/
## PrestigeSystem Autoload singletons, not mocks (none of them support
## dependency injection by design, ADR-0001; same established precedent as
## prestige_orchestration_test.gd/prestige_grant_wiring_test.gd's own header
## comments). Each test backs up and restores real state around itself.
##
## "Zero calls" technique (Implementation Notes' critical negative
## assertion): the story asks to "spy on ClassPathSystem.get_active_path()/
## get_tier() and PrestigeFormulas.grant_magnitude() -- assert zero calls".
## Neither is spyable via GdUnit4's instance-based spy()/mock() in this
## codebase's architecture:
##   - ClassPathSystem is a registered Autoload singleton. GdUnitSpyBuilder.
##     build() explicitly refuses singletons ("Spy on a Singleton is not
##     allowed!", GdUnitSpyBuilder.gd) -- and PrestigeSystem calls it via the
##     fixed global name, not an injected reference, so there is no seam to
##     substitute a separately-built spy instance into.
##   - PrestigeFormulas.grant_magnitude() is a stateless STATIC method
##     (ADR-0012 §3, no autoload, no instance) -- GDScript has no mechanism to
##     intercept a static call at runtime at all, regardless of spy tooling.
## test_on_burnout_deferred_calls_zero_grant_machinery_static_scan() below
## substitutes a runtime SOURCE-TEXT static scan of on_burnout_deferred()'s
## function body -- same technique this suite's sibling
## prestige_orchestration_test.gd already uses for a structural guarantee
## (test_prestige_system_registered_below_its_four_dependencies(), which
## parses project.godot as text). This is strictly stronger than an instance
## call-count spy: it proves the call sites are absent from the source for
## EVERY possible execution, not just the one this test run happened to
## exercise -- exactly the gap the story's Implementation Notes warns a
## read-then-discard implementation could otherwise sneak through
## ("an implementation that reads-then-discards would pass a
## totals-unchanged-only test while still violating the intent"). The
## behavioral tests below (totals unchanged) are kept anyway as defense in
## depth, not as the sole proof.
extends GdUnitTestSuite

const _ALL_BONUS_TYPES: Array[StringName] = [
	&"META_REACH_MULT", &"META_SPONSOR_MULT", &"META_HATERS_RESIST", &"META_SPONSOR_FLOOR",
]

var _snap_morale: float
var _snap_era_count: int
var _snap_meta_totals: Dictionary


func before_test() -> void:
	_snap_morale = ResourceManager.get_resource(&"Morale")
	_snap_era_count = PrestigeSystem.era_count
	_snap_meta_totals = PrestigeSystem.meta_bonus_totals.duplicate()
	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func after_test() -> void:
	var morale_delta: float = _snap_morale - ResourceManager.get_resource(&"Morale")
	ResourceManager.apply_delta({&"Morale": morale_delta})
	PrestigeSystem.restore_state({
		"era_count": _snap_era_count,
		"meta_bonus_totals": _snap_meta_totals,
	})
	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func _set_morale(value: float) -> void:
	ResourceManager.apply_delta({&"Morale": value - ResourceManager.get_resource(&"Morale")})


func _totals_snapshot() -> Dictionary:
	var out: Dictionary = {}
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		out[bonus_type] = PrestigeSystem.get_meta_bonus_total(bonus_type)
	return out


# --- AC-1: Morale below BURNOUT_DEFER_MORALE_COST clamps to 0, no grant ---

func test_ac1_below_cost_clamps_to_zero_and_totals_unchanged() -> void:
	_set_morale(20.0)
	var totals_before: Dictionary = _totals_snapshot()

	PrestigeSystem.on_burnout_deferred(50.0)

	assert_float(ResourceManager.get_resource(&"Morale")).override_failure_message(
		"Morale must clamp to exactly 0 when the defer cost exceeds current Morale"
	).is_equal(0.0)
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).override_failure_message(
			"META_BONUS_total[%s] must remain byte-for-byte unchanged by Defer" % bonus_type
		).is_equal_approx(totals_before[bonus_type], 0.0001)


## Edge case (QA Test Cases, AC-1): Morale far below cost -- a large negative
## pre-clamp value must still land exactly at 0, not some other floor.
func test_ac1_edge_far_below_cost_still_clamps_exactly_to_zero() -> void:
	_set_morale(0.0)

	PrestigeSystem.on_burnout_deferred(500.0)

	assert_float(ResourceManager.get_resource(&"Morale")).is_equal(0.0)


# --- AC-2: Morale exactly equal to the defer cost -- no underflow ---

func test_ac2_exact_boundary_clamps_to_zero_no_underflow() -> void:
	_set_morale(50.0)
	var totals_before: Dictionary = _totals_snapshot()

	PrestigeSystem.on_burnout_deferred(50.0)

	assert_float(ResourceManager.get_resource(&"Morale")).override_failure_message(
		"Morale exactly at the defer cost must land at exactly 0, not underflow negative"
	).is_equal(0.0)
	for bonus_type: StringName in _ALL_BONUS_TYPES:
		assert_float(PrestigeSystem.get_meta_bonus_total(bonus_type)).is_equal_approx(totals_before[bonus_type], 0.0001)


# --- AC-1/AC-2 (negative assertion): zero calls to PrestigeSystem's grant machinery ---

## See this file's header comment for why a source-text static scan is used
## instead of an instance-based call-count spy.
func test_on_burnout_deferred_calls_zero_grant_machinery_static_scan() -> void:
	var source: String = FileAccess.get_file_as_string("res://src/core/prestige_system.gd")
	var start: int = source.find("func on_burnout_deferred(")
	assert_int(start).override_failure_message(
		"on_burnout_deferred() must exist on PrestigeSystem"
	).is_greater(-1)

	# Function body ends at the first blank-line gap after the signature --
	# this file's own convention is two blank lines between top-level members
	# (see e.g. the gap between on_burnout_accepted() and this method), so
	# slicing at "\nfunc " would wrongly swallow the NEXT function's doc
	# comment (which sits between the two blank lines and the next "func "
	# line) into this body -- exactly what happened on first pass here
	# (_first_burnout_pending()'s own doc comment mentions "ClassPathSystem"
	# in prose, producing a false positive). Same overall source-text-slicing
	# technique prestige_orchestration_test.gd's own structural check uses
	# (String.find() on project.godot), refined to stop at the blank-line gap
	# instead of the next "func" keyword.
	var blank_gap: int = source.find("\n\n\n", start)
	var body_end: int = blank_gap if blank_gap != -1 else source.length()
	var body: String = source.substr(start, body_end - start)

	var forbidden: Array[String] = [
		"get_active_path", "get_tier", "reset_era_state",
		"grant_magnitude", "apply_stacking_and_cap",
		"ClassPathSystem", "PrestigeFormulas",
		"_apply_grant", "_check_variety_bonus",
	]
	for token: String in forbidden:
		assert_bool(body.contains(token)).override_failure_message(
			"on_burnout_deferred() must call ZERO of PrestigeSystem's grant machinery -- found forbidden reference '%s' in its body" % token
		).is_false()


# --- AC-3: meta-persistent flag write, survives a subsequent era transition ---

func test_ac3_flag_is_written_for_the_current_era() -> void:
	var era: int = PrestigeSystem.era_count
	_set_morale(100.0)

	PrestigeSystem.on_burnout_deferred(30.0)

	assert_bool(HistoryFlagManager.has_milestone(StringName("burnout_deferred_era_" + str(era)))).override_failure_message(
		"burnout_deferred_era_N (N = current era) must be set via HistoryFlagManager when Defer resolves"
	).is_true()


## Distinguishes the flag from an era-local one: a real subsequent era
## transition (ClassPathSystem.reset_era_state() + PrestigeSystem.
## on_burnout_accepted()) must not clear it -- meta-persistent flags are
## preserved by construction (Core Rule 7: absence of a clear call IS the
## mechanism, per ADR-0012 §5), unlike ClassPathSystem's own era-local
## counters, which reset_era_state() DOES clear.
func test_ac3_flag_survives_a_subsequent_era_transition() -> void:
	var era: int = PrestigeSystem.era_count
	var flag_name: StringName = StringName("burnout_deferred_era_" + str(era))
	_set_morale(100.0)

	PrestigeSystem.on_burnout_deferred(30.0)
	assert_bool(HistoryFlagManager.has_milestone(flag_name)).is_true()

	ClassPathSystem.reset_era_state()
	PrestigeSystem.on_burnout_accepted()

	assert_bool(HistoryFlagManager.has_milestone(flag_name)).override_failure_message(
		"burnout_deferred_era_N must be meta-persistent -- it must still be true after a subsequent era transition, not cleared like an era-local flag"
	).is_true()
