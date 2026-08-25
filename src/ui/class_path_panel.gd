## ClassPathPanel is the dedicated full-screen Class Path UI (Story
## class-path-full/005, GDD `design/gdd/class-path-system.md` §UI
## Requirements). Per that GDD section it is explicitly NOT a pop-up -- the
## player navigates to it -- but this project has no separate "screen stack"
## system yet, so it reuses the established "instanced sibling, toggled
## `visible`" pattern already shipped by SettingsScreen/CardScreen (same
## shell convention), with an OPAQUE background rather than SettingsScreen's
## translucent modal backdrop, so it reads as its own screen rather than a
## dialog floating over the Action Screen.
##
## Shows all 4 registered class paths simultaneously (Core Rule 1 -- never
## hidden, even at zero affiliation), each as an always-expanded card: name,
## tier badge, affiliation bar + numeric readout, a status line, and an
## Invest control. Presentation-only: every value comes from ClassPathSystem's
## existing read-only query surface (get_affiliation/get_tier/get_active_path/
## get_ambiguous_gap/can_invest) plus invest() as the sole write call, wired
## directly to each row's Invest Button.pressed signal (no intermediate
## signal layer -- same "Button wired directly to Autoload" convention as
## action_grid.gd's unlocked slots).
##
## Ambiguous-pair detection: ClassPathSystem exposes THAT the active path is
## ambiguous (get_active_path() == &"" plus get_ambiguous_gap() >= 0.0) but
## not WHICH two paths are tied. _compute_ambiguous_pair() re-derives the
## top-two Tier-1+ paths by affiliation from the public get_affiliation()/
## get_tier() getters -- a pure presentational duplication of
## ClassPathSystem's own top-two scan, needed only to decide which 2 of the 4
## cards get the ambiguous label. The actual ambiguous/resolved DECISION
## stays fully owned by ClassPathSystem; this method never influences it.
##
## Layout note: the Invest Button and its disabled-state explanation Label
## are SEPARATE full-width children directly in each row's VBoxContainer, not
## nested together in an HBoxContainer. This deliberately avoids the exact
## autowrap-in-HBox collapse bug documented in action_grid.gd's
## _configure_locked_slots()/_activate_gated_slot() history (an autowrapping
## Label inside an HBox collapses to ~0 width and wraps one character per
## line) -- there is no reparenting here, so the bug class cannot occur.
##
## No `_process()` -- entirely event-driven: refreshes on
## ClassPathSystem.tier_unlocked / active_path_changed / signature_card_unlocked
## (Implementation Notes' explicit signal list) and once more whenever this
## panel becomes visible (mirrors SettingsScreen's own resync-on-visible
## pattern) -- the latter is required because invest() alone does not emit
## any of those 3 signals when it changes affiliation without crossing a
## tier or breaking a tie, so a panel left open across an invest() tap
## refreshes explicitly from the button handler instead; the visibility
## resync instead covers card resolutions that happened while the panel was
## closed.
##
## Usage: instanced as a sibling under ActionScreen's root
## (res://scenes/action_screen/action_screen.tscn), opened by ActionScreen's
## PathButton via a plain `visible = true` flip (same untyped-caller
## convention as SettingsScreen, for the same headless-global-class-cache
## reason documented on that script).
class_name ClassPathPanel
extends Control

## ADR-0014: emitted when the Close button is tapped — the MainNavCoordinator
## (action_screen.gd) consumes this and owns the actual visible flip.
signal close_requested

## The 4 registered paths, in fixed display order (Row1..Row4). Matches the
## order used everywhere else in this codebase (ClassPathSystem's
## _MULTIPLIER_TABLE / _INVESTMENT_RATE_TABLE / _SIGNATURE_CARD_TABLE).
const PATH_IDS: Array[StringName] = [
	&"pato_streamer", &"guru_celebryta", &"ekspert_niszowy", &"biznesmen_contentu",
]

