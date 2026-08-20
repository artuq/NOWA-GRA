## Loads and validates data-driven tuning for optional Spotlight card mini-games.
## Callers receive a duplicate so presentation cannot mutate the shared source.
class_name SpotlightMinigameConfig
extends RefCounted

const DATA_PATH: String = "res://assets/data/spotlight_minigames.json"


## Returns the validated configuration for [param minigame_id], or an empty
## Dictionary when the file/id/schema is invalid. Failure is loud but safe: a
## card can then resolve at its guaranteed base value instead of blocking play.
static func load_config(minigame_id: StringName) -> Dictionary:
	var file: FileAccess = FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("SpotlightMinigameConfig: cannot open %s" % DATA_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("SpotlightMinigameConfig: root must be a Dictionary")
		return {}
	var raw: Variant = parsed.get(String(minigame_id), {})
	if not raw is Dictionary:
		return {}
	var config: Dictionary = raw
	var event_count: int = int(config.get("event_count", 0))
	var duration: float = float(config.get("event_duration_seconds", 0.0))
	var reward_resource: String = String(config.get("reward_resource", ""))
	var reward_min: float = float(config.get("reward_min", -1.0))
	var reward_max: float = float(config.get("reward_max", -1.0))
	var reward_exponent: float = float(config.get("reward_curve_exponent", 0.0))
	var events: Variant = config.get("events", [])
	if event_count <= 0 or event_count > 60:
		return {}
	if not is_finite(duration) or duration < 0.25 or duration > 5.0:
		return {}
	if reward_resource.is_empty() or not is_finite(reward_min) or not is_finite(reward_max):
		return {}
	if reward_min < 0.0 or reward_max < reward_min:
		return {}
	if not is_finite(reward_exponent) or reward_exponent < 0.25 or reward_exponent > 4.0:
		return {}
	if not events is Array or events.size() != event_count:
		return {}
	if minigame_id == &"feed_sprint":
		return _validate_feed_sprint(config, events)
	if minigame_id == &"comment_moderation":
		return _validate_comment_moderation(config, events)
	if minigame_id == &"brief_puzzle":
		return _validate_brief_puzzle(config, events)
	return {}


static func _validate_feed_sprint(config: Dictionary, events: Array) -> Dictionary:
	var lane_count: int = int(config.get("lane_count", 0))
	# FeedSprint's scene and presentation contract intentionally expose exactly
	# three equal lanes. Reject data that the fixed view cannot represent.
	if lane_count != 3:
		return {}
	for event: Variant in events:
		if not event is Dictionary:
			return {}
		var kind: String = String(event.get("kind", ""))
		var lane: int = int(event.get("lane", -1))
		if kind != "trend" and kind != "strike":
			return {}
		if lane < 0 or lane >= lane_count:
			return {}
	return config.duplicate(true)


static func _validate_comment_moderation(config: Dictionary, events: Array) -> Dictionary:
	var feedback_pause: float = float(config.get("feedback_pause_seconds", 0.0))
	if not is_finite(feedback_pause) or feedback_pause < 0.0 or feedback_pause > 1.5:
		return {}
	if String(config.get("event_order", "")) != "shuffle_nontrivial":
		return {}
	for event: Variant in events:
		if not event is Dictionary:
			return {}
		var text: String = String(event.get("text", ""))
		var text_key: String = String(event.get("text_key", ""))
		var correct_action: String = String(event.get("correct_action", ""))
		if text.is_empty() or text.length() > 180:
			return {}
		if text_key.is_empty():
			return {}
		if correct_action != "keep" and correct_action != "remove":
			return {}
	return config.duplicate(true)


static func _validate_brief_puzzle(config: Dictionary, events: Array) -> Dictionary:
	if events.size() < 3 or events.size() > 6:
		return {}
	var solution: Variant = config.get("solution", [])
	if not solution is Array or solution.size() != events.size():
		return {}
	var ids: Array[String] = []
	for event: Variant in events:
		if not event is Dictionary:
			return {}
		var clause_id: String = String(event.get("id", ""))
		if clause_id.is_empty() or ids.has(clause_id) or String(event.get("text_key", "")).is_empty():
			return {}
		ids.append(clause_id)
	for solution_id: Variant in solution:
		if String(solution_id) not in ids:
			return {}
	var max_attempts: int = int(config.get("max_attempts", 0))
	if max_attempts < 1 or max_attempts > 5:
		return {}
	return config.duplicate(true)
