## ActionScreen is the script attached to the Action UI's root scene
## (scenes/action_screen/action_screen.tscn). Per ADR-0007 the Action UI is 3
## self-contained sibling zones (ResourceHud, ActionGrid, RunningActionOverlay)
## driven independently by their own Autoload signals, plus the CardScreen
## modal driven by DecisionCardSystem.card_presented -- this script does NOT
## become a hub for any of those; they stay wired exactly as before.
##
## ADR-0014 (implemented 2026-07-28): this script IS the MainNavCoordinator.
## It owns coordination_state (NO_OVERLAY / PANEL_OPEN / CARD_PRESENTED) as
## the single source of truth for the three coordinated overlay panels
## (ClassPathPanel, SettingsScreen, BonusesPanel — StaffPanel joins whenever
## the Team/Staff system actually ships; wiring a panel for a nonexistent
## system now would be dead code). Panel `visible` flags are EFFECTS of state
## changes applied by the one synchronous resolver (_apply_state_change),
## never independently set — the GDD's "same frame" guarantee is exactly
## "one synchronous resolver call per entry point," no signal-order races.
##
## CardScreen boundary (ADR-0008 "mirror, not hub"): this script reads
## DecisionCardSystem.card_presented and CardScreen.visibility_changed but
## NEVER writes CardScreen.visible. Exit from CARD_PRESENTED gates on the
## card screen actually hiding (its resolution beat runs 1.5-3.5s after
## card_resolved), not on card_resolved.
##
## Back gesture (GDD Rule 6, Android + Web only — iOS out of scope):
## panel open -> close it (consumed); card presented -> ignored (consumed —
## the card is never bypassable); nothing visible -> platform default
## (Android: quit — the engine's own fallback is disabled via
## quit_on_go_back=false so this handler is the sole authority; Web: one
## real history.back(), see _WEB_BACK below).
##
## ADR-0018 (2026-07-24): listens for PrestigeSystem.era_transitioned and
## drives the scene swap to Challenge Selection Screen.
class_name ActionScreen
extends Control

## ADR-0014 / main-navigation-screen-flow.md States and Transitions.
enum CoordinationState { NO_OVERLAY, PANEL_OPEN, CARD_PRESENTED }

## Single source of truth for overlay coordination. No public setter —
## changes exclusively through the entry-point handlers below, each
## funneling into _apply_state_change(). After ANY entry point returns,
## this and the three panels' `visible` flags are mutually consistent.
var coordination_state: CoordinationState = CoordinationState.NO_OVERLAY

## Which panel PANEL_OPEN refers to (null under any other state).
var _open_panel: Control = null

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_screen: Control = %SettingsScreen
@onready var _path_button: Button = %PathButton
@onready var _class_path_panel: Control = %ClassPathPanel
@onready var _bonuses_button: Button = %BonusesButton
@onready var _bonuses_panel: Control = %BonusesPanel
@onready var _card_screen: Control = $CardScreen


func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_path_button.pressed.connect(_on_path_button_pressed)
	_bonuses_button.pressed.connect(_on_bonuses_button_pressed)
	_class_path_panel.close_requested.connect(_on_panel_close_requested)
	_settings_screen.close_requested.connect(_on_panel_close_requested)
	_bonuses_panel.close_requested.connect(_on_panel_close_requested)
	DecisionCardSystem.card_presented.connect(_on_card_presented)
	_card_screen.visibility_changed.connect(_on_card_screen_visibility_changed)
	PrestigeSystem.era_transitioned.connect(_on_era_transitioned)
	if OS.has_feature("web"):
		_web_arm_back_trap()


# --- Entry points (each a thin wrapper over the one resolver) -------------


func _on_path_button_pressed() -> void:
	_request_panel(_class_path_panel)


func _on_settings_button_pressed() -> void:
	_request_panel(_settings_screen)


func _on_bonuses_button_pressed() -> void:
	_request_panel(_bonuses_panel)


func _on_panel_close_requested() -> void:
	if coordination_state == CoordinationState.PANEL_OPEN:
		_apply_state_change(CoordinationState.NO_OVERLAY, null)


## Card presentation always wins collisions (GDD Rule 5). 5a defense-in-depth:
## a duplicate card_presented while already CARD_PRESENTED is a no-op — the
## resolver is idempotent, but the guard also skips the web history re-push.
func _on_card_presented(_card: Dictionary) -> void:
	if coordination_state == CoordinationState.CARD_PRESENTED:
		return
	_apply_state_change(CoordinationState.CARD_PRESENTED, null)


