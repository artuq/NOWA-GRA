## Integration tests for PrestigeSystem's era-transition atomicity guarantee
## (Story 008, "Transition Atomicity", TR-pcs-006, ADR-0012 §2, ADR-0002's
## Autosave suppression window). Narrowed 2026-07-15 (see
## production/epics/prestige-checkpoint/story-008-transition-atomicity.md's
## own "Scope Note") to the two atomicity guarantees actually implementable
## against the shipped `on_burnout_accepted()` sequence: kill-before-save vs.
## kill-after-save, and the suppression-window boundary. Does NOT cover
## card-re-presentation-on-boot or Challenge Selection kill-timing (both
## deferred, BurnoutSystem/ChallengeSystem do not exist yet, TR-pcs-007).
##
## Test-modeling technique (story's own Implementation Notes): a real app-kill
## cannot be simulated in a headless test run, and `on_burnout_accepted()` has
## no internal step-by-step resumability seam -- it always runs to completion
## once called (no yield point, per the zero-`await` call-contract lock,
## ADR-0012 §2). "Kill before `save_now()` completes" is therefore modeled as:
## capture `SaveSystem`'s persisted state (via a real `SaveSystem.load_save()`
## call) BEFORE invoking `on_burnout_accepted()`. This is valid because
## `save_now()` is the ONLY disk write anywhere in the method, and it is the
## last synchronous statement before `era_transitioned.emit()` -- so whatever
## was on disk immediately before the call is, by construction, identical to
## what a kill at ANY point during the call (real or hypothetical) would have
## left behind (ADR-0002's atomic temp-file-rename guarantee, already covered
## by that ADR's own validation criteria -- NOT re-tested here; these tests
## verify PrestigeSystem's state machine respects that guarantee, not the
## file-write mechanism itself).
##
## Fresh-instance restore technique: AC-1 and AC-3 restore the captured
## snapshot into FRESH, unparented `Script.new()` instances (never added to
## the scene tree, `.free()`'d after use) rather than the real singleton
## Autoloads -- same established convention as settings_system_test.gd /
## class_path_core_test.gd / prestige_orchestration_test.gd's own
## SaveSystemScript writer/reader pair. This is the safest way to inspect "what
## a fresh boot would read" without mutating the real Autoloads mid-test.
## JUDGMENT CALL: the story's Implementation Notes explicitly name only "a
## fresh PrestigeSystem instance" -- this suite extends the same technique to
## fresh ResourceManager/ClassPathSystem/HistoryFlagManager instances too,
## because AC-1's own wording ("previous era's resources/affiliation intact")
## and AC-3's own wording ("sweep defaults applied", "milestone present")
## cannot be verified through PrestigeSystem's restore_state() alone -- it
## only owns era_count/meta_bonus_totals (ADR-0012 §1). Each of those three
## modules' restore_state()/serialize_state() is self-contained (confirmed by
## reading their source: no _ready(), no cross-Autoload calls in the restore
## path), so instantiating them unparented is safe, matching this codebase's
## already-established pattern for exactly this class of test.
##
## AC-2 is the one case that MUST restore the REAL singleton Autoloads (not
## fresh instances): it re-invokes `on_burnout_accepted()`, which hardcodes
## references to the real `ClassPathSystem`/`SaveSystem`/`ResourceManager`/
## `HistoryFlagManager` singletons by Autoload name, not through `self` -- a
## fresh `PrestigeSystem` instance calling that method would still read/write
## the SAME real singletons underneath. JUDGMENT CALL / known modeling
## limitation: `HistoryFlagManager.restore_state()` is a documented one-way
## ratchet (only ever ADDS milestones, never removes one already true) -- it
## cannot un-set `prestige.first_burnout_used.META_REACH_MULT` if the first
## (real, in-test) call already set it, the way a genuine process kill +
## reboot would. AC-2's assertion sidesteps this by reading the REAL live
## `is_first` state as its oracle input immediately before the second call,
## rather than assuming it -- the same leakage-tolerant technique
## prestige_grant_wiring_test.gd's own tests already use elsewhere in this
## epic. This does not weaken the AC-2 proof: the invariant under test is
## "exactly one grant's worth is applied, not two", which holds regardless of
## which grant magnitude (first-burnout or not) that one grant happens to be.
##
## AC-4 reuses Story 007's AC-3 real-signal spy-array technique
## (prestige_flag_sweep_test.gd), extended here to a combined chronological
## event log across TWO real signals -- `ResourceManager.resource_changed`
## (fires only during step 5's sweep/override, i.e. INSIDE the suppression
## window per TR-pcs-006's own "steps 1-5" framing) and
## `PrestigeSystem.era_transitioned` -- proving both that suppression is
## genuinely active mid-sequence (not just "eventually false") and that
## `resume_autosave()` runs strictly before the emit.
##
## No genuine implementation bug was found in prestige_system.gd/
## save_system.gd while writing these tests -- the shipped
## on_burnout_accepted() sequence satisfies TR-pcs-006 exactly as written.
##
## Exercises the REAL PrestigeSystem/ResourceManager/ClassPathSystem/
## HistoryFlagManager/SaveSystem Autoload singletons, not mocks -- same
## established precedent as this suite's siblings (none of these Autoloads
## support dependency injection by design, ADR-0001). SaveSystem's own
## `_init()` test-isolation guard (see save_system.gd) redirects file I/O to
## `user://save.test.json`/`.tmp` under the GdUnit CLI runner, so the real
## `SaveSystem.save_now()`/`load_save()` calls below never touch a real player
## save.
extends GdUnitTestSuite

