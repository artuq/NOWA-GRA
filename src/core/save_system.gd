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
## Story 002 (TR-save-001's debounce/coalescing extension): `mark_dirty()`
## starts/restarts a 2s trailing-edge debounce `Timer`; when it fires,
## `save_now()` runs. A mobile lifecycle signal (`NOTIFICATION_APPLICATION_PAUSED`)
## bypasses the remaining debounce window and calls `save_now()` immediately
## if a save is pending — never lose progress to a routine backgrounding
## event. `decision_card_state` is written as a fixed empty placeholder —
## Decision Card System doesn't exist yet, so that round-trip is not
## implemented or tested here.
##
## Usage example:
##   SaveSystem.save_now()
##   SaveSystem.mark_dirty()  # debounced — fires save_now() ~2s later
##   var data: Dictionary = SaveSystem.load_save()
extends Node

## Test isolation (Sprint 9, story 9-3): a gdUnit4 CLI test run must never
## read or write the real player save — the developer's live playtest save
## leaked into test assertions twice (3 false failures 2026-07-05, 2 more
## 2026-07-06: clamped Cringe/milestones from a real session breaking
## delta-exactness and pool-eligibility tests). Detected via the command
## line ("GdUnit" in any arg — the CLI runner passes
## addons/gdUnit4/bin/GdUnitCmdTool.gd); test processes use a separate
## save file, deleted fresh at Autoload construction so leftovers from a
## crashed run can't pollute either. UPPER_SNAKE names kept (were consts)
## so existing `SaveSystemScript.SAVE_PATH` test references keep working.
## Known limitation: tests run from the EDITOR's gdUnit panel don't carry
## the CLI arg and still use the real save — the CLI/CI run is the gate.
static var SAVE_PATH: String = "user://save.json"
static var TEMP_PATH: String = "user://save.tmp"
## Where reset_save() (New Game, BUG-005) parks the previous save. A single
## rolling slot -- each reset overwrites the prior backup. Static (not const)
## for the same test-isolation repointing as SAVE_PATH/TEMP_PATH.
static var BACKUP_PATH: String = "user://save.backup.json"
const SCHEMA_VERSION: int = 1

## Once per PROCESS, not per instance: test suites instantiate fresh
## SaveSystem instances constantly — a per-instance delete would wipe the
## test save a previous instance in the SAME run just legitimately wrote.
static var _test_isolation_done: bool = false


func _init() -> void:
	if _test_isolation_done:
		return
	_test_isolation_done = true
	for arg: String in OS.get_cmdline_args():
		if arg.contains("GdUnit"):
			SAVE_PATH = "user://save.test.json"
			TEMP_PATH = "user://save.test.tmp"
			BACKUP_PATH = "user://save.test.backup.json"
			if FileAccess.file_exists(SAVE_PATH):
				DirAccess.remove_absolute(SAVE_PATH)
			if FileAccess.file_exists(TEMP_PATH):
				DirAccess.remove_absolute(TEMP_PATH)
			if FileAccess.file_exists(BACKUP_PATH):
				DirAccess.remove_absolute(BACKUP_PATH)
			break

## Trailing-edge debounce interval (Tuning Knob: `save_debounce_interval_sec`,
## safe range 1-5 per `save-persistence-system.md`). `mark_dirty()` restarts
## a `Timer` of this duration on every call; the save only fires after this
## many seconds with no further calls.
const _DEBOUNCE_INTERVAL_SEC: float = 2.0

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

var _debounce_timer: Timer

## Autosave suppression window (ADR-0002 §"Autosave suppression window",
## added 2026-07-13 for Prestige/Checkpoint System's era-transition atomicity
## contract, TR-pcs-006). When `true`, the debounce Timer's timeout no-ops
## instead of calling save_now() — re-checked on the timer's next natural
## fire, not queued as a catch-up call. Does NOT affect
## NOTIFICATION_APPLICATION_PAUSED-triggered saves (see _notification()) —
## an OS-initiated background-kill risk always takes priority over an
## in-progress logical transition.
var _autosave_suppressed: bool = false


func _ready() -> void:
	state = State.LOADING
	var data: Dictionary = load_save()
	ResourceManager.restore_state(data.get("resources", {}))
	HistoryFlagManager.restore_state(data.get("history_flags", {}))
	OnboardingGate.restore_state(data.get("onboarding", {}))
	ClassPathSystem.restore_state(data.get("class_path", {}))
	SettingsSystem.restore_state(data.get("settings", {}))
	PrestigeSystem.restore_state(data.get("prestige", {}))
	StaffSystem.restore_state(data.get("staff", {}))
	state = State.READY

	_debounce_timer = Timer.new()
	_debounce_timer.one_shot = true
	_debounce_timer.wait_time = _DEBOUNCE_INTERVAL_SEC
	_debounce_timer.timeout.connect(_on_debounce_timeout)
	add_child(_debounce_timer)


