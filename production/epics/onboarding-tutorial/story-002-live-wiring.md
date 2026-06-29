# Story 002: Live Wiring — ActionSystem & DecisionCardSystem Integration

> **Epic**: Onboarding/Tutorial
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-29

## Context

**GDD**: `design/gdd/onboarding-tutorial.md`
**Requirement**: `TR-onb-001` — Decision Card suppression (Phase 1) and force-cooldown-zero (Phase 1→2) — this story wires Story 001's state machine to the real `ActionSystem`/`DecisionCardSystem` Autoloads
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 (primary — the exact `force_cooldown_zero()`/`is_card_suppressed()` contract); ADR-0001 (secondary — multi-subscriber signal pattern, Autoload registration order)
**ADR Decision Summary**: `OnboardingGate` subscribes to `ActionSystem.action_completed` in `_ready()` (a peer/notification relationship — signal, per ADR-0001). `DecisionCardSystem` gains an additive `force_cooldown_zero()` method (called only by `OnboardingGate`, a direct ownership-clear write) and reads `OnboardingGate.is_card_suppressed()` directly (an ownership-clear read) inside its existing `_on_action_completed()`, before any cooldown decrement.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Autoload registration order matters for `_ready()`-time signal subscriptions only (ADR-0001's boot-order rule: a subscriber connecting in `_ready()` must be registered *below* its emitter, or the connection silently never fires — no error). `OnboardingGate` and `DecisionCardSystem` both subscribe to `ActionSystem.action_completed`, so both must be registered below `ActionSystem`. Per `control-manifest.md`'s documented exact order, `OnboardingGate` goes between `OfflineProgressSystem` and `DecisionCardSystem`.

**Control Manifest Rules (this layer — Core)**:
- Required: register `OnboardingGate` in `project.godot`'s `[autoload]` section in the exact documented order: `ResourceManager`, `HistoryFlagManager`, `CardContentDatabase`, `SaveSystem`, `ActionSystem`, `OfflineProgressSystem`, `OnboardingGate`, `DecisionCardSystem` (current order has `DecisionCardSystem` before `OfflineProgressSystem` — this story corrects the order to match the manifest exactly)
- Forbidden: `DecisionCardSystem` calling into `OnboardingGate` by checking if the global exists first, or any signal-based suppression check — per ADR-0005, this is a direct read, no indirection
- Guardrail: the suppression check + `force_cooldown_zero()` call must not alter `DecisionCardSystem`'s existing behavior when `OnboardingGate.is_card_suppressed()` returns `false` (i.e., post-onboarding) — all existing Decision Card System tests must stay green unmodified

---

## Acceptance Criteria

*From GDD `design/gdd/onboarding-tutorial.md`'s Interactions with Other Systems + Acceptance Criteria, scoped to this story (real signal wiring; the phase-transition logic itself is Story 001, already done):*

**Suppression wiring:**
- [ ] While `OnboardingGate.is_card_suppressed()` is `true`, completing actions never decrements `DecisionCardSystem`'s cooldown counter and never triggers a card pool check (no card presented), regardless of how many actions complete
- [ ] The moment `OnboardingGate`'s phase transitions to `phase_first_card_pending` (the 3rd distinct action type completes), `OnboardingGate` calls `DecisionCardSystem.force_cooldown_zero()` exactly once
- [ ] After `force_cooldown_zero()`, the very next completed action triggers a card pool check immediately (cooldown was 0, decrements to ≤0 on the next `_on_action_completed`)
- [ ] Once `OnboardingGate` reaches `phase_normal`, `DecisionCardSystem` operates with zero onboarding intervention — normal 2-action cooldown, weighting, etc. (existing Decision Card System behavior, unmodified)

**Resources/History Flags never gated:**
- [ ] While suppressed (`phase_pure_action`), every completed action still updates `ResourceManager` (Reach/Cringe/Morale) and `HistoryFlagManager` exactly as in `phase_normal` — onboarding only ever gates `DecisionCardSystem`'s card-pool checking, never resource/flag writes

**Rewards never modified:**
- [ ] The same action executed once during `phase_pure_action` and once during `phase_normal` produces identical reward output per `ActionSystem`'s existing reward table — no onboarding-specific boost or penalty exists anywhere in this implementation

---

## Implementation Notes

*Derived from ADR-0005's Decision + Implementation Guidelines (corrected for the real, non-stale API):*

**`DecisionCardSystem` additive changes** (`src/core/decision_card_system.gd`):

```gdscript
## Forces the cooldown counter to 0 -- called only by OnboardingGate, at the
## Phase 1->2 transition (architecture.md Decision: ownership-clear direct
## write, OnboardingGate owns this call). The next completed action triggers
## an immediate pool check.
func force_cooldown_zero() -> void:
    _actions_until_check = 0
```

In the existing `_on_action_completed(_action_id, _rewards)` (currently at the top of the function, before the `if state != State.COOLDOWN: return` guard or right after — confirm ordering doesn't change existing test outcomes), add:

```gdscript
func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
    if OnboardingGate.is_card_suppressed():
        return  # Phase 1: don't even decrement, per onboarding-tutorial.md
    if state != State.COOLDOWN:
        return
    _actions_until_check -= 1
    if _actions_until_check <= 0:
        state = State.CHECKING
        _check_pool()
```

**`OnboardingGate._ready()`** (extends Story 001's state machine):

```gdscript
func _ready() -> void:
    ActionSystem.action_completed.connect(_on_action_completed_signal)

func _on_action_completed_signal(action_id: StringName, _rewards: Dictionary) -> void:
    var was_pure_action: bool = phase == Phase.PURE_ACTION
    on_action_completed(action_id)  # Story 001's logic
    if was_pure_action and phase == Phase.FIRST_CARD_PENDING:
        DecisionCardSystem.force_cooldown_zero()
```

(Detecting the transition via a before/after phase comparison, rather than putting the `force_cooldown_zero()` call inside Story 001's pure logic method, keeps that method's unit tests free of any `DecisionCardSystem` dependency — confirm this split with Story 001's implementation before finalizing.)

**`project.godot` Autoload reorder**: current order is `ResourceManager, HistoryFlagManager, CardContentDatabase, SaveSystem, ActionSystem, DecisionCardSystem, OfflineProgressSystem`. Change to: `ResourceManager, HistoryFlagManager, CardContentDatabase, SaveSystem, ActionSystem, OfflineProgressSystem, OnboardingGate, DecisionCardSystem` (moves `DecisionCardSystem` to last, inserts `OnboardingGate` before it) — matches `control-manifest.md` exactly. Re-run the full test suite after reordering; Autoload order changes are a known regression risk (verify via a real headless run, not just `scene_runner`, per the lesson from Offline Report Screen Story 003).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001 (State Machine): the phase-transition logic itself — already built, this story only adds the real signal subscription and the cross-module calls
- Story 003 (Persistence): `restore_state()`/`serialize_state()`, save/load, `BootController` wiring

---

## QA Test Cases

*Interaction-test specs against the real Autoloads — the standing method for cross-system wiring stories (see Card UI Story 002/003 precedent).*

- **AC: suppression blocks cooldown decrement and card presentation**
  - Given: a fresh game state (real `OnboardingGate` in `phase_pure_action`, real `DecisionCardSystem`)
  - When: multiple actions complete (fewer than all 3 distinct types)
  - Then: `DecisionCardSystem`'s cooldown counter is unchanged from its initial value; no `card_presented` signal fires
  - Edge cases: 5+ actions of the same single type — still no decrement, no card

- **AC: force_cooldown_zero fires exactly once at the Phase 1→2 transition**
  - Given: 2 of 3 distinct types completed
  - When: the 3rd distinct type completes
  - Then: `DecisionCardSystem`'s cooldown counter becomes 0 (verify via its public state or the next action's behavior); the next completed action triggers an immediate pool check
  - Edge cases: a repeat of an already-seen type just before the 3rd new type does not falsely trigger this

- **AC: phase_normal — zero onboarding intervention**
  - Given: `OnboardingGate` in `phase_normal`
  - When: actions complete repeatedly
  - Then: `DecisionCardSystem`'s normal 2-action cooldown/weighting applies exactly as it does with no `OnboardingGate` involvement (regression-equivalent to pre-onboarding behavior)

- **AC: Resources/History Flags never gated**
  - Given: `phase_pure_action` (suppressed)
  - When: an action completes
  - Then: `ResourceManager`'s Reach/Cringe/Morale update exactly as they would in `phase_normal`; `HistoryFlagManager` counters/milestones (if any apply) update identically

- **AC: rewards never modified**
  - Given: the same action executed once in `phase_pure_action` and once in `phase_normal`
  - When: rewards are compared
  - Then: identical deltas per `ActionSystem`'s existing reward table

- **AC: Autoload reorder regression guard**
  - Given: the full existing test suite (Decision Card System, Action System, Action UI, Card UI, Offline Report Screen)
  - When: run after the `project.godot` Autoload reorder
  - Then: zero regressions; additionally, a real headless cold-start run (not just `scene_runner`) confirms no silent signal-connection failure from the reorder

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/onboarding/onboarding_live_wiring_test.gd` — must exist and pass; full suite regression confirmed; at least one real headless cold-start run documented

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (OnboardingGate State Machine) — extends its `_ready()` and phase-transition detection
- Unlocks: Story 003 (Persistence) — the live-wired system this story produces is what gets saved/restored

---

## Completion Notes
**Completed**: 2026-06-29
**Criteria**: all passing (5 interaction tests: suppression blocks decrement, force_cooldown_zero fires at transition, next action triggers immediate PRESENTING, phase_normal zero intervention, resources never gated) + 5 pre-existing DecisionCardSystem-related test files updated to force `OnboardingGate.phase = NORMAL` in their setup/teardown
**Deviations**: a real cross-subscriber signal-ordering bug was found and fixed during testing — both `OnboardingGate` and `DecisionCardSystem` subscribe to `ActionSystem.action_completed`; calling `force_cooldown_zero()` synchronously (direct call) from the transition handler let `DecisionCardSystem`'s own handler for the SAME transition-causing action see suppression already lifted, immediately triggering a pool check on the 3rd action instead of the 4th (violating the GDD's explicit "4th overall, at minimum" AC). Fixed via `DecisionCardSystem.call_deferred(&"force_cooldown_zero")`, landing strictly after the event's full synchronous handler chain, independent of Autoload connection order.
**Test Evidence**: Integration — `tests/integration/onboarding/onboarding_live_wiring_test.gd`, 5/5 passing (full regression 286/286, stable across multiple consecutive clean runs + 2 real headless cold-start runs verifying the Autoload reorder)
**Code Review**: Complete — godot-specialist verdict ISSUES FOUND → fixed (1 real gap: `test_next_action_after_transition_triggers_immediate_check` lacked the `await get_tree().process_frame` needed for the deferred call to land, making its OR-assertion a tautology proving nothing — fixed with the await + tightened to assert `State.PRESENTING` specifically, since `CardContentDatabase`'s pool is never empty). `call_deferred` confirmed the correct, idiomatic Godot 4.6 fix; suppression-check ordering confirmed correct; Autoload reorder confirmed safe.
