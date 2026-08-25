extends Node

const OUTPUT_DIR := "res://marketing/screenshots/store-9x16"
const MAIN_SCENE := preload("res://scenes/main/main.tscn")
const OFFLINE_SCENE := preload("res://scenes/offline_report/offline_report.tscn")

var _current: Node


func _ready() -> void:
	# Never let a marketing capture touch the player's real save.
	SaveSystem.SAVE_PATH = "user://save.marketing-capture.json"
	SaveSystem.TEMP_PATH = "user://save.marketing-capture.tmp"
	SaveSystem.BACKUP_PATH = "user://save.marketing-capture.backup.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_all()
	get_tree().quit()


func _capture_all() -> void:
	await _capture_main("Build Your Content Empire!", "main_endgame")
	await _capture_main("Watch Your Numbers Go Up", "numbers")
	await _capture_offline("Grow Even While Offline!")
	await _capture_main("Hire Trolls & Assistants", "staff")
	await _capture_main("Make Tough Moral Choices", "card_moral")
	await _capture_main("Every Choice Has Consequences", "card_consequence")
	await _capture_main("Will You Sell Out?", "card_sponsor")
	await _capture_main("Choose Your Unique Path", "path")
	await _capture_main("Manage Haters & Sponsors", "resources")
	await _capture_main("Survive the Drama!", "drama")
	await _capture_main("Rule the Algorithm", "bonuses")
	await _capture_main("Embrace the Cringe", "cringe")
	await _capture_main("From Empty Pub to Stardom", "early")
	await _capture_main("Unlock Satirical Eras", "eras")
	await _capture_main("Become the Ultimate Influencer!", "ultimate")
	await _capture_minigames()


func _reset_runtime() -> void:
	ResourceManager.reset_for_new_game()
	HistoryFlagManager.reset_for_new_game()
	ClassPathSystem.reset_for_new_game()
	PrestigeSystem.reset_for_new_game()
	StaffSystem.reset_era_state()
	# Card catalogue entries are read-only const dictionaries. Detach the
	# presented reference before the production reset clears its transient copy.
	DecisionCardSystem._presented_card = {}
	DecisionCardSystem.reset_for_new_game()
	ActionSystem.reset_for_new_game()
	BurnoutSystem.reset_for_new_game()
	ChallengeSystem.restore_state({})
	OnboardingGate.restore_state({})


func _seed_progress(endgame: bool = true) -> void:
	ResourceManager.restore_state({
		"Reach": 9876543.0 if endgame else 18420.0,
		"Cringe": 88.0 if endgame else 34.0,
		"Haters": 48210.0 if endgame else 740.0,
		"Morale": 62.0 if endgame else 86.0,
		"Sponsors": 8240.0 if endgame else 125.0,
		"shield_remaining_seconds": 240.0,
	})
	HistoryFlagManager.restore_state({
		"milestones": {"card.staged_drama.chosen_risky": true},
		"counters": {"risky_choices_count": 14, "safe_choices_count": 9},
	})
	StaffSystem.restore_state({"staff_count": {"troll": 8, "assistant": 7, "sponsor_manager": 6}})
	ClassPathSystem.restore_state({
		"affiliation": {"pato_streamer": 100.0, "guru_celebryta": 32.0},
		"card_contribution": {"pato_streamer": 40.0, "guru_celebryta": 12.0},
		"investment_contribution": {"pato_streamer": 60.0, "guru_celebryta": 20.0},
		"current_tier": {"pato_streamer": 5, "guru_celebryta": 1},
		"active_path": "pato_streamer",
	})
	PrestigeSystem.restore_state({
		"era_count": 8,
		"meta_bonus_totals": {
			"META_REACH_MULT": 0.75,
			"META_SPONSOR_MULT": 0.55,
			"META_HATERS_RESIST": 0.48,
			"META_SPONSOR_FLOOR": 18.0,
		},
	})


