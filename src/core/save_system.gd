## SaveSystem owns all save-file I/O: a full-snapshot JSON save written
## atomically (temp-file write, then rename), with a `schema_version` field
## and corruption/mismatch fallback to first-session defaults. On CrazyGames
## Web builds the same JSON snapshot is persisted through the SDK Data Module;
## the local file remains the native/standalone-Web backend and a best-effort
## cache, never the authority for an initialized CrazyGames session.
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
## `save_now()` runs. A second, non-restarting 10s dirty-age Timer guarantees
## that continuous one-second ambient resource ticks cannot postpone that
## trailing edge forever. A mobile lifecycle signal
## (`NOTIFICATION_APPLICATION_PAUSED`) bypasses either remaining window and
## calls `save_now()` immediately if a save is pending. `decision_card_state`
## is written as a fixed empty placeholder —
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
const _WEB_DATA_READY_TIMEOUT_MSEC: int = 10_000

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

## Maximum age of continuously dirty state. The first mark_dirty() starts this
## one-shot deadline; later calls restart only the trailing debounce. Ten
## seconds bounds progress at risk without turning a one-second live ticker
## into one filesystem write per tick.
const _MAX_DIRTY_AGE_SEC: float = 10.0

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
var _max_dirty_timer: Timer
var _web_data_prepared: bool = false
var _web_data_enabled: bool = false
var _web_loaded_data: Dictionary = {}

## Autosave suppression window (ADR-0002 §"Autosave suppression window",
## added 2026-07-13 for Prestige/Checkpoint System's era-transition atomicity
## contract, TR-pcs-006). When `true`, the debounce Timer's timeout no-ops
## instead of calling save_now() — re-checked on the timer's next natural
## fire, not queued as a catch-up call. Does NOT affect
## NOTIFICATION_APPLICATION_PAUSED-triggered saves (see _notification()) —
## an OS-initiated background-kill risk always takes priority over an
## in-progress logical transition.
var _autosave_suppressed: bool = false
var _last_saved_at_floor: float = 0.0


func _ready() -> void:
	state = State.LOADING
	# Web boot is deferred to BootController so the CrazyGames SDK can finish
	# initializing its account-aware Data Module before any progression is
	# restored. Native platforms keep the established synchronous Autoload path.
	if not OS.has_feature("web"):
		var data: Dictionary = load_save()
		ResourceManager.restore_state(data.get("resources", {}))
		HistoryFlagManager.restore_state(data.get("history_flags", {}))
		OnboardingGate.restore_state(data.get("onboarding", {}))
		SponsorContractSystem.restore_state(data.get("sponsor_contract", {}))
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

	_max_dirty_timer = Timer.new()
	_max_dirty_timer.one_shot = true
	_max_dirty_timer.wait_time = _MAX_DIRTY_AGE_SEC
	_max_dirty_timer.timeout.connect(_on_max_dirty_timeout)
	add_child(_max_dirty_timer)


## Waits for the page-level CrazyGames adapter and loads the account-aware
## Data Module snapshot before BootController restores progression. Returns
## `true` only when the Data Module is active; disabled/failed SDK hosts fall
## back to the unchanged local `user://` save path without blocking startup.
## Repeated calls in the same process are idempotent (Start Screen routes back
## through BootController once per launch).
func prepare_web_data() -> bool:
	if not OS.has_feature("web"):
		return false
	if _web_data_prepared:
		return _web_data_enabled

	var deadline_msec: int = Time.get_ticks_msec() + _WEB_DATA_READY_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline_msec:
		var status_value: Variant = JavaScriptBridge.eval(
			"window.kocSDK ? window.kocSDK.dataStatus : 'pending';",
			true,
		)
		var data_status: String = str(status_value)
		if data_status == "enabled":
			_web_data_enabled = true
			_web_data_prepared = true
			var raw_value: Variant = JavaScriptBridge.eval(
				"window.kocSDK.getSave();",
				true,
			)
			if raw_value is String and not raw_value.is_empty():
				_web_loaded_data = parse_save_json(raw_value)
				if _web_loaded_data.is_empty():
					push_error("CrazyGames Data Module returned an invalid save; starting with safe defaults")
			else:
				_web_loaded_data = {}
			return true
		if data_status == "disabled":
			_web_data_prepared = true
			_web_data_enabled = false
			return false
		await get_tree().process_frame

	_web_data_prepared = true
	_web_data_enabled = false
	push_warning("CrazyGames Data Module initialization timed out; using local Web save")
	return false


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
	if _max_dirty_timer.is_stopped():
		_max_dirty_timer.start()


