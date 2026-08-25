## Integration tests for the MainNavCoordinator (ADR-0014, implemented in
## action_screen.gd): coordination_state as single source of truth, at-most-
## one-panel, card-interrupt priority, CARD_PRESENTED exit gating on the
## CardScreen actually hiding, and back-gesture branches (GDD Rule 6).
##
## Entry-point handlers are invoked directly (not via real Autoload signal
## emission) so no cross-system side effects fire mid-test — same convention
## as burnout_warning_indicator_test.gd. The scene is the REAL
## action_screen.tscn (all three panels instanced), so the mutual-consistency
## assertion exercises the real node wiring.
extends GdUnitTestSuite

const SCENE: String = "res://scenes/action_screen/action_screen.tscn"


func _screen(runner: GdUnitSceneRunner) -> Control:
	return runner.scene()


## The ADR's validation criterion: after ANY entry point, coordination_state
## and all three panels' visible flags must be mutually consistent.
func _assert_consistent(s: Control) -> void:
	var visible_count: int = 0
	for panel: Control in [s._class_path_panel, s._settings_screen, s._bonuses_panel]:
		if panel.visible:
			visible_count += 1
	match s.coordination_state:
		s.CoordinationState.PANEL_OPEN:
			assert_int(visible_count).is_equal(1)
			assert_bool(s._open_panel.visible).is_true()
		_:
			assert_int(visible_count).is_equal(0)


func test_initial_state_no_overlay() -> void:
	var s: Control = _screen(scene_runner(SCENE))
	assert_int(s.coordination_state).is_equal(s.CoordinationState.NO_OVERLAY)
	_assert_consistent(s)


func test_buttons_open_their_panels_at_most_one_visible() -> void:
	var s: Control = _screen(scene_runner(SCENE))
	s._on_path_button_pressed()
	assert_bool(s._class_path_panel.visible).is_true()
	_assert_consistent(s)
	# Switching panels closes the previous one in the same synchronous call.
	s._on_settings_button_pressed()
	assert_bool(s._settings_screen.visible).is_true()
	assert_bool(s._class_path_panel.visible).is_false()
	_assert_consistent(s)
	s._on_bonuses_button_pressed()
	assert_bool(s._bonuses_panel.visible).is_true()
	assert_bool(s._settings_screen.visible).is_false()
	_assert_consistent(s)


## AC (the two fixed live bugs): a panel's Close button EMITS close_requested
## and the coordinator flips visibility — the panel never self-sets visible.
func test_close_request_routes_through_coordinator() -> void:
	var s: Control = _screen(scene_runner(SCENE))
	s._on_path_button_pressed()
	# Drive the real signal path: panel's own Close handler.
	s._class_path_panel._on_close_pressed()
	assert_int(s.coordination_state).is_equal(s.CoordinationState.NO_OVERLAY)
	_assert_consistent(s)
	s._on_settings_button_pressed()
	s._settings_screen._on_close_pressed()
	assert_int(s.coordination_state).is_equal(s.CoordinationState.NO_OVERLAY)
	_assert_consistent(s)


## AC (GDD Rule 5): card presentation closes any open panel in the same
## synchronous call and takes priority; 5a: duplicate presentation no-ops.
func test_card_priority_and_5a_guard() -> void:
	var s: Control = _screen(scene_runner(SCENE))
	s._on_bonuses_button_pressed()
	s._on_card_presented({})
	assert_int(s.coordination_state).is_equal(s.CoordinationState.CARD_PRESENTED)
	_assert_consistent(s)
	s._on_card_presented({})  # 5a: no-op, no crash
	assert_int(s.coordination_state).is_equal(s.CoordinationState.CARD_PRESENTED)
	# Panel taps are rejected while the card is up.
	s._on_path_button_pressed()
	assert_int(s.coordination_state).is_equal(s.CoordinationState.CARD_PRESENTED)
	_assert_consistent(s)


## AC (ADR-0014 constraint): exit from CARD_PRESENTED gates on the CardScreen
## actually hiding, not on card_resolved.
func test_card_exit_gates_on_card_screen_hidden() -> void:
	var s: Control = _screen(scene_runner(SCENE))
	s._card_screen.visible = true  # test-side simulation of the modal showing
	s._on_card_presented({})
	assert_int(s.coordination_state).is_equal(s.CoordinationState.CARD_PRESENTED)
	# Hiding the card screen fires visibility_changed -> coordinator exits.
	s._card_screen.visible = false
	assert_int(s.coordination_state).is_equal(s.CoordinationState.NO_OVERLAY)
	_assert_consistent(s)


## AC (GDD Rule 6): back gesture closes an open panel (consumed), shields a
## presented card (consumed), and defers to platform default otherwise.
func test_back_gesture_branches() -> void:
	var s: Control = _screen(scene_runner(SCENE))
	s._on_settings_button_pressed()
	assert_bool(s._on_back_gesture()).is_true()
	assert_int(s.coordination_state).is_equal(s.CoordinationState.NO_OVERLAY)
	_assert_consistent(s)

	s._on_card_presented({})
	assert_bool(s._on_back_gesture()).is_true()
	assert_int(s.coordination_state).is_equal(s.CoordinationState.CARD_PRESENTED)
	s._card_screen.visible = false  # cleanup path back to NO_OVERLAY
	if s.coordination_state == s.CoordinationState.CARD_PRESENTED:
		s._apply_state_change(s.CoordinationState.NO_OVERLAY, null)

	assert_bool(s._on_back_gesture()).is_false()
	assert_int(s.coordination_state).is_equal(s.CoordinationState.NO_OVERLAY)
	_assert_consistent(s)
