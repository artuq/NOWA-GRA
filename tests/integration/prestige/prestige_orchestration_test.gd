## Integration tests for PrestigeSystem's orchestration skeleton (Story 001,
## TR-pcs-001, ADR-0012 §1-2).
##
## AC-5 (static `await`/`CONNECT_DEFERRED`/`call_deferred` check) is NOT a
## runtime test in this suite — per story-001-orchestration-core.md and
## ADR-0012's own Validation Criteria, this is a code-review/grep check, a
## GDScript unit test cannot assert against another script's source text at
## runtime. Flagged explicitly here rather than silently skipped. Evidence
## for this story's implementation (2026-07-14):
##
##   grep -n "await\|CONNECT_DEFERRED\|call_deferred" src/core/prestige_system.gd
##   grep -n "await\|CONNECT_DEFERRED\|call_deferred" src/core/save_system.gd
##   (+ ClassPathSystem.get_active_path()/get_tier()/reset_era_state()
##    bodies, HistoryFlagManager's sweep-relevant methods — not called by
##    this story's stub sequence, checked anyway for completeness)
##
## Result: zero code matches in any of the above. The only matches at all
## were doc-comment prose documenting this very constraint (the words
## "await"/"CONNECT_DEFERRED"/"call_deferred" appearing in a `##` comment
## explaining the rule), never actual `await`/`CONNECT_DEFERRED`/
## `call_deferred` usage. Re-run this grep by hand whenever any file in the
## call graph changes — a future edit reintroducing `await` anywhere in this
## chain breaks the read-before-reset ordering guarantee with no compile
## error (ADR-0012's own stated Risk).
##
## `ChallengeSystem.get_combined_meta_multiplier()` is not part of this
## grep — that Autoload does not exist yet (TR-pcs-007, no ADR yet) and
## Story 001's `on_burnout_accepted()` omits the call entirely rather than
## stubbing it against a non-existent Autoload (see prestige_system.gd's own
## doc comment).
##
## Runtime tests below target the REAL PrestigeSystem / ClassPathSystem /
## SaveSystem / HistoryFlagManager Autoload singletons, not mocks — the
## story's AC-3 explicitly requires "real (non-mocked) collaborators... must
## be on the Vertical Slice QA checklist". None of these Autoloads support
## dependency injection by design (ADR-0001), so — matching this codebase's
## established precedent (tests/integration/save_persistence_system/
## save_core_test.gd, tests/unit/class-path/class_path_core_test.gd) — each
## test backs up and restores real state around itself rather than
## injecting fakes. SaveSystem's own `_init()` test-isolation guard (see
## save_system.gd) already redirects file I/O to `user://save.test.json`
## under the GdUnit CLI runner, so `SaveSystem.save_now()` inside
## `on_burnout_accepted()` never touches a real player save here.
extends GdUnitTestSuite

const _PATO_COUNTER: StringName = &"pato_streamer_choices_count"

var _era_count_snapshot: int


func before_test() -> void:
	_era_count_snapshot = PrestigeSystem.era_count
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	SaveSystem._debounce_timer.stop()
	SaveSystem._autosave_suppressed = false


func after_test() -> void:
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	ClassPathSystem.reset_era_state()
	PrestigeSystem.restore_state({"era_count": _era_count_snapshot})
	SaveSystem._autosave_suppressed = false
	SaveSystem._debounce_timer.stop()


## Drives the REAL ClassPathSystem to Tier 3 for pato_streamer: 15 resolved
## cards * 4.0 affiliation each = 60.0, the Tier-3 threshold (also the
## card-contribution cap, class_path_system.gd's CARD_CONTRIBUTION_MAX) —
## same math as tests/unit/class-path/class_path_core_test.gd's own Tier
## boundary tests. Increments the real HistoryFlagManager counter first,
## matching ClassPathSystem's documented DecisionCardSystem.card_resolved
## ordering contract (ADR-0010 §2).
func _drive_pato_to_tier_3() -> void:
	for i: int in 15:
		HistoryFlagManager.increment_counter(_PATO_COUNTER)
		ClassPathSystem._on_card_resolved(&"", &"pato_streamer", &"")


