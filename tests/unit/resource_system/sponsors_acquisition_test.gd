## Unit tests for the Resource-System-owned portion of Sponsors acquisition
## (Story 007, GDD Sponsorzy placeholder). The full feature — a Decision Card
## resolving a "qualifying" card and rewarding randi_range(1,3) Sponsors — is
## owned by the Decision Card System / Card Content Database epics, which are
## not built yet. The card-trigger logic and the random draw itself are
## explicitly OUT OF SCOPE here (and randi_range would violate the test
## determinism rule anyway).
##
## What the Resource System actually owns and this story locks: Sponsors is an
## UNBOUNDED resource key. apply_delta() increments it by any positive integer
## reward, never clamps it (unlike Cringe/Morale), and there is no consumption
## /sink mechanism. The reward's [1,3] domain is verified deterministically by
## applying each of the three valid amounts directly, rather than by drawing a
## random number.
##
## No new production code is added by this story — Sponsors already exists as
## an unbounded key in ResourceManager (Story 001). See
## production/epics/resource-system/story-007-sponsors-acquisition.md.
##
## Note: the production resource key is the English "Sponsors" (the binding
## decision for code); the GDD's "Sponsorzy" is a pending doc-sync item
## (tech-debt-register.md). These tests use the code key.
##
## Each test instantiates a fresh ResourceManager directly for isolation. No
## shared state, no random seeds, no time-dependent assertions, no external
## I/O — per coding-standards.md.
extends GdUnitTestSuite

const ResourceManagerScript: GDScript = preload("res://src/core/resource_manager.gd")

var _rm: Node


func before_test() -> void:
	_rm = ResourceManagerScript.new()
	add_child(_rm)


func after_test() -> void:
	# GdUnit4's own GC can free tree-added nodes between stages when a test
	# awaits — guard against double-free (see core_mutation_test.gd, 2026-06-23).
	if is_instance_valid(_rm):
		_rm.queue_free()


## Sponsors defaults to 0 — the placeholder reward path starts from empty.
func test_sponsors_starts_at_zero() -> void:
	assert_float(_rm.get_resource(&"Sponsors")).is_equal_approx(0.0, 0.0001)


## AC (reward domain [1,3], deterministic): applying each of the three valid
## reward amounts increments Sponsors by exactly that amount. This covers the
## "+random integer in {1,2,3}" requirement without a random draw — every
## value the draw could produce is verified directly.
func test_each_valid_reward_amount_increments_sponsors_exactly() -> void:
	for amount: float in [1.0, 2.0, 3.0]:
		var rm: Node = ResourceManagerScript.new()
		add_child(rm)

		var reward: Dictionary[StringName, float] = {&"Sponsors": amount}
		rm.apply_delta(reward)
		assert_float(rm.get_resource(&"Sponsors")).is_equal_approx(amount, 0.0001)

		rm.queue_free()


## AC (no clamp): Sponsors is unbounded — unlike Cringe/Morale, a value past
## 100 is NOT clamped. Locks the contrast that makes Sponsors a non-clamped key.
func test_sponsors_is_unbounded_and_never_clamped() -> void:
	var big_reward: Dictionary[StringName, float] = {&"Sponsors": 150.0}
	_rm.apply_delta(big_reward)
	assert_float(_rm.get_resource(&"Sponsors")).is_equal_approx(150.0, 0.0001)


## AC (no sink): repeated rewards accumulate with no consumption mechanism —
## there is nothing in scope that subtracts Sponsors.
func test_sponsors_rewards_accumulate_with_no_sink() -> void:
	var first: Dictionary[StringName, float] = {&"Sponsors": 3.0}
	_rm.apply_delta(first)
	var second: Dictionary[StringName, float] = {&"Sponsors": 2.0}
	_rm.apply_delta(second)

	assert_float(_rm.get_resource(&"Sponsors")).is_equal_approx(5.0, 0.0001)
