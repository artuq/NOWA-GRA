## StartScreen owns the explicit first-launch language gate plus Continue/New
## Game for existing careers. Automatic system-language detection may select
## the initial copy, but gameplay cannot start until English or Polish is
## deliberately chosen once.
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
var _has_progress: bool = false
var _language_dirty: bool = false

@onready var _confirm_panel: Control = %ConfirmPanel


func _ready() -> void:
	_has_progress = BootController.has_progress(SaveSystem.load_save())
	# This screen may remain open if the system locale changes while suspended.
	# Render formatted strings explicitly and opt them out of Godot's automatic
	# second pass, matching the rest of the runtime-localized UI.
	for control: Control in [
		%ContinueButton,
		%NewGameButton,
		%LanguagePromptLabel,
		%EnglishButton,
		%PolishButton,
		$ConfirmPanel/Panel/VBox/ConfirmTitleLabel,
		$ConfirmPanel/Panel/VBox/ConfirmBodyLabel,
		%ConfirmDeleteButton,
		%ConfirmCancelButton,
	]:
		control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	(%ContinueButton as Button).pressed.connect(_on_continue_pressed)
	(%NewGameButton as Button).pressed.connect(_on_new_game_pressed)
	(%EnglishButton as Button).pressed.connect(_on_language_pressed.bind(SettingsSystem.LANGUAGE_EN))
	(%PolishButton as Button).pressed.connect(_on_language_pressed.bind(SettingsSystem.LANGUAGE_PL))
	(%ConfirmDeleteButton as Button).pressed.connect(_on_confirm_delete_pressed)
	(%ConfirmCancelButton as Button).pressed.connect(_on_confirm_cancel_pressed)
	SettingsSystem.language_changed.connect(_on_language_changed)
	_refresh_copy()
	_refresh_language_choice()
	_confirm_panel.visible = false
	(%NewGameButton as Button).visible = _has_progress


func _on_language_changed(_preference: StringName, _locale: StringName) -> void:
	_refresh_copy()
	_refresh_language_choice()


func _refresh_copy() -> void:
	(%ContinueButton as Button).text = tr(&"UI_START_CONTINUE") if _has_progress else tr(&"UI_START_PLAY")
	(%NewGameButton as Button).text = tr(&"UI_START_NEW_GAME")
	(%LanguagePromptLabel as Label).text = tr(&"UI_START_LANGUAGE_PROMPT")
	($ConfirmPanel/Panel/VBox/ConfirmTitleLabel as Label).text = tr(&"UI_START_DELETE_TITLE")
	($ConfirmPanel/Panel/VBox/ConfirmBodyLabel as Label).text = tr(&"UI_START_DELETE_BODY")
	(%ConfirmDeleteButton as Button).text = tr(&"UI_START_DELETE_CONFIRM")
	(%ConfirmCancelButton as Button).text = tr(&"UI_COMMON_CANCEL")


func _refresh_language_choice() -> void:
	var confirmed: bool = SettingsSystem.language_choice_confirmed
	var preference: StringName = SettingsSystem.language_preference
	(%EnglishButton as Button).text = "✓ English" if confirmed and preference == SettingsSystem.LANGUAGE_EN else "English"
	(%PolishButton as Button).text = "✓ Polski" if confirmed and preference == SettingsSystem.LANGUAGE_PL else "Polski"
	(%ContinueButton as Button).disabled = not confirmed


func _on_language_pressed(preference: StringName) -> void:
	SettingsSystem.set_language_preference(preference)
	_language_dirty = true
	_refresh_language_choice()


func _on_continue_pressed() -> void:
	if not SettingsSystem.language_choice_confirmed:
		return
	# Persist the explicit choice before boot re-reads the save Dictionary.
	if _has_progress and _language_dirty:
		SaveSystem.save_now()
	elif not _has_progress and not SaveSystem.save_settings_only():
		return
	_reboot()


func _on_new_game_pressed() -> void:
	_confirm_panel.visible = true


func _on_confirm_cancel_pressed() -> void:
	_confirm_panel.visible = false


func _on_confirm_delete_pressed() -> void:
	if not SaveSystem.reset_save():
		# Backup or atomic fresh-save write failed -- the live career and its
		# save were left untouched (reset_save's contract).
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
