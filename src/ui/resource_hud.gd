## ResourceHud is one of 3 sibling Control-node zones under the ActionScreen
## root scene (ADR-0007). Displays all 5 resources as rounded "pill" panels
## (icon + value), reacting to ResourceManager.resource_changed -- never
## polls, never reads all 5 resources every frame.
##
## Redesigned 2026-06-25 per Art Director review: light-mode "Gamified
## Analytics" dashboard aesthetic (design/art/art-bible-stub.md), replacing
## the initial dark/flat/text-only HUD. Icons are emoji placeholders until
## real pixel-art sprites exist -- swapping them later does not require
## redesigning this layout.
##
## Morale is shown as its band label (High/Normal/Low/Critical), not the raw
## percentage, per action-ui.md's Resource HUD rule. Band boundaries are read
## directly from ResourceFormulas' constants (E_FULL_THRESHOLD,
## E_HIGH_THRESHOLD, E_LOW_THRESHOLD) rather than duplicated here, to avoid
## drift between the formula's bands and this HUD's displayed band.
##
## Performance: signal-driven, O(1) work per resource_changed emission (one
## label update + one Tween) -- the five resource labels have no polling cost.
## SponsorShieldControl alone refreshes its active countdown per frame.
##
## Usage: instanced as a child of ActionScreen (res://scenes/action_screen/action_screen.tscn).
class_name ResourceHud
extends Control

@onready var _reach_label: Label = %ReachValueLabel
@onready var _cringe_label: Label = %CringeValueLabel
@onready var _haters_label: Label = %HatersValueLabel
@onready var _morale_label: Label = %MoraleValueLabel
@onready var _sponsors_label: Label = %SponsorsValueLabel

@onready var _reach_pill: Control = %ReachPill
@onready var _cringe_pill: Control = %CringePill
@onready var _haters_pill: Control = %HatersPill
@onready var _morale_pill: Control = %MoralePill
@onready var _sponsors_pill: Control = %SponsorsPill

## Juice/Feedback Action channel (ADR-0011, Story 002). Count-up: on
## action_completed the rewarded labels animate from (end - delta) to end over
## a FIXED duration -- magnitude never scales timing in this channel (GDD rule
## 2). Flash: one brightness pulse on the pill's self_modulate -- self_modulate
## (not modulate) so the pulse does not cascade to the child value Label and
## the number stays legible (engine-specialist finding, 2026-07-06). ONE
## neutral token for gains and losses alike -- no valence coding (registry
## forbidden pattern, ADR-0011).
const COUNTUP_DURATION_SEC: float = 0.6
const FLASH_DURATION_SEC: float = 0.18
## Neutral "activity" brightness pulse. # TODO: art-bible-pending
const FLASH_COLOR: Color = Color(1.35, 1.35, 1.35, 1.0)

## Live count-up tweens per resource. While a resource has a running count-up,
## the resource_changed snap is skipped -- the count-up owns that label until
## it settles on the end value (ADR-0011 §2 reconciliation).
var _countup_tweens: Dictionary[StringName, Tween] = {}
var _flash_tweens: Dictionary[StringName, Tween] = {}
## Last value written by a count-up tween, per resource -- lets an interrupting
## count-up resume from what is actually displayed rather than a stale start.
var _displayed_countup_values: Dictionary[StringName, float] = {}
## Pre-change value from the most recent resource_changed, per resource. Used
## as the count-up's TRUE start: `end - reward` would fabricate a start when
## ResourceManager clamps Cringe/Morale to [0,100] (the action_completed
## payload carries pre-clamp deltas -- code-review finding, 2026-07-06).
var _last_old_values: Dictionary[StringName, float] = {}

func _ready() -> void:
	# These labels are rendered from formatted tr() results. Disable Control's
	# automatic locale pass so a runtime switch cannot translate substrings a
	# second time (for example "Reach" inside "Reach: 28.4K").
	for label: Label in [
		_reach_label, _cringe_label, _haters_label, _morale_label, _sponsors_label,
	]:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ResourceManager.resource_changed.connect(_on_resource_changed)
	ActionSystem.action_completed.connect(_on_action_completed)
	SettingsSystem.language_changed.connect(_on_language_changed)
	# Populate initial state -- resource_changed only fires on subsequent
	# changes, not on this HUD's own _ready(). No pop animation on initial load.
	_update_label(&"Reach", ResourceManager.get_resource(&"Reach"))
	_update_label(&"Cringe", ResourceManager.get_resource(&"Cringe"))
	_update_label(&"Haters", ResourceManager.get_resource(&"Haters"))
	_update_label(&"Morale", ResourceManager.get_resource(&"Morale"))
	_update_label(&"Sponsors", ResourceManager.get_resource(&"Sponsors"))


func _on_resource_changed(name: StringName, new_value: float, old_value: float) -> void:
	# Always record the true pre-change value -- even when the snap below is
	# suppressed -- so a count-up starting this frame animates from what the
	# resource actually was (post-clamp truth, not payload arithmetic).
	_last_old_values[name] = old_value
	if _countup_tweens.has(name) and _countup_tweens[name].is_running():
		return  # count-up owns this label until it settles (ADR-0011 §2)
	_update_label(name, new_value)
	# One-second ambient progression must remain legible, not become a permanent
	# stream of punch animations. The context is synchronous and false for every
	# ordinary action/card mutation, whose existing feedback stays unchanged.
	if not ResourceManager.is_applying_ambient_delta():
		_pop(_pill_for(name))