## Stable localization keys for neutral path names. Internal ids remain the
## gameplay contract; translated display text never drives mechanics.
const _DISPLAY_NAME_KEYS: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"META_PATH_PATO_STREAMER",
	&"guru_celebryta": &"META_PATH_GURU_CELEBRYTA",
	&"ekspert_niszowy": &"META_PATH_EKSPERT_NISZOWY",
	&"biznesmen_contentu": &"META_PATH_BIZNESMEN_CONTENTU",
}

const _RESOURCE_NAME_KEYS: Dictionary[StringName, StringName] = {
	&"Cringe": &"META_RESOURCE_CRINGE",
	&"Sponsors": &"META_RESOURCE_SPONSORS",
	&"Morale": &"META_RESOURCE_MORALE",
	&"Reach": &"META_RESOURCE_REACH",
	&"Haters": &"META_RESOURCE_HATERS",
}

## Per-path investment resource id (GDD `design/quick-specs/
## class-path-system-2026-07-01.md` §Investment Cost Scale).
const _RESOURCE_TABLE: Dictionary[StringName, StringName] = {
	&"pato_streamer": &"Cringe",
	&"guru_celebryta": &"Sponsors",
	&"ekspert_niszowy": &"Morale",
	&"biznesmen_contentu": &"Reach",
}

## Per-path fixed per-tap invest amount -- the reciprocal of ClassPathSystem's
## private _INVESTMENT_RATE_TABLE, chosen so every tap yields a clean +1.0
## affiliation regardless of path (GDD UI Requirements: "fixed-increment-per-
## tap... live preview of that tap's marginal affiliation gain"). Sourced
## directly from the same Investment Cost Scale table _RESOURCE_TABLE above
## reads from -- not an independently invented value.
const _INVEST_AMOUNT: Dictionary[StringName, float] = {
	&"pato_streamer": 10.0,
	&"guru_celebryta": 5.0,
	&"ekspert_niszowy": 8.0,
	&"biznesmen_contentu": 50.0,
}

## Marginal affiliation gained per Invest tap -- constant across all 4 paths
## by construction (_INVEST_AMOUNT[path] * ClassPathSystem's private
## per-path rate == 1.0 for all 4 entries). Used only for the button's
## preview text.
const _INVEST_PREVIEW_GAIN: float = 1.0

@onready var _close_button: Button = %CloseButton
@onready var _name_labels: Array[Label] = [%Row1NameLabel, %Row2NameLabel, %Row3NameLabel, %Row4NameLabel]
@onready var _tier_labels: Array[Label] = [%Row1TierLabel, %Row2TierLabel, %Row3TierLabel, %Row4TierLabel]
@onready var _affiliation_bars: Array[ProgressBar] = [
	%Row1AffiliationBar, %Row2AffiliationBar, %Row3AffiliationBar, %Row4AffiliationBar,
]
@onready var _affiliation_value_labels: Array[Label] = [
	%Row1AffiliationValueLabel, %Row2AffiliationValueLabel,
	%Row3AffiliationValueLabel, %Row4AffiliationValueLabel,
]
@onready var _status_labels: Array[Label] = [%Row1StatusLabel, %Row2StatusLabel, %Row3StatusLabel, %Row4StatusLabel]
@onready var _bonus_labels: Array[Label] = [%Row1BonusLabel, %Row2BonusLabel, %Row3BonusLabel, %Row4BonusLabel]
@onready var _invest_buttons: Array[Button] = [%Row1InvestButton, %Row2InvestButton, %Row3InvestButton, %Row4InvestButton]
@onready var _invest_explanation_labels: Array[Label] = [
	%Row1InvestExplanationLabel, %Row2InvestExplanationLabel,
	%Row3InvestExplanationLabel, %Row4InvestExplanationLabel,
]