## Debounce Timer's `timeout` handler. No-ops if autosave is currently
## suppressed (see [member _autosave_suppressed]); otherwise behaves exactly
## as the old direct `timeout.connect(save_now)` wiring did.
func _on_debounce_timeout() -> void:
	if _autosave_suppressed:
		return
	save_now()


## Hard dirty-age deadline. In production a pending dirty window always has a
## running trailing timer; the stopped guard also respects deterministic test
## cleanup that explicitly cancels that timer without writing a file.
func _on_max_dirty_timeout() -> void:
	if _autosave_suppressed or _debounce_timer.is_stopped():
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
		var debounce_pending: bool = (
			_debounce_timer != null and not _debounce_timer.is_stopped()
		)
		var max_age_pending: bool = (
			_max_dirty_timer != null and not _max_dirty_timer.is_stopped()
		)
		if debounce_pending or max_age_pending:
			save_now()


## Writes a full snapshot of all peer modules' state to disk atomically:
## serialize to `Dictionary`, `JSON.stringify()` to [constant TEMP_PATH], then
## rename to [constant SAVE_PATH] via `DirAccess.rename_absolute()`. If the
## rename fails, the `.tmp` file is retained (not deleted) for a future retry,
## and the failure is logged — never silently discarded.
##
## Example:
##   SaveSystem.save_now()
func save_now() -> bool:
	if _debounce_timer != null:
		_debounce_timer.stop()
	if _max_dirty_timer != null:
		_max_dirty_timer.stop()
	state = State.SAVING
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"last_saved_at": maxf(Time.get_unix_time_from_system(), _last_saved_at_floor),
		"resources": ResourceManager.serialize_state(),
		"history_flags": HistoryFlagManager.serialize_state(),
		"decision_card_state": {"cooldown_actions_remaining": 0, "resolved_milestone_cards": []},
		"onboarding": OnboardingGate.serialize_state(),
		"sponsor_contract": SponsorContractSystem.serialize_state(),
		"class_path": ClassPathSystem.serialize_state(),
		"settings": SettingsSystem.serialize_state(),
		"prestige": PrestigeSystem.serialize_state(),
		"staff": StaffSystem.serialize_state(),
		"algorithm_contract": AlgorithmContractSystem.serialize_state(),
	}
	var success: bool = _write_atomic(data)
	if success:
		_last_saved_at_floor = float(data["last_saved_at"])
	state = State.READY
	return success


## Persists player preferences before a first career exists. Unlike
## [method save_now], this intentionally omits every progression block, so
## choosing a language on the first-launch gate cannot make
## BootController.has_progress() report a career that has not started yet.
func save_settings_only() -> bool:
	if _debounce_timer != null:
		_debounce_timer.stop()
	if _max_dirty_timer != null:
		_max_dirty_timer.stop()
	state = State.SAVING
	var data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"last_saved_at": maxf(Time.get_unix_time_from_system(), _last_saved_at_floor),
		"settings": SettingsSystem.serialize_state(),
	}
	var success: bool = _write_atomic(data)
	if success:
		_last_saved_at_floor = float(data["last_saved_at"])
	state = State.READY
	return success


## The shared write tail of [method save_now] and [method reset_save]. An
## initialized CrazyGames session writes the JSON snapshot to the SDK Data
## Module first, then refreshes the local file as a best-effort cache. Native
## platforms and standalone Web hosts retain the original atomic local write.
func _write_atomic(data: Dictionary) -> bool:
	var json_text: String = JSON.stringify(data)
	if OS.has_feature("web") and _web_data_enabled:
		var escaped_json: String = JSON.stringify(json_text)
		var cloud_result: Variant = JavaScriptBridge.eval(
			"window.kocSDK && window.kocSDK.setSave(%s);" % escaped_json,
			true,
		)
		if not bool(cloud_result):
			push_error("CrazyGames Data Module rejected the save snapshot")
			return false
		_web_loaded_data = data.duplicate(true)
		if not _write_local_atomic(json_text):
			push_warning("CrazyGames save succeeded, but the local Web cache could not be refreshed")
		return true
	return _write_local_atomic(json_text)


## Native/standalone-Web atomic file backend retained unchanged from ADR-0002.
func _write_local_atomic(json_text: String) -> bool:
	var file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Save write failed: could not open %s (%s)" % [TEMP_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(json_text)
	file.close()
	var err: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("Save rename failed: %s — .tmp file retained for retry" % err)
		return false
	return true


