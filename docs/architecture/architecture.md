# Król Cringe'u — Master Architecture

## Document Status
- Version: 2.1
- Last Updated: 2026-08-05
- Engine: Godot 4.6.3, GDScript
- GDDs Covered: resource-system, history-flag-system, save-persistence-system, card-content-database, action-system, decision-card-system, offline-progress-system, action-ui, card-ui, offline-report-screen, onboarding-tutorial (11 MVP GDDs, unchanged from v1) + class-path-system, juice-feedback-system, prestige-checkpoint-system, main-navigation-screen-flow (In Review — see note below) — 15 GDDs total. Team/Staff Management, Staff/Sponsor UI, and Cosmetic Persona Customization remain Not Started (no GDD) and appear below only as placeholder layer assignments per `systems-index.md`.
- ADRs Referenced: ADR-0001 through ADR-0020, all Accepted
- Technical Director Sign-Off: 2026-07-22 — APPROVED
- Lead Programmer Feasibility: skipped (Lean mode)

> **Note on Main Navigation/Screen Flow**: its GDD status is `In Review` (3 `/design-review` rounds completed, all blocking findings resolved in-document; the status reflects that a 4th formal re-review round was consciously skipped, not that open blocking issues remain). It is covered fully below because its architecture — the coordination module and its ownership boundaries — is what ADR-0013-adjacent Required ADR #1 will formalize; the GDD content itself is design-complete.

## Engine Knowledge Gap Summary

Engine version (4.6.3) is post-LLM-training-cutoff (~4.3), labeled HIGH RISK in `VERSION.md`. This project's actual technical surface (2D, GDScript-only, UI/Control-node driven, no custom shaders, no 3D physics) does not intersect any documented 4.4–4.6 breaking change (Jolt 3D default, GLSL `view_matrix` change, GDExtension cast deprecations — all N/A here). **Actual engine risk for this project remains LOW**, confirmed again during this v2 pass across all 5 newly-covered systems: Class Path, Juice/Feedback, Prestige/Checkpoint, Burnout/Challenge, and Main Navigation all use only pre-4.3-stable APIs (`_process(delta)`, `Signal.connect()`, `Timer`, `Tween`, `Dictionary`/`StringName`, `Control` nodes). One item still to watch: Godot 4.6's reworked glow post-processing, relevant only if Juice/Feedback ever adds glow-based effects (currently it does not — audio was cut 2026-07-12 and juice effects are scale/shake/flash/color only). A second, new watch item: **Web export requires the Compatibility renderer**, unverified against the project's Forward+ default — blocks Main Navigation's Web back-gesture rule from being fully settled (see Open Questions).

## System Layer Map

```
PRESENTATION  Action UI · Card UI · Offline Report Screen · Onboarding/Tutorial (gate only) ·
              Class Path Panel/HUD Indicator · Juice/Feedback (FeedbackMath + UI effect nodes) ·
              Main Navigation/Screen Flow (MainNavCoordinator, planned — not yet implemented) ·
              Staff/Sponsor UI (Not Started) · Cosmetic Persona Customization (Not Started)
FEATURE       Decision Card System · Class Path System · Prestige/Checkpoint System ·
              Burnout System · Challenge System · Team/Staff Management (Not Started)
CORE          Resource System · History Flag System · Action System · Offline Progress System
FOUNDATION    Save/Persistence System · Card Content Database (static data) · Settings System
PLATFORM      Godot 4.6.3 / GDScript — Control nodes, Timer, Tween, FileAccess, SceneTree
              signals, _process(delta) (all LOW risk)
```

Class Path System, Prestige/Checkpoint System, Burnout System, and Challenge System sit in Feature (not Core) for the same reason Decision Card System does: each depends on Core-layer modules (Resource, History Flag, Action, Offline Progress, and — for Prestige/Burnout/Challenge — on Decision Card System and each other) rather than being depended upon by them, per `systems-index.md`'s dependency map. Settings System moved to Foundation (not Presentation) because — like `OnboardingGate` in v1 — it is a plain state-holding Autoload with no scene of its own; `SettingsScreen` (the UI that reads/writes it) is the Presentation-layer piece. Juice/Feedback straddles Core and Presentation by design: `FeedbackMath` is a stateless pure-function module (Core-like), while the UI effect nodes it feeds are Presentation.

