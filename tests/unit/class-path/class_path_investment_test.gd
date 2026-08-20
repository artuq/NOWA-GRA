## Unit tests for ClassPathSystem.invest() (Story class-path-full/002,
## TR-cps-008, ADR-0010 §8, GDD Core Rule 4a / Formula F2/F3).
## Covers this story's 6 QA test cases: gate rejection at card_contribution
## <= 0 (AC-1), successful invest with per-path rate (AC-2), 4-path rate
## independence (AC-3), F3 clamp at 100.0 (AC-4), insufficient-resource
## rejection (AC-5), and (AC-6) the pre-existing MVP suites' regression pass
## is run as part of this story's full-suite check (not re-asserted here —
## see class_path_core_test.gd / class_path_multiplier_table_test.gd, both
## still green against the _recalculate_affiliation() F1/F2 split).
##
## ClassPathSystem is normally an Autoload singleton; for isolation each test
## instantiates a fresh instance directly from the script WITHOUT adding it to
## the scene tree — _ready() never fires, so the instance never connects to
## the real DecisionCardSystem (same isolation pattern as
## class_path_core_test.gd / class_path_multiplier_table_test.gd).
## ResourceManager, in contrast, IS the real Autoload singleton — invest()
## calls it directly (ADR-0001 direct-call contract). Cringe and Morale are
## clamped to [0.0, 100.0] on every apply_delta() mutation (Story 001's
## ResourceManager rule) — seeding a balance above 100.0 to exercise the
## GDD's "200 Cringe" worked example therefore goes through restore_state()
## (which writes the raw value with no clamp, same as a save-file load)
## rather than apply_delta() (which would clamp the seed itself). Full
## ResourceManager state is snapshotted/restored around every test via
## serialize_state()/restore_state() so this suite never leaks resource
## balances into other suites sharing the same Autoload.
extends GdUnitTestSuite

const ClassPathSystemScript: GDScript = preload("res://src/core/class_path_system.gd")

var _instances: Array[Node] = []
var _resource_snapshot: Dictionary = {}


func before_test() -> void:
	_instances = []
	_resource_snapshot = ResourceManager.serialize_state()
	HistoryFlagManager.reset_counter(&"pato_streamer_choices_count")


func after_test() -> void:
	ResourceManager.restore_state(_resource_snapshot)
	HistoryFlagManager.reset_counter(&"pato_streamer_choices_count")
	# apply_delta() marks SaveSystem dirty — stop its debounce timer so a
	# delayed save_now() can't fire mid-suite (same precedent as
	# class_path_core_test.gd / weighted_selection_test.gd).
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


## Directly seeds [param path_id]'s card_contribution and re-derives the
## total affiliation, bypassing card resolution/HistoryFlagManager — this
## suite tests invest() in isolation, not the card-resolution path (already
## covered by class_path_core_test.gd).
func _seed_card_contribution(cps: Node, path_id: StringName, value: float) -> void:
	cps._card_contribution[path_id] = value
	cps._recalculate_total_affiliation(path_id)


## Seeds [param resource_id]'s raw balance via restore_state() — bypasses
## ResourceManager's [0.0, 100.0] clamp on Cringe/Morale (apply_delta()
## would clamp the seed itself), matching a save-file load rather than a
## live mutation.
func _seed_resource(resource_id: StringName, value: float) -> void:
	ResourceManager.restore_state({String(resource_id): value})


# --- AC-1: gate rejection at card_contribution <= 0.0 ---

