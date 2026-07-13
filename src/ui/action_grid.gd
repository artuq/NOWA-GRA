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
## Queue bar (Story 003): a programmatic HBoxContainer added below the grid
## shows queued action icons in order. The bar dims (alpha 0.5) while the
## queue is suspended (card presenting or Morale Critical). A Clear button
## (Button, "X") lets the player empty the queue without stopping the running
## action. All queue UI connects to ActionSystem.queue_changed and
## ActionSystem.queue_suspended_changed — no polling.
##
## Locked slot preview (Story 005): locked gated slots 4-6 show a preview
## card: grayed icon at LOCKED_MODULATE alpha, action name at full opacity
## with a lock prefix, unlock requirement in the stats label, and a live
## ProgressBar for counter-gated slots (4/5). Tapping a locked slot shows a
## transient 2s toast. Progress bars update event-driven only (on
## action_completed) — no _process().
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
	&"przeprosiny": preload("res://assets/ui/icons/icon_action_apologize.png"),
	# Gated unlock actions (slots 4-6) -- reuse the 3 base action icons as
	# placeholders (same free-placeholder approach as the rest of this layout;
	# swap for bespoke pixel art later without touching this wiring).
	# Wave-1 icons (2026-07-07): gated actions get their OWN icons — no more
	# borrowing the base three (the "icons don't match" complaint, ASSET-004..006).
	&"nagraj_kolaba": preload("res://assets/ui/icons/icon_action_collab.png"),
	&"udziel_wywiadu": preload("res://assets/ui/icons/icon_action_interview.png"),
	&"wydaj_kurs": preload("res://assets/ui/icons/icon_action_course.png"),
}

## The 3 gated slots occupy button indices [GATED_BASE_INDEX, 6) -- the reserved
## "locked" slots after the 3 base actions. Aligns with ActionUnlocks'
## GATED_ACTION_IDS order (slot 4 = index 3, slot 5 = index 4, slot 6 = index 5).
const GATED_BASE_INDEX: int = 3

const LOCKED_ICON: Texture2D = preload("res://assets/ui/icons/icon_system_locked.png")

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

## HBoxContainer appended below the grid, showing one icon per queued action
## plus the clear button. Created programmatically in `_setup_queue_bar()` so
## no scene edit is required for this Story 003 addition.
var _queue_bar: HBoxContainer

## "X" button at the trailing end of the queue bar. Calls
## `ActionSystem.clear_queue()` on press. Hidden during card presentation
## (suspend by card) so the player cannot clear the queue while choosing.
var _clear_btn: Button

## ProgressBar nodes for gated slots 0/1 (counter-gated).
## Null for slot 2 (milestone-gated -- no numeric progress bar).
var _slot_progress_bars: Array[ProgressBar] = [null, null, null]

## Bound callables for the locked-slot pressed handlers, stored so they can be
## cleanly disconnected in _activate_gated_slot(). A .bind(g) call creates a
## unique Callable object; we must hold a reference to disconnect it later.
var _locked_pressed_callables: Array[Callable] = [Callable(), Callable(), Callable()]

## Small padlock badges (LOCKED_ICON png) shown above a locked slot's title.
## Replaces the former "🔒 " text prefix — OpenSans has no padlock glyph, so
## the emoji rendered as a hex box on the web build (10-1 spike finding);
## a texture badge renders identically on every platform. Freed on unlock.
var _lock_badges: Array[TextureRect] = [null, null, null]


func _ready() -> void:
	ActionSystem.action_completed.connect(_on_action_completed)
	_configure_unlocked_slots()
	_configure_locked_slots()
	# Then activate any gated slot whose decision-history condition is already
	# met (e.g. restored from a save mid/late game).
	_refresh_gated_slots()
	_setup_queue_bar()
	ActionSystem.queue_changed.connect(_on_queue_changed)
	ActionSystem.queue_suspended_changed.connect(_on_queue_suspended_changed)


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


## Visual dimming for locked slot icons -- reduced alpha reads as "inactive"
## clearly on both light and dark surfaces without making the icon invisible.
## Title label is kept at full opacity (lock prefix makes intent clear).
const LOCKED_MODULATE: Color = Color(1.0, 1.0, 1.0, 0.45)