# --- AC-1 / AC-3: read-before-reset, real collaborators end-to-end ---

func test_tier_captured_before_reset_real_collaborators() -> void:
	_drive_pato_to_tier_3()
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(3)
	assert_that(ClassPathSystem.get_active_path()).is_equal(&"pato_streamer")

	PrestigeSystem.on_burnout_accepted()

	# The value captured for downstream use (per prestige_system.gd's doc
	# comment: the exact value a future grant computation, Story 003/004,
	# will consume) is 3 — proven via the Story-001 test-observability hook,
	# NOT by re-querying ClassPathSystem after the fact, which would now
	# report the post-reset value (asserted separately below). This is the
	# AC-1 requirement verbatim: "the tier value used downstream is 3, not
	# 0" and "must fail if implementation reads tier after calling reset".
	assert_int(PrestigeSystem._last_captured_tier).is_equal(3)

	# reset_era_state() really did run — confirms the read happened BEFORE
	# the reset, not that the reset simply never fired at all.
	assert_int(ClassPathSystem.get_tier(&"pato_streamer")).is_equal(0)
	assert_that(ClassPathSystem.get_active_path()).is_equal(&"")


## ADR-0012 Validation Criteria's second integration test: no active path
## (ambiguous or Tier 0) still completes the era reset and increments
## era_count, capturing tier 0 rather than erroring.
func test_edge_case_no_active_path_grants_nothing_but_still_resets() -> void:
	assert_that(ClassPathSystem.get_active_path()).is_equal(&"")
	var before: int = PrestigeSystem.era_count

	PrestigeSystem.on_burnout_accepted()

	assert_int(PrestigeSystem._last_captured_tier).is_equal(0)
	assert_int(PrestigeSystem.era_count).is_equal(before + 1)


# --- AC-2: era_transitioned fires only after the full sequence completes ---

## Story 001 has no META_BONUS_total to observe yet (grant computation is
## stubbed until Story 003/004), so AC-2's literal wording ("any listener
## observes already-updated META_BONUS_total values") is adapted to this
## story's actual observable ordering guarantees: by the time the signal
## fires, era_count already reflects the increment, ClassPathSystem's
## era-local state is already reset, and autosave suppression has already
## been lifted — every step ADR-0012 §2 places before the emit.
func test_era_transitioned_fires_after_full_sequence_completes() -> void:
	_drive_pato_to_tier_3()
	# GDScript lambdas capture outer locals BY VALUE — a direct assignment
	# inside the closure would not propagate to this function's scope.
	# Using an Array (a reference type, same pattern as
	# tests/unit/class-path/class_path_core_test.gd's signal-spy tests) to
	# carry the observed snapshot back out.
	var observed: Array = []
	var spy: Callable = func() -> void:
		observed.append({
			"era_count": PrestigeSystem.era_count,
			"tier": ClassPathSystem.get_tier(&"pato_streamer"),
			"suppressed": SaveSystem._autosave_suppressed,
		})
	PrestigeSystem.era_transitioned.connect(spy)

	var before: int = PrestigeSystem.era_count
	PrestigeSystem.on_burnout_accepted()

	PrestigeSystem.era_transitioned.disconnect(spy)
	assert_int(observed.size()).is_equal(1)
	assert_int(observed[0]["era_count"]).is_equal(before + 1)
	assert_int(observed[0]["tier"]).is_equal(0)  # already reset by emit time
	assert_bool(observed[0]["suppressed"]).is_false()  # already resumed by emit time


func test_era_transitioned_fires_exactly_once() -> void:
	# Array, not a plain int — see the capture-by-value note above.
	var emissions: Array = []
	var spy: Callable = func() -> void:
		emissions.append(true)
	PrestigeSystem.era_transitioned.connect(spy)

	PrestigeSystem.on_burnout_accepted()

	PrestigeSystem.era_transitioned.disconnect(spy)
	assert_int(emissions.size()).is_equal(1)


# --- Autosave suppression pairing (ADR-0012 §2 / ADR-0002 contract) ---