## New Game (BUG-005): backs up the current save to [constant BACKUP_PATH]
## (a single rolling slot -- the previous backup is replaced), then writes a
## minimal fresh save preserving ONLY the settings block. reduce_motion is an
## accessibility preference, not progression, so it survives the wipe; the
## fresh save deliberately has no "resources" key, which is exactly what
## BootController.has_progress() keys on -- the next cold boot after a reset
## goes straight into the fresh game, no start screen.
##
## Returns false AND leaves the existing save untouched if the backup copy
## fails -- never deletes the only copy of a player's progression. Pending
## autosave windows are stopped before the attempt: a successful reset leaves
## them stopped, while a failed reset restarts them for the preserved career.
##
## Example:
##   if SaveSystem.reset_save():
##       get_tree().change_scene_to_file("res://scenes/boot/boot.tscn")
func reset_save() -> bool:
	var debounce_was_pending: bool = (
		_debounce_timer != null and not _debounce_timer.is_stopped()
	)
	var max_dirty_was_pending: bool = (
		_max_dirty_timer != null and not _max_dirty_timer.is_stopped()
	)
	if _debounce_timer != null:
		_debounce_timer.stop()
	if _max_dirty_timer != null:
		_max_dirty_timer.stop()
	if FileAccess.file_exists(SAVE_PATH):
		var err: Error = DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		if err != OK:
			push_error("New Game aborted: backup copy to %s failed (%s) — save left untouched" % [BACKUP_PATH, err])
			_restore_autosave_after_failed_reset(
				debounce_was_pending,
				max_dirty_was_pending,
			)
			return false
	var fresh_data: Dictionary = {
		"schema_version": SCHEMA_VERSION,
		"last_saved_at": maxf(Time.get_unix_time_from_system(), _last_saved_at_floor),
		"settings": SettingsSystem.serialize_state(),
	}
	if not _write_atomic(fresh_data):
		_restore_autosave_after_failed_reset(
			debounce_was_pending,
			max_dirty_was_pending,
		)
		return false
	_last_saved_at_floor = float(fresh_data["last_saved_at"])
	_reset_runtime_for_new_game()
	return true


## A failed destructive reset leaves the current career live. Restart every
## pending autosave window using its production wait_time so preserving runtime
## state cannot silently make its unsaved portion volatile. Calling start()
## without an override is intentional: Timer.start(time_left) would permanently
## replace wait_time and shorten every later autosave window.
func _restore_autosave_after_failed_reset(
	debounce_was_pending: bool,
	max_dirty_was_pending: bool,
) -> void:
	if debounce_was_pending and _debounce_timer != null:
		_debounce_timer.start()
	if max_dirty_was_pending and _max_dirty_timer != null:
		_max_dirty_timer.start()


## Autoloads survive the StartScreen -> Boot scene change. After the fresh
## snapshot is safely written, reset every live owner so old resources, unlock
## flags, timers, queues, or pending cards cannot leak into the new career.
func _reset_runtime_for_new_game() -> void:
	_autosave_suppressed = false
	ActionSystem.reset_for_new_game()
	DecisionCardSystem.reset_for_new_game()
	SponsorContractSystem.reset_for_new_game()
	BurnoutSystem.reset_for_new_game()
	ChallengeSystem.restore_state({})
	ClassPathSystem.reset_for_new_game()
	HistoryFlagManager.reset_for_new_game()
	ResourceManager.reset_for_new_game()
	PrestigeSystem.reset_for_new_game()
	StaffSystem.restore_state({})
	AlgorithmContractSystem.reset_for_new_game()
	OfflineProgressSystem.last_simulation_result.clear()
	OnboardingGate.restore_state({})


## Reads the prepared CrazyGames Data Module snapshot when that backend is
## active; otherwise reads [constant SAVE_PATH]. Returns `{}` (triggering
## first-session defaults in every peer module's `restore_state()`) if the
## snapshot is missing, fails to parse as JSON, or its `schema_version` does
## not match [constant SCHEMA_VERSION] — never crashes, never attempts a
## partial migration. A stray leftover `.tmp` file is never read.
## Return type is intentionally the untyped `Dictionary` (heterogeneous shape:
## `schema_version: int`, nested per-module dicts) — not an oversight.
##
## Example:
##   var data: Dictionary = SaveSystem.load_save()
func load_save() -> Dictionary:
	if OS.has_feature("web") and _web_data_prepared and _web_data_enabled:
		return _web_loaded_data.duplicate(true)
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("Save read failed: could not open %s (%s) — falling back to defaults" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var raw_json: String = file.get_as_text()
	file.close()
	var parsed: Dictionary = parse_save_json(raw_json)
	_last_saved_at_floor = maxf(_last_saved_at_floor, float(parsed.get("last_saved_at", 0.0)))
	return parsed


## Parses and validates one serialized snapshot. Kept argument-driven so the
## same schema gate is shared by local files, CrazyGames cloud data, and tests.
static func parse_save_json(raw_json: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw_json)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if int(parsed.get("schema_version", -1)) != SCHEMA_VERSION:
		return {}
	return parsed
