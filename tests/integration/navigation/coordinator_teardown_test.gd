## Regression test for the era-transition crash (playtest 2026-07-28): freeing
## action_screen while coordination_state == CARD_PRESENTED (exactly the
## Wypalenie-Accept scene swap) fired CardScreen.visibility_changed during
## teardown, and the coordinator's handler dereferenced already-freed sibling
## panels. The fix guards the handler against the not-in-tree teardown state.
extends GdUnitTestSuite

const SCENE: PackedScene = preload("res://scenes/action_screen/action_screen.tscn")


## AC: freeing the scene mid-CARD_PRESENTED (the era-transition teardown
## path) completes without touching freed panels — no script errors, no
## crash. Uses free() directly (change_scene_to_file frees the old scene the
## same way) rather than queue_free, to hit the synchronous teardown order.
func test_free_while_card_presented_does_not_crash() -> void:
	var s: Control = SCENE.instantiate()
	add_child(s)
	await get_tree().process_frame
	s._card_screen.visible = true
	s._on_card_presented({})
	assert_int(s.coordination_state).is_equal(s.CoordinationState.CARD_PRESENTED)

	s.free()  # the change_scene teardown path

	assert_bool(is_instance_valid(s)).is_false()
