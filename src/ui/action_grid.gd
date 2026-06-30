## ActionGrid is one of 3 sibling Control-node zones under the ActionScreen
## root scene (ADR-0007). Renders the 6-slot action grid (3 unlocked + 3
## locked), wires each unlocked button's `pressed` signal directly to
## `ActionSystem.start_action()`, and disables/re-enables all 6 buttons on
## action start/completion.
##
## Redesigned 2026-06-25 per Art Director review: icon-first buttons (real
## pixel-art icon + small name/duration/reward caption beneath), rounded
## light-mode styling (design/art/art-bible-stub.md), replacing the original
## plain-text dark buttons. Icons are free, CC BY 4.0-licensed placeholders
## from "Icons Essential" v1.2 (see assets/ui/icons/ATTRIBUTION.md) -- swap
## for bespoke pixel art later without redesigning this layout.
##
## No `_process()` in this zone -- RunningActionOverlay is the sole
## `_process()`-using zone, per ADR-0007.
##
## Performance: event-driven only (button `pressed` signals + the
## `action_completed` connection) -- no per-frame cost.
##
## Usage: instanced as a child of ActionScreen (res://scenes/action_screen/action_screen.tscn).
class_name ActionGrid
extends Control

## The 3 unlocked action slots, in display order.
const UNLOCKED_ACTION_IDS: Array[StringName] = [&"nagraj_vloga", &"zrob_drame", &"przeprosiny"]

## Icon textures for each action, keyed by action_id. Free CC BY 4.0 assets
## (see assets/ui/icons/ATTRIBUTION.md) -- swap for bespoke pixel art later
## without redesigning this layout (Art Director direction, 2026-06-25).
const ACTION_ICONS: Dictionary[StringName, Texture2D] = {
	&"nagraj_vloga": preload("res://assets/ui/icons/icon_action_vlog.png"),
	&"zrob_drame": preload("res://assets/ui/icons/icon_action_drama.png"),
	&"przeprosiny": preload("res://assets/ui/icons/icon_action_apology.png"),
	# Gated unlock actions (slots 4-6) -- reuse the 3 base action icons as
	# placeholders (same free-placeholder approach as the rest of this layout;
	# swap for bespoke pixel art later without touching this wiring).
	&"nagraj_kolaba": preload("res://assets/ui/icons/icon_action_vlog.png"),
	&"udziel_wywiadu": preload("res://assets/ui/icons/icon_action_apology.png"),
	&"wydaj_kurs": preload("res://assets/ui/icons/icon_action_drama.png"),
}

## The 3 gated slots occupy button indices [GATED_BASE_INDEX, 6) -- the reserved
## "locked" slots after the 3 base actions. Aligns with ActionUnlocks'
## GATED_ACTION_IDS order (slot 4 = index 3, slot 5 = index 4, slot 6 = index 5).
const GATED_BASE_INDEX: int = 3

const LOCKED_ICON: Texture2D = preload("res://assets/ui/icons/icon_locked.png")

@onready var _slot_buttons: Array[Button] = [
	%Slot1Button, %Slot2Button, %Slot3Button, %Slot4Button, %Slot5Button, %Slot6Button,
]
@onready var _slot_icons: Array[TextureRect] = [
	%Slot1Icon, %Slot2Icon, %Slot3Icon, %Slot4Icon, %Slot5Icon, %Slot6Icon,
]
## Action title (display name) -- the primary, larger, white label.
@onready var _slot_titles: Array[Label] = [
	%Slot1Title, %Slot2Title, %Slot3Title, %Slot4Title, %Slot5Title, %Slot6Title,
]
## Action stats (duration + rewards) -- the secondary, smaller, grey label,
## visually subordinate to the title (typographic hierarchy, Art Director
## direction 2026-06-25).
@onready var _slot_stats: Array[Label] = [
	%Slot1Stats, %Slot2Stats, %Slot3Stats, %Slot4Stats, %Slot5Stats, %Slot6Stats,
]

## Whether each of the 3 gated slots (slot 4/5/6) has been activated this
## session. Prevents re-connecting a slot's `pressed` signal twice and tracks
## which gated slots to re-enable after an action completes. Unlocking is
## permanent (milestones/counters never decrease), so this only flips false→true.
var _gated_live: Array[bool] = [false, false, false]

func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed)
	_configure_unlocked_slots()
	_configure_locked_slots()
	# Then activate any gated slot whose decision-history condition is already
	# met (e.g. restored from a save mid/late game).
	_refresh_gated_slots()


## Wires the first 3 slots to the 3 currently-unlocked actions: icon, title +
## stats text, enabled state, and the pressed -> start_action() connection.
func _configure_unlocked_slots() -> void:
	for i in UNLOCKED_ACTION_IDS.size():
		var action_id: StringName = UNLOCKED_ACTION_IDS[i]
		_slot_icons[i].texture = ACTION_ICONS.get(action_id)
		_slot_titles[i].text = ActionSystem.ACTION_DISPLAY_NAMES.get(action_id, String(action_id))
		_slot_stats[i].text = _stats_text(action_id)
		_slot_buttons[i].disabled = false
		_slot_buttons[i].pressed.connect(_on_unlocked_button_pressed.bind(action_id))


