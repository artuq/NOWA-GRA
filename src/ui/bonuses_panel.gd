## BonusesPanel — the permanent META_BONUS visibility screen (design/ux/
## meta-bonus-visibility.md, APPROVED 2026-07-22; ADR-0014's third
## coordinated panel). The only view answering "what did I actually build
## that survives every reset" — Core Rule 5's permanence made visible.
##
## Read-only: every value pulls from PrestigeSystem.get_meta_bonus_total() /
## get_era_count() and PrestigeFormulas.META_BONUS_MAX (no writes, no new
## API). 4 rows always visible — the 0-era state shows zeros, never hides or
## gates a row (spec States: Empty is a normal starting state, not an error).
##
## Fresh-grant highlight (spec Transitions): rows whose total changed since
## the panel was last closed get a one-shot opacity-only background pulse on
## open — UI-side bookkeeping (_last_seen), no PrestigeSystem API. Opacity-
## only is reduce-motion-safe by construction (spec: no extra branch needed).
##
## Same shell convention as ClassPathPanel: instanced sibling in
## action_screen.tscn, visible-toggled, opaque background, close_requested
## signal consumed by the MainNavCoordinator (never self-sets visible —
## ADR-0014's day-one contract, no bypass bug to ever fix here).
## Deliberately NO class_name — same headless-global-class-cache rationale
## documented on settings_screen.gd (untyped-caller convention).
extends Control

signal close_requested

## Display order + per-type presentation (spec Information Hierarchy:
## humanized name ≤18 chars EN, value format %/flat, origin path for
## discoverability). Static UI content, not game state.
const _ROWS: Array[Dictionary] = [
	{
		"type": &"META_REACH_MULT",
		"label": "Permanent Reach",
		"origin": "from Trash Streamer eras",
		"is_percent": true,
	},
	{
		"type": &"META_SPONSOR_MULT",
		"label": "Sponsor income",
		"origin": "from Guru Celeb eras",
		"is_percent": true,
	},
	{
		"type": &"META_HATERS_RESIST",
		"label": "Haters resistance",
		"origin": "from Niche Expert eras",
		"is_percent": true,
	},
	{
		"type": &"META_SPONSOR_FLOOR",
		"label": "Sponsor floor",
		"origin": "from Content Mogul eras",
		"is_percent": false,
	},
]

## Highlight pulse: row background flashes to this alpha and decays back.
## Opacity-only (spec: reduce-motion-safe without a separate branch).
const _PULSE_ALPHA: float = 0.45
const _PULSE_DECAY_SEC: float = 0.9

@onready var _close_button: Button = %CloseButton
@onready var _era_count_label: Label = %EraCountLabel
@onready var _row_containers: Array[PanelContainer] = [%Row1, %Row2, %Row3, %Row4]
@onready var _name_labels: Array[Label] = [%Row1NameLabel, %Row2NameLabel, %Row3NameLabel, %Row4NameLabel]
@onready var _value_labels: Array[Label] = [%Row1ValueLabel, %Row2ValueLabel, %Row3ValueLabel, %Row4ValueLabel]
@onready var _origin_labels: Array[Label] = [%Row1OriginLabel, %Row2OriginLabel, %Row3OriginLabel, %Row4OriginLabel]
@onready var _progress_bars: Array[ProgressBar] = [%Row1ProgressBar, %Row2ProgressBar, %Row3ProgressBar, %Row4ProgressBar]
@onready var _max_labels: Array[Label] = [%Row1MaxLabel, %Row2MaxLabel, %Row3MaxLabel, %Row4MaxLabel]

## Last totals seen when the panel was last CLOSED (or session start) —
## the diff base for the fresh-grant highlight. Keyed by bonus type.
var _last_seen: Dictionary[StringName, float] = {}

var _pulse_tweens: Array[Tween] = []


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(func() -> void: close_requested.emit())
	visibility_changed.connect(_on_visibility_changed)
	for i in _ROWS.size():
		_name_labels[i].text = _ROWS[i]["label"]
		_origin_labels[i].text = _ROWS[i]["origin"]
		_last_seen[_ROWS[i]["type"]] = PrestigeSystem.get_meta_bonus_total(_ROWS[i]["type"])


func _on_visibility_changed() -> void:
	if visible:
		var fresh: Array[StringName] = _compute_fresh_types()
		_refresh_all()
		_pulse_rows(fresh)
	else:
		# Closing commits the diff base: everything currently shown counts as
		# "seen" — the next fresh-grant diff starts from here.
		for row: Dictionary in _ROWS:
			_last_seen[row["type"]] = PrestigeSystem.get_meta_bonus_total(row["type"])


## Types whose total changed since the panel was last closed. Pure read —
## split out from the pulse so tests can assert the diff without tweens.
func _compute_fresh_types() -> Array[StringName]:
	var fresh: Array[StringName] = []
	for row: Dictionary in _ROWS:
		var bonus_type: StringName = row["type"]
		if not is_equal_approx(PrestigeSystem.get_meta_bonus_total(bonus_type), _last_seen.get(bonus_type, 0.0)):
			fresh.append(bonus_type)
	return fresh


func _refresh_all() -> void:
	_era_count_label.text = "Eras completed: %d" % PrestigeSystem.get_era_count()
	for i in _ROWS.size():
		var row: Dictionary = _ROWS[i]
		var bonus_type: StringName = row["type"]
		var total: float = PrestigeSystem.get_meta_bonus_total(bonus_type)
		var cap: float = PrestigeFormulas.META_BONUS_MAX[bonus_type]
		if row["is_percent"]:
			_value_labels[i].text = "+%s%%" % _fmt_percent(total)
		else:
			_value_labels[i].text = "+%s" % _fmt_flat(total)
		_progress_bars[i].max_value = cap
		_progress_bars[i].value = total
		# Capped state needs a TEXTUAL marker, never only bar color
		# (accessibility Commitment 2 / spec AC-4).
		_max_labels[i].visible = total >= cap - 0.000001 and cap > 0.0


func _pulse_rows(fresh_types: Array[StringName]) -> void:
	for tween: Tween in _pulse_tweens:
		if tween != null:
			tween.kill()
	_pulse_tweens.clear()
	for i in _ROWS.size():
		if not fresh_types.has(_ROWS[i]["type"] as StringName):
			continue
		var target: PanelContainer = _row_containers[i]
		# One-shot opacity pulse on self_modulate (never modulate — children's
		# text must stay fully readable throughout, ADR-0011 precedent).
		target.self_modulate = Color(1.0, 1.0, 1.0, 1.0 + _PULSE_ALPHA)
		var tween: Tween = create_tween()
		tween.tween_property(target, "self_modulate", Color.WHITE, _PULSE_DECAY_SEC)
		_pulse_tweens.append(tween)


## 0.107 -> "10.7", 0.5 -> "50" (fraction to percent, trailing zeros off).
func _fmt_percent(fraction: float) -> String:
	var pct: float = snappedf(fraction * 100.0, 0.1)
	if is_equal_approx(pct, roundf(pct)):
		return str(int(roundf(pct)))
	return "%.1f" % pct


## Flat values (META_SPONSOR_FLOOR): 3.0 -> "3", 4.5 -> "4.5".
func _fmt_flat(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return str(int(roundf(value)))
	return "%.1f" % snappedf(value, 0.1)