func test_invest_rejected_when_card_contribution_is_exactly_zero() -> void:
	var cps: Node = _make_cps()
	_seed_resource(&"Cringe", 500.0)
	var ok: bool = cps.invest(&"pato_streamer", &"Cringe", 200.0)
	assert_bool(ok).is_false()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(0.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(500.0, 0.001)


func test_invest_rejected_when_card_contribution_unset_for_path() -> void:
	var cps: Node = _make_cps()
	_seed_resource(&"Sponsors", 500.0)
	var ok: bool = cps.invest(&"guru_celebryta", &"Sponsors", 200.0)
	assert_bool(ok).is_false()
	assert_float(cps.get_affiliation(&"guru_celebryta")).is_equal_approx(0.0, 0.001)


## Edge case per QA test spec: gate is a strict <= 0.0 check — a tiny
## positive epsilon must satisfy it (gate satisfied, invest proceeds).
func test_invest_allowed_at_tiny_positive_card_contribution() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 0.001)
	_seed_resource(&"Cringe", 500.0)
	var ok: bool = cps.invest(&"pato_streamer", &"Cringe", 200.0)
	assert_bool(ok).is_true()


# --- AC-2: gate satisfied, successful invest, per-path rate ---

func test_invest_200_cringe_pato_streamer_adds_20_investment_contribution() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 20.0)  # gate satisfied
	_seed_resource(&"Cringe", 500.0)
	var ok: bool = cps.invest(&"pato_streamer", &"Cringe", 200.0)
	assert_bool(ok).is_true()
	# 20.0 (card) + 20.0 (200 * 0.1 investment) = 40.0 total.
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(40.0, 0.001)


## Uses guru_celebryta/Sponsors (unbounded, unclamped) rather than
## pato_streamer/Cringe so the post-invest balance can be asserted with
## plain subtraction — Cringe/Morale's [0,100] clamp would otherwise mask
## whether apply_delta() actually ran (see suite header comment).
func test_invest_deducts_resource_via_apply_delta() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"guru_celebryta", 20.0)
	_seed_resource(&"Sponsors", 500.0)
	var before: float = ResourceManager.get_resource(&"Sponsors")
	cps.invest(&"guru_celebryta", &"Sponsors", 200.0)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(before - 200.0, 0.001)


## Edge case per QA test spec: amount = 0 is a no-op, not an error. Seeded
## within [0,100] so Cringe's clamp cannot mask the assertion.
func test_invest_zero_amount_is_noop_not_error() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 20.0)
	_seed_resource(&"Cringe", 50.0)
	var before: float = ResourceManager.get_resource(&"Cringe")
	var ok: bool = cps.invest(&"pato_streamer", &"Cringe", 0.0)
	assert_bool(ok).is_true()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(20.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(before, 0.001)


func test_invest_rejects_negative_nan_and_wrong_resource_without_side_effects() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 20.0)
	_seed_resource(&"Cringe", 100.0)
	_seed_resource(&"Reach", 100.0)
	assert_bool(cps.invest(&"pato_streamer", &"Cringe", -10.0)).is_false()
	assert_bool(cps.invest(&"pato_streamer", &"Cringe", NAN)).is_false()
	assert_bool(cps.invest(&"pato_streamer", &"Reach", 10.0)).is_false()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(20.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(100.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Reach")).is_equal_approx(100.0, 0.001)


# --- AC-3: 4-path rate independence ---

func test_four_paths_independent_rates_for_identical_100_unit_spend() -> void:
	var expected: Dictionary = {
		&"pato_streamer": {"resource": &"Cringe", "gain": 10.0},
		&"guru_celebryta": {"resource": &"Sponsors", "gain": 20.0},
		&"ekspert_niszowy": {"resource": &"Morale", "gain": 12.5},
		&"biznesmen_contentu": {"resource": &"Reach", "gain": 2.0},
	}
	for path_id: StringName in expected:
		var cps: Node = _make_cps()
		var resource_id: StringName = expected[path_id]["resource"]
		var gain: float = expected[path_id]["gain"]
		_seed_card_contribution(cps, path_id, 10.0)  # gate satisfied, well under 100
		_seed_resource(resource_id, 500.0)
		var ok: bool = cps.invest(path_id, resource_id, 100.0)
		assert_bool(ok).override_failure_message(
			"invest() should succeed for %s" % path_id
		).is_true()
		assert_float(cps.get_affiliation(path_id)).override_failure_message(
			"path %s: expected 10.0 + %s = %s" % [path_id, gain, 10.0 + gain]
		).is_equal_approx(10.0 + gain, 0.001)


func test_ekspert_niszowy_rate_0_125_independently() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"ekspert_niszowy", 5.0)
	_seed_resource(&"Morale", 500.0)
	cps.invest(&"ekspert_niszowy", &"Morale", 200.0)
	# 5.0 + (200 * 0.125 = 25.0) = 30.0
	assert_float(cps.get_affiliation(&"ekspert_niszowy")).is_equal_approx(30.0, 0.001)


# --- AC-4: decision-backed investment ceiling (F6) ---

## Cringe is reseeded via restore_state() before the second invest() call —
## the first invest()'s apply_delta() clamps the stored Cringe balance to
## 100.0 (Story 001's resource rule, orthogonal to this story), which would
## otherwise starve the second call of spendable balance. Re-seeding keeps
## the test isolated to F3's affiliation-clamp behavior, not ResourceManager's
## unrelated currency clamp.
func test_oversized_investment_is_rejected_without_deducting_resource() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 4.0)
	_seed_resource(&"Cringe", 500.0)
	var ok: bool = cps.invest(&"pato_streamer", &"Cringe", 250.0) # +25 exceeds cap 24
	assert_bool(ok).is_false()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(4.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(500.0, 0.001)


## Exact worked example from the story's AC list: card_contribution = 60.0,
## investment pushes +50.0 more raw investment_contribution -> F3 clamps the
## 110.0 raw sum to exactly 100.0, not 110.0.
func test_f6_one_card_caps_total_affiliation_at_28() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 4.0)
	_seed_resource(&"Cringe", 5000.0)
	assert_bool(cps.invest(&"pato_streamer", &"Cringe", 240.0)).is_true()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(28.0, 0.001)
	assert_float(cps.get_investment_headroom(&"pato_streamer")).is_equal_approx(0.0, 0.001)


