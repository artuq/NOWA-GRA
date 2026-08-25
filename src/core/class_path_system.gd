## ClassPathSystem owns the player's class path progression: per-path
## affiliation floats [0.0–100.0], tier ints [0–5] (MVP: 0–2), and the active
## path identity.
##
## Implements TR-cps-001..005 / ADR-0010: registered as Autoload #9 in Project
## Settings → Autoload (below DecisionCardSystem — subscriber-below-emitter
## rule, ADR-0001). Subscribes to DecisionCardSystem.card_resolved to update
## affiliation when a path-tagged card resolves; the path counter in
## HistoryFlagManager is already incremented when that signal fires (ADR-0010
## §2 ordering contract). Pull model: ActionSystem queries
## get_active_multiplier() at reward resolution — this module never references
## ActionSystem.
##
## MVP scope (Sprint 8): 2 paths (pato_streamer, guru_celebryta), Tier 1–2
## bonuses only, card affiliation only. invest() is a stub returning false —
## the active investment mechanic is Vertical Slice scope.
##
## Story class-path-full/001 (2026-07-13, ADR-0010 §11): expanded path
## registration and _MULTIPLIER_TABLE to all 4 GDD paths × Tiers 1-5 (data
## only — TIER_THRESHOLDS already generalized). invest() remains a stub;
## active investment ships in class-path-full/002.
##
## Story class-path-full/002 (2026-07-13, ADR-0010 §8, TR-cps-008, GDD Core
## Rule 4a / Formula F2): invest() goes live. The formerly-conflated
## _affiliation[path_id] float is now the sum of two separately-tracked
## terms — _card_contribution[path_id] (F1, card choices) and
## _investment_contribution[path_id] (F2, spent resources) — combined and
## clamped to [0.0, 100.0] by _recalculate_total_affiliation() (F3).
## invest() is gated on _card_contribution[path_id] > 0 (Core Rule 4a):
## a path cannot be bought with resources alone until the player has made at
## least one path-tagged card choice this era.
##
## Story class-path-full/004 (2026-07-13, ADR-0010 §10, TR-cps-006): adds the
## signature_card_unlocked/removed signals (GDD Signals table), emitted from
## _check_tier_progression() (tier 5 reached) and reset_era_state() (a
## Tier-5 path resets). These are UI-only notifications — DecisionCardSystem
## does not subscribe to them. The actual pool add/remove is a pull-model
## trigger_condition grammar entry on DecisionCardSystem
## ("class_path_tier:{path_id}:{min_tier}"), not a push from this module —
## this file has no dependency on CardContentDatabase or DecisionCardSystem's
## pool; it only needs to know which card_id corresponds to which path to
## populate the signal payload (_SIGNATURE_CARD_TABLE below).
##
## Usage example:
##   var tier: int = ClassPathSystem.get_tier(&"pato_streamer")
##   var mult: float = ClassPathSystem.get_active_multiplier(&"zrob_drame")
extends Node

## Tier thresholds: index = tier, value = inclusive minimum affiliation.
## Source: design/quick-specs/class-path-system-2026-07-01.md (20/40/60/80/100).
const TIER_THRESHOLDS: Array[float] = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]

## Affiliation gained per resolved path-tagged card (either option counts).
## GDD Tuning Knob: default 4.0, safe range 2.0–8.0.
## ponytail: const, not external balance data — extraction to .tres/JSON is a
## project-wide tech-debt item shared with ActionSystem.ACTION_REWARDS.
const CARD_AFFILIATION_PER_CHOICE: float = 4.0

## Maximum affiliation contribution from card choices per era. Active
## investment (Vertical Slice) can push total affiliation above this cap.
const CARD_CONTRIBUTION_MAX: float = 60.0

## Minimum lead the top-affiliation Tier-1+ path must hold over the
## second-highest to resolve as the sole active path (GDD F5's `M`). Below
## this margin (including an exact tie, diff == 0.0), the active path is
## "ambiguous" (&"") instead of silently picking whichever path iterates
## first in the Dictionary — BUG-003 fix (Story class-path-full/003,
## ADR-0010 §9, TR-cps-009).
## GDD Tuning Knob: default 5.0, safe range 2.0-10.0.
const PATH_AFFILIATION_TIE_BREAK_MARGIN: float = 5.0

