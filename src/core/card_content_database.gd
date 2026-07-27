## CardContentDatabase owns the static decision card content: the 12 MVP
## cards (8 risky/safe + 4 neutral) plus 4 Tier-5 signature cards (Story
## class-path-full/004, ADR-0010 §10) — one per Class Path, each gated by a
## "class_path_tier:{path_id}:5" trigger_condition instead of "always" — plus
## 4 more risky/safe cards added by Sprint 12 story 12-6 (2× ekspert_niszowy,
## 2× biznesmen_contentu — the two paths that had zero reachable path_tag
## cards before Tier 5). 17 total cards. Every card has exactly 2 options and
## their resource deltas, counter increments, and optional milestone flags.
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
## design/gdd/card-content-database.md's MVP content table, plus 4 Tier-5
## signature cards appended at the end (Story class-path-full/004 — see that
## block below for details). `text` and option `label` fields on the 12 MVP
## cards hold authored English satirical copy (2026-06-26); the 4 signature
## cards are explicitly placeholder copy (narrative-director scope, not this
## story's). Still missing: a per-card `category` field for the modal's
## category icon (CardScreen falls back to a generic placeholder icon) — see
## docs/tech-debt-register.md.
const CARDS: Array[Dictionary] = [
	{
		"id": "exposed_friend",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "Your bestie trauma-dumped on a call. That's content gold... and a betrayal.",
		"options": [
			{"label": "Post the screenshots", "resolution_reaction": "Screenshots posted. 12,000 shares. Your friend hasn't replied to your texts.", "resource_deltas": {&"Reach": 180.0, &"Cringe": 28.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Keep it private", "resolution_reaction": "Nothing posted. The call stays between two people.", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 6.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "sponsor_offer_shady",
		"path_tag": "guru_celebryta",
		"trigger_condition": "always",
		"text": "A 'wellness' brand pays you to push gummies that 'cure anxiety.' Lab results: missing.",
		"options": [
			{"label": "Take the bag", "resolution_reaction": "Sponsorship logged. 3 viewers asked if the product works. 0 received an answer.", "resource_deltas": {&"Reach": 160.0, &"Cringe": 22.0, &"Morale": -8.0, &"Sponsors": 3.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Politely decline", "resolution_reaction": "Offer declined. The algorithm notes this and moves on without comment.", "resource_deltas": {&"Reach": 90.0, &"Cringe": -5.0, &"Morale": 5.0, &"Sponsors": 0.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "hater_callout",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "A hater dropped a 12-tweet thread calling you a fraud. It's gaining traction.",
		"options": [
			{"label": "Clap back hard", "resolution_reaction": "Response posted. Engagement up. So is the thread length.", "resource_deltas": {&"Reach": 140.0, &"Cringe": 25.0, &"Morale": -15.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Rise above it", "resolution_reaction": "No response posted. The video is still trending without you in it.", "resource_deltas": {&"Reach": 85.0, &"Cringe": -6.0, &"Morale": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "staged_drama",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "Your manager pitches a fake feud with another creator. Drama = views.",
		"options": [
			{"label": "Stage the beef", "resolution_reaction": "Feud launched. Both fanbases are at war. Neither side knows it's scripted.", "resource_deltas": {&"Reach": 220.0, &"Cringe": 35.0, &"Morale": -18.0}, "counter_increments": {&"risky_choices_count": 1}, "milestone_to_set": &"card.staged_drama.chosen_risky"},
			{"label": "Refuse the script", "resolution_reaction": "No feud. The pitch deck goes back in the drawer.", "resource_deltas": {&"Reach": 120.0, &"Cringe": -15.0, &"Morale": 12.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "competitor_drama",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "A rival creator is getting dragged. Easy engagement if you pile on.",
		"options": [
			{"label": "Throw a punch", "resolution_reaction": "Quote-tweet posted. You're now part of the story you were watching.", "resource_deltas": {&"Reach": 170.0, &"Cringe": 24.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Stay out of it", "resolution_reaction": "You said nothing. The pile-on continued without you.", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 5.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "leaked_dm",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "Someone leaks spicy DMs about a celeb to you. Posting them would break the internet.",
		"options": [
			{"label": "Leak everything", "resolution_reaction": "DMs posted. 80,000 people read messages that weren't theirs to read.", "resource_deltas": {&"Reach": 190.0, &"Cringe": 32.0, &"Morale": -14.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Delete and forget", "resolution_reaction": "DMs deleted. The screenshots no longer exist on your phone.", "resource_deltas": {&"Reach": 105.0, &"Cringe": -12.0, &"Morale": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "cancel_threat",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "An old problematic clip resurfaced. #YouAreCancelled is trending.",
		"options": [
			{"label": "Double down", "resolution_reaction": "Statement posted. The hashtag is still trending. So are you.", "resource_deltas": {&"Reach": 200.0, &"Cringe": 30.0, &"Morale": -12.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Issue an apology", "resolution_reaction": "Apology posted. The comments are split. The clip keeps circulating.", "resource_deltas": {&"Reach": 110.0, &"Cringe": -10.0, &"Morale": 8.0}, "counter_increments": {&"safe_choices_count": 1}, "milestone_to_set": &"card.cancel_threat.apologized"},
		],
	},
	{
		"id": "apology_tour",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "Time for the apology video. Ring light on. Question is how... real... to make it.",
		"options": [
			{"label": "Cry on camera", "resolution_reaction": "Apology video up. 2.1M views. The top comment counts your tears.", "resource_deltas": {&"Reach": 150.0, &"Cringe": 20.0, &"Morale": -8.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Actually mean it", "resolution_reaction": "Apology posted without edits. Fewer views. Fewer follow-ups.", "resource_deltas": {&"Reach": 95.0, &"Cringe": -5.0, &"Morale": 18.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "fan_in_trouble",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "A young fan DMs you in a real crisis, asking for help.",
		"options": [
			{"label": "Make it 'awareness' content", "resolution_reaction": "Clip posted. 40,000 people watched a private moment become public.", "resource_deltas": {&"Reach": 60.0, &"Sponsors": -1.0}, "counter_increments": {}},
			{"label": "Help quietly", "resolution_reaction": "Message sent. No one else will ever know this happened.", "resource_deltas": {&"Reach": 40.0, &"Sponsors": -1.0, &"Morale": 4.0}, "counter_increments": {}},
		],
	},
	{
		"id": "brand_deal_choice",
		"path_tag": "guru_celebryta",
		"trigger_condition": "always",
		"text": "Two deals: a cringe fast-fashion mega-corp, or a small ethical label that pays less.",
		"options": [
			{"label": "Sell out big", "resolution_reaction": "Contract signed. The fast-fashion logo is now in your bio.", "resource_deltas": {&"Reach": -40.0, &"Sponsors": 3.0}, "counter_increments": {}},
			{"label": "Back the indie", "resolution_reaction": "Smaller deal signed. The indie label reshared your post.", "resource_deltas": {&"Reach": 40.0, &"Sponsors": 1.0}, "counter_increments": {}},
		],
	},
	{
		"id": "algorithm_hack",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "A growth guru sells an 'algorithm exploit' that floods feeds with your clips.",
		"options": [
			{"label": "Buy the exploit", "resolution_reaction": "Exploit purchased. Your clips are everywhere. You don't know who's watching.", "resource_deltas": {&"Reach": 220.0}, "counter_increments": {}},
			{"label": "Grow it honestly", "resolution_reaction": "No exploit. Growth is slower. The numbers are yours.", "resource_deltas": {&"Reach": 60.0}, "counter_increments": {}, "milestone_to_set": &"card.algorithm_hack.saved"},
		],
	},
	{
		"id": "burnout_warning",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "40 hours, no sleep. The grind's working, but your hands are shaking.",
		"options": [
			{"label": "Push through", "resolution_reaction": "One more upload shipped. The reach came. So did the headache.", "resource_deltas": {&"Reach": 130.0}, "counter_increments": {}},
			{"label": "Take a day off", "resolution_reaction": "Phone off for a day. Nothing was posted. Nothing was missed.", "resource_deltas": {&"Morale": 10.0}, "counter_increments": {}},
		],
	},

	# --- Card wave 2 (Sprint 12, story 12-6): 2 risky/safe pairs each for
	# ekspert_niszowy and biznesmen_contentu -- the two paths with zero
	# reachable path_tag cards before Tier 5 (their only existing tagged
	# card, kult_niszowy/ipo_influencera above, is trigger-gated behind
	# "class_path_tier:{path}:5" and can't be the card that GETS a player
	# to Tier 5 in the first place). Same schema/tone as the 8 existing
	# MVP risky/safe pairs; risky_safe_zasiegi_ratio kept in the locked
	# 1.4x-1.8x band (registry). No Sponsors resource_deltas -- the
	# registry's sponsorzy_qualifying_cards constant locks that key to
	# sponsor_offer_shady/brand_deal_choice only; extending it was
	# considered and deliberately not done here (a balance decision
	# outside this story's scope, not an oversight).
	{
		"id": "thousand_true_fans",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "always",
		"text": "A 50M-follower giveaway account wants a paid shoutout. Your actual community is 340 people who reply to everything you post.",
		"options": [
			{"label": "Take the giveaway deal", "resolution_reaction": "Shoutout posted. Reach spiked. Three regulars asked if you're okay.", "resource_deltas": {&"Reach": 130.0, &"Cringe": 15.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Stay with your 340", "resolution_reaction": "No shoutout. Someone in the replies said this is why they still watch.", "resource_deltas": {&"Reach": 75.0, &"Cringe": -6.0, &"Morale": 8.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "deep_dive_or_trend",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "always",
		"text": "This week's trend is a 15-second dance. Your last upload -- 47 minutes on one specific bolt pattern -- still gets comments daily.",
		"options": [
			{"label": "Chase the trend", "resolution_reaction": "Dance posted. It performed fine. It also wasn't you.", "resource_deltas": {&"Reach": 140.0, &"Cringe": 18.0, &"Morale": -9.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Make another deep-dive", "resolution_reaction": "47 more minutes on bolts. The comment about the last one is still going.", "resource_deltas": {&"Reach": 80.0, &"Cringe": -7.0, &"Morale": 9.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "engagement_farming",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "always",
		"text": "The dashboard flags a format that reliably outperforms everything else you make: rage-bait comment-section debates. You've never cared about the topic.",
		"options": [
			{"label": "Run the numbers", "resolution_reaction": "Debate video posted. Comments: 4,200. Position held: none, specifically.", "resource_deltas": {&"Reach": 190.0, &"Cringe": 28.0, &"Morale": -3.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Pass on the format", "resolution_reaction": "Format skipped. The dashboard logs the missed opportunity and says nothing else.", "resource_deltas": {&"Reach": 108.0, &"Cringe": -10.0, &"Morale": 3.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "quarterly_content_review",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "always",
		"text": "Your creative process this quarter is a spreadsheet: post times, retention curves, thumbnail A/B tests. It's working. You haven't watched your own video in three weeks.",
		"options": [
			{"label": "Trust the spreadsheet", "resolution_reaction": "Spreadsheet-optimal video shipped. Retention curve: excellent. Your notes on it: none.", "resource_deltas": {&"Reach": 210.0, &"Cringe": 20.0, &"Morale": -4.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "Override it once", "resolution_reaction": "You picked the thumbnail yourself this time. The curve dipped 2%. You watched the whole video.", "resource_deltas": {&"Reach": 120.0, &"Cringe": -8.0, &"Morale": 4.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},

	# --- Tier-5 signature cards (Story class-path-full/004, ADR-0010 §10,
	# TR-cps-006). One per path, gated by the "class_path_tier:{path_id}:5"
	# trigger_condition grammar entry (decision_card_system.gd) instead of
	# "always" — only enters the eligible pool once that path's tier reaches
	# 5. `text`/`label`/`resolution_reaction` below are PLACEHOLDER copy only
	# (explicitly out of scope for this story — narrative-director task) but
	# the schema shape matches the 12 MVP cards exactly so no card-rendering
	# code path is broken.
	{
		"id": "viral_moment",
		"path_tag": "pato_streamer",
		"trigger_condition": "class_path_tier:pato_streamer:5",
		"text": "[Placeholder] \"Viral Moment\" — Pato-Streamer Tier 5 signature card. Final narrative copy pending.",
		"options": [
			{"label": "[Placeholder] Lean in", "resolution_reaction": "[Placeholder] The moment lands exactly as engineered.", "resource_deltas": {&"Reach": 260.0, &"Cringe": 15.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"label": "[Placeholder] Hold back", "resolution_reaction": "[Placeholder] The moment passes. So does the spike.", "resource_deltas": {&"Reach": 140.0, &"Cringe": -10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "brand_deal_of_the_century",
		"path_tag": "guru_celebryta",
		"trigger_condition": "class_path_tier:guru_celebryta:5",
		"text": "[Placeholder] \"Brand Deal of the Century\" — Guru-Celebryta Tier 5 signature card. Final narrative copy pending.",
		"options": [
			{"label": "[Placeholder] Sign the mega-deal", "resolution_reaction": "[Placeholder] The contract is generational. So are the strings attached.", "resource_deltas": {&"Reach": 70.0, &"Morale": -6.0}, "counter_increments": {}},
			{"label": "[Placeholder] Negotiate smaller", "resolution_reaction": "[Placeholder] A smaller deal, fully on your terms.", "resource_deltas": {&"Reach": 35.0, &"Morale": 4.0}, "counter_increments": {}},
		],
	},
	{
		"id": "kult_niszowy",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "class_path_tier:ekspert_niszowy:5",
		"text": "[Placeholder] \"Kult Niszowy\" — Ekspert Niszowy Tier 5 signature card. Final narrative copy pending.",
		"options": [
			{"label": "[Placeholder] Go deeper niche", "resolution_reaction": "[Placeholder] The core audience is now a cult. A small, devoted one.", "resource_deltas": {&"Reach": 45.0, &"Morale": 8.0}, "counter_increments": {}},
			{"label": "[Placeholder] Broaden the appeal", "resolution_reaction": "[Placeholder] The niche softens. So does the edge.", "resource_deltas": {&"Reach": 90.0, &"Morale": -4.0}, "counter_increments": {}},
		],
	},
	{
		"id": "ipo_influencera",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "class_path_tier:biznesmen_contentu:5",
		"text": "[Placeholder] \"IPO Influencera\" — Biznesmen Contentu Tier 5 signature card. Final narrative copy pending.",
		"options": [
			{"label": "[Placeholder] Take it public", "resolution_reaction": "[Placeholder] Shares issued. The brand is now a balance sheet.", "resource_deltas": {&"Reach": 50.0, &"Cringe": 10.0}, "counter_increments": {}},
			{"label": "[Placeholder] Stay private", "resolution_reaction": "[Placeholder] No shares issued. No shareholders to answer to.", "resource_deltas": {&"Reach": 20.0, &"Morale": 5.0}, "counter_increments": {}},
		],
	},

		# --- Wypalenie ("Final Burnout") -- BurnoutSystem/ADR-0013, TR-pcs-007,
		# Story burnout-challenge-system/002. trigger_condition is "never" (NOT
		# "always"), DELIBERATELY -- this card must be reachable ONLY via
		# CardContentDatabase.get_card(BurnoutSystem.BURNOUT_CARD_ID) through
		# DecisionCardSystem.inject_priority_card() (BurnoutSystem's forced
		# injection), never through the normal weighted-random pool.
		# _build_eligible_pool() iterates get_all_cards() (the FULL CARDS array,
		# no id-based exclusion) when building normal draws -- "always" here
		# would let this card leak into ordinary card presentation independent
		# of the sustained-Cringe trigger. _trigger_condition_met() returns
		# false for any string that isn't "always" or a well-formed
		# "class_path_tier:..." condition, so "never" permanently excludes it
		# from normal selection while inject_priority_card()'s direct id lookup
		# (unaffected by trigger_condition) still finds it.
		#
		# path_tag "" (neutral) -- burnout accept/defer is not a Class Path
		# affiliation choice.
		#
		# resource_deltas/counter_increments are intentionally {} on both
		# options -- Story 003 (out of this story's scope) routes the real
		# Choice A/B consequences through PrestigeSystem.on_burnout_accepted()/
		# on_burnout_deferred(), called from BurnoutSystem._on_card_resolved().
		# Applying non-zero deltas here (DecisionCardSystem.resolve_choice()
		# calls ResourceManager.apply_delta() unconditionally before
		# card_resolved fires) would double-apply on top of those. Minimal
		# placeholder content only -- final copy/presentation is a future
		# content/UI pass (story-002-card-injection-guard-rails.md Out of
		# Scope).
		#
		# Option "label" fields ARE the literal option_chosen value
		# DecisionCardSystem.card_resolved carries (resolve_choice() derives it
		# from option["label"], not a separate id) -- Story 003 must match
		# against these two exact strings. Mirrored in a doc comment on
		# BurnoutSystem.BURNOUT_CARD_ID.
		{
			"id": "final_burnout",
			"path_tag": "",
			"trigger_condition": "never",
			"text": "Six months, zero days off. The hands won't stop shaking on camera anymore, and the audience thinks it's a bit.",
			"options": [
				{"label": "Accept the Burnout", "resolution_reaction": "The account goes dark. The era ends here.", "resource_deltas": {}, "counter_increments": {}},
				{"label": "Defer the Burnout", "resolution_reaction": "One more grind, running on fumes. The audience never finds out how close it came.", "resource_deltas": {}, "counter_increments": {}},
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


## Returns all cards: the 12 MVP cards plus the 4 Tier-5 signature cards
## (Story class-path-full/004).
##
## Example:
##   var all_cards: Array[Dictionary] = CardContentDatabase.get_all_cards()
func get_all_cards() -> Array[Dictionary]:
	return CARDS