func _ready() -> void:
	visible = false
	for label: Label in (
		_name_labels + _tier_labels + _affiliation_value_labels + _status_labels
		+ _bonus_labels + _invest_explanation_labels
	):
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	for button: Button in _invest_buttons:
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	visibility_changed.connect(_on_visibility_changed)
	_close_button.pressed.connect(_on_close_pressed)
	for i in PATH_IDS.size():
		_invest_buttons[i].pressed.connect(_on_invest_pressed.bind(i))
	ClassPathSystem.tier_unlocked.connect(_on_class_path_state_changed)
	ClassPathSystem.active_path_changed.connect(_on_active_path_changed)
	ClassPathSystem.signature_card_unlocked.connect(_on_signature_card_unlocked)
	SettingsSystem.language_changed.connect(_on_language_changed)


func _on_visibility_changed() -> void:
	if visible:
		_refresh_all()


func _on_close_pressed() -> void:
	# ADR-0014: the coordinator owns visibility — this panel only REQUESTS
	# closing (was `visible = false`, the documented bypass bug).
	close_requested.emit()


func _on_class_path_state_changed(_path_id: StringName, _tier: int) -> void:
	if visible:
		_refresh_all()


func _on_active_path_changed(_path_id: StringName) -> void:
	if visible:
		_refresh_all()


func _on_signature_card_unlocked(_card_id: StringName) -> void:
	if visible:
		_refresh_all()


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	if visible:
		_refresh_all()


## Handles a tap on row [param i]'s Invest button: spends this path's fixed
## per-tap resource amount via ClassPathSystem.invest(), then unconditionally
## refreshes -- invest() emits no dedicated "affiliation changed" signal of
## its own (only tier_unlocked/active_path_changed on threshold crossings),
## so a plain affiliation gain that crosses no threshold would otherwise
## leave the bar/label stale until some other signal fired.
func _on_invest_pressed(i: int) -> void:
	var path_id: StringName = PATH_IDS[i]
	var resource_id: StringName = _RESOURCE_TABLE[path_id]
	var amount: float = _INVEST_AMOUNT[path_id]
	ClassPathSystem.invest(path_id, resource_id, amount)
	_refresh_all()


## Rebuilds every row's affiliation bar/value/tier/status/Invest control from
## ClassPathSystem's current state. O(4) work, event-driven only (see class
## doc comment) -- never called from _process().
func _refresh_all() -> void:
	var ambiguous_pair: Array[StringName] = _compute_ambiguous_pair()
	var active_path: StringName = ClassPathSystem.get_active_path()
	var full_affiliation: float = ClassPathSystem.TIER_THRESHOLDS.back()  # 100.0 -- F3 clamp ceiling
	for i in PATH_IDS.size():
		var path_id: StringName = PATH_IDS[i]
		var affiliation: float = ClassPathSystem.get_affiliation(path_id)
		var tier: int = ClassPathSystem.get_tier(path_id)

		_name_labels[i].text = _path_name(path_id)
		_affiliation_bars[i].value = affiliation
		_affiliation_value_labels[i].text = "%d / %d" % [int(affiliation), int(full_affiliation)]
		_tier_labels[i].text = "T%d" % tier

		_status_labels[i].text = _status_text(path_id, tier, active_path, ambiguous_pair)
		_refresh_bonus_label(i, path_id, tier)
		_refresh_invest_control(i, path_id, affiliation, full_affiliation)


## Builds row [param path_id]'s status line. Neutral, mechanical language
## only -- Core Rule 8 / Anti-Pillar: never "good"/"evil"/"moral" or an
## equivalent value judgment.
func _status_text(
	path_id: StringName, tier: int, active_path: StringName, ambiguous_pair: Array[StringName]
) -> String:
	if ambiguous_pair.has(path_id):
		var gap: float = ClassPathSystem.get_ambiguous_gap()
		return tr("META_PATH_STATUS_AMBIGUOUS") % gap
	if tier == 0:
		return ""
	if path_id == active_path:
		return tr("META_PATH_STATUS_ACTIVE") % tier
	return tr("META_PATH_STATUS_SECONDARY") % tier


