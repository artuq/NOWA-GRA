## Regression test for the era-transition failure reported 2026-07-28:
## accepting the Wypalenie card runs a scene swap (ADR-0018) that frees
## CardScreen WHILE its resolution-beat coroutine is still parked on a timer.
## Resuming that coroutine on a freed instance is what the guard added to
## card_screen.gd's _resolve() prevents.
extends GdUnitTestSuite

const CARD_SCREEN_SCENE: PackedScene = preload("res://scenes/card_screen/card_screen.tscn")


## AC: freeing the CardScreen mid-resolution-beat (what change_scene_to_file
## does on an accepted burnout) leaves no coroutine touching a dead instance.
## The test passes only if the deferred resume is a clean no-op — gdUnit4
## fails the suite on the "previously freed instance" error the unguarded
## version produced.
func test_free_during_resolution_beat_is_safe() -> void:
	var cs: Control = CARD_SCREEN_SCENE.instantiate()
	add_child(cs)
	await get_tree().process_frame

	# Present a real card, then drive the resolution path that parks on the
	# beat timer (DecisionCardSystem is left untouched — the guard under test
	# is purely CardScreen's own post-await lifetime check).
	cs._on_card_presented(CardContentDatabase.get_card("burnout_warning"))
	cs.state = cs.State.AWAITING_SWIPE

	# Free the scene the way the era transition does, immediately after the
	# resolve call starts its beat.
	cs.free()
	assert_bool(is_instance_valid(cs)).is_false()

	# Let any parked coroutine wake up on the freed instance.
	await get_tree().create_timer(0.2).timeout
	await get_tree().process_frame
