# ADR-0003: Scene Management and Module Boot Order

## Status
Accepted (2026-06-20, following independent /architecture-review — verdict CONCERNS overall but no conflicts or blockers against this ADR specifically; stale OS.get_unix_time() prose reference fixed prior to acceptance)

## Date
2026-06-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core (Scene management / initialization) |
| **Knowledge Risk** | LOW — Autoload `_ready()` ordering and `get_tree().change_scene_to_file()` are stable, pre-4.3 patterns. Godot 4.6's unique-node-ID feature (tracked in `breaking-changes.md`) aids scene-tree debugging but requires no code changes here. |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload singleton architecture — defines the 8-module boot order this ADR builds on top of), ADR-0002 (Save file format — `load_save()`/`save_now()` interface this ADR calls) |
| **Enables** | Implementation of every Presentation-layer scene (Action UI, Card UI, Offline Report Screen) — none can be built until the boot sequence that hands off to them is fixed |
| **Blocks** | All Presentation-layer epics |
| **Ordering Note** | None beyond the above |

## Context

### Problem Statement
Per `architecture.md`'s Data Flow #4, app launch must: load the save file, restore all Core/Foundation module state, run the offline simulation, conditionally show the Offline Report Screen, then make the main gameplay scene interactive. This sequence spans multiple Autoloads (already ordered by ADR-0001) and at least one scene transition (boot → main gameplay, possibly via Offline Report). This ADR fixes where that sequencing logic lives and how the scene transition happens.

### Constraints
- Godot 4.6.3, GDScript, no threading (per `architecture.md` Principle 1)
- Offline simulation must complete (≤1440 iterations, sub-frame cost) before any gameplay UI is interactive — per `offline-progress-system.md`
- Onboarding/Tutorial's phase state must be restored before `DecisionCardSystem` becomes active, since `OnboardingGate` gates it

### Requirements
- A single, traceable place where "what happens at launch" is defined — not scattered across multiple Autoloads' `_ready()` methods racing each other
- Must support the conditional branch (Offline Report Screen shown vs. skipped) from `offline-report-screen.md`'s `MIN_REPORT_THRESHOLD_SECONDS` rule

## Decision

Introduce a dedicated **Boot scene** (`res://scenes/boot/boot.tscn`) as the project's main scene (Project Settings → Run → Main Scene). It contains a single `BootController` script with no visuals (or a minimal loading indicator) that runs the sequence below in `_ready()`, then transitions to the gameplay scene.

