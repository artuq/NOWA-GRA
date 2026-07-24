## ChallengeSelectionScreen is the standalone full-screen scene shown once at
## the start of every era (design/ux/challenge-selection-screen.md, ADR-0018):
## a recap of the meta-bonus just granted by the Wypalenie card, plus a choice
## of up to CHALLENGE_MAX_ACTIVE of the 5 designed Challenges for this era.
##
## Reached via a scene swap from main.tscn triggered by
## PrestigeSystem.era_transitioned (action_screen.gd's listener, ADR-0018) --
## not a modal (contrast Card UI/ADR-0008): the era's prior gameplay scene has
## nothing worth preserving beneath a hard, mandatory gate, same lifecycle
## reasoning as Offline Report Screen (ADR-0009).
##
## Confirm is the ONLY exit -- works identically at 0 selections (spec AC) or
## any non-zero selection. Back-gesture (Android)/Esc (Web) are suppressed on
## this scene alone; this does NOT reuse MainNavCoordinator/ADR-0014 code
## (that coordinator has no implementation yet as of this story -- see
## ADR-0018's Migration Plan note) but reuses the SAME mechanism ADR-0014
## specifies (NOTIFICATION_WM_GO_BACK_REQUEST no-op + JavaScriptBridge
## pushState/popstate no-op), implemented fresh and self-contained on this
## scene since it does not depend on action_screen.gd's (still-unbuilt) panel
## coordination in any way.
##
## No _process(): every render is event-driven (toggle press, Confirm).
class_name ChallengeSelectionScreen
extends Control

## Emitted right before the scene swap, carrying the target path and the
## selected challenge ids -- same test seam precedent as OfflineReportScreen's
## scene_swap_requested, so tests can count real Confirm side effects instead
## of only inspecting the _confirming guard bool.
signal scene_swap_requested(path: String, selected_ids: Array[StringName])

## Scene swapped to on Confirm. A var (not a const) so tests can point it at a
## harmless existing scene -- same test seam pattern as OfflineReportScreen's
## main_scene_path.
var main_scene_path: String = "res://scenes/main/main.tscn"

## The 5 ChallengeCard toggle Buttons, in catalogue order (ChallengeSystem.
## get_all_challenge_ids()) -- fixed count, statically authored in the scene,
## same "known fixed slot count" convention as ActionGrid's action buttons
## (not runtime-instantiated; there will only ever be 5, per the locked
## catalogue).
@onready var _challenge_cards: Array[Button] = [
	%ChallengeCard0, %ChallengeCard1, %ChallengeCard2, %ChallengeCard3, %ChallengeCard4,
]
@onready var _era_summary_label: Label = %EraSummaryLabel
@onready var _meta_bonus_granted_label: Label = %MetaBonusGrantedLabel
@onready var _combined_multiplier_label: Label = %CombinedMultiplierLabel
@onready var _selection_count_label: Label = %SelectionCountLabel
@onready var _confirm_button: Button = %ConfirmButton

## Catalogue ids in the same order as _challenge_cards, filled in _ready() so
## toggle handlers can map a card index back to its challenge_id without
## re-querying ChallengeSystem on every tap.
var _challenge_ids: Array[StringName] = []

## True while Confirm's single-fire commit is in flight -- same multi-tap
## latch precedent as OfflineReportScreen._dismissing, guards against a
## double-commit if Confirm is somehow pressed twice before the scene swap
## takes effect (change_scene_to_file() defers to end-of-frame).
var _confirming: bool = false


func _ready() -> void:
	_challenge_ids = ChallengeSystem.get_all_challenge_ids()
	_render_header()
	_render_cards()
	_confirm_button.pressed.connect(_on_confirm_pressed)
	if OS.has_feature("web"):
		_web_suppress_back_gesture()