## Module Ownership

### v1 modules (unchanged — see Data Flow #1–#4 below for how new systems hook into them)

| Module | Layer | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|---|
| `ResourceManager` | Core | 5 currency values, Morale bands, sponsor shield state, synchronous ambient-mutation context | `get_resource()`, `apply_delta()`, `apply_ambient_delta()`, `is_applying_ambient_delta()`, `activate_sponsor_shield()`, `elapse_sponsor_shield()`, signals `resource_changed`, `shield_changed` | SaveSystem | Autoload (LOW) |
| `HistoryFlagManager` | Core | flag log, pattern counters | `record_choice()`, `resolve_path()` | — | Autoload (LOW) |
| `ActionSystem` | Core | active action state, one Timer, bounded FIFO queue | `start_action()`, `get_progress()`, `get_current_duration()`, `get_queue_size()`, `get_queue_snapshot()`, `clear_queue()`, signals `action_started`/`action_completed`/`queue_changed` | ResourceManager, DecisionCardSystem (queue suspend), ClassPathSystem, ChallengeSystem, PrestigeSystem | `Timer` node (LOW) |
| `OfflineProgressSystem` | Core | offline sim result, 60-second/capped orchestration | `simulate_offline()` | ResourceSimulationStep, ResourceManager, ClassPathSystem (ambient effects), PrestigeSystem (Haters resistance), StaffSystem (Troll/Assistant factors) | synchronous loop (LOW) |
| `SaveSystem` | Foundation | save file I/O, 2s trailing debounce, 10s maximum dirty age | `mark_dirty()`, `save_now()`, `load_save()` | all Core/Feature/Foundation modules (read state) | `FileAccess`, two one-shot `Timer`s (LOW) |
| `CardContentDatabase` | Foundation | static card resource table | `get_card(id)`, `get_all_cards()` | — | `Resource`/JSON (LOW) |
| `DecisionCardSystem` | Feature | cooldown counter, weighting, presented card state, `State` enum (COOLDOWN/CHECKING/PRESENTING/RESOLVING) | `present_next_card()`, `inject_priority_card()`, `resolve_choice()`, signals `card_presented`, `card_resolved` | CardContentDatabase, HistoryFlagManager, ResourceManager | Autoload (LOW) |
| `ActionUI` | Presentation | Action Grid scene | reads ActionSystem/ResourceManager signals | ActionSystem, ResourceManager | `Control`, `Button` (LOW; not `TouchScreenButton` — ADR-0007) |
| `CardUI` (`CardScreen`) | Presentation | Card modal scene, drag state | reads DecisionCardSystem/CardContentDatabase | DecisionCardSystem, CardContentDatabase, SettingsSystem (reduce_motion) | `Control`, `Tween`, touch input (LOW) |
| `OfflineReportScreen` | Presentation | report modal | reads OfflineProgressSystem | OfflineProgressSystem, ActionUI (number format) | `Control`, `Tween` (LOW) |
| `OnboardingGate` | Polish | phase state (3 phases) | gates `DecisionCardSystem.present_next_card()` | ActionSystem (action-completed events) | none — pure logic |

### New in v2

