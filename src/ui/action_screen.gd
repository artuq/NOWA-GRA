## ActionScreen is the script attached to the Action UI's root scene
## (scenes/action_screen/action_screen.tscn). Per ADR-0007 the Action UI is 3
## self-contained sibling zones (ResourceHud, ActionGrid, RunningActionOverlay)
## driven independently by their own Autoload signals, plus the CardScreen
## modal driven by DecisionCardSystem.card_presented -- this script does NOT
## become a hub for any of those; they stay wired exactly as before.
##
## Its only job is the TopBar's SettingsButton: it lives directly in this
## scene and has no Autoload signal of its own to react to, so a script
## somewhere has to open the SettingsScreen modal on tap, and this scene's
## root is the one place both nodes are reachable from. (Before the Settings
## screen story, this scene's root had no script at all.)
class_name ActionScreen
extends Control

@onready var _settings_button: Button = %SettingsButton
@onready var _settings_screen: Control = %SettingsScreen


func _ready() -> void:
	_settings_button.pressed.connect(_on_settings_button_pressed)


func _on_settings_button_pressed() -> void:
	_settings_screen.visible = true
