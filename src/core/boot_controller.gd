## BootController orchestrates the cold-start sequence (ADR-0003): load the
## save, restore module state, run the offline simulation, apply its result,
## then route to the Offline Report Screen (elapsed >= threshold) or straight to
## the main scene. Attached to boot.tscn, the project's Main Scene -- by the time
## its _ready() runs, all Autoloads have already finished their own _ready()
## (Godot init order), so reading them here is safe.
##
## boot_with(data, elapsed_seconds) is the public test seam: it takes the save
## Dictionary and the elapsed time as plain arguments instead of reading
## SaveSystem.load_save() and the real system clock, so tests can drive exact
## boundary values (e.g. elapsed=300 vs 299) deterministically. _ready() is the
## only caller that computes these from the real save/clock.
class_name BootController
extends Node

## Emitted right before the routing change_scene_to_file call, carrying the
## target path -- a test seam so tests can assert routing decisions without
## depending on the target scene's load succeeding (same pattern as
## OfflineReportScreen.scene_swap_requested).
signal route_requested(scene_path: String)

const OFFLINE_REPORT_SCENE: String = "res://scenes/offline_report/offline_report.tscn"
const MAIN_SCENE: String = "res://scenes/main/main.tscn"
const START_SCREEN_SCENE: String = "res://scenes/start_screen/start_screen.tscn"

## Session-scoped guard (static: survives the start_screen -> boot.tscn scene
## round-trip, resets on a fresh process): the start screen is offered at most
## once per app launch. Both start-screen exits (Continue, New Game) route back
## through boot.tscn so ADR-0003's boot sequence stays the single boot path;
## this flag is what lets that second pass fall through to the normal sequence.
static var _start_screen_shown: bool = false

func _ready() -> void:
	var data: Dictionary = SaveSystem.load_save()
	if should_show_start_screen(data, _start_screen_shown):
		_start_screen_shown = true
		route_requested.emit(START_SCREEN_SCENE)
		# Deferred for the same Main-Scene-_ready() race documented on the
		# boot_with routing call below.
		get_tree().change_scene_to_file.call_deferred(START_SCREEN_SCENE)
		return
	boot_with(data, compute_elapsed_seconds(data, Time.get_unix_time_from_system()))


## True when [param data] is a save with actual game progress -- every real
## SaveSystem.save_now() snapshot carries a "resources" block, while both a
## first session ({}) and the minimal post-New-Game save (settings only, see
## SaveSystem.reset_save()) lack it. Gate for the start screen: a player with
## nothing to continue boots straight into the game, preserving the first-card
## hook's instant time-to-gameplay (quick-spec 2026-07-06).
static func has_progress(data: Dictionary) -> bool:
	return data.has("resources")


## Routing predicate for the start screen (BUG-005): show it only when there is
## real progress to continue AND it hasn't already been offered this session.
## Static + argument-driven so tests can exercise the truth table without a
## real save file or scene swap.
static func should_show_start_screen(data: Dictionary, already_shown: bool) -> bool:
	return has_progress(data) and not already_shown


## Computes offline elapsed seconds from the save Dictionary's "last_saved_at"
## and a [param now] timestamp, both passed explicitly so this is testable
## without mocking the system clock. Missing "last_saved_at" (first session,
## no prior save) falls back to [param now] itself, yielding elapsed=0 — the
## correct "nothing to report" case.
static func compute_elapsed_seconds(data: Dictionary, now: float) -> int:
	var last_saved_at: float = data.get("last_saved_at", now)
	return int(now - last_saved_at)


## Runs the full boot sequence against explicit inputs (see class doc for why).
## [param data] is the save Dictionary from SaveSystem.load_save() ({} on first
## session). [param elapsed_seconds] is the offline duration to simulate.
func boot_with(data: Dictionary, elapsed_seconds: int) -> void:
	# Restore module state, in ADR-0001 dependency order. ResourceManager,
	# HistoryFlagManager, and (as of Onboarding/Tutorial Story 003) OnboardingGate
	# implement restore_state; ActionSystem/DecisionCardSystem have no persisted
	# state to restore (existing gap, out of scope here). Note: SaveSystem._ready()
	# already calls these same three restore_state() methods automatically at
	# Autoload init (every process, not just this boot path) -- this is a
	# harmless, idempotent re-restore from the same data, matching the existing
	# pattern already established for ResourceManager/HistoryFlagManager.
	ResourceManager.restore_state(data.get("resources", {}))
	HistoryFlagManager.restore_state(data.get("history_flags", {}))
	OnboardingGate.restore_state(data.get("onboarding", {}))
	ClassPathSystem.restore_state(data.get("class_path", {}))
	SettingsSystem.restore_state(data.get("settings", {}))  # same idempotent re-restore as the other three
	PrestigeSystem.restore_state(data.get("prestige", {}))  # same idempotent re-restore as the other three

	# Baselines captured BEFORE the sim result is applied -- both for computing
	# the deltas below (apply_delta is the only write ResourceManager exposes)
	# and as the h0/m0 the Offline Report Screen needs (Story 002).
	var h0: float = ResourceManager.get_resource(&"Haters")
	var m0: float = ResourceManager.get_resource(&"Morale")

	var result: Dictionary = OfflineProgressSystem.simulate_offline(elapsed_seconds)
	# Built as an explicitly-typed local (engine-specialist note, 2026-06-29) --
	# a bare {} literal here would infer untyped, which apply_delta's
	# Dictionary[StringName, float] signature accepts only via an implicit
	# runtime conversion. float() casts make every value's type explicit.
	var deltas: Dictionary[StringName, float] = {
		&"Reach": float(result.get("total_Z_gained", 0.0)),
		&"Haters": float(result.get("final_H", h0)) - h0,
		&"Morale": float(result.get("final_M", m0)) - m0,
	}
	ResourceManager.apply_delta(deltas)

	OfflineProgressSystem.last_simulation_result = result.duplicate()
	OfflineProgressSystem.last_simulation_result["elapsed_seconds"] = elapsed_seconds
	OfflineProgressSystem.last_simulation_result["h0"] = h0
	OfflineProgressSystem.last_simulation_result["m0"] = m0

	var target: String = OFFLINE_REPORT_SCENE if elapsed_seconds >= OfflineProgressSystem.MIN_REPORT_THRESHOLD_SECONDS else MAIN_SCENE
	route_requested.emit(target)
	# Deferred: calling change_scene_to_file synchronously from the Main Scene's
	# own _ready() errors ("Parent node is busy adding/removing children") because
	# the SceneTree is still mid-instantiation of the current scene root at that
	# point. Deferring to the next idle frame avoids the race (discovered via a
	# real headless cold-start run, not caught by scene_runner-based tests since
	# scene_runner instances boot.tscn as a child, not as the tree's own root).
	get_tree().change_scene_to_file.call_deferred(target)
