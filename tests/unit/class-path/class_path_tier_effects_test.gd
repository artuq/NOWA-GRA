## Unit tests for the tier-bonus fill (2026-07-28, tier-bonus table draft):
## cumulative multiplier lookup (the hollow-T3-drops-T2 latent bug), the new
## _TIER_EFFECT_TABLE getters (secondary yields, duration cuts, scalar
## effects, morale floor), and the panel-feed get_tier_effect_data().
##
## Same isolation technique as class_path_multiplier_table_test.gd: fresh,
## tree-detached ClassPathSystem instances (never _ready(), no Autoload signal
## connections), state driven directly via private fields.
extends GdUnitTestSuite

const ClassPathSystemScript: GDScript = preload("res://src/core/class_path_system.gd")

var _instances: Array[Node] = []


func after_test() -> void:
	for instance: Node in _instances:
		if is_instance_valid(instance):
			instance.free()
	_instances = []


func _make_cps_at(path_id: StringName, tier: int) -> Node:
	var cps: Node = ClassPathSystemScript.new()
	_instances.append(cps)
	cps._active_path = path_id
	if path_id != &"":
		cps._current_tier[path_id] = tier
	return cps


## AC: cumulative lookup — a hollow higher tier RETAINS the highest defined
## lower-tier bonus. Before this revision, pato at T3 returned 1.0 for drama
## (its shipped T2 ×1.6 silently dropped).
func test_cumulative_lookup_retains_lower_tier_bonus() -> void:
	var cps: Node = _make_cps_at(&"pato_streamer", 3)
	assert_float(cps.get_active_multiplier(&"zrob_drame")).is_equal_approx(1.6, 0.0001)
	var cps4: Node = _make_cps_at(&"guru_celebryta", 4)
	assert_float(cps4.get_active_multiplier(&"udziel_wywiadu")).is_equal_approx(1.4, 0.0001)


## AC: biznesmen T1/T2 Collab mults (first [mult] fill cells).
func test_biznesmen_collab_multipliers() -> void:
	assert_float(_make_cps_at(&"biznesmen_contentu", 1).get_active_multiplier(&"nagraj_kolaba")).is_equal_approx(1.2, 0.0001)
	assert_float(_make_cps_at(&"biznesmen_contentu", 2).get_active_multiplier(&"nagraj_kolaba")).is_equal_approx(1.4, 0.0001)


## AC: pato T5 reach_all_mult stacks multiplicatively on the action-keyed
## entry: drama = 1.6 (T2, cumulative) × 2.0 (T5 all) = 3.2; a no-entry
## action gets the bare ×2.0.
func test_pato_t5_all_action_reach() -> void:
	var cps: Node = _make_cps_at(&"pato_streamer", 5)
	assert_float(cps.get_active_multiplier(&"zrob_drame")).is_equal_approx(3.2, 0.0001)
	assert_float(cps.get_active_multiplier(&"nagraj_vloga")).is_equal_approx(2.0, 0.0001)


## AC: T3 interlock secondary yields — path's signature action only, active
## path only, {} everywhere else.
func test_secondary_yields() -> void:
	var cps: Node = _make_cps_at(&"pato_streamer", 3)
	assert_that(cps.get_secondary_yield(&"zrob_drame")).is_equal({&"Sponsors": 3.0})
	assert_that(cps.get_secondary_yield(&"nagraj_vloga")).is_equal({})
	# Below T3: no yield yet.
	assert_that(_make_cps_at(&"pato_streamer", 2).get_secondary_yield(&"zrob_drame")).is_equal({})
	# Cumulative: still present at T5.
	assert_that(_make_cps_at(&"ekspert_niszowy", 5).get_secondary_yield(&"nagraj_vloga")).is_equal({&"Morale": 5.0})
	# No active path: nothing.
	assert_that(_make_cps_at(&"", 0).get_secondary_yield(&"zrob_drame")).is_equal({})


## AC: T4 duration cuts — specific action for pato/guru/ekspert (2/3), the
## `*` wildcard for biznesmen (0.75 on every action), 1.0 below T4.
func test_duration_multipliers() -> void:
	assert_float(_make_cps_at(&"pato_streamer", 4).get_action_duration_multiplier(&"zrob_drame")).is_equal_approx(2.0 / 3.0, 0.0001)
	assert_float(_make_cps_at(&"pato_streamer", 4).get_action_duration_multiplier(&"nagraj_vloga")).is_equal_approx(1.0, 0.0001)
	assert_float(_make_cps_at(&"pato_streamer", 3).get_action_duration_multiplier(&"zrob_drame")).is_equal_approx(1.0, 0.0001)
	var biz: Node = _make_cps_at(&"biznesmen_contentu", 4)
	assert_float(biz.get_action_duration_multiplier(&"nagraj_kolaba")).is_equal_approx(0.75, 0.0001)
	assert_float(biz.get_action_duration_multiplier(&"przeprosiny")).is_equal_approx(0.75, 0.0001)


