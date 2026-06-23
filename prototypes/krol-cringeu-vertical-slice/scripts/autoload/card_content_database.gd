# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: Does a player experience the core fantasy within 3-5 min, unguided?
# Date: 2026-06-20
#
# REAL satirical copy for 3 cards, per Creative Director's gate-check condition:
# placeholder text would make the slice creatively meaningless. These are not final
# (full Card Content Database has 12 cards, 8 risky/safe + 4 neutral) — this is a
# representative sample for the slice's single validation question.
extends Node

class CardData:
	var id: StringName
	var category: String
	var text: String
	var option_a_label: String
	var option_b_label: String
	var option_a_effects: Dictionary
	var option_b_effects: Dictionary
	var option_a_reaction: String
	var option_b_reaction: String
	var intensity: float

	func _init(p_id: StringName, p_category: String, p_text: String,
			p_a_label: String, p_a_effects: Dictionary, p_a_reaction: String,
			p_b_label: String, p_b_effects: Dictionary, p_b_reaction: String,
			p_intensity: float) -> void:
		id = p_id
		category = p_category
		text = p_text
		option_a_label = p_a_label
		option_a_effects = p_a_effects
		option_a_reaction = p_a_reaction
		option_b_label = p_b_label
		option_b_effects = p_b_effects
		option_b_reaction = p_b_reaction
		intensity = p_intensity

	func get_effects(option: StringName) -> Dictionary:
		return option_a_effects if option == &"option_a" else option_b_effects

	func get_reaction(option: StringName) -> String:
		return option_a_reaction if option == &"option_a" else option_b_reaction

var _cards: Array[CardData] = []

func _ready() -> void:
	_cards = [
		CardData.new(
			&"sponsor_offer_shady",
			"sponsor",
			"'ExtraFit Detox Tea' is offering you $1,200 for one post. Their product almost certainly doesn't do what they claim. Your viewers trust your recommendations.",
			"Take the money, post it",
			{&"Sponsors": 3.0, &"Reach": 8.0, &"Cringe": 22.0, &"Morale": -2.0},
			"Sponsorship logged. 3 viewers asked if the product works. 0 received an answer.",
			"Decline, keep your credibility",
			{&"Reach": 2.0, &"Morale": 4.0},
			"Offer declined. The algorithm notes this and moves on without comment.",
			1.6
		),
		CardData.new(
			&"hater_callout",
			"drama",
			"A well-known hater just posted a 20-minute video 'taking you apart.' Your fans are waiting for a response. You could fire back just as hard, or ignore it.",
			"Fire back even harder",
			{&"Reach": 15.0, &"Cringe": 18.0, &"Haters": 4.0, &"Morale": -5.0},
			"Response posted. Engagement up. So is the thread length.",
			"Ignore it, don't get pulled in",
			{&"Reach": 1.0, &"Morale": 3.0},
			"No response posted. The video is still trending without you in it.",
			1.4
		),
		CardData.new(
			&"fan_in_trouble",
			"neutral",
			"One of your most loyal fans messages you that they're going through a hard time and your videos are the one thing keeping them going. They ask if you could record something personal for them.",
			"Record a personal video for them",
			{&"Morale": 6.0, &"Reach": 1.0},
			"Clip posted. 40,000 people watched a private moment become public.",
			"Send a standard, friendly reply",
			{&"Morale": 1.0},
			"Message sent. No one else will ever know this happened.",
			0.0
		),
	]

func get_card(id: StringName) -> CardData:
	for card in _cards:
		if card.id == id:
			return card
	return null

func get_all_cards() -> Array[CardData]:
	return _cards
