## CardContentDatabase owns the static decision card content: the 12 MVP
## cards (8 risky/safe + 4 neutral) plus 4 Tier-5 signature cards (Story
## class-path-full/004, ADR-0010 §10) — one per Class Path, each gated by a
## "class_path_tier:{path_id}:5" trigger_condition instead of "always" — plus
## 4 more risky/safe cards added by Sprint 12 story 12-6 (2× ekspert_niszowy,
## 2× biznesmen_contentu — the two paths that had zero reachable path_tag
## cards before Tier 5), plus 8 wave-3 cards (2026-07-28: +2 guru, +2 ekspert,
## +2 biznesmen, +2 neutral — pool distribution now pato 6 / guru 4 /
## ekspert 4 / biznesmen 4 / neutral 6), plus the standalone Feed Sprint
## skill-challenge cards, one cultural-humour showcase, and 3 controlled
## Sponsor Career Contract follow-ups. 37 total cards. Every card has
## exactly 2 options and their
## resource deltas, counter increments, and optional milestone flags.
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

const REACTION_PACING_SHORT: StringName = &"short"
const REACTION_PACING_MEDIUM: StringName = &"medium"
const REACTION_PACING_LONG: StringName = &"long"
const VALID_REACTION_PACING: Array[StringName] = [
	REACTION_PACING_SHORT,
	REACTION_PACING_MEDIUM,
	REACTION_PACING_LONG,
]

## Editorial pacing is intentionally keyed by stable card/option ids. It is
## not calculated from English or translated string length: switching locale
## must never change the time available to read a consequence.
const _REACTION_PACING_BY_CARD: Dictionary = {
	"exposed_friend": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"sponsor_offer_shady": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"hater_callout": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_MEDIUM},
	"staged_drama": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"competitor_drama": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_MEDIUM},
	"leaked_dm": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"cancel_threat": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_LONG},
	"apology_tour": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_MEDIUM},
	"fan_in_trouble": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"brand_deal_choice": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_MEDIUM},
	"algorithm_hack": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"burnout_warning": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"thousand_true_fans": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"deep_dive_or_trend": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_LONG},
	"engagement_farming": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"quarterly_content_review": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"masterclass_launch": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"guru_retreat": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"wikipedia_correction": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"sponsored_inaccuracy": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"ai_content_farm": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_LONG},
	"merch_drop_qa": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"trend_hijack_tragedy": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"old_friend_collab": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_LONG},
	"viral_moment": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_MEDIUM},
	"brand_deal_of_the_century": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"kult_niszowy": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_MEDIUM},
	"ipo_influencera": {"a": REACTION_PACING_MEDIUM, "b": REACTION_PACING_MEDIUM},
	"feed_sprint_challenge": {"a": REACTION_PACING_SHORT, "b": REACTION_PACING_SHORT},
	"comment_moderation_challenge": {"a": REACTION_PACING_SHORT, "b": REACTION_PACING_SHORT},
	"polish_export_disaster": {"a": REACTION_PACING_LONG, "b": REACTION_PACING_MEDIUM},
	"sponsor_contract_mega_fallout": {"spin_crisis": REACTION_PACING_LONG, "show_receipts": REACTION_PACING_LONG},
	"sponsor_contract_indie_fallout": {"delivery_drama": REACTION_PACING_LONG, "fix_shipping": REACTION_PACING_LONG},
	"sponsor_contract_finale": {"honest_report": REACTION_PACING_LONG, "sell_legend": REACTION_PACING_LONG},
	"sponsor_contract_callback_honest": {"claim_credit": REACTION_PACING_LONG, "send_invoice": REACTION_PACING_LONG},
	"sponsor_contract_callback_legend": {"solve_brief": REACTION_PACING_LONG, "forward_brief": REACTION_PACING_LONG},
	"final_burnout": {"accept": REACTION_PACING_LONG, "defer": REACTION_PACING_LONG},
}

