## Presentation regression tests for Feed Sprint's three-lane playfield.
extends GdUnitTestSuite

const SpotlightMinigameConfigScript: GDScript = preload(
	"res://src/core/spotlight_minigame_config.gd"
)

var _locale_snapshot: String


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)


func test_playfield_uses_three_equal_full_height_lane_columns() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/feed_sprint.tscn")
	var feed: Node = runner.scene()
	var config: Dictionary = SpotlightMinigameConfigScript.load_config(&"feed_sprint")
	assert_bool(feed.start(config)).is_true()
	await get_tree().process_frame

	var left_lane: Control = feed.find_child("LeftLane") as Control
	var center_lane: Control = feed.find_child("CenterLane") as Control
	var right_lane: Control = feed.find_child("RightLane") as Control
	assert_float(left_lane.size.x).is_equal_approx(center_lane.size.x, 0.01)
	assert_float(center_lane.size.x).is_equal_approx(right_lane.size.x, 0.01)
	assert_float(left_lane.size.y).is_equal_approx(center_lane.size.y, 0.01)
	assert_float(center_lane.size.y).is_equal_approx(right_lane.size.y, 0.01)
	feed.skip()


func test_current_event_explicitly_distinguishes_trend_from_strike() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/feed_sprint.tscn")
	var feed: Node = runner.scene()
	var config: Dictionary = SpotlightMinigameConfigScript.load_config(&"feed_sprint")
	assert_bool(feed.start(config)).is_true()

	var target: Label = feed.find_child("CurrentTargetLabel") as Label
	assert_str(target.text).is_equal("TARGET: TREND — CATCH")
	feed.call("_resolve_event")
	assert_str(target.text).is_equal("DANGER: STRIKE — DODGE")
	feed.skip()


func test_lane_header_tracks_the_players_selected_lane() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/feed_sprint.tscn")
	var feed: Node = runner.scene()
	var config: Dictionary = SpotlightMinigameConfigScript.load_config(&"feed_sprint")
	assert_bool(feed.start(config)).is_true()

	var left_label: Label = feed.find_child("LeftLaneLabel") as Label
	var center_label: Label = feed.find_child("CenterLaneLabel") as Label
	assert_str(center_label.text).is_equal("[ CENTER ]")
	feed.move_left()
	assert_str(left_label.text).is_equal("[ LEFT ]")
	assert_str(center_label.text).is_equal("CENTER")
	feed.skip()


func test_open_feed_sprint_refreshes_after_polish_language_change() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/feed_sprint.tscn")
	var feed: Node = runner.scene()
	var config: Dictionary = SpotlightMinigameConfigScript.load_config(&"feed_sprint")
	assert_bool(feed.start(config)).is_true()
	assert_bool((feed.find_child("InstructionLabel") as Label).text.begins_with("Catch")).is_true()

	TranslationServer.set_locale("pl_PL")
	SettingsSystem.language_changed.emit(&"pl", &"pl_PL")

	assert_bool((feed.find_child("InstructionLabel") as Label).text.begins_with("Łap")).is_true()
	assert_str((feed.find_child("CurrentTargetLabel") as Label).text).is_equal("CEL: TREND — ŁAP")
	assert_str((feed.find_child("CenterLaneLabel") as Label).text).is_equal("[ ŚRODEK ]")
	feed.skip()


func test_feed_sprint_started_after_hidden_locale_change_uses_polish_buttons() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/feed_sprint.tscn")
	var feed: Node = runner.scene()
	TranslationServer.set_locale("pl_PL")
	SettingsSystem.language_changed.emit(&"pl", &"pl_PL")
	var config: Dictionary = SpotlightMinigameConfigScript.load_config(&"feed_sprint")

	assert_bool(feed.start(config)).is_true()
	assert_str((feed.find_child("LeftButton") as Button).text).is_equal("« LEWO")
	assert_str((feed.find_child("SkipButton") as Button).text).contains("Pomiń")
	feed.skip()
