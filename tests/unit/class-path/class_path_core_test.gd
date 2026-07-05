## Unit tests for ClassPathSystem (Class Path Core, Story 001, TR-cps-001..005).
## Covers all 13 QA test cases from qa-plan-sprint-8-2026-07-01.md §8-2:
## affiliation formula + cap, tier unlocks at 20/40 with exactly-once signal
## emission, tier monotonicity, active path resolution, T1 multipliers for
## both MVP paths, era reset (state + HistoryFlagManager counters + meta
## flags), and restore_state round-trip with first-session defaults.
##
## ClassPathSystem is normally an Autoload singleton; for isolation each test
## instantiates a fresh instance directly from the script WITHOUT adding it to
## the scene tree — _ready() never fires, so the instance never connects to
## the real DecisionCardSystem. Tests drive _on_card_resolved() directly,
## simulating the ADR-0010 contract (path counter in HistoryFlagManager is
## incremented BEFORE the signal fires) by incrementing the real counter first.
##
## Real HistoryFlagManager path counters are reset in after_test() via
## reset_counter() (era-local counters, added this story). Meta milestone
## flags written by the era-reset tests are one-way (no unset API, by design)
## — no test in this suite asserts their absence, so cross-test leakage is
## harmless here.
extends GdUnitTestSuite

const ClassPathSystemScript: GDScript = preload("res://src/core/class_path_system.gd")

const _PATO_COUNTER: StringName = &"pato_streamer_choices_count"
const _GURU_COUNTER: StringName = &"guru_celebryta_choices_count"

var _instances: Array[Node] = []


func before_test() -> void:
	_instances = []
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	HistoryFlagManager.reset_counter(_GURU_COUNTER)


func after_test() -> void:
	HistoryFlagManager.reset_counter(_PATO_COUNTER)
	HistoryFlagManager.reset_counter(_GURU_COUNTER)
	# Counter/milestone writes mark the real SaveSystem dirty — stop its
	# debounce timer so a delayed save_now() can't fire mid-suite (same
	# precedent as weighted_selection_test.gd).
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


## Simulates [param count] resolved cards for [param path]: increments the
## real HistoryFlagManager counter first (matching DecisionCardSystem's
## resolve_choice() ordering per ADR-0010 §2), then fires the handler once
## per card, as the live signal would.
func _resolve_cards(cps: Node, path: StringName, count: int) -> void:
	for i: int in count:
		HistoryFlagManager.increment_counter(StringName(String(path) + "_choices_count"))
		cps._on_card_resolved(&"", path, &"")


# --- AC-2: affiliation formula ---

func test_affiliation_at_5_choices_is_20() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(20.0, 0.001)


func test_affiliation_at_1_choice_is_4() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 1)
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(4.0, 0.001)


func test_affiliation_at_0_choices_is_0() -> void:
	var cps: Node = _make_cps()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(0.0, 0.001)


# --- AC-1 edge case: neutral / unknown tags don't create state ---

func test_neutral_card_ignored() -> void:
	var cps: Node = _make_cps()
	cps._on_card_resolved(&"burnout_warning", &"", &"")
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(0.0, 0.001)
	assert_that(cps.get_active_path()).is_equal(&"")


# --- AC-3: card contribution cap ---

func test_affiliation_capped_at_60() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 50)  # 50 * 4.0 = 200 > cap
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(60.0, 0.001)


func test_affiliation_boundary_15_choices_exactly_60() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 15)  # 15 * 4.0 = exactly 60
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(60.0, 0.001)


func test_affiliation_boundary_14_choices_56() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 14)
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(56.0, 0.001)


# --- AC-4 / AC-5: tier unlocks at 20.0 and 40.0 ---

func test_tier1_unlocked_at_affiliation_20() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)  # 20.0 — inclusive threshold
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(1)


func test_tier0_below_threshold() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 4)  # 16.0 < 20.0
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(0)


func test_tier2_unlocked_at_affiliation_40() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 10)  # 40.0
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(2)


func test_tier1_at_39_99_equivalent() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 9)  # 36.0 — Tier 1, not 2
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(1)


func test_tier_unlocked_signal_emitted_once_per_crossing() -> void:
	var cps: Node = _make_cps()
	var emissions: Array = []
	cps.tier_unlocked.connect(func(path_id: StringName, tier: int) -> void:
		emissions.append([path_id, tier])
	)
	_resolve_cards(cps, &"pato_streamer", 5)  # crosses 20.0 on the 5th card
	assert_int(emissions.size()).is_equal(1)
	assert_that(emissions[0][0]).is_equal(&"pato_streamer")
	assert_int(emissions[0][1]).is_equal(1)
	# Further cards below the next threshold emit nothing more.
	_resolve_cards(cps, &"pato_streamer", 1)  # 24.0, still Tier 1
	assert_int(emissions.size()).is_equal(1)


# --- AC-6: tier monotonicity ---

func test_tier_never_decreases() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(1)
	# Repeated reads and further resolutions never lower the tier.
	cps._on_card_resolved(&"", &"pato_streamer", &"")  # no counter increment — affiliation recalc only
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(1)


# --- AC-7 / AC-8: active path resolution ---

func test_active_path_single_path_at_tier1() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)
	_resolve_cards(cps, &"guru_celebryta", 2)  # 8.0 — Tier 0
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")