## AC: scalar effects resolve cumulatively per path/tier; neutral defaults
## with no active path or below the defining tier.
func test_scalar_effects() -> void:
	assert_float(_make_cps_at(&"pato_streamer", 5).get_cringe_gain_multiplier()).is_equal_approx(1.5, 0.0001)
	assert_float(_make_cps_at(&"pato_streamer", 4).get_cringe_gain_multiplier()).is_equal_approx(1.0, 0.0001)
	assert_float(_make_cps_at(&"guru_celebryta", 5).get_sponsor_income_multiplier()).is_equal_approx(2.0, 0.0001)
	assert_float(_make_cps_at(&"biznesmen_contentu", 3).get_sponsor_income_multiplier()).is_equal_approx(1.5, 0.0001)
	assert_float(_make_cps_at(&"biznesmen_contentu", 5).get_morale_cost_multiplier()).is_equal_approx(0.0, 0.0001)
	assert_float(_make_cps_at(&"ekspert_niszowy", 1).get_morale_drain_multiplier()).is_equal_approx(0.8, 0.0001)
	assert_float(_make_cps_at(&"ekspert_niszowy", 5).get_haters_growth_multiplier()).is_equal_approx(0.5, 0.0001)
	assert_float(_make_cps_at(&"ekspert_niszowy", 5).get_morale_floor()).is_equal_approx(40.0, 0.0001)
	# Neutral defaults.
	var idle: Node = _make_cps_at(&"", 0)
	assert_float(idle.get_cringe_gain_multiplier()).is_equal_approx(1.0, 0.0001)
	assert_float(idle.get_sponsor_income_multiplier()).is_equal_approx(1.0, 0.0001)
	assert_float(idle.get_morale_cost_multiplier()).is_equal_approx(1.0, 0.0001)
	assert_float(idle.get_morale_drain_multiplier()).is_equal_approx(1.0, 0.0001)
	assert_float(idle.get_haters_growth_multiplier()).is_equal_approx(1.0, 0.0001)
	assert_float(idle.get_morale_floor()).is_equal_approx(0.0, 0.0001)


## AC: every path now has a non-empty effect at EVERY tier 1-5 (the hollow
## ladder is filled) — the union of _MULTIPLIER_TABLE and _TIER_EFFECT_TABLE
## entries at each tier must be non-empty, with the single documented
## exception of tiers whose bonus is purely the cumulative carry-over of a
## lower tier (allowed: the tier itself defines nothing NEW but the ladder
## still escalates at T3/T4/T5). Guards against regressing back to {}.
func test_no_hollow_signature_tiers() -> void:
	for path_id: StringName in [&"pato_streamer", &"guru_celebryta", &"ekspert_niszowy", &"biznesmen_contentu"]:
		var cps: Node = _make_cps_at(path_id, 5)
		for tier: int in [3, 4, 5]:
			var data: Dictionary = cps.get_tier_effect_data(path_id, tier)
			var has_any: bool = not data["reach_mults"].is_empty() or not data["effects"].is_empty()
			assert_bool(has_any).override_failure_message(
				"%s tier %d is hollow again" % [path_id, tier]
			).is_true()


## AC: get_tier_effect_data returns raw per-tier (non-cumulative) rows for
## the panel: pato T2 shows the drama mult, pato T5 shows the signature
## effects but NOT T3's yield.
func test_tier_effect_data_is_per_tier() -> void:
	var cps: Node = _make_cps_at(&"pato_streamer", 5)
	var t2: Dictionary = cps.get_tier_effect_data(&"pato_streamer", 2)
	assert_that(t2["reach_mults"]).is_equal({&"zrob_drame": 1.6})
	assert_bool(t2["effects"].is_empty()).is_true()
	var t5: Dictionary = cps.get_tier_effect_data(&"pato_streamer", 5)
	assert_bool(t5["effects"].has(&"reach_all_mult")).is_true()
	assert_bool(t5["effects"].has(&"secondary_yield")).is_false()