const PrestigeSystemScript: GDScript = preload("res://src/core/prestige_system.gd")
const ResourceManagerScript: GDScript = preload("res://src/core/resource_manager.gd")
const ClassPathSystemScript: GDScript = preload("res://src/core/class_path_system.gd")
const HistoryFlagManagerScript: GDScript = preload("res://src/core/history_flag_manager.gd")

const _PATO_COUNTER: StringName = &"pato_streamer_choices_count"
const _ALL_RESOURCE_KEYS: Array[StringName] = [&"Cringe", &"Morale", &"Haters", &"Reach", &"Sponsors"]

var _era_count_snapshot: int
var _meta_totals_snapshot: Dictionary
var _resource_snapshot: Dictionary


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	_resource_snapshot = {}
	for key: StringName in _ALL_RESOURCE_KEYS:
		_resource_snapshot[key] = ResourceManager.get_resource(key)
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func after_test() -> void:
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	PrestigeSystem.restore_state({
		"era_count": _era_count_snapshot,
		"meta_bonus_totals": _meta_totals_snapshot,
	})
	for key: StringName in _ALL_RESOURCE_KEYS:
		_set_resource(key, _resource_snapshot[key])
	SaveSystem._autosave_suppressed = false
	SaveSystem._debounce_timer.stop()


func _set_resource(key: StringName, value: float) -> void:
	ResourceManager.apply_delta({key: value - ResourceManager.get_resource(key)})


## Drives the REAL ClassPathSystem to Tier 3 for pato_streamer: 15 resolved
## cards * 4.0 affiliation each = 60.0, the Tier-3 threshold -- same technique
## as prestige_orchestration_test.gd's/prestige_flag_sweep_test.gd's own
## _drive_pato_to_tier_3().
func _drive_pato_to_tier_3() -> void:
	for i: int in 15:
		HistoryFlagManager.increment_counter(_PATO_COUNTER)
		ClassPathSystem._on_card_resolved(&"", &"pato_streamer", &"")


# --- AC-1: kill before save_now() completes -> restore reflects pre-transition state exactly ---

