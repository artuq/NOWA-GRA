extends GdUnitTestSuite

const CommentModerationScript: GDScript = preload("res://src/ui/comment_moderation.gd")


func _alternating_events() -> Array:
	var events: Array = []
	for index: int in range(10):
		events.append({
			"text": "comment_%d" % index,
			"correct_action": "keep" if index % 2 == 0 else "remove",
		})
	return events


func _grouped_events() -> Array:
	var events: Array = _alternating_events()
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["correct_action"]) < String(b["correct_action"])
	)
	return events


func _actions(events: Array) -> Array[String]:
	var actions: Array[String] = []
	for event: Dictionary in events:
		actions.append(String(event["correct_action"]))
	return actions


func _texts(events: Array) -> Array[String]:
	var texts: Array[String] = []
	for event: Dictionary in events:
		texts.append(String(event["text"]))
	return texts


func _transition_count(actions: Array[String]) -> int:
	var transitions: int = 0
	for index: int in range(1, actions.size()):
		if actions[index] != actions[index - 1]:
			transitions += 1
	return transitions


func _identity_pick(upper_inclusive: int) -> int:
	return upper_inclusive


func _zero_pick(_upper_inclusive: int) -> int:
	return 0


func test_shuffle_preserves_all_events_and_five_five_balance() -> void:
	var source: Array = _alternating_events()
	var shuffled: Array = CommentModerationScript.build_session_events(
		source, _identity_pick
	)
	var actions: Array[String] = _actions(shuffled)

	assert_array(_texts(shuffled)).contains_exactly_in_any_order(_texts(source))
	assert_int(actions.count("keep")).is_equal(5)
	assert_int(actions.count("remove")).is_equal(5)


func test_shuffle_breaks_strict_alternation_when_picker_keeps_original_order() -> void:
	var shuffled: Array = CommentModerationScript.build_session_events(
		_alternating_events(), _identity_pick
	)
	var transitions: int = _transition_count(_actions(shuffled))

	assert_int(transitions).is_less(9)
	assert_int(transitions).is_greater(1)


func test_shuffle_breaks_single_keep_remove_block_pattern() -> void:
	var shuffled: Array = CommentModerationScript.build_session_events(
		_grouped_events(), _identity_pick
	)
	var transitions: int = _transition_count(_actions(shuffled))

	assert_int(transitions).is_less(9)
	assert_int(transitions).is_greater(1)


func test_different_picker_streams_can_create_different_balanced_orders() -> void:
	var source: Array = _alternating_events()
	var first: Array = CommentModerationScript.build_session_events(source, _identity_pick)
	var second: Array = CommentModerationScript.build_session_events(source, _zero_pick)

	assert_array(_texts(first)).is_not_equal(_texts(second))
	assert_int(_actions(first).count("keep")).is_equal(5)
	assert_int(_actions(second).count("keep")).is_equal(5)
