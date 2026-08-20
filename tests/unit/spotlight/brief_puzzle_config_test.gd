extends GdUnitTestSuite

const ConfigScript: GDScript = preload("res://src/core/spotlight_minigame_config.gd")


func test_brief_puzzle_config_is_valid_and_rewards_sponsors() -> void:
	var config: Dictionary = ConfigScript.load_config(&"brief_puzzle")
	assert_bool(config.is_empty()).is_false()
	assert_str(config["reward_resource"]).is_equal("Sponsors")
	assert_int(config["solution"].size()).is_equal(4)
	assert_int(int(config["max_attempts"])).is_equal(3)


func test_brief_puzzle_rejects_solution_with_unknown_clause() -> void:
	var config: Dictionary = ConfigScript.load_config(&"brief_puzzle")
	config["solution"] = ["legal", "proof", "claim", "missing"]
	assert_bool(ConfigScript._validate_brief_puzzle(config, config["events"]).is_empty()).is_true()