| Module | Layer | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|---|
| `ClassPathSystem` | Feature | per-path affiliation totals, tier state, active-path resolution, signature card unlocks | `get_affiliation()`, `get_tier()`, `get_active_path()`, `get_active_multiplier(action_id)`, `can_invest()`, `invest()`, `get_ambiguous_gap()`, signals `tier_unlocked`, `active_path_changed`, `signature_card_unlocked`, `signature_card_removed` | `DecisionCardSystem.card_resolved` (path_tag), ResourceManager | Autoload, registered after DecisionCardSystem (LOW) |
| `ClassPathPanel` / `ClassPathHudIndicator` | Presentation | panel/HUD scene state | reads ClassPathSystem signals | ClassPathSystem | `Control` (LOW) |
| `FeedbackMath` | Core (stateless) | none — pure functions | shake/scale-pulse/flash-color computation functions | — (pure math, no state) | none (LOW) |
| Juice/Feedback UI effect nodes | Presentation | transient animation state (Tween instances) | additive visual effects on top of existing UI nodes | FeedbackMath, SettingsSystem (`reduce_motion` gates shake only — scale-pulse/flash/stinger unaffected) | `Tween` (LOW) |
| `SettingsSystem` | Foundation | `reduce_motion: bool` | `set_reduce_motion()` (sole write path); field is read directly (established read-directly/write-through-method split) | — | Autoload (LOW) |
| `SettingsScreen` | Presentation | settings modal scene | reads/writes via SettingsSystem | SettingsSystem | `Control` (LOW) |
| `PrestigeSystem` | Feature | `era_count`, `meta_bonus_totals`, deferred-this-era flag, reset+grant sequence | `on_burnout_accepted()`, `on_burnout_deferred()`, `get_era_count()`, `get_meta_bonus_total()`, `has_deferred_this_era()`, signal `era_transitioned` (no args) | ResourceManager, ClassPathSystem (`reset_era_state()`), ChallengeSystem (`get_combined_meta_multiplier()`, `clear_active_challenges()`), SaveSystem | Autoload (LOW) |
| `BurnoutSystem` | Feature | sustained-Cringe timer, warning countdown, forced-card-pending flag, ephemeral live-play gate | `set_live_play_active()`, `is_live_play_active()`, signal `burnout_warning_changed(active, seconds_remaining)` | ActionScreen (lifecycle owner), ResourceManager (Cringe reads), `DecisionCardSystem.inject_priority_card()`/`.card_resolved`, `PrestigeSystem.on_burnout_accepted()`/`.on_burnout_deferred()` | Autoload, registered strictly after DecisionCardSystem (LOW) |
| `ChallengeSystem` | Feature | challenge catalogue, active-selection set, per-axis modifier storage | `get_challenge_data()`, `select_challenges()`, `get_active_challenge_ids()`, `clear_active_challenges()`, `get_modifier(action_id, axis)`, `get_combined_meta_multiplier()` | — (pull-model only; read by ActionSystem and PrestigeSystem) | Autoload (LOW) |
| `ResourceSimulationStep` | Core (stateless) | none — pure H→M→Mult→Reach transition | `compute(...) -> {final_H, final_M, reach_gained}` | ResourceFormulas, PrestigeFormulas | none (LOW) |
| `LiveResourceTicker` | Core (scene-scoped) | fractional live-time accumulator | fixed 1s `_process()` cadence | ResourceSimulationStep, ResourceManager, ClassPathSystem, StaffSystem, PrestigeSystem | `Node._process()` only while ActionScreen exists (LOW) |
| `SponsorShieldControl` | Presentation | Shield status/countdown/affordability rendering | button forwards `activate_sponsor_shield()` | ResourceManager | `PanelContainer`, `Button` (LOW) |
| `MainNavCoordinator` (planned, not yet implemented — ADR-0014 Accepted) | Presentation | which-panel-is-open state (`NO_OVERLAY`/`PANEL_OPEN`/`CARD_PRESENTED`) | closes its own four panels (`ClassPathPanel`/`SettingsScreen`/`BonusesPanel`/`StaffPanel`, added 2026-07-22/2026-07-23 per `meta-bonus-visibility.md`/`staff-sponsor-ui.md`) on card-interrupt; never writes `CardScreen.visible` (mirror-not-hub, per Architecture Principle 8) | `ClassPathPanel`/`SettingsScreen`/`BonusesPanel`/`StaffPanel` open/close signals, `DecisionCardSystem.card_presented`/`.card_resolved`, `CardScreen.visibility_changed` | `Control`, platform back-gesture APIs (Android: gated by `application/config/quit_on_go_back`; Web: `JavaScriptBridge` + `history.pushState()` pattern, unverified; iOS out of scope — 2026-07-22) |
| `TeamStaffManagement`, `StaffSponsorUI`, `CosmeticPersonaCustomization` | Feature / Presentation / Presentation | — (Not Started, no GDD — placeholder layer assignment only, per `systems-index.md` rows 15/16/18) | — | — | — |

