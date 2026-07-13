## Unit tests for ClassPathSystem's tie-break resolution fix (Story
## class-path-full/003, TR-cps-009, ADR-0010 §9, GDD F5). Closes
## production/qa/bugs/BUG-003-class-path-no-tiebreak-logic.md: the shipped
## `_update_active_path()` used a strict `>` comparison with no margin
## check, so two paths within PATH_AFFILIATION_TIE_BREAK_MARGIN of each
## other silently resolved to whichever iterated first in the Dictionary
## instead of GDD F5's "ambiguous" (&"") state.
##
## Covers this story's 8 acceptance criteria (AC-1..AC-8) plus
## get_ambiguous_gap() per ADR-0010 §9 Key Interfaces / Validation Criteria.
## AC-6 and the "both call sites" test explicitly drive _update_active_path()
## via invest() (Story class-path-full/002) as well as card resolution
## (_on_card_resolved(), Story class-path-full/001) — both call sites funnel
## through the same _recalculate_total_affiliation() -> _update_active_path()
## chain, so a single fix in _update_active_path() covers both, but this
## suite exercises both entry points directly rather than assuming that.
##
## ClassPathSystem is normally an Autoload singleton; for isolation each test
## instantiates a fresh instance directly from the script WITHOUT adding it to
## the scene tree — _ready() never fires, so the instance never connects to
## the real DecisionCardSystem (same isolation pattern as
## class_path_core_test.gd / class_path_investment_test.gd).
extends GdUnitTestSuite

const ClassPathSystemScript: GDScript = preload("res://src/core/class_path_system.gd")

const _PATO_COUNTER: StringName = &"pato_streamer_choices_count"
const _GURU_COUNTER: StringName = &"guru_celebryta_choices_count"

var _instances: Array[Node] = []
var _resource_snapshot: Dictionary = {}


func before_test() -> void:
	_instances = []
	_resource_snapshot = ResourceManager.serialize_state()
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	HistoryFlagManager.reset_counter(_GURU_COUNTER)


func after_test() -> void:
	ResourceManager.restore_state(_resource_snapshot)
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	HistoryFlagManager.reset_counter(_GURU_COUNTER)
	# apply_delta()/counter writes mark SaveSystem dirty — stop its debounce
	# timer so a delayed save_now() can't fire mid-suite (same precedent as
	# class_path_core_test.gd / class_path_investment_test.gd).
	SaveSystem._debounce_timer.stop()
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.free()


## Fresh, tree-detached ClassPathSystem — _ready() never runs, no Autoload
## signal connections. Freed in after_test().
func _make_cps() -> Node:
	var cps: Node = ClassPathSystemScript.new()
	_instances.append(cps)
	return cps


## Directly seeds [param path_id]'s card_contribution to an arbitrary value
## and re-derives the total affiliation (same helper pattern as
## class_path_investment_test.gd's _seed_card_contribution) — needed because
## this story's AC values (e.g. 45.0, 42.0, 38.0) aren't reachable as exact
## multiples of CARD_AFFILIATION_PER_CHOICE (4.0) through real card
## resolution alone.
func _seed_affiliation(cps: Node, path_id: StringName, value: float) -> void:
	cps._card_contribution[path_id] = value
	cps._recalculate_total_affiliation(path_id)


func _seed_resource(resource_id: StringName, value: float) -> void:
	ResourceManager.restore_state({String(resource_id): value})


# --- AC-1: BUG-003 exact repro case, now fixed ---

func test_ambiguous_when_gap_below_margin_bug003_repro() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)   # Tier 2
	_seed_affiliation(cps, &"guru_celebryta", 42.0)  # Tier 2, diff 3.0 < M(5.0)
	assert_that(cps.get_active_path()).override_failure_message(
		"BUG-003 regression: a near-tie must resolve to ambiguous, not pato_streamer"
	).is_equal(&"")


## Edge case per QA spec: the margin comparison is strict `<`, so a gap
## exactly equal to M(5.0) must resolve, not stay ambiguous.
func test_boundary_gap_exactly_at_margin_resolves_not_ambiguous() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 40.0)  # diff = 5.0 == M, not < M
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")


# --- AC-2: resolved, gap >= margin ---

func test_resolved_when_gap_above_margin() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 38.0)  # diff 7.0 >= M
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")


# --- AC-3: exact tie always ambiguous, regardless of M ---

func test_exact_tie_always_ambiguous() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 30.0)   # Tier 1
	_seed_affiliation(cps, &"guru_celebryta", 30.0)  # Tier 1, diff 0.0
	assert_that(cps.get_active_path()).is_equal(&"")


