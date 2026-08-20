extends GdUnitTestSuite

var _locale_snapshot: String


func before_test() -> void:
	_locale_snapshot = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	TranslationServer.set_locale(_locale_snapshot)


func _identity_pick(upper_inclusive: int) -> int:
	return upper_inclusive


func _zero_pick(_upper_inclusive: int) -> int:
	return 0


func _texts(events: Array) -> Array[String]:
	var texts: Array[String] = []
	for event: Dictionary in events:
		texts.append(String(event["text"]))
	return texts


func _actions(events: Array) -> Array[String]:
	var actions: Array[String] = []
	for event: Dictionary in events:
		actions.append(String(event["correct_action"]))
	return actions


func test_each_start_builds_a_new_balanced_nontrivial_session_order() -> void:
	var runner: GdUnitSceneRunner = scene_runner(
		"res://scenes/card_screen/comment_moderation.tscn"
	)
	var moderation: Node = runner.scene()
	var config: Dictionary = SpotlightMinigameConfig.load_config(&"comment_moderation")

	assert_bool(moderation.start(config, _identity_pick)).is_true()
	var first: Array = moderation.get("_events").duplicate(true)
	moderation.call("_finish", 0.0, true)

	assert_bool(moderation.start(config, _zero_pick)).is_true()
	var second: Array = moderation.get("_events").duplicate(true)
	var first_actions: Array[String] = _actions(first)
	var second_actions: Array[String] = _actions(second)

	assert_array(_texts(first)).is_not_equal(_texts(second))
	assert_int(first_actions.count("keep")).is_equal(5)
	assert_int(first_actions.count("remove")).is_equal(5)
	assert_int(second_actions.count("keep")).is_equal(5)
	assert_int(second_actions.count("remove")).is_equal(5)


func test_shuffle_config_keeps_locked_timing_and_rewards() -> void:
	var config: Dictionary = SpotlightMinigameConfig.load_config(&"comment_moderation")
	var actions: Array[String] = _actions(config["events"])

	assert_str(config["event_order"]).is_equal("shuffle_nontrivial")
	assert_float(config["event_duration_seconds"]).is_equal(5.0)
	assert_float(config["feedback_pause_seconds"]).is_equal(0.45)
	assert_float(config["reward_min"]).is_equal(25.0)
	assert_float(config["reward_max"]).is_equal(190.0)
	assert_float(config["reward_curve_exponent"]).is_equal(1.35)
	assert_int(actions.count("keep")).is_equal(5)
	assert_int(actions.count("remove")).is_equal(5)
	for event: Dictionary in config["events"]:
		assert_str(String(event.get("text_key", ""))).is_not_empty()


func test_wrong_and_timeout_feedback_remain_visible_during_pause() -> void:
	var runner: GdUnitSceneRunner = scene_runner(
		"res://scenes/card_screen/comment_moderation.tscn"
	)
	var moderation: Node = runner.scene()
	var config: Dictionary = SpotlightMinigameConfig.load_config(&"comment_moderation")
	var feedback: Label = moderation.find_child("FeedbackLabel") as Label

	assert_bool(moderation.start(config, _identity_pick)).is_true()
	var first_events: Array = moderation.get("_events")
	var correct_action: String = String(first_events[0]["correct_action"])
	var wrong_action: String = "remove" if correct_action == "keep" else "keep"
	moderation.classify(wrong_action)
	assert_str(feedback.text).is_equal("WRONG")

	moderation.call("_finish", 0.0, true)
	assert_bool(moderation.start(config, _identity_pick)).is_true()
	moderation.classify("timeout")
	assert_str(feedback.text).is_equal("MISSED")


func test_open_moderation_refreshes_comment_controls_and_feedback_in_polish() -> void:
	var runner: GdUnitSceneRunner = scene_runner(
		"res://scenes/card_screen/comment_moderation.tscn"
	)
	var moderation: Node = runner.scene()
	var config: Dictionary = SpotlightMinigameConfig.load_config(&"comment_moderation")
	assert_bool(moderation.start(config, _identity_pick)).is_true()
	var first_events: Array = moderation.get("_events")
	moderation.classify(String(first_events[0]["correct_action"]))
	assert_str((moderation.find_child("FeedbackLabel") as Label).text).is_equal("CORRECT")

	TranslationServer.set_locale("pl_PL")
	SettingsSystem.language_changed.emit(&"pl", &"pl_PL")

	assert_str((moderation.find_child("FeedbackLabel") as Label).text).is_equal("DOBRZE")
	assert_str((moderation.find_child("KeepButton") as Button).text).is_equal("ZOSTAW »")
	assert_str((moderation.find_child("RemoveButton") as Button).text).is_equal("« USUŃ")
	assert_str((moderation.find_child("CommentLabel") as Label).text).contains(
		TranslationServer.translate(String(first_events[0]["text_key"]))
	)


func test_moderation_started_after_hidden_locale_change_uses_polish_buttons() -> void:
	var runner: GdUnitSceneRunner = scene_runner(
		"res://scenes/card_screen/comment_moderation.tscn"
	)
	var moderation: Node = runner.scene()
	TranslationServer.set_locale("pl_PL")
	SettingsSystem.language_changed.emit(&"pl", &"pl_PL")
	var config: Dictionary = SpotlightMinigameConfig.load_config(&"comment_moderation")

	assert_bool(moderation.start(config, _identity_pick)).is_true()
	assert_str((moderation.find_child("KeepButton") as Button).text).is_equal("ZOSTAW »")
	assert_str((moderation.find_child("RemoveButton") as Button).text).is_equal("« USUŃ")
	moderation.call("_finish", 0.0, true)