## Visual dimming for locked slots -- distinct from the `disabled` StyleBox
## (which only changes the button's background/border), this mutes the icon
## itself so a locked slot reads as visually muted, not just inert. Uses
## reduced alpha (a "ghosted" look) rather than darkening toward black --
## against this dark-mode UI (2026-06-25 revision), darkening an already-dark
## icon would make it nearly invisible; translucency reads as "inactive"
## clearly on both light and dark surfaces.
const LOCKED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.45)

## Renders the 3 gated slots as locked placeholders (ghosted padlock, disabled).
## This is the initial/default state; _refresh_gated_slots() then activates any
## whose decision-history unlock condition is already met.
func _configure_locked_slots() -> void:
	for i in range(GATED_BASE_INDEX, _slot_buttons.size()):
		_slot_icons[i].texture = LOCKED_ICON
		_slot_icons[i].modulate = LOCKED_MODULATE
		_slot_titles[i].text = ""
		_slot_stats[i].text = ""
		_slot_buttons[i].disabled = true
		# No pressed connection while locked -- a disabled button never fires
		# pressed; _activate_gated_slot() adds the connection on unlock.


## Evaluates the 3 gated slots' unlock conditions against the live decision
## history (ActionUnlocks + HistoryFlagManager) and activates any newly-unlocked
## slot. Idempotent: already-live slots are skipped (no double-connect). Called
## at session start (_ready) and after every completed action -- the only moments
## the gating state can change (counters/milestones only move on card resolution,
## which always sits between actions). A slot thus appears at most one completed
## action after its condition is met (per the quick spec).
func _refresh_gated_slots() -> void:
	var unlocked: Array[bool] = ActionUnlocks.unlocked_slots(
		HistoryFlagManager.get_counter(&"risky_choices_count"),
		HistoryFlagManager.get_counter(&"safe_choices_count"),
		HistoryFlagManager.has_milestone(ActionUnlocks.SLOT_6_MILESTONE_RISKY),
		HistoryFlagManager.has_milestone(ActionUnlocks.SLOT_6_MILESTONE_SAFE),
	)
	for g in ActionUnlocks.GATED_ACTION_IDS.size():
		if unlocked[g] and not _gated_live[g]:
			_activate_gated_slot(g)


## Turns gated slot [param g] (0-based across the 3 gated slots) from a locked
## placeholder into a live, tappable action: real icon, title + stats, enabled,
## pressed -> start_action(). Marks it live so it's never re-activated and is
## re-enabled after future actions complete.
func _activate_gated_slot(g: int) -> void:
	var slot_index: int = GATED_BASE_INDEX + g
	var action_id: StringName = ActionUnlocks.GATED_ACTION_IDS[g]
	_slot_icons[slot_index].texture = ACTION_ICONS.get(action_id)
	_slot_icons[slot_index].modulate = Color.WHITE  # un-ghost the locked dimming
	_slot_titles[slot_index].text = ActionSystem.ACTION_DISPLAY_NAMES.get(action_id, String(action_id))
	_slot_stats[slot_index].text = _stats_text(action_id)
	_slot_buttons[slot_index].disabled = false
	_slot_buttons[slot_index].pressed.connect(_on_unlocked_button_pressed.bind(action_id))
	_gated_live[g] = true


## Builds the secondary stats line per action-ui.md's anatomy rule: duration
## and reward values, e.g. "9s — +10R, +20C, -3M" -- shown beneath the title
## in a smaller, greyed label (the title/name is set separately as the primary
## label). Reward values are formatted via ActionUIFormatting.format_number(),
## with an explicit "+" prefix added for non-negative deltas.
func _stats_text(action_id: StringName) -> String:
	var duration: float = ActionSystem.ACTION_DURATIONS[action_id]
	var rewards: Dictionary = ActionSystem.ACTION_REWARDS[action_id]
	var reach_str: String = _signed_number(rewards[&"Reach"])
	var cringe_str: String = _signed_number(rewards[&"Cringe"])
	var morale_str: String = _signed_number(rewards[&"Morale"])
	return "%ds — %sR, %sC, %sM" % [int(duration), reach_str, cringe_str, morale_str]


## Formats [param value] via ActionUIFormatting.format_number(), adding an
## explicit "+" prefix for non-negative values (format_number's own sign
## handling only ever prefixes "-", never "+").
func _signed_number(value: float) -> String:
	var formatted: String = ActionUIFormatting.format_number(value)
	return formatted if value < 0.0 else "+%s" % formatted


func _on_unlocked_button_pressed(action_id: StringName) -> void:
	var started: bool = ActionSystem.start_action(action_id)
	if started:
		_set_all_slots_disabled(true)


func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	# A card resolved between actions may have just met a gated slot's unlock
	# condition -- evaluate before re-enabling so a freshly-unlocked slot comes
	# back interactive immediately.
	_refresh_gated_slots()
	# Re-enable the 3 base slots + any live gated slots (all 6 were disabled on
	# action start). Still-locked gated slots stay disabled.
	for i in UNLOCKED_ACTION_IDS.size():
		_slot_buttons[i].disabled = false
	for g in _gated_live.size():
		if _gated_live[g]:
			_slot_buttons[GATED_BASE_INDEX + g].disabled = false


func _set_all_slots_disabled(disabled: bool) -> void:
	for button: Button in _slot_buttons:
		button.disabled = disabled
