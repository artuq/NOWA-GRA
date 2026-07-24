## Unit tests for PrestigeSystem.compute_next_grant() (ADR-0017 Validation
## Criteria): a pure function given explicit path_id/tier -- mutates nothing,
## callable any number of times with no state change between calls. These
## tests exercise the Autoload directly (not a preload+mock) since
## compute_next_grant() reads meta_bonus_totals and calls
## ChallengeSystem.get_combined_meta_multiplier() -- both real Autoload state,
## same "integration-flavored unit test of an Autoload method" precedent as
## prestige_defer_test.gd's own source-scan suite. See
## tests/integration/prestige/prestige_last_grant_test.gd for the
## preview/real-grant consistency guarantee this ADR exists for.
extends GdUnitTestSuite

## Preloaded (not the bare class_name) so the suite parses even before the
## editor has rescanned the global class cache — headless CI/CLI safety, same
## precedent as prestige_formulas_grant_test.gd.
const PrestigeFormulas: GDScript = preload("res://src/core/prestige_formulas.gd")

var _meta_totals_snapshot: Dictionary
var _challenge_snapshot: Array[StringName]


func before_test() -> void:
	_meta_totals_snapshot = PrestigeSystem.meta_bonus_totals.duplicate()
	_challenge_snapshot = ChallengeSystem.get_active_challenge_ids()
	ChallengeSystem.clear_active_challenges()


func after_test() -> void:
	PrestigeSystem.meta_bonus_totals.clear()
	for key in _meta_totals_snapshot:
		PrestigeSystem.meta_bonus_totals[key] = _meta_totals_snapshot[key]
	ChallengeSystem.select_challenges(_challenge_snapshot)


# --- Purity: repeated calls with no state change return identical results ---

func test_repeated_calls_with_no_state_change_return_identical_results() -> void:
	var first: Dictionary = PrestigeSystem.compute_next_grant(&"pato_streamer", 3)
	var second: Dictionary = PrestigeSystem.compute_next_grant(&"pato_streamer", 3)
	assert_dict(second).is_equal(first)
	# meta_bonus_totals must be unchanged -- the whole point of "preview" is
	# zero mutation, verified explicitly, not just inferred from equal output.
	assert_float(PrestigeSystem.get_meta_bonus_total(&"META_REACH_MULT")).is_equal_approx(
		_meta_totals_snapshot.get(&"META_REACH_MULT", 0.0), 0.0001
	)


# --- No active path -> granted: false, not an inferred zero ---

func test_no_active_path_returns_granted_false() -> void:
	var result: Dictionary = PrestigeSystem.compute_next_grant(&"", 0)
	assert_bool(result["granted"]).is_false()
	assert_str(result["type"]).is_equal("")
	assert_float(result["amount"]).is_equal(0.0)


func test_unrecognized_path_id_returns_granted_false() -> void:
	var result: Dictionary = PrestigeSystem.compute_next_grant(&"not_a_real_path", 3)
	assert_bool(result["granted"]).is_false()


# --- Capped type: amount is the post-cap applied delta, not raw_grant ---

func test_capped_type_returns_post_cap_delta_not_raw_grant() -> void:
	# Push META_REACH_MULT to its cap (0.50, per META_BONUS_MAX) before
	# previewing -- any further grant must compute to (near-)zero applied
	# delta, never the uncapped PrestigeFormulas.grant_magnitude() output.
	PrestigeSystem.meta_bonus_totals[&"META_REACH_MULT"] = PrestigeFormulas.META_BONUS_MAX[&"META_REACH_MULT"]
	var result: Dictionary = PrestigeSystem.compute_next_grant(&"pato_streamer", 5)
	var raw_grant: float = PrestigeFormulas.grant_magnitude(&"META_REACH_MULT", 5, 1.0, false)
	assert_bool(result["granted"]).is_true()
	assert_float(result["amount"]).override_failure_message(
		"amount must be the post-cap applied delta (~0.0 when already at cap), not the uncapped raw_grant (%s)" % raw_grant
	).is_less(raw_grant)
	assert_float(result["amount"]).is_equal_approx(0.0, 0.0001)


# --- Challenge multiplier is read live, same as the real grant path ---

func test_active_challenge_multiplier_is_reflected_in_preview() -> void:
	var baseline: Dictionary = PrestigeSystem.compute_next_grant(&"pato_streamer", 1)
	ChallengeSystem.select_challenges([&"drama_bez_granic"])  # meta_bonus_multiplier 2.5
	var with_challenge: Dictionary = PrestigeSystem.compute_next_grant(&"pato_streamer", 1)
	assert_float(with_challenge["amount"]).override_failure_message(
		"an active challenge's meta_bonus_multiplier must scale the preview identically to a real grant"
	).is_greater(baseline["amount"])
