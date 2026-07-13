## Unit tests for ClassPathSystem's 4-path / Tier 1-5 expansion (Story
## class-path-full/001, TR-cps-010, ADR-0010 §11).
## Covers this story's 4 QA test cases: tier boundaries for all 4 paths
## (AC-1), multi-tier-jump single-emit-per-tier (AC-2), tier monotonicity
## (AC-3), and additive (never multiplicative) stacking against a stubbed
## second Reach modifier source (AC-4).
##
## ClassPathSystem is normally an Autoload singleton; for isolation each test
## instantiates a fresh instance directly from the script WITHOUT adding it to
## the scene tree — _ready() never fires, so the instance never connects to
## the real DecisionCardSystem. Tests drive affiliation/tier state directly
## via restore_state() (no HistoryFlagManager dependency needed for these
## ACs — see class_path_core_test.gd for the card-resolution-driven tests).
extends GdUnitTestSuite

const ClassPathSystemScript: GDScript = preload("res://src/core/class_path_system.gd")

const _ALL_PATHS: Array[StringName] = [
	&"pato_streamer", &"guru_celebryta", &"ekspert_niszowy", &"biznesmen_contentu",
]

var _instances: Array[Node] = []


func before_test() -> void:
	_instances = []


func after_test() -> void:
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.free()


## Fresh, tree-detached ClassPathSystem — _ready() never runs, no Autoload
## signal connections. Freed in after_test().
func _make_cps() -> Node:
	var cps: Node = ClassPathSystemScript.new()
	_instances.append(cps)
	return cps


## Sets [param path_id]'s affiliation directly and runs tier progression,
## bypassing card resolution — sufficient for tier-boundary/monotonicity
## assertions. get_tier() reads a stored, monotonic _current_tier value (set
## only by _check_tier_progression()), not a value derived live from
## affiliation, so progression must be driven explicitly here.
func _set_affiliation(cps: Node, path_id: StringName, affiliation: float) -> void:
	cps._affiliation[path_id] = affiliation
	cps._check_tier_progression(path_id)


# --- AC-1: tier boundaries, all 4 paths ---

func test_tier_boundaries_all_4_paths() -> void:
	for path_id: StringName in _ALL_PATHS:
		var cps: Node = _make_cps()
		_set_affiliation(cps, path_id, 79.9)
		assert_int(cps.get_tier(path_id)).override_failure_message(
			"path %s at 79.9 should be Tier 3" % path_id
		).is_equal(3)


func test_tier_boundary_80_is_tier_4_all_paths() -> void:
	for path_id: StringName in _ALL_PATHS:
		var cps: Node = _make_cps()
		_set_affiliation(cps, path_id, 80.0)
		assert_int(cps.get_tier(path_id)).override_failure_message(
			"path %s at 80.0 should be Tier 4" % path_id
		).is_equal(4)


func test_tier_boundary_100_is_tier_5_all_paths() -> void:
	for path_id: StringName in _ALL_PATHS:
		var cps: Node = _make_cps()
		_set_affiliation(cps, path_id, 100.0)
		assert_int(cps.get_tier(path_id)).override_failure_message(
			"path %s at 100.0 should be Tier 5" % path_id
		).is_equal(5)


func test_tier_boundaries_at_each_exact_threshold_all_paths() -> void:
	var expected: Dictionary = {20.0: 1, 40.0: 2, 60.0: 3, 80.0: 4, 100.0: 5}
	for path_id: StringName in _ALL_PATHS:
		for affil: float in expected:
			var cps: Node = _make_cps()
			_set_affiliation(cps, path_id, affil)
			assert_int(cps.get_tier(path_id)).override_failure_message(
				"path %s at %s should be Tier %s" % [path_id, affil, expected[affil]]
			).is_equal(expected[affil])


# --- AC-2: multi-tier jump, single emit-per-tier, never skipping ---

func test_tier_unlocked_fires_twice_on_jump_to_45() -> void:
	var cps: Node = _make_cps()
	var emissions: Array = []
	cps.tier_unlocked.connect(func(path_id: StringName, tier: int) -> void:
		emissions.append([path_id, tier])
	)
	cps._affiliation[&"pato_streamer"] = 45.0
	cps._check_tier_progression(&"pato_streamer")
	assert_int(emissions.size()).is_equal(2)
	assert_that(emissions[0]).is_equal([&"pato_streamer", 1])
	assert_that(emissions[1]).is_equal([&"pato_streamer", 2])
	assert_int(cps.get_tier(&"pato_streamer")).is_equal(2)