## Juice Action channel entry point: count-up + flash for every rewarded
## resource. Fires AFTER resource_changed (ActionSystem applies deltas, then
## emits action_completed synchronously), so the label already shows the end
## value -- the count-up derives its start from the payload (start = end -
## delta) instead of reading the label (ADR-0011 §2 / architecture-review
## advisory). No shake, no audio in this channel -- structurally absent.
func _on_action_completed(_action_id: StringName, rewards: Dictionary) -> void:
	for resource_name: StringName in rewards:
		var end_value: float = ResourceManager.get_resource(resource_name)
		# True start: the cached pre-change value from resource_changed (handles
		# clamped Cringe/Morale correctly); payload arithmetic only as fallback
		# for a resource that somehow never emitted resource_changed.
		var start_value: float = _last_old_values.get(resource_name, end_value - float(rewards[resource_name]))
		# Morale renders as a band label, not a number -- a numeric count-up
		# would flicker the band text through thresholds mid-tween. Flash only.
		if resource_name != &"Morale":
			_start_countup(resource_name, start_value, end_value)
		_start_flash(resource_name)


## Animates [param resource_name]'s label from [param start_value] to
## [param end_value] over the fixed count-up duration. Kills any previous
## count-up for the same resource first -- if one was mid-flight, the new
## count-up starts from the currently displayed value (no jump, no stacking).
func _start_countup(resource_name: StringName, start_value: float, end_value: float) -> void:
	var from_value: float = start_value
	if _countup_tweens.has(resource_name) and _countup_tweens[resource_name].is_running():
		_countup_tweens[resource_name].kill()
		from_value = _displayed_countup_values.get(resource_name, start_value)
	var tween: Tween = create_tween()
	tween.tween_method(
		func(value: float) -> void:
			_displayed_countup_values[resource_name] = value
			_update_label(resource_name, value),
		from_value, end_value, COUNTUP_DURATION_SEC
	)
	# An ambient tick may land while the count-up owns this label. Re-read the
	# authoritative value after the tween so its older action endpoint cannot
	# leave the HUD stale.
	tween.tween_callback(func() -> void:
		if _countup_tweens.get(resource_name) == tween:
			_update_label(resource_name, ResourceManager.get_resource(resource_name))
	)
	_countup_tweens[resource_name] = tween


## One brightness pulse on the pill chrome: self_modulate -> FLASH_COLOR ->
## identity over FLASH_DURATION_SEC. Same single token regardless of the
## delta's sign or size -- plays even at zero magnitude (TR-juice-004).
func _start_flash(resource_name: StringName) -> void:
	var pill: Control = _pill_for(resource_name)
	if pill == null:
		return
	if _flash_tweens.has(resource_name) and _flash_tweens[resource_name].is_running():
		_flash_tweens[resource_name].kill()
		pill.self_modulate = Color.WHITE
	var tween: Tween = create_tween()
	tween.tween_property(pill, "self_modulate", FLASH_COLOR, FLASH_DURATION_SEC * 0.4)
	tween.tween_property(pill, "self_modulate", Color.WHITE, FLASH_DURATION_SEC * 0.6)
	_flash_tweens[resource_name] = tween


func _update_label(name: StringName, value: float) -> void:
	match name:
		&"Reach":
			_reach_label.text = tr("RESOURCE_REACH_FORMAT") % ActionUIFormatting.format_number(value)
		&"Cringe":
			_cringe_label.text = tr("RESOURCE_CRINGE_FORMAT") % ActionUIFormatting.format_number(value)
		&"Haters":
			_haters_label.text = tr("RESOURCE_HATERS_FORMAT") % ActionUIFormatting.format_number(value)
		&"Morale":
			_morale_label.text = tr("RESOURCE_MORALE_FORMAT") % _morale_band_label(value)
		&"Sponsors":
			_sponsors_label.text = tr("RESOURCE_SPONSORS_FORMAT") % ActionUIFormatting.format_number(value)


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_update_label(&"Reach", ResourceManager.get_resource(&"Reach"))
	_update_label(&"Cringe", ResourceManager.get_resource(&"Cringe"))
	_update_label(&"Haters", ResourceManager.get_resource(&"Haters"))
	_update_label(&"Morale", ResourceManager.get_resource(&"Morale"))
	_update_label(&"Sponsors", ResourceManager.get_resource(&"Sponsors"))


func _pill_for(name: StringName) -> Control:
	match name:
		&"Reach":
			return _reach_pill
		&"Cringe":
			return _cringe_pill
		&"Haters":
			return _haters_pill
		&"Morale":
			return _morale_pill
		&"Sponsors":
			return _sponsors_pill
		_:
			return null


## Brief scale-punch (~1.0 -> 1.3 -> 1.0, ~200ms) on the pill when its value
## changes -- a small, locally-scoped piece of the eventual Juice/Feedback
## System (Vertical Slice tier), not a substitute for it. Sets pivot_offset
## to the pill's own size/2 each call so the punch scales from its center
## regardless of layout position.
func _pop(pill: Control) -> void:
	if pill == null:
		return
	pill.pivot_offset = pill.size / 2.0
	var tween: Tween = create_tween()
	tween.tween_property(pill, "scale", Vector2(1.3, 1.3), 0.1)
	tween.tween_property(pill, "scale", Vector2(1.0, 1.0), 0.1)


## Maps a raw Morale value to its band label. Delegates to the shared
## ResourceFormulas.morale_band_label (single source of truth, also used by the
## Offline Report Screen) so the band boundaries are never duplicated.
func _morale_band_label(morale: float) -> String:
	var band: String = ResourceFormulas.morale_band_label(morale)
	return tr("MORALE_%s" % band.to_upper())