## Renders the 3 gated slots as locked preview cards: grayed action icon,
## full-opacity title with lock prefix, unlock requirement in stats label,
## and a ProgressBar for counter-gated slots (g=0, g=1). Slots are enabled
## so tap -> toast works. _refresh_gated_slots() then activates any slot
## whose unlock condition is already met.
func _configure_locked_slots() -> void:
	for g in ActionUnlocks.GATED_ACTION_IDS.size():
		var slot_index: int = GATED_BASE_INDEX + g
		var action_id: StringName = ActionUnlocks.GATED_ACTION_IDS[g]

		# Icon: show the action's own icon at LOCKED_MODULATE alpha (grayed preview).
		_slot_icons[slot_index].texture = ACTION_ICONS.get(action_id)
		_slot_icons[slot_index].modulate = LOCKED_MODULATE

		# Title: full opacity, plain display name — the lock signifier is the
		# padlock badge below (texture, not a text glyph — web-safe).
		_slot_titles[slot_index].text = ActionSystem.ACTION_DISPLAY_NAMES.get(action_id, String(action_id))
		_slot_titles[slot_index].modulate = Color.WHITE

		# Padlock badge: small LOCKED_ICON texture placed NEXT TO the title
		# text (user direction 2026-07-06). The title Label is reparented into
		# a centered HBox wrapper: [badge][title]. The wrapper stays after
		# unlock (harmless container); only the badge is freed.
		var badge: TextureRect = TextureRect.new()
		badge.name = "Slot%dLockBadge" % (slot_index + 1)
		badge.texture = LOCKED_ICON
		badge.custom_minimum_size = Vector2(22, 22)
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var title: Label = _slot_titles[slot_index]
		# Autowrap OFF while locked: an autowrapping Label inside an HBox
		# collapses to its minimum width and wraps one character per line
		# (found on the web build 2026-07-06). Locked display names are short;
		# WORD_SMART is restored on unlock, where the label returns to living
		# directly in the VBox.
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		var title_group: VBoxContainer = title.get_parent() as VBoxContainer
		var title_index_in_group: int = title.get_index()
		var wrap: HBoxContainer = HBoxContainer.new()
		wrap.alignment = BoxContainer.ALIGNMENT_CENTER
		wrap.add_theme_constant_override("separation", 6)
		title_group.add_child(wrap)
		title_group.move_child(wrap, title_index_in_group)
		var scene_owner: Node = title.owner  # reparent() clears owner — capture first
		wrap.owner = scene_owner  # the whole chain must be owned, or an owned
		title.reparent(wrap)      # find_child() prunes traversal at the wrapper
		title.owner = scene_owner
		wrap.add_child(badge)
		wrap.move_child(badge, 0)  # badge to the LEFT of the title text
		_lock_badges[g] = badge

		# Stats label: unlock requirement string at 0.45 alpha.
		if ActionUnlocks.is_milestone_gated(g):
			_slot_stats[slot_index].text = "Reach a story moment"
		else:
			var progress: Dictionary = ActionUnlocks.get_choice_progress(
				g,
				HistoryFlagManager.get_counter(&"risky_choices_count"),
				HistoryFlagManager.get_counter(&"safe_choices_count"),
			)
			_slot_stats[slot_index].text = "%d / %d choices" % [progress["current"], progress["required"]]
		_slot_stats[slot_index].modulate = Color(1.0, 1.0, 1.0, 0.45)

		# Enable for tap -> toast (locked slots are not disabled).
		_slot_buttons[slot_index].disabled = false

		# Store and connect the bound callable so we can disconnect it cleanly on unlock.
		var locked_callable: Callable = _on_locked_button_pressed.bind(g)
		_locked_pressed_callables[g] = locked_callable
		_slot_buttons[slot_index].pressed.connect(locked_callable)

		# ProgressBar for counter-gated slots only (g=0, g=1). None for g=2 (milestone).
		if not ActionUnlocks.is_milestone_gated(g):
			var bar_progress: Dictionary = ActionUnlocks.get_choice_progress(
				g,
				HistoryFlagManager.get_counter(&"risky_choices_count"),
				HistoryFlagManager.get_counter(&"safe_choices_count"),
			)
			var bar: ProgressBar = ProgressBar.new()
			bar.min_value = 0
			bar.max_value = float(bar_progress["required"])
			bar.value = float(bar_progress["current"])
			bar.show_percentage = false
			# TextGroup VBox — captured BEFORE the title was reparented into
			# the badge HBox above (title.get_parent() is the HBox now).
			title_group.add_child(bar)
			_slot_progress_bars[g] = bar


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
## preview into a live, tappable action: disconnects the locked handler, frees
## any ProgressBar, restores icon to full opacity, sets real title (no lock
## prefix) and stats at full alpha, re-enables, and connects to start_action().
func _activate_gated_slot(g: int) -> void:
	var slot_index: int = GATED_BASE_INDEX + g
	var action_id: StringName = ActionUnlocks.GATED_ACTION_IDS[g]

	# Disconnect the locked tap handler using the stored bound callable.
	if _locked_pressed_callables[g].is_valid():
		_slot_buttons[slot_index].pressed.disconnect(_locked_pressed_callables[g])
		_locked_pressed_callables[g] = Callable()

	# Free the ProgressBar if present (counter-gated slots only).
	if _slot_progress_bars[g] != null:
		_slot_progress_bars[g].queue_free()
		_slot_progress_bars[g] = null

	# Free the padlock badge — the slot is live now — and restore the title's
	# word wrapping (disabled while locked for the single-line badge row).
	if _lock_badges[g] != null:
		_lock_badges[g].queue_free()
		_lock_badges[g] = null
	var title: Label = _slot_titles[slot_index]
	# Reparent the title back out of the badge HBox and into the plain VBox
	# it lived in before _configure_locked_slots() wrapped it. Leaving it in
	# the (now single-child) HBox reproduces the exact collapse bug the OFF
	# workaround above exists to avoid: HBoxContainer sizes to its children's
	# minimum content width, so an autowrapping Label left inside it shrinks
	# to ~0 width and wraps one character per line the moment WORD_SMART is
	# restored (found live 2026-07-13 — the wrapper was never actually
	# removed on unlock, only the badge was).
	var wrap: HBoxContainer = title.get_parent() as HBoxContainer
	var title_group: VBoxContainer = wrap.get_parent() as VBoxContainer
	var wrap_index: int = wrap.get_index()
	var scene_owner: Node = title.owner
	title.reparent(title_group)
	title.owner = scene_owner
	title_group.move_child(title, wrap_index)
	wrap.queue_free()
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Restore icon to full opacity with the action's real icon.
	_slot_icons[slot_index].texture = ACTION_ICONS.get(action_id)
	_slot_icons[slot_index].modulate = Color.WHITE

	# Remove lock prefix; restore title and stats to full opacity.
	_slot_titles[slot_index].text = ActionSystem.ACTION_DISPLAY_NAMES.get(action_id, String(action_id))
	_slot_titles[slot_index].modulate = Color.WHITE
	_slot_stats[slot_index].text = _stats_text(action_id)
	_slot_stats[slot_index].modulate = Color.WHITE

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