**Boot sequence** (runs once, at cold start only — not on every scene change):
1. By the time `BootController._ready()` runs, all 8 Autoloads (per ADR-0001's boot order) have already completed their own `_ready()` — this is guaranteed by Godot's initialization order (Autoloads before the main scene).
2. `BootController` calls `SaveSystem.load_save()` synchronously, getting back a `Dictionary` (empty if first session).
3. `BootController` calls each module's `restore_state(data)` method in the same dependency order as ADR-0001's Autoload list: `ResourceManager`, `HistoryFlagManager`, `CardContentDatabase` (no-op, static data), `ActionSystem`, `OnboardingGate`, `DecisionCardSystem`. (`SaveSystem` and `OfflineProgressSystem` have no persisted state of their own to restore beyond what they read from other modules.)
4. `BootController` calls `OfflineProgressSystem.simulate_offline(elapsed_seconds)`, where `elapsed_seconds = Time.get_unix_time_from_system() - data.get("last_save_timestamp", Time.get_unix_time_from_system())` (matching the code sample in Key Interfaces, which already used the correct `Time` singleton).
5. `BootController` applies the simulation result to `ResourceManager` directly (ownership-clear write, per ADR-0001).
6. If `elapsed_seconds >= MIN_REPORT_THRESHOLD_SECONDS` (300s, per `offline-report-screen.md`): `BootController` calls `get_tree().change_scene_to_file("res://scenes/offline_report/offline_report.tscn")`, passing the simulation result via an Autoload-held transient variable (not a save-file field — this data is launch-only and never persisted).
7. Else: `BootController` calls `get_tree().change_scene_to_file("res://scenes/main/main.tscn")` directly.
8. The Offline Report Screen, once dismissed, itself calls `change_scene_to_file("res://scenes/main/main.tscn")` — `BootController`'s job ends once it hands off to either scene.

### Architecture Diagram
```
[Cold start] -> Autoloads init (ADR-0001 order) -> Boot scene _ready()
                                                          |
                                          SaveSystem.load_save()
                                                          |
                                  restore_state() on each module (dependency order)
                                                          |
                                  OfflineProgressSystem.simulate_offline()
                                                          |
                                          apply result to ResourceManager
                                                          |
                              elapsed >= 300s? ---yes---> Offline Report Screen -> Main scene
                                       |
                                       no
                                       v
                                  Main scene (interactive)
```

### Key Interfaces
```gdscript
# BootController (attached to boot.tscn's root node, the project's Main Scene)
func _ready() -> void:
    var data := SaveSystem.load_save()
    ResourceManager.restore_state(data.get("resources", {}))
    HistoryFlagManager.restore_state(data.get("history", {}))
    ActionSystem.restore_state(data.get("action", {}))
    OnboardingGate.restore_state(data.get("onboarding", {}))
    DecisionCardSystem.restore_state(data.get("decision_card", {}))

    var last_save: int = data.get("last_save_timestamp", Time.get_unix_time_from_system())
    var elapsed: int = Time.get_unix_time_from_system() - last_save
    var result := OfflineProgressSystem.simulate_offline(elapsed)
    ResourceManager.apply_delta(result.get("resource_deltas", {}))

    if elapsed >= 300:
        OfflineProgressSystem.last_simulation_result = result  # transient, read-once by Offline Report Screen, never serialized by SaveSystem
        get_tree().change_scene_to_file("res://scenes/offline_report/offline_report.tscn")
    else:
        get_tree().change_scene_to_file("res://scenes/main/main.tscn")
```
Each module's `restore_state(data: Dictionary) -> void` is a new method this ADR requires (one per module owning persisted state) — a no-op-safe default (treat missing keys as first-session defaults) is mandatory, since `data` is `{}` on first launch.

**Note on `change_scene_to_file()`:** the scene swap is deferred to the end of the current frame, not synchronous — the old scene's root isn't freed and the new scene's `_ready()` doesn't fire until then. This is harmless here since `BootController`'s responsibility ends at the call (step 8); no code after it depends on the new scene already existing.

## Alternatives Considered

### Alternative A: Main scene handles boot logic directly in its own `_ready()`
- **Description**: Skip a dedicated Boot scene; have the main gameplay scene (`main.tscn`) run the load/restore/simulate sequence itself before making its own UI interactive.
- **Pros**: One fewer scene file.
- **Cons**: Couples the main gameplay scene's `_ready()` to launch-only logic it doesn't conceptually own — every time `main.tscn` reloads for any reason (which it currently never does, but the coupling is still a smell), boot logic would need an explicit "only run once" guard. Also makes the Offline Report Screen branch awkward: the main scene would need to conditionally avoid showing its own UI and instead transition *away* to the report screen, inverting the natural flow.
- **Rejection Reason**: Mixing "one-time launch sequencing" with "ongoing gameplay scene" responsibilities violates the same ownership-clarity principle ADR-0001 established for modules — scenes deserve the same discipline.

### Alternative B: Dedicated Boot scene — CHOSEN
Described above. Matches `architecture.md`'s Data Flow #4 exactly, keeps the main gameplay scene's `_ready()` free of launch-only logic.

## Consequences

### Positive
- One file (`boot.tscn` + `BootController`) is the single source of truth for "what happens at launch" — easy to find, easy to reason about, easy to test in isolation
- Offline Report Screen's conditional branch is a natural fit for a scene-transition decision, not an awkward in-place UI toggle within the main scene

### Negative
- Adds one more scene file and one more script vs. Alternative A's "fewer files" — acceptable, minimal cost for the clarity gained

### Risks
- **Risk**: If a module's `restore_state()` is forgotten when a new module is added later (e.g., Vertical Slice tier's Class Path System), that module silently starts from defaults every launch instead of restoring saved state.
  - **Mitigation**: `architecture-review`'s traceability check (run after this ADR) should flag any module with persisted state but no `restore_state()` call in `BootController` — add this as an explicit item to watch when `/architecture-review` runs.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| offline-progress-system.md | Runs once at app launch, before any UI shows | Boot sequence step 4, before any `change_scene_to_file()` call |
| offline-report-screen.md | Appears only if elapsed >= `MIN_REPORT_THRESHOLD_SECONDS` (300s) | Boot sequence step 6's conditional |
| save-persistence-system.md | Load on launch, treat missing/corrupt save as first session | Boot sequence step 2, consuming ADR-0002's `load_save()` contract directly |
| onboarding-tutorial.md | Phase state must be restored before Decision Card System becomes active | Boot sequence step 3 restores `OnboardingGate` before `DecisionCardSystem` (matches ADR-0001's dependency order) |

## Performance Implications
- **CPU**: Negligible beyond the already-budgeted offline simulation cost (≤1440 iterations, confirmed cheap at design time)
- **Memory**: Negligible — transient `pending_report` dictionary held briefly between scenes
- **Load Time**: One extra scene load (`boot.tscn`) before the main scene — boot scene has no heavy assets, cost is effectively zero
- **Network**: N/A

## Migration Plan
N/A — first boot sequence for this project.

## Validation Criteria
- Cold-start with no save file: confirm all modules initialize to documented defaults, no Offline Report shown, main scene becomes interactive
- Cold-start with a save file and `elapsed < 300s`: confirm main scene shows directly, no report screen
- Cold-start with a save file and `elapsed >= 300s`: confirm Offline Report Screen shows with correct values, then transitions to main scene on dismiss
- Add a new module later (e.g., Class Path System) without updating `BootController.restore_state()` calls: confirm `/architecture-review` flags the gap (per the Risks mitigation above)

## Related Decisions
- ADR-0001 (Autoload singleton architecture) — defines the module boot order this ADR's restore sequence follows
- ADR-0002 (Save file format) — `load_save()` is this ADR's first call
- `docs/architecture/architecture.md` — Data Flow #4, which this ADR implements in full
