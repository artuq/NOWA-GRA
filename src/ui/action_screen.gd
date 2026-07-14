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
class_name ActionScreen
extends Control

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_screen: Control = %SettingsScreen
@onready var _path_button: Button = %PathButton
@onready var _class_path_panel: Control = %ClassPathPanel


func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_button_pressed)
	_path_button.pressed.connect(_on_path_button_pressed)


func _on_settings_button_pressed() -> void:
	_settings_screen.visible = true


func _on_path_button_pressed() -> void:
	_class_path_panel.visible = true