## Multiplier table: path_id -> tier (int) -> action_id -> Reach multiplier.
## Any unregistered combination resolves to 1.0 in get_active_multiplier().
## get_active_multiplier() only resolves Reach bonuses tied to a specific
## named action — this is a strict subset of the GDD's Tier Bonuses by Path
## table (design/gdd/class-path-system.md §Detailed Design). Most tier
## bonuses (Sponsor income, Morale floor, Haters conversion rate, action
## slots, unlock cost, signature cards, etc.) are NOT expressible as an
## action-keyed Reach multiplier and are intentionally represented as an
## empty {} tier entry here — their gameplay hooks belong to whichever
## system consumes them (ADR-0010 §11 / Story class-path-full/001 Out of
## Scope). All 4 paths list explicit keys 1-5 so a missing tier is always a
## deliberate `{}`, never an accidental omission.
## Source: pato T1 "Zrób dramę" +30% / T2 continuation to +60% (shipped MVP,
## unchanged); guru T1 "Zrób wywiad" +20% / T2 continuation to +40% (shipped
## MVP, unchanged); ekspert T2 "Nagraj vloga" +20%; biznesmen T1/T2 Collab
## ×1.2/×1.4 (tier-bonus table draft 2026-07-28 — its first Reach-keyed
## entries; its other bonuses live in _TIER_EFFECT_TABLE below).
## LOOKUP IS CUMULATIVE (tier-fill revision, 2026-07-28): an action's
## multiplier comes from the HIGHEST tier <= the path's current tier that
## defines that action — previously the lookup read ONLY the current tier's
## dict, so reaching a hollow T3 silently DROPPED the shipped T2 bonus
## (latent bug, unreachable while tiers stopped at 2 in practice).
const _MULTIPLIER_TABLE: Dictionary[StringName, Dictionary] = {
	&"pato_streamer": {
		1: {&"zrob_drame": 1.3},
		2: {&"zrob_drame": 1.6},
		3: {},
		4: {},
		5: {},
	},
	&"guru_celebryta": {
		1: {&"udziel_wywiadu": 1.2},
		2: {&"udziel_wywiadu": 1.4},
		3: {},
		4: {},
		5: {},
	},
	&"ekspert_niszowy": {
		1: {},
		2: {&"nagraj_vloga": 1.2},
		3: {},
		4: {},
		5: {},
	},
	&"biznesmen_contentu": {
		1: {&"nagraj_kolaba": 1.2},
		2: {&"nagraj_kolaba": 1.4},
		3: {},
		4: {},
		5: {},
	},
}

## Non-Reach tier effects: path_id -> tier (int) -> effect dict (tier-bonus
## table draft, design/reference/class-path-tier-bonus-table-draft.md — the
## 10 `[hook]` cells; T1/T2 `[mult]` cells stay in _MULTIPLIER_TABLE above).
## ALL VALUES PROVISIONAL pending the economy-designer balance pass the draft
## itself mandates.
##
## Effect keys (each resolved cumulatively — the highest tier <= the path's
## current tier that defines a key wins; see _resolve_effect()):
## - secondary_yield: {action_id: {resource: amount}} — T3 interlocks: the
##   path's signature action also yields a second resource on completion
##   (Melvor web-of-dependencies model).
## - duration_mult: {action_id: float} or {&"*": float} — T4 power spikes:
##   action duration cuts (draft: 9s->6s etc == 2/3; biznesmen: all -25%).
## - reach_all_mult: float — pato T5: all-action Reach multiplier, stacks
##   multiplicatively ON TOP of the action-keyed _MULTIPLIER_TABLE entry.
## - cringe_gain_mult: float — pato T5 "bait burns hot": positive action
##   Cringe deltas scaled up.
## - sponsor_income_mult: float — guru T5 / biznesmen T3: positive Sponsors
##   deltas (cards + interlock yields) scaled.
## - morale_cost_mult: float — biznesmen T5: negative action Morale deltas
##   scaled (0.0 == full immunity, "content without emotional cost").
## - morale_drain_mult: float — ekspert T1: ambient Morale drain (offline
##   sim) scaled.
## - haters_growth_mult: float — ekspert T5: Haters growth rate scaled.
## - morale_floor: float — ekspert T5: AMBIENT drain (offline sim) never
##   takes Morale below this ("cult immune to hate") — see get_morale_floor()
##   for why this is drain-only, never a live apply_delta clamp.
const _TIER_EFFECT_TABLE: Dictionary[StringName, Dictionary] = {
	# Interlock yield magnitudes (balance sanity pass, 2026-07-28): the draft's
	# original +3/+2/+5 per completion flooded both meters — at drama's 9s
	# (6s at T4) cadence, +3 Sponsors/completion is ~20-30/min against sinks
	# priced in single digits per MINUTES (shield 5 per 300s, guru invest
	# 5/tap, cards +3 once per multiple minutes), and +5 Morale per 6s vlog
	# out-heals every Morale cost in the game combined. Cut to sink-scale:
	# +1 Sponsor (drama/interview), +2 Morale (vlog). Still provisional.
	&"pato_streamer": {
		3: {&"secondary_yield": {&"zrob_drame": {&"Sponsors": 1.0}}},
		4: {&"duration_mult": {&"zrob_drame": 2.0 / 3.0}},
		5: {&"reach_all_mult": 2.0, &"cringe_gain_mult": 1.5},
	},
	&"guru_celebryta": {
		3: {&"secondary_yield": {&"udziel_wywiadu": {&"Sponsors": 1.0}}},
		4: {&"duration_mult": {&"udziel_wywiadu": 2.0 / 3.0}},
		5: {&"sponsor_income_mult": 2.0},
	},
	&"ekspert_niszowy": {
		1: {&"morale_drain_mult": 0.8},
		3: {&"secondary_yield": {&"nagraj_vloga": {&"Morale": 2.0}}},
		4: {&"duration_mult": {&"nagraj_vloga": 2.0 / 3.0}},
		5: {&"haters_growth_mult": 0.5, &"morale_floor": 40.0},
	},
	&"biznesmen_contentu": {
		3: {&"sponsor_income_mult": 1.5},
		4: {&"duration_mult": {&"*": 0.75}},
		5: {&"morale_cost_mult": 0.0},
	},
}