func test_f6_five_cards_cap_total_affiliation_at_60() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"guru_celebryta", 20.0)
	_seed_resource(&"Sponsors", 200.0)
	assert_bool(cps.invest(&"guru_celebryta", &"Sponsors", 200.0)).is_true()
	assert_float(cps.get_affiliation(&"guru_celebryta")).is_equal_approx(60.0, 0.001)


func test_f6_ten_cards_can_reach_100() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"biznesmen_contentu", 40.0)
	_seed_resource(&"Reach", 3000.0)
	assert_bool(cps.invest(&"biznesmen_contentu", &"Reach", 3000.0)).is_true()
	assert_float(cps.get_affiliation(&"biznesmen_contentu")).is_equal_approx(100.0, 0.001)


# --- AC-5: insufficient resource rejection ---

func test_invest_rejected_when_cannot_afford() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 20.0)  # gate satisfied
	_seed_resource(&"Cringe", 0.0)
	var ok: bool = cps.invest(&"pato_streamer", &"Cringe", 200.0)
	assert_bool(ok).is_false()
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(20.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Cringe")).is_equal_approx(0.0, 0.001)


func test_invest_rejected_exactly_one_unit_short() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"guru_celebryta", 20.0)
	_seed_resource(&"Sponsors", 199.0)
	var ok: bool = cps.invest(&"guru_celebryta", &"Sponsors", 200.0)
	assert_bool(ok).is_false()
	assert_float(cps.get_affiliation(&"guru_celebryta")).is_equal_approx(20.0, 0.001)
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(199.0, 0.001)


func test_invest_allowed_when_exact_amount_affordable() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"guru_celebryta", 20.0)
	_seed_resource(&"Sponsors", 200.0)
	var ok: bool = cps.invest(&"guru_celebryta", &"Sponsors", 200.0)
	assert_bool(ok).is_true()
	assert_float(ResourceManager.get_resource(&"Sponsors")).is_equal_approx(0.0, 0.001)


# --- Tier progression / active path still fire from invest() (F3 chain) ---