## Header: era-summary recap (Purpose & Player Need's "closure" goal) plus the
## exact grant amount the Wypalenie card previously previewed (ADR-0017's
## get_last_grant(), NOT a re-derivation -- same underlying compute_next_
## grant() math on both ends, guaranteeing the two numbers can never diverge).
func _render_header() -> void:
	_era_summary_label.text = "Era %d started." % PrestigeSystem.get_era_count()
	var grant: Dictionary = PrestigeSystem.get_last_grant()
	if not grant.get("granted", false):
		# No Bonus Granted state (States & Variants) -- previous era ended
		# without an active Class Path. Never a blank label, never a
		# misleading "0%" that would imply some (even zero) grant happened.
		_meta_bonus_granted_label.text = "No bonus this era."
		return
	var bonus_type: StringName = grant["type"]
	var amount: float = grant["amount"]
	_meta_bonus_granted_label.text = "Permanent bonus gained: +%s%% %s" % [
		String("%.1f" % (amount * 100.0)), _bonus_type_display_name(bonus_type),
	]


## Human-readable label for a META_BONUS type StringName. Local to this
## screen -- no existing shared formatter covers this specific mapping yet
## (meta-bonus-visibility.md's BonusesPanel does its own equivalent mapping
## independently; unifying the two is future cleanup, not this story's scope).
func _bonus_type_display_name(bonus_type: StringName) -> String:
	match bonus_type:
		&"META_REACH_MULT": return "Reach"
		&"META_SPONSOR_MULT": return "Sponsors"
		&"META_HATERS_RESIST": return "Haters Resist"
		&"META_SPONSOR_FLOOR": return "Sponsors Floor"
		_: return String(bonus_type)


## Wires all 5 ChallengeCards from the catalogue and renders their initial
## (all-unselected) state, then does one _update_footer() pass -- 0 selected
## is a complete, valid Default state (States & Variants), not a transient one
## that needs a first toggle to become correct.
func _render_cards() -> void:
	for i in _challenge_ids.size():
		var data: Dictionary = ChallengeSystem.get_challenge_data(_challenge_ids[i])
		var card: Button = _challenge_cards[i]
		card.set_meta("challenge_id", _challenge_ids[i])
		card.set_meta("meta_bonus_multiplier", data.get("meta_bonus_multiplier", 1.0))
		card.toggle_mode = true
		card.button_pressed = false
		_render_card_label(card, data, false)
		card.toggled.connect(_on_card_toggled.bind(card))
	_update_footer()


## Renders one card's label text, including the checkbox glyph -- selection
## state is communicated structurally (☑/☐ + a border style swap the .tscn's
## toggle-mode Button theme already provides), never by color alone
## (Accessibility section: "Brak informacji tylko przez kolor").
func _render_card_label(card: Button, data: Dictionary, selected: bool) -> void:
	var glyph: String = "☑" if selected else "☐"
	var name_text: String = data.get("name", "")
	var modifier_text: String = _format_modifier(data)
	var meta_mult: float = data.get("meta_bonus_multiplier", 1.0)
	card.text = "%s %s\n%s\n×%s meta-bonus" % [glyph, name_text, modifier_text, String("%.1f" % meta_mult)]


## "Nagraj vloga: 0.3× Reach"-style modifier line (Component Inventory's
## ChallengeModifierLabel). applies_to may be "all" (bez_tlumu's catalogue
## entry) or a specific action list -- this screen only shows the axis and
## magnitude, not the full applies_to list, matching the ASCII wireframe's own
## level of detail (per-action breakdown is discoverable in-play, not needed
## here for the selection decision).
func _format_modifier(data: Dictionary) -> String:
	var axis: StringName = data.get("modifier_type", &"")
	var value: float = data.get("modifier_value", 1.0)
	var axis_label: String = String(axis).replace("_multiplier", "").capitalize()
	return "%s× %s" % [String("%.1f" % value), axis_label]


## Toggle handler for one ChallengeCard. Enforces CHALLENGE_MAX_ACTIVE
## (At-cap state, spec AC: "3/3 already selected, 4th toggle attempt
## rejected"): a rejected attempt reverts the Button's own pressed state
## (Godot already flipped it before this signal fires) and shows a tooltip,
## without mutating any other card.
func _on_card_toggled(pressed: bool, card: Button) -> void:
	if pressed and _selected_count() > ChallengeSystem.CHALLENGE_MAX_ACTIVE:
		card.button_pressed = false  # revert -- this signal already reflects the rejected press
		card.tooltip_text = "You can only select %d Challenges this era." % ChallengeSystem.CHALLENGE_MAX_ACTIVE
		return
	var data: Dictionary = ChallengeSystem.get_challenge_data(StringName(card.get_meta("challenge_id")))
	_render_card_label(card, data, pressed)
	_update_footer()


