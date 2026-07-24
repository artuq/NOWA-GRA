## ActionScreen is the script attached to the Action UI's root scene
## (scenes/action_screen/action_screen.tscn). Per ADR-0007 the Action UI is 3
## self-contained sibling zones (ResourceHud, ActionGrid, RunningActionOverlay)
## driven independently by their own Autoload signals, plus the CardScreen
## modal driven by DecisionCardSystem.card_presented -- this script does NOT
## become a hub for any of those; they stay wired exactly as before.
##
## Its job is the TopBar's SettingsButton and PathButton: both live directly
## in this scene and have no Autoload signal of their own to react to, so a
## script somewhere has to open their respective modal/screen on tap, and
## this scene's root is the one place all of these nodes are reachable from.
## (Before the Settings screen story, this scene's root had no script at all.)
##
## PathButton (Story class-path-full/005) opens ClassPathPanel -- a
## deliberately separate entry point from ClassPathHudIndicator, which stays
## untouched by this story (it is a PanelContainer, not a Button, and has no
## tap affordance; AC-3 of that story explicitly says not to rebuild it).
##
## ADR-0018 (this revision, 2026-07-24): listens for PrestigeSystem.
## era_transitioned and drives the scene swap to Challenge Selection Screen.
## This is intentionally the ONLY addition this story makes here -- ADR-0014
## (MainNavCoordinator: coordination_state, BonusesPanel/StaffPanel,
## close_requested wiring, back-gesture handling) has no implementation yet
## and is explicitly out of scope for this story (Sprint 12, 12-2 minimal
## scope decision) -- SettingsButton/PathButton stay on their pre-ADR-0014
## direct visible=true handling, unchanged.
class_name ActionScreen
extends Control

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_screen: Control = %SettingsScreen
@onready var _path_button: Button = %PathButton
@onready var _class_path_panel: Control = %ClassPathPanel


func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_path_button.pressed.connect(_on_path_button_pressed)
	PrestigeSystem.era_transitioned.connect(_on_era_transitioned)


func _on_settings_button_pressed() -> void:
	_settings_screen.visible = true


func _on_path_button_pressed() -> void:
	_class_path_panel.visible = true


## ADR-0018: fires synchronously inside the signal handler -- change_scene_
## to_file() itself defers to end-of-frame regardless (same documented
## behavior ADR-0003/ADR-0009 already rely on), so nothing here needs to wait
## for or check the swap's completion.
func _on_era_transitioned() -> void:
	get_tree().change_scene_to_file("res://scenes/challenge_selection/challenge_selection.tscn")
