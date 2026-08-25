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

## Test seam: production keeps real deferred scene swaps enabled; focused flow
## tests can observe route_requested without replacing the SceneTree root.
var scene_changes_enabled: bool = true

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
	# CrazyGames portal glue (web only, no-op everywhere else): the engine is
	# held on the loading screen until the account-aware Data Module snapshot
	# has been prepared. Gameplay itself begins only when ActionScreen becomes
	# interactive; boot/start/offline-report scenes must not inflate analytics.
	# kocSDK and SaveSystem both fall back cleanly when the SDK is unavailable.
	if OS.has_feature("web"):
		await SaveSystem.prepare_web_data()
		JavaScriptBridge.eval("window.kocSDK && window.kocSDK.loadingComplete();", true)
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


## Routing predicate for the start screen: show it once when there is progress
## to continue OR the player has never explicitly chosen a language. A fresh
## install therefore receives the language gate before entering gameplay.
## Static + argument-driven so tests can exercise the truth table without a
## real save file or scene swap.
static func should_show_start_screen(data: Dictionary, already_shown: bool) -> bool:
	if already_shown:
		return false
	var settings: Dictionary = data.get("settings", {})
	var language_confirmed: bool = bool(settings.get("language_choice_confirmed", false))
	return has_progress(data) or not language_confirmed


## Computes offline elapsed seconds from the save Dictionary's "last_saved_at"
## and a [param now] timestamp, both passed explicitly so this is testable
## without mocking the system clock. Missing "last_saved_at" (first session,
## no prior save) falls back to [param now] itself, yielding elapsed=0 — the
## correct "nothing to report" case.
static func compute_elapsed_seconds(data: Dictionary, now: float) -> int:
	var last_saved_at: float = data.get("last_saved_at", now)
	return maxi(0, int(now - last_saved_at))


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
	SponsorContractSystem.restore_state(data.get("sponsor_contract", {}))
	SponsorContractSystem.process_offline_elapsed(elapsed_seconds)
	ClassPathSystem.restore_state(data.get("class_path", {}))
	SettingsSystem.restore_state(data.get("settings", {}))  # same idempotent re-restore as the other three
	PrestigeSystem.restore_state(data.get("prestige", {}))  # same idempotent re-restore as the other three
	StaffSystem.restore_state(data.get("staff", {}))  # same idempotent re-restore as the other three
	AlgorithmContractSystem.restore_state(data.get("algorithm_contract", {}))

	if AlgorithmContractSystem.state == AlgorithmContractSystem.State.ARMED \
		and elapsed_seconds >= OfflineProgressSystem.MIN_REPORT_THRESHOLD_SECONDS:
		var staged: Dictionary = AlgorithmContractSystem.stage_return(elapsed_seconds)
		if not staged.is_empty():
			var chosen: Dictionary = staged["chosen"]
			OfflineProgressSystem.last_simulation_result = staged.duplicate(true)
			OfflineProgressSystem.last_simulation_result["final_H"] = chosen["final_H"]
			OfflineProgressSystem.last_simulation_result["final_M"] = chosen["final_M"]
			OfflineProgressSystem.last_simulation_result["total_Z_gained"] = chosen["total_Z_gained"]
			OfflineProgressSystem.last_simulation_result["h0"] = staged["start"]["Haters"]
			OfflineProgressSystem.last_simulation_result["m0"] = staged["start"]["Morale"]
			_route_to(OFFLINE_REPORT_SCENE)
			return
		# Invalid snapshots fail closed: preserve resources and contract rather
		# than silently applying a result the player cannot verify.
		_route_to(MAIN_SCENE)
		return

	# Baselines captured BEFORE the sim result is applied -- both for computing
	# the deltas below (apply_delta is the only write ResourceManager exposes)
	# and as the h0/m0 the Offline Report Screen needs (Story 002).
	var h0: float = ResourceManager.get_resource(&"Haters")
	var m0: float = ResourceManager.get_resource(&"Morale")

	var result: Dictionary = OfflineProgressSystem.simulate_offline(elapsed_seconds)
	# Resource simulation is capped at 24h, but Sponsor Shield is a persisted
	# wall-clock timer. The sim above consumes its protected segment; now remove
	# the full real elapsed duration from the live timer before the result is
	# saved, including time beyond the economy cap.
	ResourceManager.elapse_sponsor_shield(float(maxi(0, elapsed_seconds)))
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
	_route_to(target)
	# Deferred: calling change_scene_to_file synchronously from the Main Scene's
	# own _ready() errors ("Parent node is busy adding/removing children") because
	# the SceneTree is still mid-instantiation of the current scene root at that
	# point. Deferring to the next idle frame avoids the race (discovered via a
	# real headless cold-start run, not caught by scene_runner-based tests since
	# scene_runner instances boot.tscn as a child, not as the tree's own root).


func _route_to(target: String) -> void:
	route_requested.emit(target)
	if scene_changes_enabled:
		get_tree().change_scene_to_file.call_deferred(target)
