## Interaction test for ActionGrid (Story 003, Action UI epic). Uses
## GdUnit4's scene_runner() to instantiate the real scene headlessly and
## assert on button state/labels and ActionSystem interaction -- same
## evidence approach as Story 002's ResourceHud, the standing method for
## all UI stories in this project (see docs/tech-debt-register.md, Story
## 002 entry).
##
## ActionSystem state is reset per before_test()/after_test() to guarantee
## idle state at the start of each test, since start_action() is a
## single-concurrency gate.
extends GdUnitTestSuite

var _risky_snapshot: int
var _safe_snapshot: int

func before_test() -> void:
	# Force idle: if a prior test left an action running, resolve it before
	# this test begins. ActionSystem has no public "force idle" seam, so
	# directly clear current_action_id -- acceptable here since this is test
	# setup, not production code touching another system's internals.
	ActionSystem.current_action_id = &""
	# The grid now gates slots 4-6 on the real HistoryFlagManager (DDR-0001 #3).
	# Reset the two gating counters to 0 so these "3 locked" assertions are not
	# polluted by counters another suite left set. The slot-6 milestones
	# (card.staged_drama.chosen_risky / card.cancel_threat.apologized) are only
	# ever set by resolving those exact real cards -- no test does that -- so
	# they need no reset (and HistoryFlagManager has no unset API by design).
	_risky_snapshot = HistoryFlagManager.get_counter(&"risky_choices_count")
	_safe_snapshot = HistoryFlagManager.get_counter(&"safe_choices_count")
	HistoryFlagManager.restore_state({"counters": {"risky_choices_count": 0, "safe_choices_count": 0}})

func after_test() -> void:
	ActionSystem.current_action_id = &""
	HistoryFlagManager.restore_state({"counters": {
		"risky_choices_count": _risky_snapshot, "safe_choices_count": _safe_snapshot,
	}})

## AC: exactly 6 slots, 3 unlocked + 3 locked. Since Story 005 (locked slot
## preview), locked slots are NOT disabled (enabled for tap -> toast) -- the
## locked/unlocked distinction is the icon's LOCKED_MODULATE gray-out.
func test_action_grid_renders_six_slots_three_unlocked_three_locked() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	var unlocked_count: int = 0
	var locked_count: int = 0
	for i in range(1, 7):
		var icon: TextureRect = grid.find_child("Slot%dIcon" % i) as TextureRect
		if icon.modulate == ActionGrid.LOCKED_MODULATE:
			locked_count += 1
		else:
			unlocked_count += 1

	assert_int(unlocked_count).is_equal(3)
	assert_int(locked_count).is_equal(3)

## AC (revised by Story 005 locked slot preview): a locked slot shows a
## PREVIEW of its real action -- the action's own icon grayed to
## LOCKED_MODULATE, the real display name with a lock prefix, and the unlock
## requirement in the stats label ("N / M choices" for counter-gated slots
## 4-5, "Reach a story moment" for the milestone-gated slot 6).
func test_locked_slots_show_action_preview_with_unlock_requirement() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	for i in range(4, 7):
		var icon: TextureRect = grid.find_child("Slot%dIcon" % i) as TextureRect
		assert_object(icon.texture).is_not_equal(ActionGrid.LOCKED_ICON)  # real action icon, not padlock
		assert_object(icon.modulate).is_equal(ActionGrid.LOCKED_MODULATE)
		# Padlock badge (texture, not a text glyph — web-safe, 2026-07-06)
		var badge: TextureRect = grid.find_child("Slot%dLockBadge" % i, true, false) as TextureRect
		assert_object(badge).is_not_null()
		assert_object(badge.texture).is_equal(ActionGrid.LOCKED_ICON)

	assert_str((grid.find_child("Slot4Stats") as Label).text).is_equal("0 / 3 choices")
	assert_str((grid.find_child("Slot5Stats") as Label).text).is_equal("0 / 6 choices")
	assert_str((grid.find_child("Slot6Stats") as Label).text).is_equal("Reach a story moment")

## Coverage gap closed (flagged by playtest feedback): locked slots must be
## visually dimmed, not just disabled -- the disabled StyleBox alone reads
## as too subtle. Verifies the icon's modulate is darkened.
func test_locked_slot_icons_are_visually_dimmed() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	for i in range(4, 7):
		var icon: TextureRect = grid.find_child("Slot%dIcon" % i) as TextureRect
		assert_object(icon.modulate).is_equal(ActionGrid.LOCKED_MODULATE)

## Buttons must EXPAND horizontally (so the 2-column grid splits screen width
## evenly) but only FILL vertically, NOT expand -- vertical expand caused the
## "skyscraper" buttons in portrait (flagged by playtest 2026-06-25). The grid
## now sits as a fixed-height block pushed down by a spacer, with compact
## app-tile-proportioned cards rather than tall stretched ones.
func test_slot_buttons_expand_horizontally_but_not_vertically() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	for i in range(1, 7):
		var button: Button = grid.find_child("Slot%dButton" % i) as Button
		assert_int(button.size_flags_horizontal).is_equal(Control.SIZE_EXPAND_FILL)
		assert_int(button.size_flags_vertical).is_equal(Control.SIZE_FILL)

## Portrait layout: the grid is 2 columns x 3 rows (not 3x2), which fits a
## phone's narrow vertical screen far better (flagged by playtest 2026-06-25).
func test_grid_uses_two_columns_for_portrait() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid_container: GridContainer = runner.scene().find_child("GridContainer") as GridContainer

	assert_int(grid_container.columns).is_equal(2)

