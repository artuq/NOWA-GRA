# Król Cringe'u — Master Architecture

## Document Status
- Version: 1
- Last Updated: 2026-06-19
- Engine: Godot 4.6.3, GDScript
- GDDs Covered: resource-system, history-flag-system, save-persistence-system, card-content-database, action-system, decision-card-system, offline-progress-system, action-ui, card-ui, offline-report-screen, onboarding-tutorial (all 11 MVP GDDs)
- ADRs Referenced: ADR-0001 through ADR-0006, all Accepted (2026-06-20, following independent /architecture-review — verdict CONCERNS overall, no blocking conflicts)
- Technical Director Sign-Off: 2026-06-19 — APPROVED
- Lead Programmer Feasibility: skipped (Lean mode)

## Engine Knowledge Gap Summary

Engine version (4.6.3) is post-LLM-training-cutoff (~4.3), labeled HIGH RISK in `VERSION.md`. However, this project's actual technical surface (2D, GDScript-only, UI/Control-node driven, no custom shaders, no 3D physics) does not intersect any of the documented 4.4-4.6 breaking changes (Jolt 3D default, GLSL view_matrix change, GDExtension cast deprecations — all N/A here). **Actual engine risk for this project is LOW.** One item to watch later: Godot 4.6's reworked glow post-processing, relevant only if Vertical Slice-tier "Juice/Feedback System" uses glow effects.

## System Layer Map

```
PRESENTATION  Action UI · Card UI · Offline Report Screen · Onboarding/Tutorial (gate only, no UI of its own)
FEATURE       Decision Card System
CORE          Resource System · History Flag System · Action System · Offline Progress System
FOUNDATION    Save/Persistence System · Card Content Database (static data)
PLATFORM      Godot 4.6.3 / GDScript — Control nodes, Timer, FileAccess, SceneTree signals (all LOW risk)
```

Decision Card System sits in Feature (not Core) because it depends on Card Content Database and History Flag System rather than being depended upon by them, per `systems-index.md`'s dependency map.

## Module Ownership

| Module | Layer | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|---|
| `ResourceManager` | Core | 5 currency values, Morale bands | `get_resource()`, `apply_delta()`, signal `resource_changed` | — | Autoload singleton (LOW) |
| `HistoryFlagManager` | Core | flag log, pattern counters | `record_choice()`, `resolve_path()` | — | Autoload (LOW) |
| `ActionSystem` | Core | active action state, timer | `start_action()`, signal `action_completed` | ResourceManager | `Timer` node (LOW) |
| `OfflineProgressSystem` | Core | offline sim result | `simulate_offline()`, signal `offline_result_ready` | ResourceManager, SaveSystem | `Time.get_unix_time_from_system()` (LOW) |
| `SaveSystem` | Foundation | save file I/O, debounce timer | `save_now()`, `load_save()`, signal `save_flushed` | all Core modules (read state) | `FileAccess`, `Timer`, `NOTIFICATION_APPLICATION_PAUSED` (LOW, stable pre-4.3 API) |
| `CardContentDatabase` | Foundation | static card resource table (12 cards) | `get_card(id)`, `get_all_cards()` | — | `Resource`/JSON (LOW) |
| `DecisionCardSystem` | Feature | cooldown counter, weighting, presented card state | `present_next_card()`, signal `card_presented` | CardContentDatabase, HistoryFlagManager, ResourceManager | Autoload (LOW) |
| `ActionUI` | Presentation | Action Grid scene | reads ActionSystem/ResourceManager signals | ActionSystem, ResourceManager | `Control`, `Button` (LOW; not `TouchScreenButton` — per ADR-0007) |
| `CardUI` | Presentation | Card modal scene, drag state | reads DecisionCardSystem/CardContentDatabase | DecisionCardSystem, CardContentDatabase | `Control`, `Tween`, touch input (LOW) |
| `OfflineReportScreen` | Presentation | report modal | reads OfflineProgressSystem | OfflineProgressSystem, ActionUI (number format) | `Control`, `Tween` (LOW) |
| `OnboardingGate` | Polish | phase state (3 phases) | gates `DecisionCardSystem.present_next_card()` | ActionSystem (action-completed events) | none — pure logic |

```
ActionUI ─┐                    CardUI ─┐              OfflineReportScreen
          ├─> ActionSystem            ├─> DecisionCardSystem ──┐
          │        │                  │        │               │
          │        v                  │        v               v
          └──> ResourceManager <───────┘   CardContentDatabase  OfflineProgressSystem
                    │                       HistoryFlagManager        │
                    v                                                 v
               SaveSystem <──────────────────────────────────────────┘
                    ^
                    │
              OnboardingGate (gates DecisionCardSystem only, reads ActionSystem events)
```

## Data Flow

**1. Action completion path** (sync call → signal):
```
TouchScreenButton.pressed → ActionUI → ActionSystem.start_action(id)
Timer.timeout (4-9s) → ActionSystem emits action_completed(id, rewards)
  → ResourceManager.apply_delta(rewards)   [direct call]
  → OnboardingGate.on_action_completed(id) [signal, peer]
  → DecisionCardSystem.on_action_completed() [signal] → maybe present_next_card()
```

**2. Card resolution path:**
```
CardUI swipe commit → DecisionCardSystem.resolve_choice(option)
  → ResourceManager.apply_delta(card_effects)
  → HistoryFlagManager.record_choice(card_id, option)
  → DecisionCardSystem emits card_resolved → CardUI plays resolution beat → hides
```

