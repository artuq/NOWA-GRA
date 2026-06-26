## CardContentDatabase owns the static MVP decision card content: 12 cards
## (8 risky/safe + 4 neutral), each with exactly 2 options and their resource
## deltas, counter increments, and optional milestone flags.
##
## Implements ADR-0001: a read-only Autoload — this module owns no mutation
## logic and emits no signals. Decision Card System (downstream, not yet
## built) reads this data via get_card()/get_all_cards() to evaluate each
## card's trigger_condition, select/weight cards for display, and apply
## their effects to ResourceManager/HistoryFlagManager — none of that
## happens here.
##
## Registered as a Godot Autoload singleton per the Control Manifest's boot
## order — between HistoryFlagManager and SaveSystem.
##
## Resource keys use the codebase's English StringName convention (&"Reach",
## &"Cringe", &"Morale", &"Sponsors"), NOT the GDD's Polish labels (Zasięgi,
## Sponsorzy) — translated per Story 001's Implementation Notes. Counter
## names (&"risky_choices_count", &"safe_choices_count") match
## HistoryFlagManager's existing convention exactly, no translation needed.
##
## Usage example:
##   var card: Dictionary = CardContentDatabase.get_card("exposed_friend")
##   var all_cards: Array[Dictionary] = CardContentDatabase.get_all_cards()
extends Node

## The 12 MVP cards (8 risky/safe + 4 neutral), per
## design/gdd/card-content-database.md's MVP content table. `text` and
## `text` and option `label` fields hold authored English satirical copy
## (2026-06-26). Still missing: a per-card `category` field for the modal's
## category icon (CardScreen falls back to a generic placeholder icon) — see
## docs/tech-debt-register.md.
const CARDS: Array[Dictionary] = [
	{
		"id": "exposed_friend",
		"trigger_condition": "always",
		"text": "Your bestie trauma-dumped on a call. That's content gold... and a betrayal.",
		"options": [
			{"label": "Post the screenshots", "resource_deltas": {&"Reach": 180.0, &"Cringe": 28.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Keep it private", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 6.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "sponsor_offer_shady",
		"trigger_condition": "always",
		"text": "A 'wellness' brand pays you to push gummies that 'cure anxiety.' Lab results: missing.",
		"options": [
			{"label": "Take the bag", "resource_deltas": {&"Reach": 160.0, &"Cringe": 22.0, &"Morale": -8.0, &"Sponsors": 3.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Politely decline", "resource_deltas": {&"Reach": 90.0, &"Cringe": -5.0, &"Morale": 5.0, &"Sponsors": 0.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "hater_callout",
		"trigger_condition": "always",
		"text": "A hater dropped a 12-tweet thread calling you a fraud. It's gaining traction.",
		"options": [
			{"label": "Clap back hard", "resource_deltas": {&"Reach": 140.0, &"Cringe": 25.0, &"Morale": -15.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Rise above it", "resource_deltas": {&"Reach": 85.0, &"Cringe": -6.0, &"Morale": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "staged_drama",
		"trigger_condition": "always",
		"text": "Your manager pitches a fake feud with another creator. Drama = views.",
		"options": [
			{"label": "Stage the beef", "resource_deltas": {&"Reach": 220.0, &"Cringe": 35.0, &"Morale": -18.0}, "counter_increments": {&"risky_choices_count": 1}, "milestone_to_set": &"card.staged_drama.chosen_risky"},
			{"label": "Refuse the script", "resource_deltas": {&"Reach": 120.0, &"Cringe": -15.0, &"Morale": 12.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "competitor_drama",
		"trigger_condition": "always",
		"text": "A rival creator is getting dragged. Easy engagement if you pile on.",
		"options": [
			{"label": "Throw a punch", "resource_deltas": {&"Reach": 170.0, &"Cringe": 24.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Stay out of it", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 5.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "leaked_dm",
		"trigger_condition": "always",
		"text": "Someone leaks spicy DMs about a celeb to you. Posting them would break the internet.",
		"options": [
			{"label": "Leak everything", "resource_deltas": {&"Reach": 190.0, &"Cringe": 32.0, &"Morale": -14.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Delete and forget", "resource_deltas": {&"Reach": 105.0, &"Cringe": -12.0, &"Morale": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "cancel_threat",
		"trigger_condition": "always",
		"text": "An old problematic clip resurfaced. #YouAreCancelled is trending.",
		"options": [
			{"label": "Double down", "resource_deltas": {&"Reach": 200.0, &"Cringe": 30.0, &"Morale": -12.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Issue an apology", "resource_deltas": {&"Reach": 110.0, &"Cringe": -10.0, &"Morale": 8.0}, "counter_increments": {&"safe_choices_count": 1}, "milestone_to_set": &"card.cancel_threat.apologized"},
		],
	},
	{
		"id": "apology_tour",
		"trigger_condition": "always",
		"text": "Time for the apology video. Ring light on. Question is how... real... to make it.",
		"options": [
			{"label": "Cry on camera", "resource_deltas": {&"Reach": 150.0, &"Cringe": 20.0, &"Morale": -8.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Actually mean it", "resource_deltas": {&"Reach": 95.0, &"Cringe": -5.0, &"Morale": 18.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "fan_in_trouble",
		"trigger_condition": "always",
		"text": "A young fan DMs you in a real crisis, asking for help.",
		"options": [
			{"label": "Make it 'awareness' content", "resource_deltas": {&"Reach": 60.0, &"Sponsors": -1.0}, "counter_increments": {}},
			{"label": "Help quietly", "resource_deltas": {&"Reach": 40.0, &"Sponsors": -1.0, &"Morale": 4.0}, "counter_increments": {}},
		],
	},
	{
		"id": "brand_deal_choice",
		"trigger_condition": "always",
		"text": "Two deals: a cringe fast-fashion mega-corp, or a small ethical label that pays less.",
		"options": [
			{"label": "Sell out big", "resource_deltas": {&"Reach": -40.0, &"Sponsors": 3.0}, "counter_increments": {}},
			{"label": "Back the indie", "resource_deltas": {&"Reach": 40.0, &"Sponsors": 1.0}, "counter_increments": {}},
		],
	},
	{
		"id": "algorithm_hack",
		"trigger_condition": "always",
		"text": "A growth guru sells an 'algorithm exploit' that floods feeds with your clips.",
		"options": [
			{"label": "Buy the exploit", "resource_deltas": {&"Reach": 220.0}, "counter_increments": {}},
			{"label": "Grow it honestly", "resource_deltas": {&"Reach": 60.0}, "counter_increments": {}, "milestone_to_set": &"card.algorithm_hack.saved"},
		],
	},
	{
		"id": "burnout_warning",
		"trigger_condition": "always",
		"text": "40 hours, no sleep. The grind's working, but your hands are shaking.",
		"options": [
			{"label": "Push through", "resource_deltas": {&"Reach": 130.0}, "counter_increments": {}},
			{"label": "Take a day off", "resource_deltas": {&"Morale": 10.0}, "counter_increments": {}},
		],
	},
]


## Returns the card matching [param card_id], or an empty `Dictionary` if no
## card has that id.
##
## Example:
##   var card: Dictionary = CardContentDatabase.get_card("exposed_friend")
func get_card(card_id: String) -> Dictionary:
	for card: Dictionary in CARDS:
		if card["id"] == card_id:
			return card
	return {}


## Returns all 12 MVP cards.
##
## Example:
##   var all_cards: Array[Dictionary] = CardContentDatabase.get_all_cards()
func get_all_cards() -> Array[Dictionary]:
	return CARDS