## Per-path investment rate (GDD F2 `INVESTMENT_AFFILIATION_RATE[path]`):
## affiliation points gained per unit of that path's investment resource
## spent via invest(). Derived as the reciprocal of each path's "cost per 1
## affiliation" figure (10 Cringe / 5 Sponsors / 8 Morale / 50 Reach — GDD
## Investment Cost Scale table). Candidate values only, pending
## economy-designer's income-curve pass before Alpha (GDD F2 Open Question).
## ponytail: same in-file-const sourcing pattern as _MULTIPLIER_TABLE above —
## ADR-0010 §8 describes this as sourced from `assets/data/balance.json`, but
## no such file exists in this project yet and _MULTIPLIER_TABLE (§5's own
## documented source) is itself a plain const, not JSON-loaded. This table
## follows the pattern actually shipped in this file, not the ADR's
## aspirational data-file text; balance.json extraction remains the same
## project-wide tech-debt item noted on CARD_AFFILIATION_PER_CHOICE above.
const _INVESTMENT_RATE_TABLE: Dictionary[StringName, float] = {
	&"pato_streamer": 0.1,
	&"guru_celebryta": 0.2,
	&"ekspert_niszowy": 0.125,
	&"biznesmen_contentu": 0.02,
}

const _INVESTMENT_RESOURCE_TABLE: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"Cringe",
	&"guru_celebryta": &"Sponsors",
	&"ekspert_niszowy": &"Morale",
	&"biznesmen_contentu": &"Reach",
}

## Investment can accelerate an established direction, but cannot replace
## card-choice history. The usable investment ceiling grows one-for-one with
## card contribution, from a 20-point base (GDD F3 / Algorithm Contract F6).
const PATH_INVESTMENT_HISTORY_BASE: float = 20.0

## Path -> Tier-5 signature card id (GDD `design/gdd/class-path-system.md`
## Tier Bonuses by Path table: "Viral Moment" / "Brand Deal of the Century" /
## "Kult Niszowy" / "IPO Influencera"; card content lives in
## CardContentDatabase, not here). Used only to populate the
## signature_card_unlocked/removed signal payload — Story class-path-full/004,
## ADR-0010 §10. This module never reads CardContentDatabase itself; pool
## eligibility is resolved entirely by DecisionCardSystem's
## "class_path_tier:{path_id}:{min_tier}" trigger_condition grammar entry
## reading get_tier(), independent of these signals.
const _SIGNATURE_CARD_TABLE: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"viral_moment",
	&"guru_celebryta": &"brand_deal_of_the_century",
	&"ekspert_niszowy": &"kult_niszowy",
	&"biznesmen_contentu": &"ipo_influencera",
}

## Emitted exactly once per tier crossing for [param path_id] — only from
## _check_tier_progression(), never from getters (ADR-0010 rejected
## side-effecting getters explicitly).
signal tier_unlocked(path_id: StringName, tier: int)

## Emitted when the active path changes. [param path_id] is &"" when no path
## is at Tier 1+ (including after reset_era_state()).
signal active_path_changed(path_id: StringName)

## Emitted when [param path_id] first reaches Tier 5 this era (GDD Signals
## table; Story class-path-full/004, ADR-0010 §10, TR-cps-006). UI-only
## notification — DecisionCardSystem does not subscribe to this; the card's
## actual pool eligibility is driven independently by its own
## trigger_condition grammar. [param card_id] is looked up from
## _SIGNATURE_CARD_TABLE.
signal signature_card_unlocked(card_id: StringName)

## Emitted when a Tier-5 path's signature card is removed — currently only
## reachable via reset_era_state() (tiers are monotonic within an era, so
## this never fires mid-era). Same UI-only-notification contract as
## signature_card_unlocked.
signal signature_card_removed(card_id: StringName)

## Per-path TOTAL affiliation [0.0–100.0] — F3's clamped sum of
## _card_contribution and _investment_contribution. Absent key = 0.0 (see
## get_affiliation). Written only by _recalculate_total_affiliation(); never
## written directly by card- or investment-handling code.
var _affiliation: Dictionary[StringName, float] = {}

## Per-path card-contribution term (F1): min(count * CARD_AFFILIATION_PER_CHOICE,
## CARD_CONTRIBUTION_MAX). Absent key = 0.0. Written only by
## _recalculate_card_contribution(). Gates invest() per Core Rule 4a — a path
## cannot be invested in while its entry here is <= 0.0.
var _card_contribution: Dictionary[StringName, float] = {}

## Per-path investment-contribution term (F2): cumulative
## resource_spent[path] * INVESTMENT_AFFILIATION_RATE[path], unclamped
## (pre-F3 clamp). Absent key = 0.0. Written only by invest(). Monotonically
## non-decreasing within an era — only reset_era_state() clears it.
var _investment_contribution: Dictionary[StringName, float] = {}