## Handles a tap on a locked gated slot [param g] (0-based). Shows a transient
## informational toast instead of starting an action. For counter-gated slots
## the remaining count is clamped to >= 0 in case of edge-case over-progress.
func _on_locked_button_pressed(g: int) -> void:
	var slot_index: int = GATED_BASE_INDEX + g
	var toast_text: String
	if ActionUnlocks.is_milestone_gated(g):
		toast_text = "Unlock by reaching a key story moment"
	else:
		var risky: int = HistoryFlagManager.get_counter(&"risky_choices_count")
		var safe: int = HistoryFlagManager.get_counter(&"safe_choices_count")
		var progress: Dictionary = ActionUnlocks.get_choice_progress(g, risky, safe)
		var remaining: int = maxi(0, progress["required"] - progress["current"])
		toast_text = "Make %d more choices to unlock" % remaining
	_show_locked_toast(slot_index, toast_text)


## Shows a transient Label (toast) as a child of the slot button, auto-dismissed
## after 2 seconds. Any existing toast on the same slot is removed first to
## avoid stacking. The label sits within the slot bounds and does not affect
## neighbouring slots.
func _show_locked_toast(slot_index: int, text: String) -> void:
	# Remove any existing toast on this slot to avoid stacking.
	var existing: Node = _slot_buttons[slot_index].find_child("LockedToast", false, false)
	if existing != null:
		existing.queue_free()

	var toast: Label = Label.new()
	toast.name = "LockedToast"
	toast.text = text
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_slot_buttons[slot_index].add_child(toast)
	# Button is not a Container — explicitly fill the slot rect so autowrap works
	# and the toast doesn't stack at (0,0) over the icon.
	toast.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	get_tree().create_timer(2.0).timeout.connect(func() -> void:
		if is_instance_valid(toast):
			toast.queue_free()
	)


