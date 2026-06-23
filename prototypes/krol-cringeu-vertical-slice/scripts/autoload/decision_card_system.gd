# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the core fantasy within 3-5 min, unguided?
# Date: 2026-06-20
#
# Implements ADR-0005: cooldown is an int counter on completed actions (not a Timer),
# weighted-random pick scaled by current Cringe.
extends Node

const BASE_WEIGHT := 10.0
const DECISION_CARD_COOLDOWN := 2

var _actions_until_next_card: int = DECISION_CARD_COOLDOWN
var current_card = null  # CardContentDatabase.CardData, null when none presented
var _rng := RandomNumberGenerator.new()

signal card_presented(card)
signal card_resolved(card_id: StringName, option: StringName, reaction: String, magnitude: float, effects: Dictionary)

func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed)
	# Godot auto-seeds its GLOBAL RNG (randi()/randf()) from real OS entropy at
	# engine startup — manually mixing low-entropy sources (ticks/unix-time/PID)
	# at this early _ready() point produced near-identical values across rapid
	# editor restarts and didn't fix the collision. Seeding our local _rng from
	# the engine's own pre-seeded global RNG borrows that real entropy directly.
	_rng.seed = randi()

func set_seed(s: int) -> void:
	_rng.seed = s

func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	if OnboardingGate.is_card_suppressed():
		return
	if _actions_until_next_card > 0:
		_actions_until_next_card -= 1
		return
	present_next_card()

func present_next_card() -> void:
	if current_card != null:
		return
	current_card = _weighted_pick(CardContentDatabase.get_all_cards())
	_actions_until_next_card = DECISION_CARD_COOLDOWN
	card_presented.emit(current_card)

func force_cooldown_zero() -> void:
	_actions_until_next_card = 0

func _weighted_pick(cards: Array):
	var current_cringe: float = ResourceManager.get_resource(&"Cringe")
	var weights: Array[float] = []
	var total: float = 0.0
	for card in cards:
		var w: float = BASE_WEIGHT + (current_cringe / 100.0) * card.intensity
		weights.append(w)
		total += w
	var roll := _rng.randf() * total
	var cumulative := 0.0
	for i in cards.size():
		cumulative += weights[i]
		if roll <= cumulative:
			return cards[i]
	return cards[-1]

func resolve_choice(option: StringName) -> void:
	# current_card stays set until dismiss_card() — Card UI shows the resolution
	# payoff first (juice-feedback-system.md), then explicitly dismisses.
	var effects: Dictionary = current_card.get_effects(option)
	var reaction: String = current_card.get_reaction(option)
	var mag: float = FeedbackSystem.magnitude(effects)
	ResourceManager.apply_delta(effects)
	card_resolved.emit(current_card.id, option, reaction, mag, effects)

func dismiss_card() -> void:
	current_card = null