## Per-path tier [0–5]. Absent key = 0 (see get_tier). Monotonically
## non-decreasing within an era — only _check_tier_progression() raises it,
## only reset_era_state() clears it.
var _current_tier: Dictionary[StringName, int] = {}

## The active path (highest affiliation among Tier 1+ paths), or &"" if none.
var _active_path: StringName = &""

## Cached result of the last _update_active_path() computation: the gap
## between the top two Tier-1+ affiliations when currently ambiguous, or
## -1.0 when resolved (or fewer than 2 paths are Tier 1+). Backs
## get_ambiguous_gap() (ADR-0010 §9 Key Interfaces) — not persisted
## (serialize_state()/restore_state() don't round-trip it; it's a pure
## derived-display value, recomputed on the next active-path change).
var _ambiguous_gap: float = -1.0


func _ready() -> void:
	DecisionCardSystem.card_resolved.connect(_on_card_resolved)


## Reacts to every card resolution. Neutral cards (path_tag == &"") are
## ignored. The path counter is already incremented in HistoryFlagManager
## before this handler runs (ADR-0010 §2), so _recalculate_card_contribution()
## reads the fresh value. _recalculate_total_affiliation() folds in the F3
## clamp, tier-progression check, and active-path update (Story
## class-path-full/002 — same consequence chain invest() triggers).
func _on_card_resolved(_card_id: StringName, path_tag: StringName, _option: StringName) -> void:
	if path_tag == &"":
		return
	_recalculate_card_contribution(path_tag)
	_recalculate_total_affiliation(path_tag)


## Card-contribution formula (F1, from the quick-spec):
## min(count * CARD_AFFILIATION_PER_CHOICE, CARD_CONTRIBUTION_MAX).
## Writes _card_contribution only — callers must follow with
## _recalculate_total_affiliation() to fold the result into _affiliation.
func _recalculate_card_contribution(path_id: StringName) -> void:
	var count: int = HistoryFlagManager.get_counter(StringName(String(path_id) + "_choices_count"))
	_card_contribution[path_id] = minf(float(count) * CARD_AFFILIATION_PER_CHOICE, CARD_CONTRIBUTION_MAX)


## Total-affiliation formula (F3, GDD Formulas): sums the F1 card term and
## F2 investment term, clamped to [0.0, 100.0], into _affiliation. Then
## re-runs the same consequence chain the old conflated _recalculate_affiliation()
## triggered inline at both its call sites: tier-progression check and
## active-path update. Called from both _on_card_resolved() and invest()
## (Story class-path-full/002, ADR-0010 §8) so the two contribution sources
## can never desync from the derived total.
func _recalculate_total_affiliation(path_id: StringName) -> void:
	var card: float = _card_contribution.get(path_id, 0.0)
	var investment: float = _investment_contribution.get(path_id, 0.0)
	var usable_investment: float = minf(investment, get_investment_cap(path_id))
	_affiliation[path_id] = clampf(card + usable_investment, 0.0, 100.0)
	_check_tier_progression(path_id)
	_update_active_path()


## Advances [param path_id]'s tier if its affiliation crossed one or more
## thresholds, emitting tier_unlocked once per newly reached tier level, in
## ascending order, never skipping an intermediate tier (GDD AC, Story
## class-path-full/001). Never lowers a tier.
func _check_tier_progression(path_id: StringName) -> void:
	var affil: float = _affiliation.get(path_id, 0.0)
	var old_tier: int = _current_tier.get(path_id, 0)
	var new_tier: int = old_tier
	for t: int in range(old_tier + 1, TIER_THRESHOLDS.size()):
		if affil >= TIER_THRESHOLDS[t]:
			new_tier = t
		else:
			break
	if new_tier > old_tier:
		for t: int in range(old_tier + 1, new_tier + 1):
			_current_tier[path_id] = t
			tier_unlocked.emit(path_id, t)
			if t == 5:
				var card_id: StringName = _SIGNATURE_CARD_TABLE.get(path_id, &"")
				if card_id != &"":
					signature_card_unlocked.emit(card_id)


## Recomputes the active path per GDD F5: among Tier 1+ paths, the highest
## affiliation only wins if it leads the second-highest by at least
## PATH_AFFILIATION_TIE_BREAK_MARGIN; otherwise the state is "ambiguous"
## (&"") — BUG-003 fix (Story class-path-full/003), replacing the old
## strict `>` comparison that let Dictionary iteration order silently pick
## a winner on a near- or exact tie. Tracks only the top two candidates —
## per F5, a third (or further) lower-affiliation Tier 1+ path never
## affects the result. Also refreshes _ambiguous_gap (get_ambiguous_gap()).
## Emits active_path_changed only when the resolved value actually changes.
func _update_active_path() -> void:
	var top_two: Dictionary = _compute_top_two_tier1plus()
	var best_path: StringName = top_two["best_path"]
	var best_affil: float = top_two["best_affil"]
	var second_affil: float = top_two["second_affil"]
	var resolved: StringName = best_path
	var ambiguous: bool = second_affil >= 0.0 and (best_affil - second_affil) < PATH_AFFILIATION_TIE_BREAK_MARGIN
	if ambiguous:
		resolved = &""
	_ambiguous_gap = (best_affil - second_affil) if ambiguous else -1.0
	if resolved != _active_path:
		_active_path = resolved
		active_path_changed.emit(_active_path)


