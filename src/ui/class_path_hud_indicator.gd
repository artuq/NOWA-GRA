## ClassPathHudIndicator is a display-only HUD badge showing the player's
## active class path and current tier once Tier 1 is reached (Story 8-3,
## ADR-0010). Hidden by default; becomes visible only after
## ClassPathSystem.active_path_changed fires with a non-empty path id.
##
## Presentation layer rule (ADR-0010 / control-manifest.md): this node reads
## ClassPathSystem via signals and getters only -- it never writes path state,
## never calls invest()/reset_era_state(), and owns no path/tier data of its
## own beyond what it displays.
##
## Usage: instanced as a child of MainLayout/TopBar in
## res://scenes/action_screen/action_screen.tscn, next to the avatar.
class_name ClassPathHudIndicator
extends PanelContainer

## English, non-judgmental display names for known path ids. Unregistered
## path ids fall back to str(path_id) in _get_display_name() -- see Story
## 8-3 AC "no Polish path names / no moral framing in label text."
## "Trash Streamer" chosen over a literal "Pato-Streamer" (user decision,
## 2026-07-05): "patostream" is a Polish-only term with no meaning to the
## game's English-speaking audience. Internal path ids stay as-is.
const _DISPLAY_NAMES: Dictionary[StringName, String] = {
	&"pato_streamer": "Trash Streamer",
	&"guru_celebryta": "Guru Celeb",
}

@onready var _label: Label = %ClassPathLabel


func _ready() -> void:
	hide()
	ClassPathSystem.active_path_changed.connect(_on_active_path_changed)
	ClassPathSystem.tier_unlocked.connect(_on_tier_unlocked)
	# restore_state() (boot/load) does not re-emit active_path_changed, so a
	# returning player with a persisted active path needs an explicit sync
	# once this node and its @onready refs are ready (ADR-0010 Story 8-3 Step 5).
	call_deferred("_sync_on_ready")


## One-shot sync for the restored-save case: reads the current active path
## directly instead of waiting for a signal that will not fire on restore.
func _sync_on_ready() -> void:
	_on_active_path_changed(ClassPathSystem.get_active_path())


## Reacts to ClassPathSystem.active_path_changed. Hides the badge when there
## is no active path (path_id == &""); otherwise refreshes the label and shows.
func _on_active_path_changed(path_id: StringName) -> void:
	if path_id.is_empty():
		hide()
	else:
		_refresh_label()
		show()


## Reacts to ClassPathSystem.tier_unlocked -- refreshes the label text so a
## tier advance on the currently active path is reflected immediately.
func _on_tier_unlocked(_path_id: StringName, _tier: int) -> void:
	if not ClassPathSystem.get_active_path().is_empty():
		_refresh_label()


## Rebuilds the label text from ClassPathSystem's current active path + tier.
## Format: "[DisplayName] T[tier]", e.g. "Trash Streamer T1".
func _refresh_label() -> void:
	var path_id: StringName = ClassPathSystem.get_active_path()
	var tier: int = ClassPathSystem.get_tier(path_id)
	_label.text = "%s T%d" % [_get_display_name(path_id), tier]


## Maps a path id to its English, moral-framing-free display name. Falls
## back to the raw id (stringified) for any path not yet in _DISPLAY_NAMES,
## so future paths do not silently break the HUD.
func _get_display_name(path_id: StringName) -> String:
	return _DISPLAY_NAMES.get(path_id, str(path_id))