# --- AC-4: multiplier consistency during ambiguity (no stale _active_path leak) ---

func test_ambiguous_state_multiplier_returns_1_for_both_tied_paths() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)   # Tier 2 — would normally give 1.6
	_seed_affiliation(cps, &"guru_celebryta", 42.0)  # Tier 2 — would normally give 1.4, diff 3.0 < M
	assert_that(cps.get_active_path()).is_equal(&"")
	assert_float(cps.get_active_multiplier(&"zrob_drame")).override_failure_message(
		"ambiguous state must not leak pato_streamer's multiplier via a stale _active_path"
	).is_equal_approx(1.0, 0.001)
	assert_float(cps.get_active_multiplier(&"udziel_wywiadu")).override_failure_message(
		"ambiguous state must not leak guru_celebryta's multiplier via a stale _active_path"
	).is_equal_approx(1.0, 0.001)


# --- AC-5: 3+ paths — only the top two determine ambiguity ---

func test_three_plus_paths_third_lower_path_has_zero_effect() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 50.0)      # top, Tier 3
	_seed_affiliation(cps, &"guru_celebryta", 44.0)     # second, diff to top = 6.0 >= M -> resolved
	_seed_affiliation(cps, &"ekspert_niszowy", 43.0)    # third, Tier 2 — close to 2nd but must not be compared
	# If the third path were incorrectly compared against the top (or if the
	# "second-highest" bookkeeping picked the wrong candidate), this would
	# spuriously flip to ambiguous or to the wrong winner.
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(-1.0, 0.001)


func test_three_plus_paths_top_two_still_go_ambiguous_with_third_present() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 42.0)     # diff 3.0 < M -> ambiguous
	_seed_affiliation(cps, &"ekspert_niszowy", 25.0)    # third, far below — irrelevant
	assert_that(cps.get_active_path()).is_equal(&"")


# --- AC-6: signal fires exactly once when investment breaks the tie ---
# Explicitly drives _update_active_path() via invest() (not card resolution)
# to confirm the fix also applies at that call site.

func test_signal_fires_exactly_once_when_investment_breaks_tie_via_invest() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)   # gate satisfied for invest()
	_seed_affiliation(cps, &"guru_celebryta", 42.0)  # diff 3.0 < M -> starts ambiguous
	assert_that(cps.get_active_path()).is_equal(&"")

	var received: Array = []
	cps.active_path_changed.connect(func(path_id: StringName) -> void:
		received.append(path_id)
	)
	_seed_resource(&"Cringe", 500.0)
	# 100 Cringe * INVESTMENT_AFFILIATION_RATE[pato_streamer](0.1) = +10.0
	# investment -> pato_streamer 55.0 vs guru_celebryta 42.0, diff 13.0 >= M.
	var ok: bool = cps.invest(&"pato_streamer", &"Cringe", 100.0)
	assert_bool(ok).is_true()
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")
	assert_int(received.size()).override_failure_message(
		"active_path_changed must fire exactly once when invest() breaks the tie"
	).is_equal(1)
	assert_that(received[0]).is_equal(&"pato_streamer")


## Same call-site confirmation, but via card resolution (_on_card_resolved())
## rather than invest() — quantized to CARD_AFFILIATION_PER_CHOICE (4.0) so
## the tie is reachable through real card counts alone: pato 6 choices = 24.0,
## guru 5 choices = 20.0, diff 4.0 < M -> ambiguous.
func test_ambiguous_via_card_resolution_call_site() -> void:
	var cps: Node = _make_cps()
	for i in 6:
		HistoryFlagManager.increment_counter(_PATO_COUNTER)
		cps._on_card_resolved(&"", &"pato_streamer", &"")
	for i in 5:
		HistoryFlagManager.increment_counter(_GURU_COUNTER)
		cps._on_card_resolved(&"", &"guru_celebryta", &"")
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(24.0, 0.001)
	assert_float(cps.get_affiliation(&"guru_celebryta")).is_equal_approx(20.0, 0.001)
	assert_that(cps.get_active_path()).override_failure_message(
		"card-resolution call site must also resolve a near-tie to ambiguous"
	).is_equal(&"")


# --- AC-7: baseline unaffiliated ---

func test_baseline_no_path_ever_tier1_returns_empty_and_multiplier_1() -> void:
	var cps: Node = _make_cps()
	assert_that(cps.get_active_path()).is_equal(&"")
	assert_float(cps.get_active_multiplier(&"zrob_drame")).is_equal_approx(1.0, 0.001)
	assert_float(cps.get_active_multiplier(&"udziel_wywiadu")).is_equal_approx(1.0, 0.001)
	assert_float(cps.get_active_multiplier(&"some_unregistered_action")).is_equal_approx(1.0, 0.001)