## Marks game state dirty, starting (or restarting) the [constant
## _DEBOUNCE_INTERVAL_SEC]-second trailing-edge debounce timer. Calling this
## again before the timer fires restarts the countdown from the full
## duration — multiple calls within one window coalesce into exactly one
## `save_now()`, timed from the *latest* call, reflecting whatever state was
## current at that latest call.
##
## Example:
##   SaveSystem.mark_dirty()
func mark_dirty() -> void:
	_debounce_timer.stop()
	_debounce_timer.start()


## Debounce Timer's `timeout` handler. No-ops if autosave is currently
## suppressed (see [member _autosave_suppressed]); otherwise behaves exactly
## as the old direct `timeout.connect(save_now)` wiring did.
func _on_debounce_timeout() -> void:
	if _autosave_suppressed:
		return
	save_now()


## Suppresses the debounce Timer's autosave trigger (routine 2s-debounce path
## only — see [member _autosave_suppressed]). A pending Timer is NOT
## cancelled, only prevented from calling save_now() while suppressed; it
## re-arms normally once [method resume_autosave] is called. Added for
## Prestige/Checkpoint System's era-transition atomicity contract (ADR-0002
## §"Autosave suppression window", TR-pcs-006) — Choice A's resolution is
## itself a card resolution, so an unmodified autosave trigger could
## otherwise fire mid-transition and persist a half-transitioned state.
## Callers MUST pair every call with [method resume_autosave] in the same
## synchronous call chain (no `await` between them) — an unpaired suppression
## silently disables autosave indefinitely.
##
## Example:
##   SaveSystem.suppress_autosave()
##   ClassPathSystem.reset_era_state()
##   SaveSystem.save_now()
##   SaveSystem.resume_autosave()
func suppress_autosave() -> void:
	_autosave_suppressed = true


## Lifts the suppression started by [method suppress_autosave]. See that
## method's doc comment for the pairing contract.
func resume_autosave() -> void:
	_autosave_suppressed = false


## Godot lifecycle notification handler. On `NOTIFICATION_APPLICATION_PAUSED`
## (OS backgrounding/suspension signal), if a debounced save is pending
## (timer running), it fires immediately via `save_now()`, bypassing the
## remaining debounce window. Backgrounding with no save pending is a no-op
## — never triggers a spurious write.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		if _debounce_timer != null and not _debounce_timer.is_stopped():
			_debounce_timer.stop()
			save_now()


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
		"onboarding": OnboardingGate.serialize_state(),
		"class_path": ClassPathSystem.serialize_state(),
		"settings": SettingsSystem.serialize_state(),
		"prestige": PrestigeSystem.serialize_state(),
		"staff": StaffSystem.serialize_state(),
	}
	_write_atomic(data)
	state = State.READY


## The shared atomic-write tail of [method save_now] and [method reset_save]:
## JSON to [constant TEMP_PATH], then rename onto [constant SAVE_PATH]. Failure
## modes and logging unchanged from the original save_now() body -- a failed
## rename retains the `.tmp` for retry, never silently discards.
func _write_atomic(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Save write failed: could not open %s (%s)" % [TEMP_PATH, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(data))
	file.close()
	var err: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Save rename failed: %s — .tmp file retained for retry" % err)


## New Game (BUG-005): backs up the current save to [constant BACKUP_PATH]
## (a single rolling slot -- the previous backup is replaced), then writes a
## minimal fresh save preserving ONLY the settings block. reduce_motion is an
## accessibility preference, not progression, so it survives the wipe; the
## fresh save deliberately has no "resources" key, which is exactly what
## BootController.has_progress() keys on -- the next cold boot after a reset
## goes straight into the fresh game, no start screen.
##
## Returns false AND leaves the existing save untouched if the backup copy
## fails -- never deletes the only copy of a player's progression. Also stops
## any pending debounced autosave so pre-reset in-memory state can't be
## re-persisted after the wipe.
##
## Example:
##   if SaveSystem.reset_save():
##       get_tree().change_scene_to_file("res://scenes/boot/boot.tscn")
func reset_save() -> bool:
	if _debounce_timer != null:
		_debounce_timer.stop()
	if FileAccess.file_exists(SAVE_PATH):
		var err: Error = DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		if err != OK:
			push_error("New Game aborted: backup copy to %s failed (%s) — save left untouched" % [BACKUP_PATH, err])
			return false
	_write_atomic({
		"schema_version": SCHEMA_VERSION,
		"last_saved_at": Time.get_unix_time_from_system(),
		"settings": SettingsSystem.serialize_state(),
	})
	return true


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
