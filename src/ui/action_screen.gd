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
## (ClassPathPanel, SettingsScreen, BonusesPanel, StaffPanel — the fourth
## joined 2026-07-28 when the Team/Staff system shipped). Panel `visible`
## flags are EFFECTS of state
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
## quit_on_go_back=false so this handler is the sole authority). On Web the
## gesture only prevents leaving the game — see _WEB_BACK_TRAP_JS for why
## that branch is deliberately implemented without a GDScript callback.
##
## ADR-0018 (2026-07-24): listens for PrestigeSystem.era_transitioned and
## drives the scene swap to Challenge Selection Screen.
##
## Burnout live-play boundary: this scene is the sole lifecycle owner that
## enables BurnoutSystem's sustained-Cringe detector. Boot, Start, Offline
## Report and Challenge Selection never opt in.
class_name ActionScreen
extends Control

## ADR-0014 / main-navigation-screen-flow.md States and Transitions.
enum CoordinationState { NO_OVERLAY, PANEL_OPEN, CARD_PRESENTED }

## Single source of truth for overlay coordination. No public setter —
## changes exclusively through the entry-point handlers below, each
## funneling into _apply_state_change(). After ANY entry point returns,
## this and the four panels' `visible` flags are mutually consistent.
var coordination_state: CoordinationState = CoordinationState.NO_OVERLAY

## Which panel PANEL_OPEN refers to (null under any other state).
var _open_panel: Control = null

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_screen: Control = %SettingsScreen
@onready var _path_button: Button = %PathButton
@onready var _class_path_panel: Control = %ClassPathPanel
@onready var _bonuses_button: Button = %BonusesButton
@onready var _bonuses_panel: Control = %BonusesPanel
@onready var _staff_button: Button = %StaffButton
@onready var _staff_panel: Control = %StaffPanel
@onready var _creator_empire_strip: Control = %CreatorEmpireStrip
@onready var _away_plan_panel: Control = %AwayPlanPanel
@onready var _card_screen: Control = $CardScreen


func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_path_button.pressed.connect(_on_path_button_pressed)
	_bonuses_button.pressed.connect(_on_bonuses_button_pressed)
	_staff_button.pressed.connect(_on_staff_button_pressed)
	_creator_empire_strip.away_plan_requested.connect(_on_away_plan_requested)
	_class_path_panel.close_requested.connect(_on_panel_close_requested)
	_settings_screen.close_requested.connect(_on_panel_close_requested)
	_bonuses_panel.close_requested.connect(_on_panel_close_requested)
	_staff_panel.close_requested.connect(_on_panel_close_requested)
	_away_plan_panel.close_requested.connect(_on_panel_close_requested)
	DecisionCardSystem.card_presented.connect(_on_card_presented)
	_card_screen.visibility_changed.connect(_on_card_screen_visibility_changed)
	PrestigeSystem.era_transitioned.connect(_on_era_transitioned)
	if OS.has_feature("web"):
		_web_arm_back_trap()
		_web_set_gameplay_active(not AlgorithmContractSystem.open_away_plan_on_main)
	# Enable only after all child presentation nodes (including CardScreen)
	# have completed their own _ready() lifecycle.
	BurnoutSystem.set_live_play_active(true)
	if AlgorithmContractSystem.open_away_plan_on_main:
		AlgorithmContractSystem.open_away_plan_on_main = false
		_request_panel.call_deferred(_away_plan_panel)


func _exit_tree() -> void:
	BurnoutSystem.set_live_play_active(false)
	if OS.has_feature("web"):
		_web_set_gameplay_active(false)


# --- Entry points (each a thin wrapper over the one resolver) -------------


func _on_path_button_pressed() -> void:
	_request_panel(_class_path_panel)


func _on_settings_button_pressed() -> void:
	_request_panel(_settings_screen)


func _on_bonuses_button_pressed() -> void:
	_request_panel(_bonuses_panel)


func _on_staff_button_pressed() -> void:
	_request_panel(_staff_panel)


func _on_away_plan_requested() -> void:
	_request_panel(_away_plan_panel)


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
## EFFECT — at most one of the four panels visible, and only under
## PANEL_OPEN. Never touches CardScreen.visible under any branch.
func _apply_state_change(new_state: CoordinationState, panel: Control) -> void:
	coordination_state = new_state
	_open_panel = panel if new_state == CoordinationState.PANEL_OPEN else null
	_class_path_panel.visible = _open_panel == _class_path_panel
	_settings_screen.visible = _open_panel == _settings_screen
	_bonuses_panel.visible = _open_panel == _bonuses_panel
	_staff_panel.visible = _open_panel == _staff_panel
	_away_plan_panel.visible = _open_panel == _away_plan_panel
	# Web: keep the history trap primed while anything consumable is up —
	# synchronously, inside the resolver (ADR-0014 Risks: the pushState trap
	# must be armed before the next possible back gesture).
	if OS.has_feature("web"):
		_web_set_gameplay_active(new_state != CoordinationState.PANEL_OPEN)
		if new_state != CoordinationState.NO_OVERLAY:
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
## popstate listener that immediately re-pushes it (GDD Rule 6 Engine Notes).
##
## DELIBERATELY PURE JS (revised 2026-07-28, era-transition crash hunt): the
## listener is installed ONCE, idempotently, and lives entirely in the page —
## it never holds a GDScript Callable. The earlier version registered a
## `JavaScriptBridge.create_callback(...)` on `window`, which is a
## use-after-free waiting to happen: this scene is FREED on every era
## transition (change_scene_to_file -> Challenge Selection), while the JS
## listener it registered stays on `window` pointing at the now-dead callback.
## `challenge_selection.gd` had the same pattern in an even worse form (the
## callback was a local var, released the moment `_ready()` returned).
##
## Trade-off, accepted and documented: on Web the back gesture now only
## PREVENTS leaving the game (which is the portal-critical behavior — an
## accidental Back on CrazyGames must not navigate out of an iframe game); it
## no longer closes an open panel. Panels close via their Close button; the
## panel-closing branch of Rule 6 remains fully live on Android, where the
## native NOTIFICATION_WM_GO_BACK_REQUEST hook needs no JS bridge at all.
## The GDD itself marks the Web branch of Rule 6 PROVISIONAL.
const _WEB_BACK_TRAP_JS: String = """
if (!window.__kocBackTrap) {
	window.__kocBackTrap = true;
	history.pushState({koc_trap: 1}, '');
	window.addEventListener('popstate', function () {
		history.pushState({koc_trap: 1}, '');
	});
}
"""


func _web_arm_back_trap() -> void:
	JavaScriptBridge.eval(_WEB_BACK_TRAP_JS, true)


func _web_push_history_state() -> void:
	JavaScriptBridge.eval("history.pushState({koc_trap: 1}, '');", true)


## CrazyGames gameplay analytics: live ActionScreen and decision cards count
## as gameplay; coordinated menu panels are breaks. The page-level adapter
## remembers this state across asynchronous SDK initialization and scene swaps.
func _web_set_gameplay_active(active: bool) -> void:
	var js_value: String = "true" if active else "false"
	JavaScriptBridge.eval(
		"window.kocSDK && window.kocSDK.setGameplay(%s);" % js_value,
		true,
	)


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