# --- AC-8: secondary paths never stack (Core Rule 6) ---

func test_secondary_path_never_stacks_when_not_tied() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 90.0)      # resolved active, no ambiguity
	_seed_affiliation(cps, &"ekspert_niszowy", 25.0)    # Tier 1, not tied (diff 65.0 >= M)
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")
	assert_int(cps.get_tier(&"ekspert_niszowy")).is_equal(1)
	# ekspert_niszowy's Tier 2 bonus action must not apply while pato_streamer
	# is the active path — secondary paths never stack.
	assert_float(cps.get_active_multiplier(&"nagraj_vloga")).is_equal_approx(1.0, 0.001)


# --- get_ambiguous_gap() (ADR-0010 §9 Key Interfaces) ---

func test_get_ambiguous_gap_returns_positive_gap_when_ambiguous() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 42.0)  # diff 3.0
	assert_that(cps.get_active_path()).is_equal(&"")
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(3.0, 0.001)


func test_get_ambiguous_gap_returns_zero_on_exact_tie() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 30.0)
	_seed_affiliation(cps, &"guru_celebryta", 30.0)
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(0.0, 0.001)


func test_get_ambiguous_gap_returns_negative_one_when_resolved() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 38.0)  # diff 7.0 >= M
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(-1.0, 0.001)


func test_get_ambiguous_gap_returns_negative_one_when_never_computed() -> void:
	var cps: Node = _make_cps()
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(-1.0, 0.001)


func test_get_ambiguous_gap_returns_negative_one_with_single_eligible_path() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 24.0)  # Tier 1, sole eligible path
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(-1.0, 0.001)


## qa-tester suggestion (code review 2026-07-13): get_ambiguous_gap() with a
## third Tier-1+ path present must still reflect only the top-two gap, not be
## thrown off by the third path's presence.
func test_get_ambiguous_gap_correct_with_third_path_present() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 42.0)   # diff 3.0 < M -> ambiguous
	_seed_affiliation(cps, &"ekspert_niszowy", 25.0)  # third, far below — irrelevant
	assert_that(cps.get_active_path()).is_equal(&"")
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(3.0, 0.001)


## qa-tester suggestion (code review 2026-07-13): all 4 registered paths
## (Story class-path-full/001) simultaneously at Tier 1+, confirming the
## top-two logic scales past the 3-path cases tested above.
func test_all_four_paths_tier1plus_top_two_still_correctly_ambiguous() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 42.0)        # diff 3.0 < M -> ambiguous
	_seed_affiliation(cps, &"ekspert_niszowy", 25.0)
	_seed_affiliation(cps, &"biznesmen_contentu", 20.0)
	assert_that(cps.get_active_path()).is_equal(&"")
	assert_float(cps.get_ambiguous_gap()).is_equal_approx(3.0, 0.001)


# --- restore_state() must recompute _ambiguous_gap (BLOCKING finding, code review 2026-07-13) ---
# restore_state() trusts the persisted active_path directly (not re-derived),
# but get_ambiguous_gap()'s cache must still be correct immediately after
# load, before any card resolution or invest() call recomputes it.

func test_restore_state_recomputes_ambiguous_gap_when_loaded_mid_ambiguity() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 42.0)  # diff 3.0 < M -> ambiguous
	var saved: Dictionary = cps.serialize_state()

	var restored: Node = _make_cps()
	restored.restore_state(saved)
	assert_that(restored.get_active_path()).is_equal(&"")
	assert_float(restored.get_ambiguous_gap()).override_failure_message(
		"get_ambiguous_gap() must reflect the restored state immediately, not stay at the -1.0 field default until the next recalculation"
	).is_equal_approx(3.0, 0.001)


func test_restore_state_gives_negative_one_gap_when_loaded_resolved() -> void:
	var cps: Node = _make_cps()
	_seed_affiliation(cps, &"pato_streamer", 45.0)
	_seed_affiliation(cps, &"guru_celebryta", 38.0)  # diff 7.0 >= M -> resolved
	var saved: Dictionary = cps.serialize_state()

	var restored: Node = _make_cps()
	restored.restore_state(saved)
	assert_that(restored.get_active_path()).is_equal(&"pato_streamer")
	assert_float(restored.get_ambiguous_gap()).is_equal_approx(-1.0, 0.001)