## Shared top-two-candidate scan used by _update_active_path() and
## restore_state() (BUG-003 fix follow-up, code review 2026-07-13 — the gap
## cache must be recomputable without re-deriving _active_path itself, since
## restore_state() trusts the persisted active_path value rather than
## recomputing it, but still needs a correct _ambiguous_gap for a save loaded
## mid-ambiguity). Returns {"best_path": StringName, "best_affil": float,
## "second_affil": float} — see _update_active_path() for the margin logic
## that turns this into a resolved/ambiguous decision.
func _compute_top_two_tier1plus() -> Dictionary:
	var best_path: StringName = &""
	var best_affil: float = -1.0
	var second_affil: float = -1.0
	for path_id: StringName in _affiliation:
		if _current_tier.get(path_id, 0) >= 1:
			var a: float = _affiliation[path_id]
			if a > best_affil:
				second_affil = best_affil
				best_affil = a
				best_path = path_id
			elif a > second_affil:
				second_affil = a
	return {"best_path": best_path, "best_affil": best_affil, "second_affil": second_affil}


## Returns [param path_id]'s current affiliation [0.0–100.0], or 0.0 if the
## path has never gained any. Pure read — no side effects (ADR-0010).
func get_affiliation(path_id: StringName) -> float:
	return _affiliation.get(path_id, 0.0)


## Returns [param path_id]'s current tier [0–5], or 0 if never advanced.
## Pure read — no side effects.
func get_tier(path_id: StringName) -> int:
	return _current_tier.get(path_id, 0)


## Highest tier ever reached on this path across all eras. Current state is
## included so a freshly-earned tier counts before the next burnout persists
## its milestone.
func get_lifetime_best_tier(path_id: StringName) -> int:
	var best: int = get_tier(path_id)
	for tier: int in range(5, 0, -1):
		var flag: StringName = StringName("class_path." + String(path_id) + ".best_tier." + str(tier))
		if HistoryFlagManager.has_milestone(flag):
			best = maxi(best, tier)
			break
	return clampi(best, 0, 5)


## Returns the active path id, or &"" if no path has reached Tier 1.
func get_active_path() -> StringName:
	return _active_path


## Returns the affiliation gap between the top two Tier-1+ paths when
## get_active_path() is currently ambiguous (GDD F5, ADR-0010 §9), or -1.0
## when resolved (a sole path leads by >= PATH_AFFILIATION_TIE_BREAK_MARGIN)
## or when fewer than 2 paths are Tier 1+. Pure read reflecting the last
## _update_active_path() computation — no side effects. Story
## class-path-full/005's Ambiguous UI state consumes this.
func get_ambiguous_gap() -> float:
	return _ambiguous_gap


## Returns whether [param path_id] currently satisfies invest()'s Core Rule
## 4a history gate. It intentionally does not include resource affordability
## or the F6 headroom check; callers read get_investment_headroom() separately.
## Mirrors invest()'s history check exactly. Added
## for Story class-path-full/005: no public query previously exposed this
## private _card_contribution term, and the Class Path Panel's Invest control
## needs it to render a visually-disabled state with an explanatory label
## rather than merely being non-functional. Pure read -- no side effects.
func can_invest(path_id: StringName) -> bool:
	return _card_contribution.get(path_id, 0.0) > 0.0


## Returns the Reach multiplier for [param action_id] under the active path
## at its current tier, or 1.0 when there is no active path or no registered
## bonus. Called by ActionSystem._on_action_timeout() at reward resolution
## (ADR-0010 pull model — this module never calls into ActionSystem).
## Cumulative lookup (2026-07-28 tier-fill revision): the action-keyed entry
## from the highest defining tier <= current tier, multiplied by the
## reach_all_mult effect (pato T5 "all actions ×2") when present.
func get_active_multiplier(action_id: StringName) -> float:
	if _active_path.is_empty():
		return 1.0
	var tier: int = _current_tier.get(_active_path, 0)
	var specific: float = _resolve_action_keyed(_MULTIPLIER_TABLE, _active_path, tier, action_id, 1.0)
	var all_mult: float = float(_resolve_effect(_active_path, tier, &"reach_all_mult", 1.0))
	return specific * all_mult