## Presentation-only bindings for literal Polish cultural references. Stable
## card/option ids keep this metadata outside selection, rewards and saves,
## while giving localization QA an explicit boundary to verify.
const POLISH_LITERAL_QUOTE_OPTIONS: Dictionary = {
	"hater_callout": {"b": &"quote.pl.psy.nie_chce_mi_sie_gadac_01"},
	"burnout_warning": {"a": &"quote.pl.dzien_swira.skrajnie_wyczerpany_01"},
	"masterclass_launch": {"a": &"quote.pl.poranek_kojota.nigdy_nie_czytal_01"},
	"ai_content_farm": {"a": &"quote.pl.kiler_2.lepszy_z_importu_01"},
	"merch_drop_qa": {"a": &"quote.pl.mis.oczko_sie_odlepilo_01"},
	"polish_export_disaster": {"a": &"quote.pl.kiler_2.no_i_w_pizdu_01"},
	"final_burnout": {"accept": &"quote.pl.psy.puszczamy_z_dymem_01"},
}

## The decision-card catalogue, beginning with the 12 MVP cards (8 risky/safe
## + 4 neutral), per
## design/gdd/card-content-database.md's MVP content table, plus 4 Tier-5
## signature cards appended at the end (Story class-path-full/004 — see that
## block below for details). `text` and option `label` fields hold authored
## English satirical fallback copy; locale catalogs provide the displayed copy.
## Skill-challenge cards use `card_category`; legacy narrative cards
## still lack category metadata, so CardScreen falls back to its generic icon
## for them — see docs/tech-debt-register.md. Every option has a stable `id`;
## labels are presentation copy and must never be used for gameplay routing.
const CARDS: Array[Dictionary] = [
	{
		"id": "exposed_friend",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "Your bestie trauma-dumped on a call. That's content gold... and a betrayal.",
		"options": [
			{"id": "a", "label": "Post the screenshots", "resolution_reaction": "Screenshots posted. 12,000 shares. Your friend hasn't replied to your texts.", "resource_deltas": {&"Reach": 180.0, &"Cringe": 28.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Keep it private", "resolution_reaction": "Nothing posted. The call stays between two people.", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 6.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "sponsor_offer_shady",
		"path_tag": "guru_celebryta",
		"trigger_condition": "always",
		"text": "A 'wellness' brand pays you to push gummies that 'cure anxiety.' Lab results: missing.",
		"options": [
			{"id": "a", "label": "Take the bag", "resolution_reaction": "Sponsorship logged. 3 viewers asked if the product works. 0 received an answer.", "resource_deltas": {&"Reach": 160.0, &"Cringe": 22.0, &"Morale": -8.0, &"Sponsors": 3.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Politely decline", "resolution_reaction": "Offer declined. The algorithm notes this and moves on without comment.", "resource_deltas": {&"Reach": 90.0, &"Cringe": -5.0, &"Morale": 5.0, &"Sponsors": 0.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "hater_callout",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "A hater dropped a 12-tweet thread calling you a fraud. It's gaining traction.",
		"options": [
			{"id": "a", "label": "Clap back hard", "resolution_reaction": "Response posted. Engagement up. So is the thread length.", "resource_deltas": {&"Reach": 140.0, &"Cringe": 25.0, &"Morale": -15.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Rise above it", "resolution_reaction": "No response posted. The video is still trending without you in it.", "resource_deltas": {&"Reach": 85.0, &"Cringe": -6.0, &"Morale": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "staged_drama",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "Your manager pitches a fake feud with another creator. Drama = views.",
		"options": [
			{"id": "a", "label": "Stage the beef", "resolution_reaction": "Feud launched. Both fanbases are at war. Neither side knows it's scripted.", "resource_deltas": {&"Reach": 220.0, &"Cringe": 35.0, &"Morale": -18.0}, "counter_increments": {&"risky_choices_count": 1}, "milestone_to_set": &"card.staged_drama.chosen_risky"},
			{"id": "b", "label": "Refuse the script", "resolution_reaction": "No feud. The pitch deck goes back in the drawer.", "resource_deltas": {&"Reach": 120.0, &"Cringe": -15.0, &"Morale": 12.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "competitor_drama",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "A rival creator is getting dragged. Easy engagement if you pile on.",
		"options": [
			{"id": "a", "label": "Throw a punch", "resolution_reaction": "Quote-tweet posted. You're now part of the story you were watching.", "resource_deltas": {&"Reach": 170.0, &"Cringe": 24.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Stay out of it", "resolution_reaction": "You said nothing. The pile-on continued without you.", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 5.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "leaked_dm",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "Someone leaks spicy DMs about a celeb to you. Posting them would break the internet.",
		"options": [
			{"id": "a", "label": "Leak everything", "resolution_reaction": "DMs posted. 80,000 people read messages that weren't theirs to read.", "resource_deltas": {&"Reach": 190.0, &"Cringe": 32.0, &"Morale": -14.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Delete and forget", "resolution_reaction": "DMs deleted. The screenshots no longer exist on your phone.", "resource_deltas": {&"Reach": 105.0, &"Cringe": -12.0, &"Morale": 10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "cancel_threat",
		"path_tag": "pato_streamer",
		"trigger_condition": "always",
		"text": "An old problematic clip resurfaced. #YouAreCancelled is trending.",
		"options": [
			{"id": "a", "label": "Double down", "resolution_reaction": "Statement posted. The hashtag is still trending. So are you.", "resource_deltas": {&"Reach": 200.0, &"Cringe": 30.0, &"Morale": -12.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Issue an apology", "resolution_reaction": "Apology posted. The comments are split. The clip keeps circulating.", "resource_deltas": {&"Reach": 110.0, &"Cringe": -10.0, &"Morale": 8.0}, "counter_increments": {&"safe_choices_count": 1}, "milestone_to_set": &"card.cancel_threat.apologized"},
		],
	},
	{
		"id": "apology_tour",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "Time for the apology video. Ring light on. Question is how... real... to make it.",
		"options": [
			{"id": "a", "label": "Cry on camera", "resolution_reaction": "Apology video up. 2.1M views. The top comment counts your tears.", "resource_deltas": {&"Reach": 150.0, &"Cringe": 20.0, &"Morale": -8.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Actually mean it", "resolution_reaction": "Apology posted without edits. Fewer views. Fewer follow-ups.", "resource_deltas": {&"Reach": 95.0, &"Cringe": -5.0, &"Morale": 18.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "fan_in_trouble",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "A young fan DMs you in a real crisis, asking for help.",
		"options": [
			{"id": "a", "label": "Make it 'awareness' content", "resolution_reaction": "Clip posted. 40,000 people watched a private moment become public.", "resource_deltas": {&"Reach": 60.0, &"Sponsors": -1.0}, "counter_increments": {}},
			{"id": "b", "label": "Help quietly", "resolution_reaction": "Message sent. No one else will ever know this happened.", "resource_deltas": {&"Reach": 40.0, &"Sponsors": -1.0, &"Morale": 4.0}, "counter_increments": {}},
		],
	},
	{
		"id": "brand_deal_choice",
		"path_tag": "guru_celebryta",
		"trigger_condition": "always",
		"text": "Two deals: a cringe fast-fashion mega-corp, or a small ethical label that pays less.",
		"options": [
			{"id": "a", "label": "Sell out big", "resolution_reaction": "Contract signed. The fast-fashion logo is now in your bio.", "resource_deltas": {&"Reach": -40.0, &"Sponsors": 3.0}, "counter_increments": {}},
			{"id": "b", "label": "Back the indie", "resolution_reaction": "Smaller deal signed. The indie label reshared your post.", "resource_deltas": {&"Reach": 40.0, &"Sponsors": 1.0}, "counter_increments": {}},
		],
	},
	{
		"id": "algorithm_hack",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "A growth guru sells an 'algorithm exploit' that floods feeds with your clips.",
		"options": [
			{"id": "a", "label": "Buy the exploit", "resolution_reaction": "Exploit purchased. Your clips are everywhere. You don't know who's watching.", "resource_deltas": {&"Reach": 220.0}, "counter_increments": {}},
			{"id": "b", "label": "Grow it honestly", "resolution_reaction": "No exploit. Growth is slower. The numbers are yours.", "resource_deltas": {&"Reach": 60.0}, "counter_increments": {}, "milestone_to_set": &"card.algorithm_hack.saved"},
		],
	},
	{
		"id": "burnout_warning",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "40 hours, no sleep. The grind's working, but your hands are shaking.",
		"options": [
			{"id": "a", "label": "Push through", "resolution_reaction": "One more upload shipped. The reach came. So did the headache.", "resource_deltas": {&"Reach": 130.0}, "counter_increments": {}},
			{"id": "b", "label": "Take a day off", "resolution_reaction": "Phone off for a day. Nothing was posted. Nothing was missed.", "resource_deltas": {&"Morale": 10.0}, "counter_increments": {}},
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
	# These ordinary cards intentionally do not extend the sponsor-card faucet;
	# Sponsor Career Contract follow-ups are the separately designed exception.
	# outside this story's scope, not an oversight).
	{
		"id": "thousand_true_fans",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "always",
		"text": "A 50M-follower giveaway account wants a paid shoutout. Your actual community is 340 people who reply to everything you post.",
		"options": [
			{"id": "a", "label": "Take the giveaway deal", "resolution_reaction": "Shoutout posted. Reach spiked. Three regulars asked if you're okay.", "resource_deltas": {&"Reach": 130.0, &"Cringe": 15.0, &"Morale": -10.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Stay with your 340", "resolution_reaction": "No shoutout. Someone in the replies said this is why they still watch.", "resource_deltas": {&"Reach": 75.0, &"Cringe": -6.0, &"Morale": 8.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "deep_dive_or_trend",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "always",
		"text": "This week's trend is a 15-second dance. Your last upload -- 47 minutes on one specific bolt pattern -- still gets comments daily.",
		"options": [
			{"id": "a", "label": "Chase the trend", "resolution_reaction": "Dance posted. It performed fine. It also wasn't you.", "resource_deltas": {&"Reach": 140.0, &"Cringe": 18.0, &"Morale": -9.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Make another deep-dive", "resolution_reaction": "47 more minutes on bolts. The comment about the last one is still going.", "resource_deltas": {&"Reach": 80.0, &"Cringe": -7.0, &"Morale": 9.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "engagement_farming",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "always",
		"text": "The dashboard flags a format that reliably outperforms everything else you make: rage-bait comment-section debates. You've never cared about the topic.",
		"options": [
			{"id": "a", "label": "Run the numbers", "resolution_reaction": "Debate video posted. Comments: 4,200. Position held: none, specifically.", "resource_deltas": {&"Reach": 190.0, &"Cringe": 28.0, &"Morale": -3.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Pass on the format", "resolution_reaction": "Format skipped. The dashboard logs the missed opportunity and says nothing else.", "resource_deltas": {&"Reach": 108.0, &"Cringe": -10.0, &"Morale": 3.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "quarterly_content_review",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "always",
		"text": "Your creative process this quarter is a spreadsheet: post times, retention curves, thumbnail A/B tests. It's working. You haven't watched your own video in three weeks.",
		"options": [
			{"id": "a", "label": "Trust the spreadsheet", "resolution_reaction": "Spreadsheet-optimal video shipped. Retention curve: excellent. Your notes on it: none.", "resource_deltas": {&"Reach": 210.0, &"Cringe": 20.0, &"Morale": -4.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Override it once", "resolution_reaction": "You picked the thumbnail yourself this time. The curve dipped 2%. You watched the whole video.", "resource_deltas": {&"Reach": 120.0, &"Cringe": -8.0, &"Morale": 4.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},

	# --- Card wave 3 (2026-07-28, "everything to the finish line" push):
	# +2 guru_celebryta (previously 2 reachable tagged cards vs pato's 6),
	# +2 ekspert_niszowy, +2 biznesmen_contentu (4 each now), +2 neutral.
	# Same schema/tone/band discipline as wave 2: risky/safe Reach ratio in
	# the locked 1.4x-1.8x band, no Sponsors resource_deltas (registry's
	# Ordinary wave cards stay outside the sponsor-card faucet — same
	# deliberate scope call wave 2 documented above).
	{
		"id": "masterclass_launch",
		"path_tag": "guru_celebryta",
		"trigger_condition": "always",
		"text": "Your audience asks how you got here. You could tell them — or you could sell them 'Manifest The Algorithm', a $999 masterclass.",
		"options": [
			{"id": "a", "label": "Launch the masterclass", "resolution_reaction": "Course live. Module 3 is a 40-minute video about believing in yourself. It has a workbook.", "resource_deltas": {&"Reach": 180.0, &"Cringe": 26.0, &"Morale": -8.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Post it for free", "resolution_reaction": "Free guide posted. Someone commented that it's the only honest one in the niche. It didn't trend.", "resource_deltas": {&"Reach": 105.0, &"Cringe": -7.0, &"Morale": 6.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "guru_retreat",
		"path_tag": "guru_celebryta",
		"trigger_condition": "always",
		"text": "You're planning a 'digital detox retreat' for your followers. Tickets are $500. You are planning to livestream it.",
		"options": [
			{"id": "a", "label": "Livestream the detox", "resolution_reaction": "Retreat streamed in 4K. Attendees meditated in front of a camera crane. Engagement: excellent.", "resource_deltas": {&"Reach": 165.0, &"Cringe": 24.0, &"Morale": -12.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Actually unplug", "resolution_reaction": "No stream. Twelve people sat by a lake. One of them was you.", "resource_deltas": {&"Reach": 100.0, &"Cringe": -8.0, &"Morale": 9.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "wikipedia_correction",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "always",
		"text": "A 4M-subscriber creator got your entire field wrong in a viral video. You have receipts. You always have receipts.",
		"options": [
			{"id": "a", "label": "Post the takedown", "resolution_reaction": "Correction video up. Their fans arrived first, your citations arrived second.", "resource_deltas": {&"Reach": 150.0, &"Cringe": 16.0, &"Morale": -6.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Email them privately", "resolution_reaction": "Correction sent. They pinned a quiet errata comment. Nobody clipped it.", "resource_deltas": {&"Reach": 90.0, &"Cringe": -5.0, &"Morale": 7.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "sponsored_inaccuracy",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "always",
		"text": "A brand loves your explainer — they just need you to simplify one detail. The simplified version is, technically, false.",
		"options": [
			{"id": "a", "label": "Read the script", "resolution_reaction": "Ad read delivered. The detail is now wrong in 200,000 heads, but the transition was smooth.", "resource_deltas": {&"Reach": 145.0, &"Cringe": 20.0, &"Morale": -11.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Correct the script", "resolution_reaction": "Brand accepted the accurate version. The campaign manager called it 'a compromise'.", "resource_deltas": {&"Reach": 88.0, &"Cringe": -6.0, &"Morale": 8.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "ai_content_farm",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "always",
		"text": "A vendor demo shows your face and voice generating 40 videos a week without you. The demo video of you is already rendered.",
		"options": [
			{"id": "a", "label": "Deploy the clone", "resolution_reaction": "Pipeline live. Your channel uploaded twice while you read this sentence.", "resource_deltas": {&"Reach": 230.0, &"Cringe": 30.0, &"Morale": -5.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Stay handmade", "resolution_reaction": "Vendor declined. Output unchanged: one video, made by a person, on purpose.", "resource_deltas": {&"Reach": 130.0, &"Cringe": -9.0, &"Morale": 3.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "merch_drop_qa",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "always",
		"text": "The merch shipment arrived with your logo printed slightly off-center. Reprinting costs a quarter of the margin. Pre-orders are sold out.",
		"options": [
			{"id": "a", "label": "Ship it anyway", "resolution_reaction": "Units shipped. The off-center logo is now a 'limited misprint edition', per your own tweet.", "resource_deltas": {&"Reach": 185.0, &"Cringe": 27.0, &"Morale": -7.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Eat the reprint cost", "resolution_reaction": "Reprint ordered. Margin gone. The logo is exactly where logos go.", "resource_deltas": {&"Reach": 110.0, &"Cringe": -9.0, &"Morale": 6.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "trend_hijack_tragedy",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "A tragedy is the top trend worldwide. Your editor drafted a 'raising awareness' video with your best-performing thumbnail face.",
		"options": [
			{"id": "a", "label": "Post the awareness video", "resolution_reaction": "Video live. It's your biggest reach this month. The comments are turned off.", "resource_deltas": {&"Reach": 175.0, &"Cringe": 30.0, &"Morale": -12.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Sit this one out", "resolution_reaction": "Nothing posted. The trend moved on within a day. So did everyone who did post.", "resource_deltas": {&"Reach": 100.0, &"Cringe": -10.0, &"Morale": 8.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "old_friend_collab",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "A friend from before the follower count asks to collab. Their content is, honestly, not good. Their DM is very excited.",
		"options": [
			{"id": "a", "label": "Mine the nostalgia", "resolution_reaction": "Collab posted, cut around their parts. It performed. They texted 'we should do this more'.", "resource_deltas": {&"Reach": 155.0, &"Cringe": 22.0, &"Morale": -9.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Help them off-camera", "resolution_reaction": "You spent an evening fixing their setup instead. No video exists of it.", "resource_deltas": {&"Reach": 92.0, &"Cringe": -6.0, &"Morale": 9.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},

	# --- Tier-5 signature cards (Story class-path-full/004, ADR-0010 §10,
	# TR-cps-006). One per path, gated by the "class_path_tier:{path_id}:5"
	# trigger_condition grammar entry (decision_card_system.gd) instead of
	# "always" — only enters the eligible pool once that path's tier reaches
	# 5. The schema shape matches the 12 MVP cards exactly, and player-facing
	# copy is resolved through stable localization keys added by get_card().
	{
		"id": "viral_moment",
		"path_tag": "pato_streamer",
		"trigger_condition": "class_path_tier:pato_streamer:5",
		"text": "Your livestream catches a backstage argument, an open mic, and exactly one sentence the internet can misunderstand. Clips are already escaping.",
		"options": [
			{"id": "a", "label": "Keep the cameras rolling", "resolution_reaction": "You add a thumbnail before anyone adds context. By breakfast, context is officially irrelevant.", "resource_deltas": {&"Reach": 260.0, &"Cringe": 15.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "b", "label": "Cut the feed", "resolution_reaction": "The clip survives, but without your help it remains merely embarrassing.", "resource_deltas": {&"Reach": 140.0, &"Cringe": -10.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "brand_deal_of_the_century",
		"path_tag": "guru_celebryta",
		"trigger_condition": "class_path_tier:guru_celebryta:5",
		"text": "A global wellness brand wants your face, voice, and \"spontaneous opinions\" for the next seven years. Legal calls it standard.",
		"options": [
			{"id": "a", "label": "Sign everything", "resolution_reaction": "The deal closes. Your morning routine now requires brand approval.", "resource_deltas": {&"Reach": 70.0, &"Morale": -6.0}, "counter_increments": {}},
			{"id": "b", "label": "Cut the contract down", "resolution_reaction": "Half the money, but your personality still belongs to you.", "resource_deltas": {&"Reach": 35.0, &"Morale": 4.0}, "counter_increments": {}},
		],
	},
	{
		"id": "kult_niszowy",
		"path_tag": "ekspert_niszowy",
		"trigger_condition": "class_path_tier:ekspert_niszowy:5",
		"text": "Your forum now has its own glossary, an initiation quiz, and three competing readings of your oldest tutorial. You may have founded a school of thought by accident.",
		"options": [
			{"id": "a", "label": "Go deeper", "resolution_reaction": "The audience gets smaller, the conversations get better, and nobody asks what the acronyms mean.", "resource_deltas": {&"Reach": 45.0, &"Morale": 8.0}, "counter_increments": {}},
			{"id": "b", "label": "Translate it for everyone", "resolution_reaction": "The numbers rise. Half the comments ask for a short version of the short version.", "resource_deltas": {&"Reach": 90.0, &"Morale": -4.0}, "counter_increments": {}},
		],
	},
	{
		"id": "ipo_influencera",
		"path_tag": "biznesmen_contentu",
		"trigger_condition": "class_path_tier:biznesmen_contentu:5",
		"text": "Investment bankers want to take your personal brand public. Their presentation lists authenticity under \"scalable assets.\"",
		"options": [
			{"id": "a", "label": "Ring the opening bell", "resolution_reaction": "The shares debut. Your personality now reports quarterly earnings.", "resource_deltas": {&"Reach": 50.0, &"Cringe": 10.0}, "counter_increments": {}},
			{"id": "b", "label": "Stay privately held", "resolution_reaction": "No ticker, no shareholders. For once, growth can wait until Monday.", "resource_deltas": {&"Reach": 20.0, &"Morale": 5.0}, "counter_increments": {}},
		],
	},

	{
		"id": "feed_sprint_challenge",
		"card_category": "skill_challenge",
		"spotlight_minigame": "feed_sprint",
		"spotlight_reward_profile": "feed_sprint",
		"spotlight_skip_option": 1,
		"path_tag": "",
		"trigger_condition": "always",
		"text": "The Algorithm opened a 24-second distribution window. Catch the trends. Dodge the strikes.",
		"options": [
			{"id": "a", "label": "Play Feed Sprint", "resolution_reaction": "Feed Sprint complete.", "starts_spotlight": true, "resource_deltas": {}, "counter_increments": {}},
			{"id": "b", "label": "Skip challenge", "resolution_reaction": "Challenge skipped. No penalty.", "resource_deltas": {}, "counter_increments": {}},
		],
	},
	{
		"id": "comment_moderation_challenge",
		"card_category": "skill_challenge",
		"spotlight_minigame": "comment_moderation",
		"spotlight_reward_profile": "comment_moderation",
		"spotlight_skip_option": 1,
		"path_tag": "",
		"trigger_condition": "always",
		"text": "The comment queue is on fire. Keep the community. Remove the garbage.",
		"options": [
			{"id": "a", "label": "Moderate the queue", "resolution_reaction": "Moderation shift complete.", "starts_spotlight": true, "resource_deltas": {}, "counter_increments": {}},
			{"id": "b", "label": "Ignore the queue", "resolution_reaction": "Queue ignored. No penalty.", "resource_deltas": {}, "counter_increments": {}},
		],
	},
	{
		"id": "polish_export_disaster",
		"card_category": "cultural_humor",
		"path_tag": "",
		"trigger_condition": "always",
		"text": "The perfect upload is ready. Your editor hits export. The laptop answers with the sound of a vacuum cleaner taking off.",
		"options": [
			{"id": "a", "label": "Publish without a backup", "resolution_reaction": "It crashed, landed badly, and took the entire elaborate plan with it.", "resource_deltas": {&"Reach": 140.0, &"Cringe": 18.0, &"Morale": -8.0}, "counter_increments": {}},
			{"id": "b", "label": "Make a backup first", "resolution_reaction": "The export fails. The backup opens. For once, competence gets the punchline.", "resource_deltas": {&"Reach": 75.0, &"Morale": 6.0}, "counter_increments": {}},
		],
	},
	# --- Sponsor Career Contract follow-ups. These never enter the ordinary
	# weighted pool; SponsorContractSystem schedules them only after their
	# action objectives are complete. Stable semantic option ids preserve
	# branch memory independently of localized labels.
	{
		"id": "sponsor_contract_mega_fallout",
		"card_category": "career_contract",
		"path_tag": "",
		"trigger_condition": "never",
		"text": "The first collection stains skin in the brand color. The sponsor asks whether it can be called 'immersive branding.'",
		"options": [
			{"id": "spin_crisis", "label": "Spin the crisis", "resolution_reaction": "Statement posted. The official causes are the algorithm, the weather, and customers holding it wrong.", "resource_deltas": {&"Reach": 175.0, &"Cringe": 22.0, &"Morale": -8.0, &"Sponsors": 1.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "show_receipts", "label": "Show the test results", "resolution_reaction": "The table goes public. The sponsor discovers transparency was not included in the campaign package.", "resource_deltas": {&"Reach": 100.0, &"Cringe": -4.0, &"Morale": 6.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "sponsor_contract_indie_fallout",
		"card_category": "career_contract",
		"path_tag": "",
		"trigger_condition": "never",
		"text": "The small brand cannot ship the launch orders. Comments are asking whether the company exists outside one mood board.",
		"options": [
			{"id": "delivery_drama", "label": "Turn delivery into drama", "resolution_reaction": "The livestream starts. The parcels are still missing; three clips and a logistics expert have arrived.", "resource_deltas": {&"Reach": 150.0, &"Cringe": 18.0, &"Morale": -6.0, &"Sponsors": 1.0}, "counter_increments": {&"risky_choices_count": 1}},
			{"id": "fix_shipping", "label": "Help ship the orders", "resolution_reaction": "The evening goes into labels and tape. Reach is smaller. The parcels actually leave.", "resource_deltas": {&"Reach": 90.0, &"Cringe": -5.0, &"Morale": 8.0, &"Sponsors": 1.0}, "counter_increments": {&"safe_choices_count": 1}},
		],
	},
	{
		"id": "sponsor_contract_finale",
		"card_category": "career_contract",
		"path_tag": "",
		"trigger_condition": "never",
		"text": "The campaign ends. The sponsor wants a 'success case study.' The internet has already prepared its own version.",
		"options": [
			{"id": "honest_report", "label": "Publish the real numbers", "resolution_reaction": "The report goes live without smoke or mirrors. Legal reads the numbers from left to right for the first time.", "resource_deltas": {&"Reach": 120.0, &"Cringe": -8.0, &"Morale": 10.0, &"Sponsors": 2.0}, "counter_increments": {&"safe_choices_count": 1}},
			{"id": "sell_legend", "label": "Sell the success legend", "resolution_reaction": "The chart launches, crashes, and still gets labeled RECORD. The sponsor approves the deck.", "resource_deltas": {&"Reach": 210.0, &"Cringe": 25.0, &"Morale": -10.0, &"Sponsors": 2.0}, "counter_increments": {&"risky_choices_count": 1}},
		],
	},
	{
		"id": "sponsor_contract_callback_honest",
		"card_category": "career_contract",
		"path_tag": "",
		"trigger_condition": "never",
		"text": "A week later, the sponsor quotes your honest report in a meeting. The slide is titled RADICAL TRANSPARENCY (Q3 GROWTH LEVER).",
		"options": [
			{"id": "claim_credit", "label": "Claim the credit", "resolution_reaction": "Your honesty becomes a branded methodology. The PDF is free; the workshop costs more than the campaign.", "resource_deltas": {&"Reach": 100.0, &"Morale": 5.0, &"Sponsors": 1.0}, "counter_increments": {&"safe_choices_count": 1}},
			{"id": "send_invoice", "label": "Send another invoice", "resolution_reaction": "The invoice says strategic transparency consulting. Accounting approves it before learning what that means.", "resource_deltas": {&"Reach": 70.0, &"Cringe": 5.0, &"Sponsors": 2.0}, "counter_increments": {&"risky_choices_count": 1}},
		],
	},
	{
		"id": "sponsor_contract_callback_legend",
		"card_category": "career_contract",
		"spotlight_minigame": "brief_puzzle",
		"spotlight_reward_profile": "brief_puzzle",
		"spotlight_skip_option": 1,
		"path_tag": "",
		"trigger_condition": "never",
		"text": "The agency returns with a post-campaign brief assembled by four departments. Every instruction contradicts the next one.",
		"options": [
			{"id": "solve_brief", "label": "Untangle the brief", "resolution_reaction": "Brief decoded. The final instruction says: use your best judgment. Legal removes it as too risky.", "starts_spotlight": true, "resource_deltas": {}, "counter_increments": {}},
			{"id": "forward_brief", "label": "Let the agency handle it", "resolution_reaction": "The agency schedules a meeting to decide who should schedule the meeting.", "resource_deltas": {}, "counter_increments": {}},
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
		# Final copy is localized through the same stable keys as other cards.
		#
		# Semantic option ids are consumed by BurnoutSystem. Labels remain
		# presentation-only so copy/localization cannot change routing.
		{
			"id": "final_burnout",
			"path_tag": "",
			"trigger_condition": "never",
			"text": "Six months, zero days off. The hands won't stop shaking on camera anymore, and the audience thinks it's a bit.",
			"options": [
				{"id": "accept", "label": "Accept the Burnout", "resolution_reaction": "The account goes dark. The era ends here.", "resource_deltas": {}, "counter_increments": {}},
				{"id": "defer", "label": "Defer the Burnout", "resolution_reaction": "One more grind, running on fumes. The audience never finds out how close it came.", "resource_deltas": {}, "counter_increments": {}},
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
			return _with_presentation_metadata(card)
	return {}


## Returns all cards: the 12 MVP cards plus the 4 Tier-5 signature cards
## (Story class-path-full/004).
##
## Example:
##   var all_cards: Array[Dictionary] = CardContentDatabase.get_all_cards()
func get_all_cards() -> Array[Dictionary]:
	var cards_with_metadata: Array[Dictionary] = []
	cards_with_metadata.assign(CARDS.map(_with_presentation_metadata))
	return cards_with_metadata


## Keeps authored English strings beside the mechanics as a migration-safe
## fallback while exposing stable localization keys to presentation code.
## The returned deep copy prevents UI code from mutating the static catalogue.
func _with_presentation_metadata(source_card: Dictionary) -> Dictionary:
	var card: Dictionary = source_card.duplicate(true)
	var card_id: String = card["id"]
	card["text_key"] = StringName("cards.%s.body" % card_id)

	var pacing_by_option: Dictionary = _REACTION_PACING_BY_CARD.get(card_id, {})
	for option: Dictionary in card["options"]:
		var option_id: String = option["id"]
		var option_key_root: String = "cards.%s.options.%s" % [card_id, option_id]
		option["label_key"] = StringName("%s.label" % option_key_root)
		option["reaction_key"] = StringName("%s.reaction" % option_key_root)
		option["reaction_pacing"] = pacing_by_option.get(option_id, REACTION_PACING_MEDIUM)
		var quote_options: Dictionary = POLISH_LITERAL_QUOTE_OPTIONS.get(card_id, {})
		if quote_options.has(option_id):
			option["cultural_reference_locale"] = &"pl_PL"
			option["literal_quote_id"] = quote_options[option_id]
	return card