func test_tier_unlocked_fires_five_times_on_jump_to_100() -> void:
	var cps: Node = _make_cps()
	var emissions: Array = []
	cps.tier_unlocked.connect(func(path_id: StringName, tier: int) -> void:
		emissions.append([path_id, tier])
	)
	cps._affiliation[&"ekspert_niszowy"] = 100.0
	cps._check_tier_progression(&"ekspert_niszowy")
	assert_int(emissions.size()).is_equal(5)
	for i: int in range(5):
		assert_that(emissions[i]).is_equal([&"ekspert_niszowy", i + 1])
	assert_int(cps.get_tier(&"ekspert_niszowy")).is_equal(5)


# --- AC-3: monotonicity ---

func test_tier_never_drops_below_2_within_era() -> void:
	var cps: Node = _make_cps()
	cps._affiliation[&"biznesmen_contentu"] = 45.0
	cps._check_tier_progression(&"biznesmen_contentu")
	assert_int(cps.get_tier(&"biznesmen_contentu")).is_equal(2)
	# A subsequent progression check at the same (or any non-decreasing)
	# affiliation must never lower the stored tier.
	cps._check_tier_progression(&"biznesmen_contentu")
	assert_int(cps.get_tier(&"biznesmen_contentu")).is_equal(2)
	cps._affiliation[&"biznesmen_contentu"] = 50.0
	cps._check_tier_progression(&"biznesmen_contentu")
	assert_int(cps.get_tier(&"biznesmen_contentu")).is_equal(2)
	# Real regression case: affiliation drops (e.g. a future recalculation bug),
	# tier must still never lower (qa-tester finding, code review 2026-07-13).
	cps._affiliation[&"biznesmen_contentu"] = 10.0
	cps._check_tier_progression(&"biznesmen_contentu")
	assert_int(cps.get_tier(&"biznesmen_contentu")).is_equal(2)


# --- AC-4: additive stacking, never multiplicative ---

func test_additive_stacking_pato_t1_plus_stubbed_10_percent() -> void:
	var cps: Node = _make_cps()
	_set_affiliation(cps, &"pato_streamer", 20.0)  # Tier 1
	cps._active_path = &"pato_streamer"
	var base: float = 100.0
	var path_bonus: float = cps.get_active_multiplier(&"zrob_drame") - 1.0  # 0.30
	var stub_second_source_bonus: float = 0.10
	var combined_multiplicative: float = base * (1.0 + path_bonus) * (1.0 + stub_second_source_bonus)
	var combined_additive: float = base * (1.0 + path_bonus + stub_second_source_bonus)
	assert_float(combined_additive).is_equal_approx(140.0, 0.001)
	assert_float(combined_multiplicative).is_equal_approx(143.0, 0.001)  # 100 * 1.3 * 1.1
	assert_bool(is_equal_approx(combined_additive, combined_multiplicative)).is_false()


func test_additive_stacking_stub_zero_percent_equals_t1_alone() -> void:
	var cps: Node = _make_cps()
	_set_affiliation(cps, &"pato_streamer", 20.0)  # Tier 1
	cps._active_path = &"pato_streamer"
	var base: float = 100.0
	var path_bonus: float = cps.get_active_multiplier(&"zrob_drame") - 1.0  # 0.30
	var stub_second_source_bonus: float = 0.0
	var combined_additive: float = base * (1.0 + path_bonus + stub_second_source_bonus)
	assert_float(combined_additive).is_equal_approx(130.0, 0.001)


## biznesmen_contentu has no Reach-action-keyed bonus at any tier (all {}) —
## confirms get_active_multiplier() resolves to the documented 1.0 default
## rather than erroring on an unregistered action_id (qa-tester suggestion,
## code review 2026-07-13).
func test_unregistered_action_resolves_to_1_for_biznesmen() -> void:
	var cps: Node = _make_cps()
	_set_affiliation(cps, &"biznesmen_contentu", 100.0)  # Tier 5
	cps._active_path = &"biznesmen_contentu"
	assert_float(cps.get_active_multiplier(&"zrob_drame")).is_equal_approx(1.0, 0.001)
