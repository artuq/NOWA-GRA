## SaveSystem owns all save-file I/O: a full-snapshot JSON save written
## atomically (temp-file write, then rename), with a `schema_version` field
## and corruption/mismatch fallback to first-session defaults.
##
## Implements TR-save-001/002/003 / ADR-0002: `save_now()` serializes peer
## modules' state to `user://save.tmp` via `JSON.stringify()`, then atomically
## renames to `user://save.json` via `DirAccess.rename_absolute()` — a partial
## write never overwrites the previous, complete save. `load_save()` returns
## `{}` (triggering first-session defaults) on a missing file, a JSON parse
## failure, or a `schema_version` mismatch — never crashes, never attempts a
## partial migration.
##
## Registered as a Godot Autoload singleton per the Control Manifest's boot
## order (after `HistoryFlagManager`, before `ActionSystem` — `CardContentDatabase`
## doesn't exist yet, so its canonical slot is simply skipped).
##
## Story 002 (debounce/coalescing, mobile lifecycle flush) is out of scope
## here — this module only provides the `save_now()`/`load_save()` mechanics
## Story 002 will trigger on a timer. `decision_card_state` is written as a
## fixed empty placeholder — Decision Card System doesn't exist yet, so that
## round-trip is not implemented or tested here.
##
## Usage example:
##   SaveSystem.save_now()
##   var data: Dictionary = SaveSystem.load_save()
extends Node

const SAVE_PATH: String = "user://save.json"
const TEMP_PATH: String = "user://save.tmp"
const SCHEMA_VERSION: int = 1

## State machine per the GDD: `UNINITIALIZED` only at construction, before
## `_ready()` runs `load_save()` + `restore_state()` on every peer module and
## moves to `READY`. `SAVING` is held only for the duration of `save_now()`'s
## body, then returns to `READY`. Never re-enters `LOADING` after the initial
## boot load this session.
enum State { UNINITIALIZED, LOADING, READY, SAVING }

## Current lifecycle state. Public so tests and peer modules can assert on it
## directly, matching this codebase's existing public-state-field convention
## (e.g. `ActionSystem.current_action_id`).
var state: State = State.UNINITIALIZED


func _ready() -> void:
	state = State.LOADING
	var data: Dictionary = load_save()
	ResourceManager.restore_state(data.get("resources", {}))
	HistoryFlagManager.restore_state(data.get("history_flags", {}))
	state = State.READY


## Writes a full snapshot of all peer modules' state to disk atomically:
## serialize to `Dictionary`, `JSON.stringify()` to [constant TEMP_PATH], then
## rename to [constant SAVE_PATH] via `DirAccess.rename_absolute()`. If the
## rename fails, the `.tmp` file is retained (not deleted) for a future retry,
## and the failure is logged — never silently discarded.
##
## Example:
##   SaveSystem.save_now()
func save_now() -> void:
	state = State.SAVING
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"last_saved_at": Time.get_unix_time_from_system(),
		"resources": ResourceManager.serialize_state(),
		"history_flags": HistoryFlagManager.serialize_state(),
		"decision_card_state": {"cooldown_actions_remaining": 0, "resolved_milestone_cards": []},
	}
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Save write failed: could not open %s (%s)" % [TEMP_PATH, FileAccess.get_open_error()])
		state = State.READY
		return
	file.store_string(JSON.stringify(data))
	file.close()
	var err: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Save rename failed: %s — .tmp file retained for retry" % err)
	state = State.READY


## Reads and parses [constant SAVE_PATH]. Returns `{}` (triggering
## first-session defaults in every peer module's `restore_state()`) if the
## file is missing, fails to parse as JSON, or its `schema_version` does not
## match [constant SCHEMA_VERSION] — never crashes, never attempts a partial
## migration. A stray leftover `.tmp` file is never read by this method.
## Return type is intentionally the untyped `Dictionary` (heterogeneous shape:
## `schema_version: int`, nested per-module dicts) — not an oversight.
##
## Example:
##   var data: Dictionary = SaveSystem.load_save()
func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Save read failed: could not open %s (%s) — falling back to defaults" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY or parsed.get("schema_version") != SCHEMA_VERSION:
		return {}
	return parsed
