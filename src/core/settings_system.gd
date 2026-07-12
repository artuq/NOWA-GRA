## SettingsSystem owns persisted player-facing accessibility/UX preferences.
## Currently a single flag: reduce_motion (art-bible.md Section 7 MANDATE --
## shake amplitude/duration gate to near-zero when set; scale-pulse, flash,
## and stinger are explicitly unaffected, per FeedbackMath's shake functions).
##
## Same shape as OnboardingGate (ADR-0001 peer-module pattern): a plain
## Autoload with serialize_state()/restore_state(), registered in SaveSystem's
## boot order. No new architectural pattern here -- ADR-0001 already covers
## "every Core/Foundation module is a Godot Autoload singleton."
##
## UI never mutates reduce_motion directly (UI must not own state) -- it calls
## set_reduce_motion(), which also marks the save dirty. Reads (e.g.
## CardScreen at resolution time) go straight to the public field, matching
## this codebase's established read-directly / write-through-a-method split
## (e.g. HistoryFlagManager.get_counter() reads freely; ActionSystem.
## start_action() is the sole write path for its own state).
##
## Usage example:
##   SettingsSystem.set_reduce_motion(true)
##   var reduced: bool = SettingsSystem.reduce_motion
extends Node

## Reduce-motion accessibility flag. Defaults false (motion effects at full
## strength) -- matches every other peer module's "first-session default"
## convention (e.g. HistoryFlagManager's empty counters).
var reduce_motion: bool = false


## Sets [param value] and marks the save dirty. The only write path for
## reduce_motion -- UI (SettingsScreen) calls this, never sets the field
## directly, keeping "UI displays state, does not own it" true for this
## module too.
##
## Example:
##   SettingsSystem.set_reduce_motion(true)
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	SaveSystem.mark_dirty()


## Serializes this module's state for SaveSystem.save_now()'s payload, under
## the "settings" key. Plain JSON-serializable shape (bool), matching the
## established convention (see OnboardingGate.serialize_state()).
##
## Example:
##   var snapshot: Dictionary = SettingsSystem.serialize_state()
func serialize_state() -> Dictionary:
	return {"reduce_motion": reduce_motion}


## Restores from [param data] (the "settings" sub-dict, or {} on first session
## / a save predating this module) -- never crashes, falls back to the false
## default per SaveSystem's "missing key -> default" contract.
##
## Example:
##   SettingsSystem.restore_state(data.get("settings", {}))
func restore_state(data: Dictionary) -> void:
	reduce_motion = bool(data.get("reduce_motion", false))