## Sets row [param i]'s Invest button text/disabled state and explanation
## label per the GDD's two documented disabled cases (UI Requirements §Invest
## control): `can_invest() == false` (Core Rule 4a gate, this story's
## required AC-4) and `affiliation >= 100.0` (F3 clamp cap -- GDD-documented,
## included here as it is a pure read against an existing getter, though not
## itself one of this story's 5 required ACs).
func _refresh_invest_control(i: int, path_id: StringName, affiliation: float, full_affiliation: float) -> void:
	var button: Button = _invest_buttons[i]
	var explanation: Label = _invest_explanation_labels[i]
	if not ClassPathSystem.can_invest(path_id):
		button.disabled = true
		button.text = tr("META_PATH_INVEST")
		explanation.text = tr("META_PATH_INVEST_CHOICE_FIRST") % _path_name(path_id)
		explanation.visible = true
	elif ClassPathSystem.get_investment_headroom(path_id) < _INVEST_PREVIEW_GAIN:
		button.disabled = true
		button.text = tr("META_PATH_INVEST")
		explanation.text = (
			tr("META_PATH_INVEST_FULL")
			if affiliation >= full_affiliation
			else tr("META_PATH_INVEST_RAISE_LIMIT") % _path_name(path_id)
		)
		explanation.visible = true
	else:
		button.disabled = false
		var amount: float = _INVEST_AMOUNT[path_id]
		var resource_id: StringName = _RESOURCE_TABLE[path_id]
		button.text = tr("META_PATH_INVEST_FORMAT") % [
			int(amount), _resource_name(resource_id), _INVEST_PREVIEW_GAIN,
		]
		explanation.visible = false


## Fills row [param i]'s bonus label: one line per unlocked tier (1..tier)
## with CONCRETE numbers, plus a next-tier teaser line — the Pillar 1
## legibility fix from playtest 12-3 ("Tier N active" with no values
## answered "what do I get?" with nothing). Tier lines render for every
## path regardless of active state (the status line above already says
## whether they're in effect); hidden entirely at Tier 0 with no teaser
## suppression — a Tier-0 path still teases T1 so the ladder is visible
## before the first threshold.
func _refresh_bonus_label(i: int, path_id: StringName, tier: int) -> void:
	var lines: Array[String] = []
	for t: int in range(1, tier + 1):
		var desc: String = _describe_tier(path_id, t)
		if desc != "":
			lines.append(tr("META_PATH_TIER_BONUS") % [t, desc])
	if tier < 5:
		var teaser: String = _describe_tier(path_id, tier + 1)
		if teaser != "":
			lines.append(tr("META_PATH_NEXT_TIER") % [tier + 1, teaser])
	_bonus_labels[i].text = "\n".join(lines)
	_bonus_labels[i].visible = not lines.is_empty()