func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
	# A card resolved between actions may have just met a gated slot's unlock
	# condition -- evaluate before re-enabling so a freshly-unlocked slot comes
	# back interactive immediately.
	_refresh_gated_slots()
	# Update progress bars for any slots still locked after the refresh.
	for g in _gated_live.size():
		if not _gated_live[g]:
			_update_locked_slot_progress(g)
	# Re-enable base + live gated slots (and still-locked slots for toast),
	# unless queue is at cap.
	_refresh_action_buttons()


## Updates the ProgressBar value and stats label text for a still-locked
## counter-gated slot [param g]. No-op for milestone-gated slots (bar is null).
## Called event-driven only (on action_completed) — no _process().
func _update_locked_slot_progress(g: int) -> void:
	if _slot_progress_bars[g] == null:
		return
	var risky: int = HistoryFlagManager.get_counter(&"risky_choices_count")
	var safe: int = HistoryFlagManager.get_counter(&"safe_choices_count")
	var progress: Dictionary = ActionUnlocks.get_choice_progress(g, risky, safe)
	_slot_progress_bars[g].value = float(progress["current"])
	var slot_index: int = GATED_BASE_INDEX + g
	_slot_stats[slot_index].text = "%d / %d choices" % [progress["current"], progress["required"]]


## Creates the queue bar HBoxContainer and appends it as a child. The bar is
## hidden until the queue becomes non-empty. The Clear button ("X") is always
## the last child and calls ActionSystem.clear_queue() on press. Uses Button
## per ADR-0007 (no TouchScreenButton).
func _setup_queue_bar() -> void:
	_queue_bar = HBoxContainer.new()
	_queue_bar.visible = false
	add_child(_queue_bar)
	_clear_btn = Button.new()
	_clear_btn.text = "X"
	_clear_btn.tooltip_text = "Clear queue"
	_clear_btn.pressed.connect(ActionSystem.clear_queue)
	_queue_bar.add_child(_clear_btn)


## Rebuilds the queue bar from [param snapshot]: removes all existing icon
## nodes (keeps _clear_btn), creates one TextureRect (or Label fallback) per
## queued action id, then moves _clear_btn to the trailing position. Shows or
## hides the entire bar based on whether the snapshot is empty. Disables all
## action buttons when the queue is at cap (QUEUE_CAP reached).
func _on_queue_changed(snapshot: Array[StringName]) -> void:
	# Remove icon children (all children that are not _clear_btn).
	for child: Node in _queue_bar.get_children():
		if child != _clear_btn:
			child.queue_free()
	# Rebuild icon nodes from the snapshot.
	for action_id: StringName in snapshot:
		if ACTION_ICONS.has(action_id):
			var icon: TextureRect = TextureRect.new()
			icon.texture = ACTION_ICONS[action_id]
			_queue_bar.add_child(icon)
		else:
			# Fallback: Label with the display name when no icon is registered.
			var lbl: Label = Label.new()
			lbl.text = ActionSystem.ACTION_DISPLAY_NAMES.get(action_id, String(action_id))
			_queue_bar.add_child(lbl)
	# Keep _clear_btn as the last child regardless of how many icons were added.
	_queue_bar.move_child(_clear_btn, -1)
	_queue_bar.visible = not snapshot.is_empty()
	# Enforce cap-disable: buttons stay off when the queue is full.
	_refresh_action_buttons()


## Dims the queue bar (alpha 0.5) and hides the Clear button while suspended
## (card presenting). Restores full opacity and shows the Clear button when
## the suspend lifts.
func _on_queue_suspended_changed(is_suspended: bool) -> void:
	_queue_bar.modulate.a = 0.5 if is_suspended else 1.0
	_clear_btn.visible = not is_suspended


## Re-enables the base 3 slots, live gated slots, and still-locked gated slots
## (so tap -> toast continues to work after an action completes). All slots
## stay disabled only when the queue is at cap.
func _refresh_action_buttons() -> void:
	var at_cap: bool = ActionSystem.get_queue_size() >= ActionSystem.QUEUE_CAP
	for i in UNLOCKED_ACTION_IDS.size():
		_slot_buttons[i].disabled = at_cap
	for g in _gated_live.size():
		if _gated_live[g]:
			_slot_buttons[GATED_BASE_INDEX + g].disabled = at_cap
		else:
			# Still locked — re-enable so tap -> toast works.
			_slot_buttons[GATED_BASE_INDEX + g].disabled = false


func _set_all_slots_disabled(disabled: bool) -> void:
	for button: Button in _slot_buttons:
		button.disabled = disabled