func _capture_main(title: String, mode: String) -> void:
	_reset_runtime()
	if mode == "early":
		ResourceManager.restore_state({"Reach": 24.0, "Cringe": 3.0, "Haters": 1.0, "Morale": 100.0, "Sponsors": 0.0})
	else:
		_seed_progress(mode in ["main_endgame", "ultimate", "bonuses", "eras", "staff", "path"])
	if mode == "resources":
		ResourceManager.restore_state({"Reach": 284000.0, "Cringe": 91.0, "Haters": 99000.0, "Morale": 43.0, "Sponsors": 12800.0, "shield_remaining_seconds": 300.0})
	if mode == "cringe":
		ResourceManager.restore_state({"Reach": 1200000.0, "Cringe": 100.0, "Haters": 33333.0, "Morale": 18.0, "Sponsors": 666.0})
	if mode == "ultimate":
		ResourceManager.restore_state({"Reach": 999999999.0, "Cringe": 100.0, "Haters": 999999.0, "Morale": 12.0, "Sponsors": 999999.0})
	_current = MAIN_SCENE.instantiate()
	add_child(_current)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Node = _current.get_node("ActionScreen")
	match mode:
		"staff": screen.call("_on_staff_button_pressed")
		"path": screen.call("_on_path_button_pressed")
		"bonuses", "eras": screen.call("_on_bonuses_button_pressed")
		"card_moral": DecisionCardSystem.present_next_card([CardContentDatabase.get_card(&"exposed_friend").duplicate(true)])
		"card_sponsor": DecisionCardSystem.present_next_card([CardContentDatabase.get_card(&"sponsor_offer_shady").duplicate(true)])
		"card_consequence":
			DecisionCardSystem.present_next_card([CardContentDatabase.get_card(&"staged_drama").duplicate(true)])
			await get_tree().process_frame
			var card_screen: Node = screen.get_node("CardScreen")
			card_screen.get_node("Card/VBox/SituationLabel").text = "Feud launched. Reach exploded. Morale collapsed. The algorithm is delighted."
			card_screen.get_node("Card/VBox/Options/OptionALabel").visible = false
			card_screen.get_node("Card/VBox/Options/OptionBLabel").visible = false
			ResourceManager.restore_state({"Reach": 680000.0, "Cringe": 100.0, "Haters": 75000.0, "Morale": 9.0, "Sponsors": 340.0})
		"drama":
			ActionSystem.start_action(&"zrob_drame")
			await get_tree().create_timer(2.2).timeout
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(title)
	_current.queue_free()
	await get_tree().process_frame


func _capture_offline(title: String) -> void:
	_reset_runtime()
	OfflineProgressSystem.last_simulation_result = {
		"total_Z_gained": 159480.0,
		"h0": 420.0,
		"final_H": 18420.0,
		"m0": 88.0,
		"final_M": 42.0,
		"elapsed_seconds": 86400,
		"capped": true,
	}
	_current = OFFLINE_SCENE.instantiate()
	add_child(_current)
	await get_tree().process_frame


func _capture_minigames() -> void:
	await _capture_spotlight_set(
		&"feed_sprint_challenge",
		"Mini Game - Feed Sprint Card",
		"Mini Game - Feed Sprint - Catch the Trend",
		"Mini Game - Feed Sprint - Dodge the Strike"
	)
	await _capture_spotlight_set(
		&"comment_moderation_challenge",
		"Mini Game - Comment Moderation Card",
		"Mini Game - Comment Moderation - Keep or Delete",
		"Mini Game - Comment Moderation - Correct Call"
	)


func _capture_spotlight_set(card_id: StringName, card_title: String, play_title: String, feedback_title: String) -> void:
	_reset_runtime()
	_seed_progress(false)
	_current = MAIN_SCENE.instantiate()
	add_child(_current)
	await get_tree().process_frame
	await get_tree().process_frame
	var screen: Node = _current.get_node("ActionScreen")
	var card_screen: Node = screen.get_node("CardScreen")
	DecisionCardSystem.present_next_card([CardContentDatabase.get_card(card_id).duplicate(true)])
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(card_title)
	card_screen.call("_begin_spotlight", 0)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(play_title)
	if card_id == &"feed_sprint_challenge":
		var game: Node = card_screen.get_node("FeedSprint")
		for index: int in range(game._events.size()):
			if String(game._events[index].get("kind", "")) == "strike":
				game._event_timer.stop()
				game._event_index = index
				game.call("_show_event")
				game._event_timer.stop()
				break
	else:
		var moderation: Node = card_screen.get_node("CommentModeration")
		var correct_action: String = String(moderation._events[moderation._event_index].get("correct_action", "keep"))
		moderation.call("classify", correct_action)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_save(feedback_title)
	_current.queue_free()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _save(title: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	# macOS can constrain a 1080x1920 window to the physical display height.
	# Preserve the authentic render pixel-for-pixel and letterbox it onto an
	# exact store-ready 1080x1920 (9:16) canvas instead of stretching the UI.
	if image.get_width() != 1080 or image.get_height() != 1920:
		image.convert(Image.FORMAT_RGBA8)
		var canvas := Image.create(1080, 1920, false, Image.FORMAT_RGBA8)
		canvas.fill(Color("15151a"))
		var x := maxi((1080 - image.get_width()) / 2, 0)
		var y := maxi((1920 - image.get_height()) / 2, 0)
		canvas.blit_rect(image, Rect2i(0, 0, mini(image.get_width(), 1080), mini(image.get_height(), 1920)), Vector2i(x, y))
		image = canvas
	var path := "%s/%s.png" % [OUTPUT_DIR, title]
	var error := image.save_png(ProjectSettings.globalize_path(path))
	if error != OK:
		push_error("Failed to save %s: %s" % [path, error_string(error)])
	else:
		print("CAPTURED: %s" % path)