## One human-readable line for [param path_id]'s tier [param tier] from
## ClassPathSystem.get_tier_effect_data() — raw per-tier data formatted with
## action display names (UI-side lookup; ClassPathSystem never references
## ActionSystem, ADR-0010). Deadpan number-first phrasing per art-bible §1.
func _describe_tier(path_id: StringName, tier: int) -> String:
	var data: Dictionary = ClassPathSystem.get_tier_effect_data(path_id, tier)
	var parts: Array[String] = []
	var reach_mults: Dictionary = data["reach_mults"]
	for action_id: StringName in reach_mults:
		parts.append(tr("META_PATH_EFFECT_ACTION_REACH") % [_action_name(action_id), _fmt(reach_mults[action_id])])
	var effects: Dictionary = data["effects"]
	for effect_key: StringName in effects:
		var value: Variant = effects[effect_key]
		match effect_key:
			&"secondary_yield":
				for action_id: StringName in value:
					for resource_id: StringName in value[action_id]:
						parts.append(tr("META_PATH_EFFECT_SECONDARY_YIELD") % [
							_action_name(action_id), int(value[action_id][resource_id]), _resource_name(resource_id),
						])
			&"duration_mult":
				for action_id: StringName in value:
					var label: String = tr("META_PATH_ALL_ACTIONS") if action_id == &"*" else _action_name(action_id)
					parts.append(tr("META_PATH_EFFECT_DURATION") % [label, _fmt(value[action_id])])
			&"reach_all_mult":
				parts.append(tr("META_PATH_EFFECT_ALL_REACH") % _fmt(value))
			&"cringe_gain_mult":
				parts.append(tr("META_PATH_EFFECT_CRINGE_GAIN") % _fmt(value))
			&"sponsor_income_mult":
				parts.append(tr("META_PATH_EFFECT_SPONSOR_INCOME") % _fmt(value))
			&"morale_cost_mult":
				parts.append(tr("META_PATH_EFFECT_MORALE_COST") % _fmt(value))
			&"morale_drain_mult":
				parts.append(tr("META_PATH_EFFECT_MORALE_DRAIN") % _fmt(value))
			&"haters_growth_mult":
				parts.append(tr("META_PATH_EFFECT_HATERS_GROWTH") % _fmt(value))
			&"morale_floor":
				parts.append(tr("META_PATH_EFFECT_MORALE_FLOOR") % int(value))
	if tier == 5:
		parts.append(tr("META_PATH_SIGNATURE_CARD"))
	return ", ".join(parts)


func _action_name(action_id: StringName) -> String:
	var localization_key: String = "ACTION_%s_LABEL" % String(action_id).to_upper()
	var localized: String = tr(localization_key)
	return localized if localized != localization_key else ActionSystem.ACTION_DISPLAY_NAMES.get(action_id, String(action_id))


func _path_name(path_id: StringName) -> String:
	var key: StringName = _DISPLAY_NAME_KEYS.get(path_id, &"")
	return tr(key) if not key.is_empty() else String(path_id)


func _resource_name(resource_id: StringName) -> String:
	var key: StringName = _RESOURCE_NAME_KEYS.get(resource_id, &"")
	return tr(key) if not key.is_empty() else String(resource_id)


## Compact multiplier formatting: 1.6 -> "1.6", 2.0 -> "2", 0.6667 -> "0.67".
func _fmt(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	var two_places: float = snappedf(value, 0.01)
	return ("%.2f" % two_places).rstrip("0").rstrip(".")


## Re-derives the top-two Tier-1+ paths by affiliation from the public
## get_affiliation()/get_tier() getters -- the same top-two scan
## ClassPathSystem's own private _compute_top_two_tier1plus() performs, but
## read-only and re-expressed against public API only (see class doc comment
## for why this duplication exists). Returns an empty array unless
## ClassPathSystem currently reports an ambiguous state
## (get_active_path() == &"" and get_ambiguous_gap() >= 0.0); returns exactly
## the 2 tied path ids otherwise.
func _compute_ambiguous_pair() -> Array[StringName]:
	if ClassPathSystem.get_active_path() != &"" or ClassPathSystem.get_ambiguous_gap() < 0.0:
		return []
	var best_path: StringName = &""
	var best_affil: float = -1.0
	var second_path: StringName = &""
	var second_affil: float = -1.0
	for path_id: StringName in PATH_IDS:
		if ClassPathSystem.get_tier(path_id) < 1:
			continue
		var affil: float = ClassPathSystem.get_affiliation(path_id)
		if affil > best_affil:
			second_path = best_path
			second_affil = best_affil
			best_path = path_id
			best_affil = affil
		elif affil > second_affil:
			second_path = path_id
			second_affil = affil
	if best_path == &"" or second_path == &"":
		return []
	return [best_path, second_path]