func test_no_active_path_before_tier1() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 3)  # 12.0 — Tier 0
	assert_that(cps.get_active_path()).is_equal(&"")


func test_active_path_changed_signal() -> void:
	var cps: Node = _make_cps()
	var received: Array = []
	cps.active_path_changed.connect(func(path_id: StringName) -> void:
		received.append(path_id)
	)
	_resolve_cards(cps, &"pato_streamer", 5)
	assert_int(received.size()).is_equal(1)
	assert_that(received[0]).is_equal(&"pato_streamer")


# --- AC-9 / AC-10 / multiplier defaults ---

func test_multiplier_pato_t1_zrob_drame_1_3() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)  # Tier 1, active
	assert_float(cps.get_active_multiplier(&"zrob_drame")).is_equal_approx(1.3, 0.001)


func test_multiplier_guru_t1_udziel_wywiadu_1_2() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"guru_celebryta", 5)
	assert_float(cps.get_active_multiplier(&"udziel_wywiadu")).is_equal_approx(1.2, 0.001)


func test_multiplier_1_when_no_active_path() -> void:
	var cps: Node = _make_cps()
	assert_float(cps.get_active_multiplier(&"zrob_drame")).is_equal_approx(1.0, 0.001)


func test_multiplier_1_for_unaffected_action() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)  # pato active — guru bonus must NOT apply
	assert_float(cps.get_active_multiplier(&"udziel_wywiadu")).is_equal_approx(1.0, 0.001)


func test_multiplier_pato_t2_zrob_drame_1_6() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 10)  # 40.0 — Tier 2
	assert_float(cps.get_active_multiplier(&"zrob_drame")).is_equal_approx(1.6, 0.001)


func test_multiplier_guru_t2_udziel_wywiadu_1_4() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"guru_celebryta", 10)  # 40.0 — Tier 2
	assert_float(cps.get_active_multiplier(&"udziel_wywiadu")).is_equal_approx(1.4, 0.001)


# --- AC-12 / AC-13: era reset ---

func test_era_reset_clears_affiliation_tier_and_counter() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 11)  # 44.0 — Tier 2
	cps.reset_era_state()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(0.0, 0.001)
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(0)
	assert_int(HistoryFlagManager.get_counter(_PATO_COUNTER)).is_equal(0)
	assert_that(cps.get_active_path()).is_equal(&"")


func test_era_reset_clears_all_paths_not_just_active() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 11)  # 44.0 — Tier 2, active
	_resolve_cards(cps, &"guru_celebryta", 3)  # 12.0 — Tier 0, inactive
	cps.reset_era_state()
	assert_float(cps.get_affiliation(&"guru_celebryta")).is_equal_approx(0.0, 0.001)
	assert_int(HistoryFlagManager.get_counter(_GURU_COUNTER)).is_equal(0)
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(0.0, 0.001)
	assert_int(HistoryFlagManager.get_counter(_PATO_COUNTER)).is_equal(0)


func test_era_reset_emits_active_path_changed_empty() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)  # Tier 1 — active
	var received: Array = []
	cps.active_path_changed.connect(func(path_id: StringName) -> void:
		received.append(path_id)
	)
	cps.reset_era_state()
	assert_int(received.size()).is_equal(1)
	assert_that(received[0]).is_equal(&"")


func test_era_reset_no_signal_when_no_active_path() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 2)  # 8.0 — Tier 0, never active
	var received: Array = []
	cps.active_path_changed.connect(func(path_id: StringName) -> void:
		received.append(path_id)
	)
	cps.reset_era_state()
	assert_int(received.size()).is_equal(0)


func test_era_reset_preserves_meta_flags() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 11)  # Tier 2
	cps.reset_era_state()
	assert_bool(HistoryFlagManager.has_milestone(&"class_path.pato_streamer.best_tier.1")).is_true()
	assert_bool(HistoryFlagManager.has_milestone(&"class_path.pato_streamer.best_tier.2")).is_true()
	assert_bool(HistoryFlagManager.has_milestone(&"class_path.pato_streamer.era_completed")).is_true()


# --- Save / Load ---

func test_restore_state_round_trip() -> void:
	var cps: Node = _make_cps()
	cps.restore_state({
		"affiliation": {"pato_streamer": 24.0},
		"current_tier": {"pato_streamer": 1},
		"active_path": "pato_streamer",
	})
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(24.0, 0.001)
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(1)
	assert_that(cps.get_active_path()).is_equal(&"pato_streamer")


func test_restore_state_missing_keys_default_safely() -> void:
	var cps: Node = _make_cps()
	cps.restore_state({})  # first-session case
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(0.0, 0.001)
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(0)
	assert_that(cps.get_active_path()).is_equal(&"")


func test_serialize_restore_symmetry() -> void:
	var cps: Node = _make_cps()
	_resolve_cards(cps, &"pato_streamer", 5)
	var snapshot: Dictionary = cps.serialize_state()
	var cps2: Node = _make_cps()
	cps2.restore_state(snapshot)
	assert_float(cps2.get_affiliation(&"pato_streamer")).is_equal_approx(20.0, 0.001)
	assert_int(cps2.get_tier(&"pato_streamer")).is_equal(1)
	assert_that(cps2.get_active_path()).is_equal(&"pato_streamer")