```
ActionUI ─┐                    CardUI ─┐              OfflineReportScreen
          ├─> ActionSystem            ├─> DecisionCardSystem ──┐
          │        │                  │        │               │
          │        v                  │        v               v
          └──> ResourceManager <───────┘   CardContentDatabase  OfflineProgressSystem
                    │  ^                    HistoryFlagManager        │
                    │  │                         │                    v
                    │  └── ClassPathSystem <─────┘               SaveSystem
                    │           │  ^                                  ^
                    │           v  │                                  │
                    │      ClassPathPanel/HUD                         │
                    v                                                 │
               SaveSystem <────────────────────────────────────────┬─┘
                    ^                                               │
                    │                                               │
              OnboardingGate (gates DecisionCardSystem only)        │
                                                                     │
   DecisionCardSystem.card_resolved (Wypalenie) ──> BurnoutSystem ──┤
                                                          │          │
                                                          v          │
                                                    PrestigeSystem ──┤
                                                     ^         │     │
                                          ChallengeSystem      v     │
                                          (pull: get_combined_    ClassPathSystem
                                           meta_multiplier(),     .reset_era_state()
                                           clear_active_challenges())

   ActionSystem.on_action_completed ──> ChallengeSystem.get_modifier() [pull, reward resolution]

   MainNavCoordinator (planned) ──reads──> ClassPathPanel/SettingsScreen/BonusesPanel/StaffPanel open state,
                                            DecisionCardSystem.card_presented/.card_resolved,
                                            CardScreen.visibility_changed
                       ──closes──> ClassPathPanel, SettingsScreen, BonusesPanel, StaffPanel (never CardScreen — mirror not hub)
```

## Data Flow

**1. Action completion path** (sync call → signal) — extended from v1:
```
Button.pressed → ActionUI → ActionSystem.start_action(id)
Timer.timeout → ActionSystem computes rewards:
  base_rewards * ClassPathSystem.get_active_multiplier(id) * ChallengeSystem.get_modifier(id, axis) [per axis, pull reads]
  → emits action_completed(id, rewards)
  → ResourceManager.apply_delta(rewards)   [direct call]
  → OnboardingGate.on_action_completed(id) [signal, peer]
  → DecisionCardSystem.on_action_completed() [signal] → maybe present_next_card()
```

**2. Card resolution path** — extended from v1 with Class Path and Burnout branches:
```
CardScreen swipe commit → DecisionCardSystem.resolve_choice(option)
  → ResourceManager.apply_delta(card_effects)
  → HistoryFlagManager.record_choice(card_id, option)
  → DecisionCardSystem emits card_resolved(card_id, path_tag, option_chosen)
      → ClassPathSystem._on_card_resolved() [signal] → recalculates affiliation, may emit tier_unlocked/active_path_changed
      → BurnoutSystem._on_card_resolved() [signal] → IF card_id == Wypalenie: routes Choice A/B synchronously into
        PrestigeSystem.on_burnout_accepted()/on_burnout_deferred() (same call stack, no await/call_deferred — ADR-0012's
        ordering guarantee inherited by ADR-0013)
  → CardScreen plays resolution beat (Juice/Feedback: FeedbackMath-computed shake/scale-pulse/flash on ResourceHud) → hides
```

**5. Burnout/prestige transition path** (new — synchronous orchestration, zero await/deferred in the call graph):
```
ActionScreen._ready() enables BurnoutSystem (and _exit_tree() pauses it) → while enabled, sustained Cringe=100 advances the accumulator → emits burnout_warning_changed(true, countdown)
  countdown expires (still sustained) → DecisionCardSystem.inject_priority_card(BURNOUT_CARD_ID)
    guarded on: return value checked (no soft-lock), DecisionCardSystem.state == COOLDOWN (no clobbering an in-progress card)
  Player resolves Wypalenie card → BurnoutSystem routes to PrestigeSystem.on_burnout_accepted():
    1. read ChallengeSystem.get_combined_meta_multiplier()   [pull, before any reset]
    2. compute grant via PrestigeFormulas.grant_magnitude(..., challenge_mult)
    3. apply grant to meta_bonus_totals
    4. ResourceManager reset (5 currencies)
    5. ClassPathSystem.reset_era_state()
    6. _sweep_era_local_flags() → ChallengeSystem.clear_active_challenges()  [era-local flags cleared last]
    7. era_count += 1 → emit era_transitioned (no args)
  (all steps 1–7 execute synchronously in one call stack — ADR-0012/ADR-0013's binding constraint)
  Post-era_transitioned (no longer under the zero-await constraint): ChallengeSystem's Challenge Selection screen
  presents 0–N modifier choices for the new era → select_challenges() stores the selection
```