func test_ac1_kill_before_save_completes_restores_pre_transition_state() -> void:
	_drive_pato_to_tier_3()
	var era_before: int = PrestigeSystem.era_count
	# An arbitrary NONZERO pre-existing total -- proves "unchanged", not just
	# "still zero" (a weaker assertion a buggy implementation could pass by
	# accident).
	PrestigeSystem.restore_state({
		"era_count": era_before,
		"meta_bonus_totals": {"META_REACH_MULT": 3.5},
	})
	_set_resource(&"Cringe", 77.0)
	_set_resource(&"Morale", 40.0)
	_set_resource(&"Haters", 12.0)
	_set_resource(&"Reach", 88.0)
	_set_resource(&"Sponsors", 5.0)

	# Persist this as "the last completed save" -- writes to disk exactly what
	# a real boot's SaveSystem.load_save() would read at this moment.
	SaveSystem.save_now()
	var pre_call_snapshot: Dictionary = SaveSystem.load_save()

	# Act: run the REAL transition to completion. Capturing the snapshot
	# BEFORE this call (above) is what models "killed at any point before
	# save_now() completed" -- the pre-call snapshot is untouched by whatever
	# this call does, real or hypothetical (see this file's header comment).
	PrestigeSystem.on_burnout_accepted()

	var fresh_prestige: Node = PrestigeSystemScript.new()
	fresh_prestige.restore_state(pre_call_snapshot.get("prestige", {}))
	assert_int(fresh_prestige.era_count).override_failure_message(
		"era_count must NOT be incremented in a save captured before save_now() ran"
	).is_equal(era_before)
	assert_float(fresh_prestige.get_meta_bonus_total(&"META_REACH_MULT")).override_failure_message(
		"no META_BONUS from this transition may appear in a save captured before save_now() ran"
	).is_equal_approx(3.5, 0.0001)
	fresh_prestige.free()

	var fresh_resources: Node = ResourceManagerScript.new()
	fresh_resources.restore_state(pre_call_snapshot.get("resources", {}))
	assert_float(fresh_resources.get_resource(&"Cringe")).override_failure_message(
		"previous era's resources must be intact in a save captured before save_now() ran"
	).is_equal_approx(77.0, 0.0001)
	assert_float(fresh_resources.get_resource(&"Morale")).is_equal_approx(40.0, 0.0001)
	assert_float(fresh_resources.get_resource(&"Haters")).is_equal_approx(12.0, 0.0001)
	assert_float(fresh_resources.get_resource(&"Reach")).is_equal_approx(88.0, 0.0001)
	assert_float(fresh_resources.get_resource(&"Sponsors")).is_equal_approx(5.0, 0.0001)
	fresh_resources.free()

	var fresh_class_path: Node = ClassPathSystemScript.new()
	fresh_class_path.restore_state(pre_call_snapshot.get("class_path", {}))
	assert_int(fresh_class_path.get_tier(&"pato_streamer")).override_failure_message(
		"pato_streamer's affiliation/tier must be intact in a save captured before reset_era_state() ran"
	).is_equal(3)
	assert_str(String(fresh_class_path.get_active_path())).is_equal("pato_streamer")
	fresh_class_path.free()


# --- AC-2: re-confirm against the AC-1 restored state runs exactly once, no double-grant ---

func test_ac2_reconfirm_after_restore_grants_exactly_once() -> void:
	_drive_pato_to_tier_3()
	var era_before: int = PrestigeSystem.era_count
	PrestigeSystem.restore_state({"era_count": era_before, "meta_bonus_totals": {}})
	_set_resource(&"Cringe", 10.0)

	SaveSystem.save_now()
	var pre_call_snapshot: Dictionary = SaveSystem.load_save()

	# First (real) attempt -- conceptually "the one killed before save_now()
	# completes". It runs to full completion for real, but the next step
	# restores the REAL Autoloads back to the pre-call snapshot, discarding
	# everything this call did -- modeling exactly what a genuine reboot from
	# an interrupted save would read.
	PrestigeSystem.on_burnout_accepted()

	PrestigeSystem.restore_state(pre_call_snapshot.get("prestige", {}))
	ResourceManager.restore_state(pre_call_snapshot.get("resources", {}))
	ClassPathSystem.restore_state(pre_call_snapshot.get("class_path", {}))
	# HistoryFlagManager milestones are a one-way ratchet (see this file's
	# header comment) -- see below for how the expected-grant oracle stays
	# correct despite this.
	HistoryFlagManager.restore_state(pre_call_snapshot.get("history_flags", {}))

	assert_int(PrestigeSystem.era_count).is_equal(era_before)
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")).is_equal_approx(0.0, 0.0001)
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(3)

	var total_before: float = PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")
	var was_first: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_REACH_MULT")
	var expected_grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 3, 1.0, was_first)

	# Act: the re-confirm -- on_burnout_accepted() invoked again, against the
	# restored pre-transition state.
	PrestigeSystem.on_burnout_accepted()

	assert_int(PrestigeSystem.era_count).override_failure_message(
		"era_count must increment exactly once from the restored pre-transition value, not twice"
	).is_equal(era_before + 1)
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")).override_failure_message(
		"META_BONUS must be granted exactly once total across both attempts -- the killed attempt persisted nothing to disk, so nothing from it can double up here"
	).is_equal_approx(total_before + expected_grant, 0.0001)


# --- AC-3: kill after save_now() -> restore reflects the fully-transitioned era ---