func test_invest_triggers_tier_unlock_signal() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"pato_streamer", 4.0)  # below Tier 1 (20.0)
	var emissions: Array = []
	cps.tier_unlocked.connect(func(path_id: StringName, tier: int) -> void:
		emissions.append([path_id, tier])
	)
	_seed_resource(&"Cringe", 500.0)
	cps.invest(&"pato_streamer", &"Cringe", 160.0)  # 160 * 0.1 = 16.0 -> total 20.0, crosses Tier 1
	assert_int(emissions.size()).is_equal(1)
	assert_that(emissions[0]).is_equal([&"pato_streamer", 1])
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(1)


func test_invest_updates_active_path() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"biznesmen_contentu", 4.0)
	_seed_resource(&"Reach", 5000.0)
	cps.invest(&"biznesmen_contentu", &"Reach", 800.0)  # 800 * 0.02 = 16.0 -> total 20.0, Tier 1
	assert_that(cps.get_active_path()).is_equal(&"biznesmen_contentu")


# --- Save/load round-trip: investment_contribution must survive restore ---
# Regression for a BLOCKING code-review finding (2026-07-13): investment
# progress was silently discarded on the next card resolution after a
# save/load, because restore_state()/serialize_state() only round-tripped
# the derived _affiliation total, never the _investment_contribution term
# _recalculate_total_affiliation() re-derives from on every call.

func test_investment_contribution_survives_save_load_round_trip() -> void:
	var cps: Node = _make_cps()
	# Real HistoryFlagManager counter (5 choices * 4.0 = 20.0), matching how
	# _recalculate_card_contribution() actually derives card_contribution —
	# needed so the post-restore recalculation below exercises the real
	# formula, not a stale disconnected value.
	for i in 5:
		HistoryFlagManager.increment_counter(&"pato_streamer_choices_count")
	cps._recalculate_card_contribution(&"pato_streamer")
	_seed_resource(&"Cringe", 500.0)
	cps.invest(&"pato_streamer", &"Cringe", 200.0)  # +20.0 investment -> 40.0 total
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(40.0, 0.001)

	var saved: Dictionary = cps.serialize_state()
	var restored: Node = _make_cps()
	restored.restore_state(saved)
	assert_float(restored.get_affiliation(&"pato_streamer")).is_equal_approx(40.0, 0.001)

	# The real regression: a card resolution AFTER restore must not silently
	# wipe the restored investment_contribution by recomputing from a zeroed
	# value. Simulate the card-resolution path's recalculation directly —
	# the real HistoryFlagManager counter is unchanged (5), so this exercises
	# exactly what a genuine post-restore card resolve would do.
	restored._recalculate_card_contribution(&"pato_streamer")
	restored._recalculate_total_affiliation(&"pato_streamer")
	assert_float(restored.get_affiliation(&"pato_streamer")).override_failure_message(
		"investment_contribution must survive a post-restore recalculation, not silently reset to 0"
	).is_equal_approx(40.0, 0.001)


func test_restore_migrates_legacy_overinvestment_and_tier_to_f6_cap() -> void:
	var cps: Node = _make_cps()
	cps.restore_state({
		"affiliation": {"pato_streamer": 100.0},
		"card_contribution": {"pato_streamer": 4.0},
		"investment_contribution": {"pato_streamer": 96.0},
		"current_tier": {"pato_streamer": 5},
		"active_path": "pato_streamer",
	})
	assert_float(cps.get_affiliation(&"pato_streamer")).is_equal_approx(28.0, 0.001)
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(1)


func test_card_contribution_survives_save_load_for_invest_gate() -> void:
	var cps: Node = _make_cps()
	_seed_card_contribution(cps, &"guru_celebryta", 20.0)
	var saved: Dictionary = cps.serialize_state()
	var restored: Node = _make_cps()
	restored.restore_state(saved)
	_seed_resource(&"Sponsors", 500.0)
	# Without card_contribution restored, this would incorrectly fail Core
	# Rule 4a's gate immediately after a fresh restore.
	var ok: bool = restored.invest(&"guru_celebryta", &"Sponsors", 200.0)
	assert_bool(ok).is_true()