## Cumulative lookup shared by get_active_multiplier() and
## get_action_duration_multiplier(): scans [param table]'s tiers from [param
## tier] down to 1 and returns the first (= highest-tier) entry defining
## [param action_id] — an exact action key wins over an `&"*"` wildcard at
## the same tier; a wildcard at a higher tier wins over an exact key at a
## lower one (highest-defining-tier-first is the rule, key specificity only
## breaks ties within one tier). Returns [param fallback] when nothing
## defines the action. For _MULTIPLIER_TABLE the values are floats; for
## _TIER_EFFECT_TABLE's duration_mult sub-dicts the same shape applies.
func _resolve_action_keyed(
	table: Dictionary, path_id: StringName, tier: int, action_id: StringName, fallback: float
) -> float:
	var path_entry: Dictionary = table.get(path_id, {})
	for t: int in range(tier, 0, -1):
		var tier_entry: Dictionary = path_entry.get(t, {})
		if tier_entry.has(action_id):
			return float(tier_entry[action_id])
		if tier_entry.has(&"*"):
			return float(tier_entry[&"*"])
	return fallback


## Cumulative scalar-effect lookup against _TIER_EFFECT_TABLE: the value of
## [param effect_key] from the highest tier <= [param tier] that defines it,
## or [param fallback]. Pure read — shared by every effect getter below and
## (via get_tier_effect_data) the Class Path Panel's legibility rendering.
func _resolve_effect(path_id: StringName, tier: int, effect_key: StringName, fallback: Variant) -> Variant:
	var path_entry: Dictionary = _TIER_EFFECT_TABLE.get(path_id, {})
	for t: int in range(tier, 0, -1):
		var tier_entry: Dictionary = path_entry.get(t, {})
		if tier_entry.has(effect_key):
			return tier_entry[effect_key]
	return fallback


## Returns the active path's T3-interlock secondary yield for [param
## action_id] on completion — e.g. pato T3+: drama also yields {Sponsors: 3}
## — or {} when there is no active path / no yield for this action. The
## caller (ActionSystem) merges these into the completion deltas; Sponsors
## amounts are further scaled there by get_sponsor_income_multiplier().
func get_secondary_yield(action_id: StringName) -> Dictionary:
	if _active_path.is_empty():
		return {}
	var tier: int = _current_tier.get(_active_path, 0)
	var yields: Dictionary = _resolve_effect(_active_path, tier, &"secondary_yield", {})
	return yields.get(action_id, {})


## Returns the active path's duration multiplier for [param action_id]
## (T4 power spikes — e.g. pato T4 drama 9s -> 6s == 2/3; biznesmen T4 all
## actions ×0.75), or 1.0 when there is no active path / no registered cut.
## Called by ActionSystem.start_action() when arming the timer.
func get_action_duration_multiplier(action_id: StringName) -> float:
	if _active_path.is_empty():
		return 1.0
	var tier: int = _current_tier.get(_active_path, 0)
	var path_entry: Dictionary = _TIER_EFFECT_TABLE.get(_active_path, {})
	for t: int in range(tier, 0, -1):
		var durations: Dictionary = path_entry.get(t, {}).get(&"duration_mult", {})
		if durations.has(action_id):
			return float(durations[action_id])
		if durations.has(&"*"):
			return float(durations[&"*"])
	return 1.0


## Scalar effect getters — all follow the same contract: the active path's
## cumulative effect value, or the neutral default when there is no active
## path / the effect is not defined at any tier <= current. Pure reads,
## pull-model consumers only (ADR-0010): ActionSystem (cringe/morale-cost),
## DecisionCardSystem (sponsor income), OfflineProgressSystem (drain/haters/
## floor).
func get_cringe_gain_multiplier() -> float:
	return _active_scalar(&"cringe_gain_mult", 1.0)


func get_sponsor_income_multiplier() -> float:
	return _active_scalar(&"sponsor_income_mult", 1.0)


func get_morale_cost_multiplier() -> float:
	return _active_scalar(&"morale_cost_mult", 1.0)


func get_morale_drain_multiplier() -> float:
	return _active_scalar(&"morale_drain_mult", 1.0)


func get_haters_growth_multiplier() -> float:
	return _active_scalar(&"haters_growth_mult", 1.0)


## Morale floor (ekspert T5): AMBIENT drain never takes Morale below this
## while the path is active — consumed only by OfflineProgressSystem's drain
## loop (the game's sole ambient-drain site). Deliberately NOT wired into
## ResourceManager.apply_delta(): a live clamp there would make Morale spends
## (including ekspert's own Morale-priced invest()) free at the floor.
## 0.0 (no-op) by default.
func get_morale_floor() -> float:
	return _active_scalar(&"morale_floor", 0.0)


func _active_scalar(effect_key: StringName, fallback: float) -> float:
	if _active_path.is_empty():
		return fallback
	var tier: int = _current_tier.get(_active_path, 0)
	return float(_resolve_effect(_active_path, tier, effect_key, fallback))


## Raw per-tier effect data for [param path_id] at exactly [param tier] —
## NOT cumulative, NOT gated on the active path: {reach_mults: {action: mult},
## effects: {effect_key: value}}. Presentation-layer feed for the Class Path
## Panel's legibility rendering (Pillar 1 fix, playtest 12-3): the panel
## formats these into human-readable per-tier bonus lines (display names live
## UI-side — this module never references ActionSystem, ADR-0010).
func get_tier_effect_data(path_id: StringName, tier: int) -> Dictionary:
	return {
		"reach_mults": _MULTIPLIER_TABLE.get(path_id, {}).get(tier, {}),
		"effects": _TIER_EFFECT_TABLE.get(path_id, {}).get(tier, {}),
	}