func test_ac3_kill_after_save_completes_restores_fully_transitioned_state() -> void:
	_drive_pato_to_tier_3()
	var era_before: int = PrestigeSystem.era_count
	PrestigeSystem.restore_state({"era_count": era_before, "meta_bonus_totals": {}})
	var was_first: bool = not HistoryFlagManager.has_milestone(&"prestige.first_burnout_used.META_REACH_MULT")
	var expected_grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 3, 1.0, was_first)

	# Act: the REAL transition runs to completion, including its own
	# save_now() -- the disk now reflects the fully-transitioned era.
	PrestigeSystem.on_burnout_accepted()

	var post_call_snapshot: Dictionary = SaveSystem.load_save()

	var fresh_prestige: Node = PrestigeSystemScript.new()
	fresh_prestige.restore_state(post_call_snapshot.get("prestige", {}))
	assert_int(fresh_prestige.era_count).override_failure_message(
		"era_count must be incremented in a save captured after save_now() completed"
	).is_equal(era_before + 1)
	assert_float(fresh_prestige.get_meta_bonus_total(&"META_REACH_MULT")).override_failure_message(
		"this era's META_BONUS grant must be present in a save captured after save_now() completed"
	).is_equal_approx(expected_grant, 0.0001)
	fresh_prestige.free()

	var fresh_resources: Node = ResourceManagerScript.new()
	fresh_resources.restore_state(post_call_snapshot.get("resources", {}))
	assert_float(fresh_resources.get_resource(&"Cringe")).override_failure_message(
		"sweep defaults must be present in a save captured after save_now() completed"
	).is_equal(0.0)
	assert_float(fresh_resources.get_resource(&"Morale")).is_equal(100.0)
	assert_float(fresh_resources.get_resource(&"Haters")).is_equal(0.0)
	assert_float(fresh_resources.get_resource(&"Reach")).is_equal(0.0)
	fresh_resources.free()

	var fresh_flags: Node = HistoryFlagManagerScript.new()
	fresh_flags.restore_state(post_call_snapshot.get("history_flags", {}))
	assert_bool(fresh_flags.has_milestone(StringName("burnout_accepted_era_" + str(era_before + 1)))).override_failure_message(
		"burnout_accepted_era_N milestone must be present in a save captured after save_now() completed"
	).is_true()
	fresh_flags.free()


# --- AC-4: suppression window brackets only the synchronous steps, never extends past the emit ---

## Reuses Story 007's AC-3 real-signal spy-array technique
## (prestige_flag_sweep_test.gd), combining TWO real signals into one
## chronological event log: ResourceManager.resource_changed (fires only
## during step 5's sweep/override -- inside the suppression window per
## TR-pcs-006's "steps 1-5" framing) and PrestigeSystem.era_transitioned.
func test_ac4_suppression_window_is_narrow_not_unbounded() -> void:
	_drive_pato_to_tier_3()

	# Array of Dictionaries, not separate plain vars -- GDScript lambdas
	# capture outer locals BY VALUE, same pattern as
	# prestige_orchestration_test.gd's/prestige_flag_sweep_test.gd's own
	# signal-spy tests (an Array is a reference type, so appends inside the
	# closures propagate back out to this function's scope).
	var events: Array = []
	var resource_spy: Callable = func(_name: StringName, _new_value: float, _old_value: float) -> void:
		events.append({"event": "resource_changed", "suppressed": SaveSystem._autosave_suppressed})
	var emit_spy: Callable = func() -> void:
		events.append({"event": "era_transitioned", "suppressed": SaveSystem._autosave_suppressed})
	ResourceManager.resource_changed.connect(resource_spy)
	PrestigeSystem.era_transitioned.connect(emit_spy)

	assert_bool(SaveSystem._autosave_suppressed).is_false()

	PrestigeSystem.on_burnout_accepted()

	ResourceManager.resource_changed.disconnect(resource_spy)
	PrestigeSystem.era_transitioned.disconnect(emit_spy)

	assert_bool(SaveSystem._autosave_suppressed).override_failure_message(
		"suppression must be lifted after the full sequence completes -- not left unbounded"
	).is_false()

	# The sweep (5 resource keys) + F3d's override (1 more) = 6 resource_changed
	# emissions, all inside the suppression window, plus the final emit.
	assert_int(events.size()).override_failure_message(
		"expected the sweep's resource writes plus the final era_transitioned emit"
	).is_equal(7)

	var last_event: Dictionary = events[events.size() - 1]
	assert_str(String(last_event["event"])).override_failure_message(
		"era_transitioned must be the LAST event observed -- nothing (no resource write) may follow it"
	).is_equal("era_transitioned")
	assert_bool(last_event["suppressed"]).override_failure_message(
		"resume_autosave() must be called strictly BEFORE era_transitioned.emit() (TR-pcs-006)"
	).is_false()

	for i: int in events.size() - 1:
		assert_str(String(events[i]["event"])).is_equal("resource_changed")
		assert_bool(events[i]["suppressed"]).override_failure_message(
			"every resource write during the sweep (step 5, inside the suppression window per TR-pcs-006's 'steps 1-5') must observe suppression still active -- the window must not have been lifted early"
		).is_true()