**3. Save/load path:**
```
On any Resource/History/Decision-cooldown mutation → SaveSystem.mark_dirty() (starts/refreshes 2s debounce Timer)
Timer.timeout OR app NOTIFICATION_APPLICATION_PAUSED → SaveSystem.save_now()
  → serializes: ResourceManager state, HistoryFlagManager state, DecisionCardSystem cooldown, OnboardingGate phase
  → FileAccess write to temp file → rename (atomic)
```

**4. Initialization order** (app launch):
```
1. SaveSystem.load_save() — synchronous, blocks scene entry
2. ResourceManager, HistoryFlagManager, DecisionCardSystem, OnboardingGate restore from save data
3. OfflineProgressSystem.simulate_offline(now - last_save_timestamp) — synchronous, <=1440 iterations
4. IF elapsed >= 300s: OfflineReportScreen shows (blocks input) ELSE proceed directly
5. Main scene (ActionUI) becomes interactive
```

All flows are synchronous calls + Godot signals — no threading required anywhere (Offline Progress's bounded 1440-iteration cap was confirmed cheap at design time).

## API Boundaries

```gdscript
# ResourceManager (Autoload)
func get_resource(name: StringName) -> float
func apply_delta(deltas: Dictionary) -> void   # {resource_name: delta}, clamps per resource rules
signal resource_changed(name: StringName, new_value: float, old_value: float)
# Guarantee: clamps Cringe/Morale to [0,100] internally; callers never clamp themselves

# ActionSystem (Autoload)
func start_action(action_id: StringName) -> bool   # false if an action is already running
signal action_completed(action_id: StringName, rewards: Dictionary)
# Invariant: only one action runs at a time (single-concurrency)

# DecisionCardSystem (Autoload)
func present_next_card() -> void   # no-op if cooldown not met or onboarding suppresses
func resolve_choice(option: StringName) -> void   # "option_a" | "option_b"
signal card_presented(card_data: Resource)
signal card_resolved(card_id: StringName, option: StringName)
# Invariant: only one card presented at a time

# SaveSystem (Autoload)
func mark_dirty() -> void
func save_now() -> void   # synchronous, bypasses debounce
func load_save() -> Dictionary   # empty Dictionary if no save / corrupted (triggers first-session init)
signal save_flushed

# OfflineProgressSystem (Autoload)
func simulate_offline(elapsed_seconds: int) -> Dictionary   # {final_H, final_M, total_Z_gained, capped}
# Guarantee: pure function of (elapsed_seconds, current resource state) — no side effects until caller applies result

# OnboardingGate (Autoload)
func is_card_suppressed() -> bool
func on_action_completed(action_type: StringName) -> void
# Invariant: terminal once phase_normal reached — never re-suppresses
```

All types are GDScript primitives/`Dictionary`/`Resource` — no engine API exceeding LOW risk.

## ADR Audit

No ADRs exist yet (`docs/architecture/` was empty prior to this document). 0 to audit, 17/17 Technical Requirements are gaps requiring new ADRs.

## Required ADRs

**Foundation Layer (must create before any coding):**
- "Autoload singleton architecture vs event bus" → covers TR-res-001, TR-hist-001, TR-save-001
- "Save file format and atomic write strategy" → covers TR-save-001, TR-save-002, TR-save-003
- "Scene management and module boot order" → covers TR-off-002 (init sequencing)

**Core Layer (should have before the relevant system is built):**
- "Action System timer and single-concurrency enforcement" → covers TR-act-001
- "Decision Card weighting and cooldown implementation" → covers TR-dcs-001, TR-dcs-002
- "Offline simulation loop implementation" → covers TR-off-001

**Can defer to implementation:**
- UI touch-input handling specifics (TR-aui-001, TR-cui-001, TR-ors-001) — straightforward Control-node patterns already fully specified in their GDDs' Formulas sections; low architectural risk, can be implemented directly against the GDD without a dedicated ADR.

## Architecture Principles

1. **No threading, anywhere.** Every system in this MVP (including the worst case, Offline Progress's 1440-iteration simulation) is cheap enough to run synchronously on the main thread. Don't introduce threads pre-emptively.
2. **Signals over tight coupling, direct calls for ownership-clear writes.** Peer/notification relationships (OnboardingGate watching ActionSystem, UI watching state changes) use signals. Direct ownership writes (ActionSystem calling ResourceManager.apply_delta) use direct calls. Don't route everything through an event bus — most of this project's coupling is already shallow per the dependency map.
3. **Data-driven content, hardcoded mechanics.** Card content lives in `Resource`/JSON files (Card Content Database); the formulas/thresholds that operate on that content live in code, per `technical-preferences.md`'s "gameplay values must be data-driven" rule. Don't conflate the two — mechanics aren't player-tunable, content is.
4. **Autoload singletons for Core/Foundation, scenes for Presentation.** Matches Godot's idiomatic pattern for global game state; avoids the overhead of a custom service-locator or DI framework this project doesn't need at its scale.
5. **Offline-first is a launch-time concern, not a background concern.** Per Pillar 4, offline simulation runs once at app launch (Data Flow #4), not on a timer or in the background — simplest implementation that satisfies the design intent.

## Open Questions

None blocking — all Open Questions carried from individual GDDs (satire copy unwritten, no art bible, multi-device sync) are content/visual-identity concerns, not architectural ones, and are tracked in `production/session-state/active.md`.
