# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the core fantasy within 3-5 min, unguided?
# Date: 2026-06-20
#
# Implements onboarding-tutorial.md: variety-gate (set, not count) on action types,
# suppresses Decision Card System until all 3 action types tried at least once.
extends Node

enum Phase { PURE_ACTION, FIRST_CARD_PENDING, NORMAL }

var phase: Phase = Phase.PURE_ACTION
var _tried_types: Dictionary = {}  # StringName -> true

func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed)

func is_card_suppressed() -> bool:
	return phase == Phase.PURE_ACTION

func _on_action_completed(action_id: StringName, _rewards: Dictionary) -> void:
	if phase == Phase.PURE_ACTION:
		_tried_types[action_id] = true
		if _tried_types.size() >= 3:
			phase = Phase.FIRST_CARD_PENDING
			DecisionCardSystem.force_cooldown_zero()
	elif phase == Phase.FIRST_CARD_PENDING:
		phase = Phase.NORMAL
