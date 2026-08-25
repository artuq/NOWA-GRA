extends GdUnitTestSuite

const SpotlightMinigameConfigScript: GDScript = preload(
	"res://src/core/spotlight_minigame_config.gd"
)


func _feed_config(lane_count: int) -> Dictionary:
	return {
		"lane_count": lane_count,
		"events": [{"kind": "trend", "lane": 0}],
	}


func test_feed_sprint_validator_accepts_its_three_lane_view_contract() -> void:
	var config: Dictionary = _feed_config(3)
	var result: Dictionary = SpotlightMinigameConfigScript._validate_feed_sprint(
		config, config["events"]
	)

	assert_bool(result.is_empty()).is_false()
	assert_int(result["lane_count"]).is_equal(3)


func test_feed_sprint_validator_rejects_lane_counts_the_view_cannot_render() -> void:
	for lane_count: int in [2, 4, 5]:
		var config: Dictionary = _feed_config(lane_count)
		var result: Dictionary = SpotlightMinigameConfigScript._validate_feed_sprint(
			config, config["events"]
		)

		assert_dict(result).is_empty()