## Exit from CARD_PRESENTED gates on the CardScreen actually hiding (its
## resolution beat outlives card_resolved by seconds — ADR-0014 constraint).
## CanvasItem.visibility_changed carries no payload; reads .visible directly.
func _on_card_screen_visibility_changed() -> void:
	if coordination_state == CoordinationState.CARD_PRESENTED and not _card_screen.visible:
		_apply_state_change(CoordinationState.NO_OVERLAY, null)


## GDD Rule 6. Returns true when the gesture was consumed (panel closed or
## card shielded), false when the platform default should proceed — the
## return value is what the platform glue below branches on.
func _on_back_gesture() -> bool:
	match coordination_state:
		CoordinationState.PANEL_OPEN:
			_apply_state_change(CoordinationState.NO_OVERLAY, null)
			return true
		CoordinationState.CARD_PRESENTED:
			return true  # card is the most important moment — never bypassable
		_:
			return false


# --- The one synchronous resolver -----------------------------------------


func _request_panel(panel: Control) -> void:
	# Opening a panel is rejected outright while a card is presented (card
	# priority is absolute; the TopBar sits under CardScreen's STOP root
	# anyway, so this is defense-in-depth, not the primary gate).
	if coordination_state == CoordinationState.CARD_PRESENTED:
		return
	_apply_state_change(CoordinationState.PANEL_OPEN, panel)


## The ONE resolver every entry point funnels through (GDD's "same frame"
## contract). Sets coordination_state, then applies panel visibility as an
## EFFECT — at most one of the three panels visible, and only under
## PANEL_OPEN. Never touches CardScreen.visible under any branch.
func _apply_state_change(new_state: CoordinationState, panel: Control) -> void:
	coordination_state = new_state
	_open_panel = panel if new_state == CoordinationState.PANEL_OPEN else null
	_class_path_panel.visible = _open_panel == _class_path_panel
	_settings_screen.visible = _open_panel == _settings_screen
	_bonuses_panel.visible = _open_panel == _bonuses_panel
	# Web: keep the history trap primed while anything consumable is up —
	# synchronously, inside the resolver (ADR-0014 Risks: the pushState trap
	# must be armed before the next possible back gesture).
	if OS.has_feature("web") and new_state != CoordinationState.NO_OVERLAY:
		_web_push_history_state()


# --- Platform back-gesture glue -------------------------------------------


## Android: NOTIFICATION_WM_GO_BACK_REQUEST — delivered only because
## project.godot sets application/config/quit_on_go_back=false (otherwise
## the engine quits synchronously on its own, ADR-0014 constraint). On an
## unconsumed gesture this handler IS the platform default: quit.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if not _on_back_gesture() and OS.has_feature("android"):
			get_tree().quit()


## Web: no true back interception exists — the standard workaround is a
## sacrificial history entry (pushState) consumed by the first Back, with a
## popstate listener reacting after the fact (GDD Rule 6 Engine Notes,
## godot-specialist-verified mechanism). Consumed branches re-arm the trap
## (inside _apply_state_change / here); the unconsumed branch issues one
## real history.back() to continue past our own entry — the GDD's
## PROVISIONAL no-confirm default.
var _web_popstate_callback: JavaScriptObject = null


func _web_arm_back_trap() -> void:
	_web_push_history_state()
	_web_popstate_callback = JavaScriptBridge.create_callback(_on_web_popstate)
	JavaScriptBridge.get_interface("window").addEventListener("popstate", _web_popstate_callback)


func _web_push_history_state() -> void:
	JavaScriptBridge.eval("history.pushState({koc_trap: 1}, '');", true)


func _on_web_popstate(_args: Array) -> void:
	if _on_back_gesture():
		# Consumed (card branch — the panel branch already re-pushed inside
		# the resolver; pushing twice would stack trap entries).
		if coordination_state == CoordinationState.CARD_PRESENTED:
			_web_push_history_state()
	else:
		JavaScriptBridge.eval("history.back();", true)


# --- ADR-0018 -------------------------------------------------------------


## ADR-0018: fires synchronously inside the signal handler -- change_scene_
## to_file() itself defers to end-of-frame regardless (same documented
## behavior ADR-0003/ADR-0009 already rely on), so nothing here needs to wait
## for or check the swap's completion.
func _on_era_transitioned() -> void:
	# CrazyGames happytime (web only, no-op elsewhere/off-portal): completing
	# an era is the game's biggest win moment — exactly what the portal's
	# celebration signal is for.
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.kocSDK && window.kocSDK.happytime();", true)
	get_tree().change_scene_to_file("res://scenes/challenge_selection/challenge_selection.tscn")