## Full mid-sequence suppression coverage (asserting the flag is TRUE while
## reset/grant/sweep are running) is Story 008's atomicity test, explicitly
## Out of Scope here. This test verifies the paired-call postcondition this
## story's implementation guarantees: not suppressed before, not suppressed
## after — the pairing contract from SaveSystem.suppress_autosave()'s own
## doc comment ("Callers MUST pair every call with resume_autosave() in the
## same synchronous call chain").
func test_autosave_not_suppressed_before_or_after_transition() -> void:
	assert_bool(SaveSystem._autosave_suppressed).is_false()
	PrestigeSystem.on_burnout_accepted()
	assert_bool(SaveSystem._autosave_suppressed).is_false()


# --- Save/restore round-trip (Story 001 scope: era_count only) ---

func test_restore_state_round_trip() -> void:
	PrestigeSystem.restore_state({"era_count": 7})
	assert_int(PrestigeSystem.era_count).is_equal(7)
	assert_int(PrestigeSystem.get_era_count()).is_equal(7)


func test_restore_state_missing_key_defaults_to_zero() -> void:
	PrestigeSystem.restore_state({})
	assert_int(PrestigeSystem.era_count).is_equal(0)


func test_serialize_restore_symmetry() -> void:
	PrestigeSystem.restore_state({"era_count": 4})
	var snapshot: Dictionary = PrestigeSystem.serialize_state()
	PrestigeSystem.restore_state({})
	assert_int(PrestigeSystem.era_count).is_equal(0)
	PrestigeSystem.restore_state(snapshot)
	assert_int(PrestigeSystem.era_count).is_equal(4)


func test_on_burnout_accepted_increments_era_count() -> void:
	var before: int = PrestigeSystem.era_count
	PrestigeSystem.on_burnout_accepted()
	assert_int(PrestigeSystem.era_count).is_equal(before + 1)


## Regression for a BLOCKING code-review finding (2026-07-14): the story's
## own restore_state()/serialize_state() were implemented but never actually
## wired into SaveSystem's save_now()/_ready() or BootController's
## boot_with() -- the exact same class of bug this project has already hit
## twice before (tech-debt-register.md's 2026-06-29 "mark_dirty had ZERO
## call sites" entry, and the Class Path HUD Story 002 "ClassPathSystem
## missing from SaveSystem/BootController wiring" entry). A unit-level
## restore_state()/serialize_state() round-trip test (below, already
## present) cannot catch this class of bug -- only a real SaveSystem.save_now()
## -> fresh Autoload state -> SaveSystem._ready() cycle can, matching
## save_core_test.gd's own established pattern for this exact regression class.
func test_era_count_survives_real_save_now_and_reload_cycle() -> void:
	# SaveSystem's _init() test-isolation guard (see save_system.gd) redirects
	# SAVE_PATH/TEMP_PATH to user://save.test.json/.tmp under the GdUnit CLI
	# runner, deleting any pre-existing test file first -- safe to instantiate
	# real SaveSystem instances here without a real-save-file backup/restore
	# dance (see this file's header comment).
	var SaveSystemScript: GDScript = load("res://src/core/save_system.gd")
	var writer: Node = SaveSystemScript.new()
	add_child(writer)

	PrestigeSystem.restore_state({"era_count": 12})
	writer.save_now()

	PrestigeSystem.restore_state({"era_count": 0})
	assert_int(PrestigeSystem.era_count).is_equal(0)

	var reader: Node = SaveSystemScript.new()
	add_child(reader)

	assert_int(PrestigeSystem.era_count).override_failure_message(
		"era_count must survive a real SaveSystem.save_now() -> fresh _ready() cycle, not just a direct restore_state() call"
	).is_equal(12)

	writer.queue_free()
	reader.queue_free()


# --- AC-4: Autoload registration order ---

func test_prestige_system_registered_below_its_four_dependencies() -> void:
	var text: String = FileAccess.get_file_as_string("res://project.godot")
	var prestige_idx: int = text.find("PrestigeSystem=")
	assert_int(prestige_idx).is_greater(-1)
	for dep: String in ["ClassPathSystem=", "DecisionCardSystem=", "SaveSystem=", "HistoryFlagManager="]:
		var dep_idx: int = text.find(dep)
		assert_int(dep_idx).is_greater(-1)
		assert_int(prestige_idx).is_greater(dep_idx)