## AC: idle state -- tapping an unlocked button calls ActionSystem.start_action()
## and the action actually starts (current_action_id becomes non-empty).
func test_tapping_unlocked_button_starts_the_action() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var slot1: Button = runner.scene().find_child("Slot1Button") as Button

	slot1.pressed.emit()

	assert_str(String(ActionSystem.current_action_id)).is_equal("nagraj_vloga")

## AC (revised by Story 005): tapping a locked slot shows an informational
## toast but never starts an action -- current_action_id must stay empty.
func test_tapping_locked_slot_is_a_noop() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var slot4: Button = runner.scene().find_child("Slot4Button") as Button

	slot4.pressed.emit()

	assert_str(String(ActionSystem.current_action_id)).is_equal("")

## AC: running state -- starting an action disables all 6 buttons immediately.
func test_starting_an_action_disables_all_six_buttons() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	var slot1: Button = grid.find_child("Slot1Button") as Button

	slot1.pressed.emit()

	for i in range(1, 7):
		var button: Button = grid.find_child("Slot%dButton" % i) as Button
		assert_bool(button.disabled).is_true()

## AC (revised by Story 005): running->resolved->idle transition re-enables
## ALL six buttons -- the base 3 for starting actions, and the still-locked
## gated slots for tap -> toast. Locked slots remain visually grayed
## (LOCKED_MODULATE) even though their buttons are enabled.
func test_action_completed_reenables_all_slots_locked_stay_grayed() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	var slot1: Button = grid.find_child("Slot1Button") as Button
	slot1.pressed.emit()

	ActionSystem.action_completed.emit(&"nagraj_vloga", {&"Reach": 5.0, &"Cringe": 2.0, &"Morale": 0.0})

	for i in range(1, 7):
		assert_bool((grid.find_child("Slot%dButton" % i) as Button).disabled).is_false()
	for i in range(4, 7):
		assert_object((grid.find_child("Slot%dIcon" % i) as TextureRect).modulate).is_equal(ActionGrid.LOCKED_MODULATE)

## AC: button anatomy -- now split into a primary Title label (action name)
## and a secondary Stats label (duration + rewards), for typographic hierarchy
## (Art Director direction 2026-06-25). The title is large/white, the stats
## small/grey; they're separate nodes, not one \n-joined string.
func test_button_shows_title_and_stats_as_separate_labels() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	# zrob_drame: 9s, Reach +10, Cringe +20, Morale -3 (per ActionSystem.ACTION_REWARDS)
	assert_str((grid.find_child("Slot2Title") as Label).text).is_equal("Make Drama")
	assert_str((grid.find_child("Slot2Stats") as Label).text).is_equal("9s — +10R, +20C, -3M")

## ActionScreen root scene instantiates ActionGrid as a sibling of ResourceHud.
func test_action_screen_root_instantiates_action_grid_zone() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_screen.tscn")
	var root: Node = runner.scene()
	var grid: Node = root.find_child("ActionGrid", true, false)
	var hud: Node = root.find_child("ResourceHud", true, false)

	assert_object(grid).is_not_null()
	assert_object(hud).is_not_null()

## AC (revised by playtest feedback 2026-06-25): a long action title should
## WRAP onto multiple lines rather than truncate with an ellipsis -- the
## buttons are large icon-first cards with room for wrapped text. The Title
## label uses word-smart autowrap; the button keeps a sane custom_minimum_size
## floor so it never collapses below readability.
func test_title_labels_wrap_text_and_buttons_have_minimum_size() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()

	for i in range(1, 7):
		var button: Button = grid.find_child("Slot%dButton" % i) as Button
		var title: Label = grid.find_child("Slot%dTitle" % i) as Label
		if i <= 3:
			assert_int(title.autowrap_mode).is_equal(TextServer.AUTOWRAP_WORD_SMART)
		else:
			# Locked slots run autowrap OFF while the padlock badge shares the
			# title row (an autowrapping Label in an HBox collapses to 1 char
			# per line — 2026-07-06 web finding); WORD_SMART returns on unlock.
			assert_int(title.autowrap_mode).is_equal(TextServer.AUTOWRAP_OFF)
		assert_vector(button.custom_minimum_size).is_equal(Vector2(100, 160))

## AC (coverage gap closed, flagged by code review): start_action() returning
## false (e.g. an action already running) must not disable buttons a second
## time or error -- the pressed handler's `if started:` guard must hold.
func test_pressed_handler_does_not_disable_buttons_when_start_action_rejects() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/action_screen/action_grid.tscn")
	var grid: Node = runner.scene()
	var slot1: Button = grid.find_child("Slot1Button") as Button
	var slot2: Button = grid.find_child("Slot2Button") as Button

	slot1.pressed.emit()  # starts nagraj_vloga, current_action_id now non-empty
	assert_bool(slot2.disabled).is_true()  # already disabled by the first start

	# Directly invoke the handler again (simulating a stale/race button press)
	# while an action is already running -- start_action() must return false,
	# and the handler must not error or change state further.
	runner.invoke("_on_unlocked_button_pressed", &"zrob_drame")

	assert_str(String(ActionSystem.current_action_id)).is_equal("nagraj_vloga")
	assert_bool(slot2.disabled).is_true()
