## BurnoutWarningIndicator — the ambient pre-burnout countdown in the Action
## UI's HUD zone (design/ux/burnout-warning-hud-indicator.md, APPROVED
## 2026-07-22), extended with the meta-loop telegraph line (playtest 12-3 /
## progression-mechanics-analysis-2026-07.md fix #3): alongside the countdown
## it shows exactly what accepting the incoming Wypalenie will bank
## ("Accept banks +X% ... — permanent"), so the era-end reads as a goal, not
## a surprise punishment (Reigns death-is-progress / Idle Research dangle).
## This line is also the answer to the spec's own Open Question ("what the
## bar means isn't clear from the bar alone").
##
## Pure signal receiver, fully non-interactive (spec Interaction Map: no tap
## handlers, no touch targets). Two hide triggers per the spec's verified
## finding: burnout_warning_changed(false, ...) (Cringe dropped) AND
## DecisionCardSystem.card_presented (ANY card — card injection resets the
## sustain counter silently without a false emission).
##
## Fade-in/out ~0.18s via modulate, near-instant under
## SettingsSystem.reduce_motion (accessibility-requirements.md / art-bible §7).
extends VBoxContainer

const BurnoutSystemScript: GDScript = preload("res://src/core/burnout_system.gd")

## Warning window in seconds: first emission (180s sustained) to trigger
## (300s) — the spec's fill_ratio denominator.
const _WARNING_WINDOW: float = BurnoutSystemScript.BURNOUT_THRESHOLD - BurnoutSystemScript.BURNOUT_WARNING_THRESHOLD

## Player-facing names for the 4 META_BONUS types (same humanization
## direction as design/ux/meta-bonus-visibility.md's BonusLabel; English per
## the UI-language decision 2026-06-25).
const _BONUS_NOUNS: Dictionary[StringName, String] = {
	&"META_REACH_MULT": "Reach",
	&"META_SPONSOR_MULT": "Sponsor income",
	&"META_HATERS_RESIST": "Haters resistance",
	&"META_SPONSOR_FLOOR": "era-start Sponsors",
}

const _FADE_DURATION: float = 0.18

@onready var _countdown_bar: ProgressBar = %CountdownBar
@onready var _seconds_label: Label = %SecondsRemainingLabel
@onready var _bank_preview_label: Label = %BankPreviewLabel

var _fade_tween: Tween
## Cache key for the preview line: [path_id, tier] of the last computed
## preview — compute_next_grant() is cheap but per-frame recomputation of an
## unchanged line is still pointless work.
var _preview_key: Array = []


func _ready() -> void:
	visible = false
	modulate.a = 0.0
	BurnoutSystem.burnout_warning_changed.connect(_on_warning_changed)
	DecisionCardSystem.card_presented.connect(_on_card_presented)


func _on_warning_changed(active: bool, seconds_remaining: float) -> void:
	if not active:
		_set_shown(false)
		return
	_countdown_bar.value = clampf(seconds_remaining / _WARNING_WINDOW, 0.0, 1.0)
	_seconds_label.text = "%ds" % int(ceilf(maxf(seconds_remaining, 0.0)))
	_refresh_bank_preview()
	_set_shown(true)


## Spec Entry & Exit finding: card injection (any card) resets the sustain
## counter WITHOUT a burnout_warning_changed(false) emission — without this
## second listener the indicator would freeze at ~0s forever.
func _on_card_presented(_card: Dictionary) -> void:
	_set_shown(false)


## Rebuilds the telegraph line from the CURRENT projected grant
## (PrestigeSystem.compute_next_grant, ADR-0017's preview API — this is its
## first shipped consumer). Recomputed only when the active path/tier pair
## changes (see _preview_key).
func _refresh_bank_preview() -> void:
	var path_id: StringName = ClassPathSystem.get_active_path()
	var tier: int = ClassPathSystem.get_tier(path_id) if path_id != &"" else 0
	var key: Array = [path_id, tier]
	if key == _preview_key:
		return
	_preview_key = key
	_bank_preview_label.text = _bank_preview_text(path_id, tier)


func _bank_preview_text(path_id: StringName, tier: int) -> String:
	if path_id == &"":
		return "Burnout ahead — no active path, accepting banks nothing"
	var grant: Dictionary = PrestigeSystem.compute_next_grant(path_id, tier)
	if not grant["granted"] or grant["amount"] <= 0.0:
		return "Burnout ahead — bonus cap reached, accepting banks nothing new"
	var noun: String = _BONUS_NOUNS.get(grant["type"], String(grant["type"]))
	if grant["type"] == &"META_SPONSOR_FLOOR":
		return "Burnout ahead — accepting banks +%d %s, permanent" % [int(roundf(grant["amount"])), noun]
	return "Burnout ahead — accepting banks +%s%% %s, permanent" % [_fmt_percent(grant["amount"]), noun]


## 0.02 -> "2", 0.0107 -> "1.1" (percent, trailing zeros stripped).
func _fmt_percent(fraction: float) -> String:
	var pct: float = snappedf(fraction * 100.0, 0.1)
	if is_equal_approx(pct, roundf(pct)):
		return str(int(roundf(pct)))
	return ("%.1f" % pct)


## Fade toward shown/hidden. Near-instant under reduce_motion; identical
## fade for both hide sources (spec: consistency regardless of cause).
func _set_shown(shown: bool) -> void:
	if shown == visible and (_fade_tween == null or not _fade_tween.is_running()):
		if shown and is_equal_approx(modulate.a, 1.0):
			return
		if not shown:
			return
	if _fade_tween != null:
		_fade_tween.kill()
	if SettingsSystem.reduce_motion:
		visible = shown
		modulate.a = 1.0 if shown else 0.0
		if not shown:
			_preview_key = []
		return
	if shown:
		visible = true
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 1.0, _FADE_DURATION)
	else:
		_fade_tween = create_tween()
		_fade_tween.tween_property(self, "modulate:a", 0.0, _FADE_DURATION)
		_fade_tween.tween_callback(func() -> void:
			visible = false
			_preview_key = [])