## Spends [param amount] of [param resource_id] to buy [param path_id]
## investment-contribution (F2, GDD Formulas / ADR-0010 §8). Gated on Core
## Rule 4a: rejected (no resource deducted, no affiliation change) unless
## the path already has card_contribution > 0, i.e. the player has made at
## least one path-tagged card choice this era. Also rejected if the player
## cannot afford [param amount] of [param resource_id] — no side effects on
## rejection either way. Otherwise deducts the resource via
## ResourceManager.apply_delta(), adds amount * INVESTMENT_AFFILIATION_RATE[path]
## to _investment_contribution[path_id], and folds the result into
## _affiliation via _recalculate_total_affiliation() (F3 clamp + tier
## progression + active-path update). Returns true on success.
##
## Investment is also rejected without deduction when the requested gain
## exceeds the decision-backed headroom exposed by get_investment_headroom().
## This prevents offline stockpiles from pre-buying future card-history tiers.
##
## Example:
##   var ok: bool = ClassPathSystem.invest(&"pato_streamer", &"Cringe", 200.0)
func get_investment_cap(path_id: StringName) -> float:
	var card: float = _card_contribution.get(path_id, 0.0)
	return minf(100.0 - card, PATH_INVESTMENT_HISTORY_BASE + card)


func get_investment_headroom(path_id: StringName) -> float:
	return maxf(get_investment_cap(path_id) - _investment_contribution.get(path_id, 0.0), 0.0)


func invest(path_id: StringName, resource_id: StringName, amount: float) -> bool:
	if _card_contribution.get(path_id, 0.0) <= 0.0:  # gate — Core Rule 4a
		return false
	if not is_finite(amount) or amount < 0.0 or _INVESTMENT_RESOURCE_TABLE.get(path_id, &"") != resource_id:
		return false
	var rate: float = _INVESTMENT_RATE_TABLE.get(path_id, 0.0)
	var requested_gain: float = amount * rate
	# Never deduct resources for progress that current card history cannot use.
	# The UI invests in one-point steps, while this defensive check also keeps
	# direct/system calls from pre-banking progress for future choices.
	if not is_finite(requested_gain) or requested_gain > get_investment_headroom(path_id):
		return false
	if ResourceManager.get_resource(resource_id) < amount:  # can't afford
		return false
	var deltas: Dictionary[StringName, float] = {resource_id: -amount}
	ResourceManager.apply_delta(deltas)
	_investment_contribution[path_id] = _investment_contribution.get(path_id, 0.0) + amount * rate
	_recalculate_total_affiliation(path_id)  # F3 clamp, then _check_tier_progression + _update_active_path
	return true


## Restores persisted affiliation/tier/active-path state from [param data]
## (as written by SaveSystem). Missing keys default to zero state — the
## first-session `{}` case is safe per ADR-0003's restore_state() contract.
## Restores _card_contribution/_investment_contribution (Story
## class-path-full/002) alongside the F3-derived _affiliation total — without
## this, a save/load followed by the next card resolution on a path would
## silently recompute _affiliation from a zeroed _investment_contribution,
## discarding prior investment with no error (found in code review,
## 2026-07-13). _card_contribution alone would eventually self-heal from
## HistoryFlagManager's counter on the next card resolve, but restoring it
## directly also closes the narrower gap where invest()'s Core Rule 4a gate
## would otherwise incorrectly reject a path with real prior card history
## until that next resolve.
func restore_state(data: Dictionary) -> void:
	var affil_in: Dictionary = data.get("affiliation", {})
	for key: String in affil_in:
		_affiliation[StringName(key)] = float(affil_in[key])
	var card_in: Dictionary = data.get("card_contribution", {})
	for key: String in card_in:
		_card_contribution[StringName(key)] = float(card_in[key])
	var investment_in: Dictionary = data.get("investment_contribution", {})
	for key: String in investment_in:
		_investment_contribution[StringName(key)] = float(investment_in[key])
	var tier_in: Dictionary = data.get("current_tier", {})
	for key: String in tier_in:
		_current_tier[StringName(key)] = int(tier_in[key])
	_active_path = StringName(data.get("active_path", ""))
	# F6 migration: older saves may contain affiliation/tier values bought
	# before the decision-backed ceiling existed. Re-derive both canonical
	# values without unlock signals; grandfathering them would preserve the
	# exact offline-stockpile skip this rule closes.
	for path_id: StringName in _card_contribution:
		var card: float = _card_contribution.get(path_id, 0.0)
		var usable_investment: float = minf(
			_investment_contribution.get(path_id, 0.0), get_investment_cap(path_id)
		)
		var migrated_affiliation: float = clampf(card + usable_investment, 0.0, 100.0)
		_affiliation[path_id] = migrated_affiliation
		var migrated_tier: int = 0
		for tier: int in range(1, TIER_THRESHOLDS.size()):
			if migrated_affiliation >= TIER_THRESHOLDS[tier]:
				migrated_tier = tier
			else:
				break
		_current_tier[path_id] = migrated_tier
	_update_active_path()
	# Recompute _ambiguous_gap from the just-restored affiliation/tier data —
	# without this, a save loaded mid-ambiguity would report get_ambiguous_gap()
	# == -1.0 (field-initializer default) until the next card resolution or
	# invest() call, contradicting its documented "reflects the last computed
	# state" contract (found in code review, 2026-07-13). _active_path itself
	# is trusted directly from [param data], not re-derived here — this only
	# fixes the derived display cache alongside it.
	var top_two: Dictionary = _compute_top_two_tier1plus()
	var best_affil: float = top_two["best_affil"]
	var second_affil: float = top_two["second_affil"]
	var ambiguous: bool = second_affil >= 0.0 and (best_affil - second_affil) < PATH_AFFILIATION_TIE_BREAK_MARGIN
	_ambiguous_gap = (best_affil - second_affil) if ambiguous else -1.0


