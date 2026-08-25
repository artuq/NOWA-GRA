extends GdUnitTestSuite


func test_brief_puzzle_supports_undo_and_correct_solution() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/brief_puzzle.tscn")
	var puzzle: Control = runner.scene()
	var config: Dictionary = SpotlightMinigameConfig.load_config(&"brief_puzzle")
	assert_bool(puzzle.start(config)).is_true()
	puzzle._select_clause(2)
	puzzle._select_clause(0)
	puzzle.undo()
	assert_int(puzzle._selection.size()).is_equal(1)
	puzzle._select_clause(3)
	puzzle._select_clause(0)
	puzzle._select_clause(1)
	monitor_signals(puzzle)
	puzzle.submit()
	await assert_signal(puzzle).is_emitted("finished", [1.0, false])


func test_brief_puzzle_skip_is_no_penalty_abandonment() -> void:
	var runner: GdUnitSceneRunner = scene_runner("res://scenes/card_screen/brief_puzzle.tscn")
	var puzzle: Control = runner.scene()
	assert_bool(puzzle.start(SpotlightMinigameConfig.load_config(&"brief_puzzle"))).is_true()
	monitor_signals(puzzle)
	puzzle.skip()
	await assert_signal(puzzle).is_emitted("finished", [0.0, true])
