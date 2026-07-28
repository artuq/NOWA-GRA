## StartScreen (BUG-005): the Continue / New Game gate, shown at cold boot ONLY
## when a save with real progress exists (BootController.has_progress()) -- a
## fresh player never sees it and boots straight into the game, preserving the
## first-card hook's instant time-to-gameplay (quick-spec 2026-07-06). Offered
## at most once per app launch (BootController._start_screen_shown).
##
## Both exits route back through boot.tscn so ADR-0003's boot sequence
## (restore -> offline sim -> routing) stays the single source of boot truth;
## this screen never restores or simulates anything itself. New Game asks for
## inline confirmation (plain Controls, not a ConfirmationDialog Window --
## keeps ADR-0007's Button-based touch targets and avoids Window quirks in the
## web export), then SaveSystem.reset_save() backs up + wipes and the reboot
## lands in a fresh game.
extends Control

## Test seam: emitted right before change_scene_to_file with the target path,
## same pattern as BootController.route_requested and
## OfflineReportScreen.scene_swap_requested.
signal scene_swap_requested(scene_path: String)

## Retargetable for tests (offline_report_screen_test pattern) so a real
## change_scene_to_file in a test process never boots the actual game.
## Production value is the real boot scene.
var boot_scene_path: String = "res://scenes/boot/boot.tscn"

## Single-fire guard: once a reboot is requested, further taps no-op.
var _swap_done: bool = false

@onready var _confirm_panel: Control = %ConfirmPanel


func _ready() -> void:
	(%ContinueButton as Button).pressed.connect(_on_continue_pressed)
	(%NewGameButton as Button).pressed.connect(_on_new_game_pressed)
	(%ConfirmDeleteButton as Button).pressed.connect(_on_confirm_delete_pressed)
	(%ConfirmCancelButton as Button).pressed.connect(_on_confirm_cancel_pressed)
	_confirm_panel.visible = false


func _on_continue_pressed() -> void:
	_reboot()


func _on_new_game_pressed() -> void:
	_confirm_panel.visible = true


func _on_confirm_cancel_pressed() -> void:
	_confirm_panel.visible = false


func _on_confirm_delete_pressed() -> void:
	if not SaveSystem.reset_save():
		# Backup failed -- the save was left untouched (reset_save's contract).
		# Close the confirm rather than reboot into a game that would silently
		# continue the old save the player just asked to delete.
		_confirm_panel.visible = false
		return
	_reboot()


func _reboot() -> void:
	if _swap_done:
		return
	_swap_done = true
	scene_swap_requested.emit(boot_scene_path)
	get_tree().change_scene_to_file(boot_scene_path)