**7. Live ambient resource path** (ADR-0020):
```
ActionScreen exists → LiveResourceTicker accumulates frame delta
  → for each complete 1s: ResourceSimulationStep.compute(H→M→Mult→Reach)
  → ResourceManager.apply_ambient_delta(one batch)
      → ResourceHud updates text, skips ambient juice
      → SaveSystem.mark_dirty(): restart 2s trailing timer, preserve first 10s deadline
ActionScreen freed → ticker freed → no live accrual on non-gameplay scenes
```

**6. Main Navigation coordination path** (new — GDD-complete, implementation pending Required ADR #1):
```
Player opens ClassPathPanel or SettingsScreen → panel sets its own visible=true (existing behavior, unchanged)
  → MainNavCoordinator observes the panel's open signal → coordination_state: NO_OVERLAY → PANEL_OPEN
Card interrupt while a panel is open (DecisionCardSystem.card_presented fires):
  → MainNavCoordinator closes whichever of its four panels is open (ClassPathPanel/SettingsScreen/BonusesPanel/StaffPanel only —
    never writes CardScreen.visible, per the mirror-not-hub boundary)
  → coordination_state: PANEL_OPEN → CARD_PRESENTED
  → on CardScreen.visibility_changed (false) → coordination_state: CARD_PRESENTED → NO_OVERLAY
Back gesture (Android/Web only — iOS out of scope, 2026-07-22, redundant not primary affordance):
  Android: gated by project setting application/config/quit_on_go_back (must be false, else engine's
    synchronous get_tree().quit() fallback fires regardless of any handler)
  Web: no true interception, only reaction — preventive history.pushState() pattern (unverified — Open Question,
    also gated on the unresolved Compatibility-renderer web-export spike)
```

**3. Save/load path** (unchanged from v1, module list extended):
```
On any Resource/History/Decision-cooldown/ClassPath/Prestige/Burnout/Challenge/Settings mutation →
  SaveSystem.mark_dirty() (restart 2s trailing Timer; start 10s max-age Timer only if stopped)
Either eligible timeout OR app NOTIFICATION_APPLICATION_PAUSED → SaveSystem.save_now() → stop both Timers
  → serializes: ResourceManager, HistoryFlagManager, DecisionCardSystem cooldown, OnboardingGate phase,
    ClassPathSystem.serialize_state(), PrestigeSystem.serialize_state(), BurnoutSystem.serialize_state(),
    ChallengeSystem.serialize_state(), SettingsSystem.serialize_state()
  → FileAccess write to temp file → rename (atomic)
```

**4. Initialization order** (extended — new modules restore in dependency order):
```
1. SaveSystem.load_save() — synchronous, blocks scene entry
2. ResourceManager, HistoryFlagManager, DecisionCardSystem, OnboardingGate, ClassPathSystem, PrestigeSystem,
   BurnoutSystem, ChallengeSystem, SettingsSystem restore from save data (autoload order: DecisionCardSystem
   before ClassPathSystem before BurnoutSystem — both later modules connect to its signals in _ready())
3. OfflineProgressSystem.simulate_offline(now - last_save_timestamp) — synchronous, <=1440 iterations
4. IF elapsed >= 300s: OfflineReportScreen shows (blocks input) ELSE proceed directly (ADR-0003 boot sequence)
5. Main scene (ActionUI, thin-wrapped by main.tscn) becomes interactive
```

All flows remain synchronous calls + Godot signals — no threading anywhere. The one binding exception is the burnout/prestige orchestration (Data Flow #5), which is synchronous by explicit architectural requirement (ADR-0012/ADR-0013), not merely by absence of need.

## API Boundaries

```gdscript
# ResourceManager (Autoload) — unchanged from v1, plus:
func activate_sponsor_shield() -> bool
func get_active_sponsor_multiplier() -> float   # pull-model precedent all later multiplier getters follow
signal shield_changed(is_active: bool, remaining_seconds: float)

# ClassPathSystem (Autoload)
func get_affiliation(path_id: StringName) -> float
func get_tier(path_id: StringName) -> int
func get_active_path() -> StringName
func get_active_multiplier(action_id: StringName) -> float
func can_invest(path_id: StringName) -> bool
func invest(path_id: StringName, resource_id: StringName, amount: float) -> bool
func get_ambiguous_gap() -> float
func reset_era_state() -> void   # called by PrestigeSystem only
signal tier_unlocked(path_id: StringName, tier: int)
signal active_path_changed(path_id: StringName)
signal signature_card_unlocked(card_id: StringName)
signal signature_card_removed(card_id: StringName)
# Guarantee: get_active_multiplier() is a pure function of current affiliation/tier state — safe to call
# from any reward-resolution context without ordering concerns (ADR-0010 precedent)

# PrestigeSystem (Autoload)
func on_burnout_accepted() -> void   # locked entry point — ADR-0012, zero await/call_deferred in call graph
func on_burnout_deferred(morale_cost: float) -> void
func get_era_count() -> int
func get_meta_bonus_total(bonus_type: StringName) -> float
func has_deferred_this_era() -> bool
signal era_transitioned   # no arguments — read era_count/meta_bonus via getters, not signal payload
# Invariant: on_burnout_accepted()'s internal call graph (read ChallengeSystem multiplier → grant → reset →
# ClassPathSystem reset → ChallengeSystem clear → era_count++) is entirely synchronous; nothing downstream
# may introduce await/CONNECT_DEFERRED/call_deferred without violating ADR-0012/ADR-0013

# BurnoutSystem (Autoload)
signal burnout_warning_changed(active: bool, seconds_remaining: float)
# Invariant: registered strictly after DecisionCardSystem in project.godot [autoload] order (its _ready()
# connects to DecisionCardSystem.card_resolved). Owns none of era_count/reset/grant — routes only.

# ChallengeSystem (Autoload)
func get_challenge_data(challenge_id: StringName) -> Dictionary
func select_challenges(challenge_ids: Array[StringName]) -> bool
func get_active_challenge_ids() -> Array[StringName]
func clear_active_challenges() -> void   # called by PrestigeSystem._sweep_era_local_flags() only
func get_modifier(action_id: StringName, axis: StringName) -> float   # pull, called by ActionSystem
func get_combined_meta_multiplier() -> float   # pull, called by PrestigeSystem before reset
# Guarantee: both getters are pure functions of current selection state — no cache, no push signal
# (Architecture Principle 7: pull-model multiplier getters, never push)

# SettingsSystem (Autoload)
func set_reduce_motion(value: bool) -> void   # sole write path; field `reduce_motion: bool` read directly
# Invariant: UI never mutates reduce_motion directly — "UI displays state, does not own it"

# DecisionCardSystem (Autoload) — unchanged surface, enum now explicit:
enum State { COOLDOWN, CHECKING, PRESENTING, RESOLVING }
func present_next_card(pool: Array[Dictionary]) -> void
func inject_priority_card(card_id: StringName) -> bool   # bool return MUST be checked by callers (ADR-0013)
func resolve_choice(option_index: int) -> void
signal card_presented(card: Dictionary)
signal card_resolved(card_id: StringName, path_tag: StringName, option_chosen: StringName)

# MainNavCoordinator (planned — API surface as specified by the GDD, not yet implemented)
# coordination_state: NO_OVERLAY | PANEL_OPEN | CARD_PRESENTED (enum, GDD States/Transitions table)
# Invariant (mirror not hub): reads ClassPathPanel/SettingsScreen/BonusesPanel/StaffPanel open signals and DecisionCardSystem
# signals; may call close() on the two panels it coordinates; NEVER writes CardScreen.visible directly.
# Known pre-existing bug this module must work around (found during /design-review, not yet fixed):
# SettingsScreen/ClassPathPanel Close buttons currently set visible=false on themselves directly,
# bypassing any future coordinator — BLOCKING rewiring requirement for whoever implements this module.
```

All types remain GDScript primitives/`Dictionary`/`Array[StringName]`/`Resource` — no engine API exceeding LOW risk anywhere in v2's additions.

## ADR Audit

### ADR Quality Check

| ADR | Engine Compat | Version | GDD Linkage | Conflicts | Valid |
|-----|--------------|---------|-------------|-----------|-------|
| ADR-0001: Autoload singleton vs event bus | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0002: Save file format, atomic write | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0003: Scene management and boot order | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0004: Action System timer/concurrency | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0005: Decision Card weighting/cooldown | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0006: Offline simulation loop | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0007: Action UI scene structure/autoload binding | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0008: Card UI modal/swipe integration | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0009: Offline Report Screen scene/data hand-off | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0010: Class Path System autoload/signal/multiplier | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0011: Juice/Feedback stateless math + UI effects | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0012: Prestige/Checkpoint autoload orchestration | ✅ | ✅ | ✅ | None | ✅ |
| ADR-0013: Burnout/Challenge trigger and selection | ✅ | ✅ | ✅ | None (internal inconsistency noted: Constraints line 41 vs 43 — both Stories 007/008 correctly followed line 43; non-blocking, flagged for a future ADR-0013 clarification pass) | ✅ |

All 13 ADRs pass structural completeness (Engine Compatibility section, version recorded, post-cutoff APIs flagged, GDD Requirements Addressed section present) and remain valid for the pinned 4.6.3 engine version. None conflict with the layer/ownership decisions made in this v2 session.

### Traceability Coverage Check

| Req ID | GDD | Requirement | ADR Coverage | Status |
|--------|-----|-------------|---------------|--------|
| TR-cps-001…009 (excl. 007) | class-path-system.md | Affiliation tracking, tier progression, active-path resolution, multiplier application, signature cards | ADR-0010 | ✅ |
| TR-jfs-001…007 | juice-feedback-system.md | Stateless shake/scale-pulse/flash math, additive UI effect nodes, reduce-motion gating | ADR-0011 | ✅ |
| TR-pcs-001…008 | prestige-checkpoint-system.md | Era orchestration, meta-bonus grant, five-currency reset, variety bonus, deferred-choice cost | ADR-0012 | ✅ |
| TR-bcs-001…006 | prestige-checkpoint-system.md (burnout sub-scope) | Trigger detection, warning countdown, forced card injection, choice routing, persistence | ADR-0013 | ✅ |
| TR-ecs-001…006 | prestige-checkpoint-system.md (challenge sub-scope) | Challenge catalogue, selection storage, modifier application, meta-multiplier pull, era-local reset | ADR-0013 | ✅ |
| TR-mns-001…N | main-navigation-screen-flow.md | At-most-one-panel coordination, card-interrupt priority, mirror-not-hub CardScreen boundary, cross-platform back gesture | **— GAP** | ❌ |
| Settings System (no formal TR-IDs assigned — GDD never written, retrofit candidate) | — | reduce_motion persistence, sole-write-path pattern | **— GAP** | ❌ |

Count: **35/37 new requirement groups covered, 2 gaps** (Main Navigation coordinator, Settings System). Both become Required New ADRs below. (11 MVP-GDD requirement groups from v1 remain covered by ADR-0001 through ADR-0009, unchanged.)

## Required ADRs

**Foundation/Feature Layer (must create before coding — both are currently zero-lines-of-code modules blocked on this):**
- `/architecture-decision "Main Navigation Coordinator — panel ownership, card-interrupt priority, cross-platform back gesture"` → covers all Main Navigation/Screen Flow TRs; also the mechanism to formally document the fix for the pre-existing Close-button-bypass bug found during `/design-review`
- `/architecture-decision "Settings System — Autoload shape and reduce_motion ownership"` → covers Settings System's currently-undocumented pattern (already shipped and working, but has zero ADR coverage — this is a retrofit, not new design)

**Feature Layer (should have before the relevant system is built):**
- `/architecture-decision "DecisionCardSystem inject_priority_card() reentrancy guard"` → covers the theoretical double-emission bug found during Main Navigation's `/design-review` (checks only `_priority_card_pending`, never `state`) — small, isolated fix to already-shipped code

**Can defer to implementation:**
- Web back-gesture concrete mechanism — explicitly unverified in the Main Navigation GDD, gated on the dedicated web-export spike; the coordinator ADR above should define the *contract* (what MainNavCoordinator expects from the platform) without committing to the unverified mechanism details
- Team/Staff Management, Staff/Sponsor UI, Cosmetic Persona Customization — no GDD yet; architecturally undecided by design (Not Started tier)

## Architecture Principles

1. **No threading, anywhere.** Every system, including the burnout/prestige orchestration's multi-step reset+grant sequence, is cheap enough to run synchronously on the main thread. Don't introduce threads pre-emptively.
2. **Signals over tight coupling, direct calls for ownership-clear writes.** Peer/notification relationships use signals (ClassPathSystem/BurnoutSystem watching `DecisionCardSystem.card_resolved`); direct ownership writes use direct calls (`BurnoutSystem` calling `PrestigeSystem.on_burnout_accepted()`). Don't route everything through an event bus.
3. **Data-driven content, hardcoded mechanics.** Card/challenge content lives in data files; formulas/thresholds live in code. Don't conflate the two.
4. **Autoload singletons for Core/Foundation/Feature, scenes for Presentation.** Matches Godot's idiomatic pattern; every new Feature-layer module in v2 (ClassPathSystem, PrestigeSystem, BurnoutSystem, ChallengeSystem) follows this without exception.
5. **Offline-first is a launch-time concern, not a background concern.** Per Pillar 4, offline simulation runs once at app launch, not on a timer or in the background.
6. **Synchronous orchestrations have zero `await`/`call_deferred` in their call graph.** Established by `PrestigeSystem.on_burnout_accepted()` (ADR-0012, inherited by ADR-0013) — guarantees read-before-reset ordering without races. Enforced by static grep, not only runtime tests. Apply this discipline to any future multi-step orchestration that must guarantee ordering.
7. **Pull-model getters for cross-system multipliers, never push.** `ClassPathSystem.get_active_multiplier()`, `ChallengeSystem.get_modifier()`/`get_combined_meta_multiplier()`, `ResourceManager.get_active_sponsor_multiplier()` — the consumer reads at the moment of use; the owner never pushes a change. Avoids premature synchronization and ordering-dependent bugs.
8. **Cross-system boundaries are "mirror, not hub" by default.** `MainNavCoordinator` (planned) reads `DecisionCardSystem` signals to know when to close its own panels, but never writes `CardScreen.visible` — it is a subscriber, not an owner, of state it doesn't need to control. Apply the same distinction whenever one system must react to another's state without taking over its ownership.

## Open Questions

- **Main Navigation/Screen Flow has no ADR despite a mature, 3-round-reviewed GDD** — the primary blocker before implementation; see Required ADRs #1.
- **Settings System has no ADR** — low urgency (shipped, working, trivial shape), but a real coverage gap; see Required ADRs #2.
- **`DecisionCardSystem.inject_priority_card()` reentrancy** — found during Main Navigation's 3rd `/design-review` round, verified against shipped code: checks only `_priority_card_pending`, never `state`, so a theoretical double-emission of `card_presented` is possible if called while a normal card is already presenting. `MainNavCoordinator`'s planned no-op guard (Core Rule 5a) is defense-in-depth, not the fix.
- **Web back-gesture interception mechanism** — unverified `JavaScriptBridge` + `history.pushState()` pattern, additionally gated on the still-backlogged Compatibility-renderer web-export spike (project defaults to Forward+; Web export requires Compatibility/WebGL2). Also unknown: what "browser back" does inside a CrazyGames portal iframe (warm in-iframe back vs. cold navigation away).
- **ADR-0013 internal inconsistency** (Constraints line 41 vs. 43) — non-blocking; both Stories 007 and 008 correctly followed line 43's explicit instruction. Flagged for a future ADR-0013 clarification pass, not urgent.
- **`balance.json`-style external data pattern never realized** — ADR-0004, 0005, 0010, 0013 all describe a "future data-driven source" that, in shipped code, is still a plain `const`. Tracked informally in `docs/tech-debt-register.md`; now also noted at the architecture level so it isn't lost across future ADRs that repeat the same aspiration.
- **Team/Staff Management, Staff/Sponsor UI, Cosmetic Persona Customization** — Not Started, no GDD, no architectural decisions made. Placeholder layer assignments only (System Layer Map above); revisit once `/design-system` is run for each.