## Returns this module's persisted state as a JSON-serializable Dictionary
## (plain String keys — StringName is not a JSON type), mirroring
## HistoryFlagManager.serialize_state()'s convention. Read by SaveSystem.
## Includes card_contribution/investment_contribution (Story
## class-path-full/002) alongside the derived affiliation total — see
## restore_state()'s doc comment for why both terms must round-trip.
func serialize_state() -> Dictionary:
	var affil_out: Dictionary = {}
	for key: StringName in _affiliation:
		affil_out[String(key)] = _affiliation[key]
	var card_out: Dictionary = {}
	for key: StringName in _card_contribution:
		card_out[String(key)] = _card_contribution[key]
	var investment_out: Dictionary = {}
	for key: StringName in _investment_contribution:
		investment_out[String(key)] = _investment_contribution[key]
	var tier_out: Dictionary = {}
	for key: StringName in _current_tier:
		tier_out[String(key)] = _current_tier[key]
	return {
		"affiliation": affil_out,
		"card_contribution": card_out,
		"investment_contribution": investment_out,
		"current_tier": tier_out,
		"active_path": String(_active_path),
	}


## Clears both era-local and derived class-path state for New Game without
## writing the permanent best-tier milestones created by an era prestige.
func reset_for_new_game() -> void:
	_affiliation.clear()
	_card_contribution.clear()
	_investment_contribution.clear()
	_current_tier.clear()
	_ambiguous_gap = -1.0
	if _active_path != &"":
		_active_path = &""
		active_path_changed.emit(&"")


## Resets all era-local path state: affiliation, tiers, and the per-path
## choice counters in HistoryFlagManager. Permanent meta milestone flags
## (class_path.{path}.best_tier.{N}, class_path.{path}.era_completed) are
## written BEFORE clearing, so they survive the reset (quick-spec Era Reset
## table). MVP: callable from debug/tests only; Alpha: BurnoutSystem wires
## its era_transitioned signal to this method (deferred per ADR-0010 §6).
func reset_era_state() -> void:
	# Iterates the UNION of _affiliation and _current_tier keys, not just
	# _affiliation. _current_tier only gains a path_id once it first reaches
	# Tier 1+ (a path that resolved cards but stayed at Tier 0 has an
	# _affiliation entry with no _current_tier entry) — every such path still
	# needs its HistoryFlagManager counter reset below, so _affiliation alone
	# is the broader, correct set for that. But restore_state() loads the two
	# dicts independently from a save payload's keys, so a saved current_tier
	# entry could in principle exist without a matching affiliation entry;
	# iterating the union (not either dict alone) is the only version safe
	# against both gaps (revised in code review, 2026-07-13 — an earlier fix
	# that iterated _current_tier alone regressed the Tier-0 counter-reset
	# case caught by test_era_reset_clears_all_paths_not_just_active).
	var all_path_ids: Dictionary = {}
	for path_id: StringName in _affiliation:
		all_path_ids[path_id] = true
	for path_id: StringName in _current_tier:
		all_path_ids[path_id] = true
	for path_id: StringName in all_path_ids:
		var tier: int = _current_tier.get(path_id, 0)
		for t: int in range(1, tier + 1):
			HistoryFlagManager.set_milestone(StringName("class_path." + String(path_id) + ".best_tier." + str(t)))
		if tier == 5:
			var card_id: StringName = _SIGNATURE_CARD_TABLE.get(path_id, &"")
			if card_id != &"":
				signature_card_removed.emit(card_id)
		if _active_path == path_id:
			HistoryFlagManager.set_milestone(StringName("class_path." + String(path_id) + ".era_completed"))
		HistoryFlagManager.reset_counter(StringName(String(path_id) + "_choices_count"))
	_affiliation.clear()
	_card_contribution.clear()
	_investment_contribution.clear()
	_current_tier.clear()
	_ambiguous_gap = -1.0  # nothing is Tier 1+ anymore, so nothing can be ambiguous
	# Same emit-only-on-change contract as _update_active_path() — a reset with
	# no active path (nothing ever reached Tier 1) emits nothing.
	if _active_path != &"":
		_active_path = &""
		active_path_changed.emit(&"")