## Recomputes and renders the live combined_meta_multiplier + selection count
## (Interaction Map: "przelicza się natychmiast" -- no animation delay,
## Pillar 1 readability over spectacle). Pure local math over already-loaded
## catalogue data -- no ChallengeSystem call, nothing is written until Confirm
## (Data Requirements: "nic nie jest jeszcze zapisane do systemu przed
## Confirm").
func _update_footer() -> void:
	var product: float = 1.0
	var count: int = 0
	for card: Button in _challenge_cards:
		if card.button_pressed:
			count += 1
			product *= float(card.get_meta("meta_bonus_multiplier"))
	_combined_multiplier_label.text = "Combined multiplier: ×%s" % String("%.1f" % product)
	_selection_count_label.text = "%d/%d" % [count, ChallengeSystem.CHALLENGE_MAX_ACTIVE]
	# Disable the remaining unselected cards once at cap -- Disabled-State
	# Tooltip pattern (interaction-patterns.md), not a silent reject-only UX.
	var at_cap: bool = count >= ChallengeSystem.CHALLENGE_MAX_ACTIVE
	for card: Button in _challenge_cards:
		if not card.button_pressed:
			card.disabled = at_cap
			if at_cap:
				card.tooltip_text = "You can only select %d Challenges this era." % ChallengeSystem.CHALLENGE_MAX_ACTIVE


func _selected_count() -> int:
	var count: int = 0
	for card: Button in _challenge_cards:
		if card.button_pressed:
			count += 1
	return count


## Confirm: writes the selection (ChallengeSystem.select_challenges(), an
## already-designed API -- this screen is only its trigger, per Events Fired's
## explicit warning that this call modifies persistent game state), then swaps
## back to live gameplay. Works identically at 0 selections (spec AC) -- an
## empty array is simply select_challenges([]), the normal "no challenges"
## case ChallengeSystem already defaults to.
func _on_confirm_pressed() -> void:
	if _confirming:
		return
	_confirming = true
	var selected_ids: Array[StringName] = []
	for i in _challenge_cards.size():
		if _challenge_cards[i].button_pressed:
			selected_ids.append(_challenge_ids[i])
	ChallengeSystem.select_challenges(selected_ids)
	scene_swap_requested.emit(main_scene_path, selected_ids)
	get_tree().change_scene_to_file(main_scene_path)


## Android: consumed as a pure no-op -- Confirm is the only exit (spec AC).
## Requires application/config/quit_on_go_back=false in project.godot (ADR-
## 0014's project-setting dependency, applied project-wide -- this scene does
## not need its own copy of that setting).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		pass  # deliberately does nothing


## Web: no true back-gesture interception exists (ADR-0014's own documented
## engine constraint) -- the same preventive history.pushState() + popstate-
## callback pattern that ADR reuses, registered fresh here since this scene is
## self-contained and does not depend on any not-yet-built MainNavCoordinator
## code. The popstate callback is a no-op: same intent as the Android
## override, just re-pushing state so the browser's own back button never
## actually navigates away from this scene.
##
## godot-gdscript-specialist review (2026-07-24) caught a BLOCKING issue in an
## earlier draft: passing a create_callback() result as a string-interpolated
## "arguments[0]" inside eval() does not work -- eval() only executes a JS
## string, it has no mechanism to inject a GDScript Callable that way, and
## "arguments" isn't even defined outside a function scope with
## use_global_execution_context=true (throws ReferenceError on Web export).
## Fixed: JavaScriptBridge.get_interface("window") returns a proxy object
## whose method calls correctly marshal a JavaScriptObject callback as a real
## argument -- no eval()/string-interpolation trick needed.
func _web_suppress_back_gesture() -> void:
	JavaScriptBridge.eval("history.pushState(null, '', location.href);", true)
	var callback: JavaScriptObject = JavaScriptBridge.create_callback(_on_web_popstate)
	JavaScriptBridge.get_interface("window").addEventListener("popstate", callback)


func _on_web_popstate(_args: Array) -> void:
	JavaScriptBridge.eval("history.pushState(null, '', location.href);", true)
