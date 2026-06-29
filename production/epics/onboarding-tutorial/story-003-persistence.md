# Story 003: Persistence — Save/Load & Boot Wiring

> **Epic**: Onboarding/Tutorial
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-29

## Context

**GDD**: `design/gdd/onboarding-tutorial.md`
**Requirement**: `TR-onb-001` — Decision Card suppression (Phase 1) and force-cooldown-zero (Phase 1→2) — this story makes the onboarding phase survive save/load, per the GDD's 5 defined edge cases
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (primary — `restore_state()` contract + `BootController` call order); ADR-0002 (secondary — save file format, the `mark_dirty()` wiring this story must also use, per the recently-fixed pattern)
**ADR Decision Summary**: `OnboardingGate` gains `serialize_state()`/`restore_state(data)` (same shape as `ResourceManager`/`HistoryFlagManager`). `SaveSystem.save_now()`'s payload gains a real `"onboarding"` key (currently the payload has no such key at all — `OnboardingGate` doesn't exist yet in that file). `BootController.boot_with()` calls `OnboardingGate.restore_state()` in the correct dependency order, alongside the existing `ResourceManager`/`HistoryFlagManager` calls.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: This story directly depends on the `SaveSystem.mark_dirty()` wiring fixed 2026-06-29 (see `docs/tech-debt-register.md`) — without that fix, onboarding phase changes (like every other mutation) would never actually be written to disk. Confirm that fix is in place before testing this story's save/load behavior; `OnboardingGate`'s own mutation method must also call `SaveSystem.mark_dirty()` following that same pattern.

**Control Manifest Rules (this layer — Core)**:
- Required: `serialize_state()`/`restore_state(data)` method signatures match the existing `ResourceManager`/`HistoryFlagManager` convention exactly (plain `String` keys in the returned Dictionary, since `StringName` is not a JSON type); `OnboardingGate`'s phase-mutating method calls `SaveSystem.mark_dirty()` (per the 2026-06-29 fix's established pattern — do not reintroduce the same gap for a 4th module)
- Forbidden: do not invent a new save-file top-level shape; extend the existing `{schema_version, last_saved_at, resources, history_flags, decision_card_state}` Dictionary with one additional `"onboarding"` key, following the established sibling-key convention
- Guardrail: `restore_state()` must never call `mark_dirty()` (a load must not re-trigger a save — same rule already enforced on `ResourceManager`/`HistoryFlagManager`, confirmed by code review on the 2026-06-29 fix)

---

## Acceptance Criteria

*From GDD `design/gdd/onboarding-tutorial.md`'s Edge Cases section, scoped to this story:*

- [ ] App closes during `phase_pure_action` with 1 of 3 types completed, then relaunches → state restores to `phase_pure_action` with that exact type marked complete, others still pending (read from save, never reset)
- [ ] App closes right after entering `phase_first_card_pending`, then relaunches → state restores to `phase_first_card_pending`; the `DecisionCardSystem` cooldown-zero effect survives (the next completed action still triggers an immediate card, not a delayed one)
- [ ] No save file exists (fresh install/reinstall) → initializes `phase_pure_action`, 0 of 3 types — identical to true first-session behavior
- [ ] `phase_normal` with a developer/QA data reset (no special mechanism required — a cleared/absent save file is sufficient) → relaunch initializes `phase_pure_action`, 0 of 3 — identical to a fresh install, no "returning player" special case
- [ ] All 3 types complete in any of the 6 possible permutations, with a save/load occurring mid-sequence at an arbitrary point → the transition still fires at the same logical point (after the 3rd distinct type) regardless of when the save/load happened

---

## Implementation Notes

*Derived from ADR-0003's restore_state contract + the real SaveSystem payload shape (see Offline Report Screen Story 003's "Discovered Deviations" note — ADR-0003's own code sample is stale, implement against the real APIs):*

**`OnboardingGate` persistence methods** (extends Story 001/002's file):

```gdscript
## Returns this module's persisted state, per the established sibling
## convention (ResourceManager.serialize_state(), HistoryFlagManager.
## serialize_state()) -- plain String keys/values only (JSON-serializable).
func serialize_state() -> Dictionary:
    return {
        "phase": phase,  # int (enum value)
        "completed_types": _completed_types.keys().map(func(k): return String(k)),
    }

## Restores from [param data] (the "onboarding" sub-dict, or {} on first
## session). Does NOT call SaveSystem.mark_dirty() -- a load must never
## re-trigger a save (same rule as ResourceManager/HistoryFlagManager).
func restore_state(data: Dictionary) -> void:
    phase = data.get("phase", Phase.PURE_ACTION) as Phase
    _completed_types.clear()
    for type_str: String in data.get("completed_types", []):
        _completed_types[StringName(type_str)] = true
```

The phase-mutating method (`on_action_completed` from Story 001, or wherever the phase assignment happens) must call `SaveSystem.mark_dirty()` after a phase change — follow the exact pattern from the 2026-06-29 fix (`ResourceManager.apply_delta`'s guard-then-mark-dirty shape): only mark dirty when something actually changed (a no-op `on_action_completed` call in `phase_normal`, or a repeat-type call that doesn't advance the variety gate, should NOT mark dirty).

**`SaveSystem.save_now()`** (`src/core/save_system.gd`): add `"onboarding": OnboardingGate.serialize_state(),` to the `data` Dictionary literal, alongside the existing `"resources"`/`"history_flags"`/`"decision_card_state"` keys.

**`BootController.boot_with()`** (`src/core/boot_controller.gd`): add `OnboardingGate.restore_state(data.get("onboarding", {}))` alongside the existing `ResourceManager.restore_state(...)`/`HistoryFlagManager.restore_state(...)` calls, in the dependency order `control-manifest.md` specifies (`OnboardingGate` after `ActionSystem`/`OfflineProgressSystem`, before `DecisionCardSystem` — though `DecisionCardSystem` itself has no `restore_state` yet, an existing out-of-scope gap noted in Offline Report Screen Story 003, not this story's job to fix).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001 (State Machine): the phase-transition logic — this story only persists/restores it
- Story 002 (Live Wiring): the real signal subscription and `DecisionCardSystem` calls — already built; this story's `restore_state()` only needs to put the state machine back where it was, the live wiring then continues normally from there
- `DecisionCardSystem`'s own persistence (the `decision_card_state` save key is a pre-existing hardcoded stub, not a real implementation) — a known, separate gap, out of scope here

---

## QA Test Cases

*Interaction-test specs against the real `OnboardingGate`/`SaveSystem`/`BootController` — same pattern as Offline Report Screen Story 003's `boot_flow_test.gd`.*

- **AC: mid-phase save/restore**
  - Given: `OnboardingGate` with 1 of 3 types completed
  - When: `serialize_state()` is captured, the gate is reset, then `restore_state()` is called with that captured data
  - Then: phase is `phase_pure_action`, exactly that one type is marked complete, the other two are not
  - Edge cases: restore with 2 of 3 types; restore with all 3 (should this even be a valid persisted state, or does the transition always fire before a save could capture it? — confirm: GDD's "all 3 collected mid-call" transitions synchronously, so a save can only ever capture 0, 1, or 2 types in `phase_pure_action`, or `phase_first_card_pending`/`phase_normal` with the type-set irrelevant at that point)

- **AC: phase_first_card_pending survives restore**
  - Given: `OnboardingGate` in `phase_first_card_pending`
  - When: serialized then restored
  - Then: phase restores to `phase_first_card_pending`; the next `on_action_completed_signal` call still transitions to `phase_normal` and still triggers the cooldown-zero effect via Story 002's wiring (verify end-to-end, not just the phase value)

- **AC: fresh install / no save data**
  - Given: `restore_state({})`
  - When: called
  - Then: phase is `phase_pure_action`, `_completed_types` is empty — identical to a brand-new `OnboardingGate` instance

- **AC: BootController wiring**
  - Given: a real boot sequence (via `BootController.boot_with()`, the test seam from Offline Report Screen Story 003)
  - When: boot runs with a save Dictionary containing an `"onboarding"` key
  - Then: `OnboardingGate.restore_state()` is called with that exact sub-dict; `OnboardingGate.phase` reflects the restored value
  - Edge cases: save Dictionary with no `"onboarding"` key at all (older save format / first session under this story) → falls back to fresh `phase_pure_action`, no crash

- **AC: SaveSystem.save_now() payload**
  - Given: `OnboardingGate` in a known non-default phase
  - When: `SaveSystem.save_now()` is called
  - Then: the written JSON contains an `"onboarding"` key matching `OnboardingGate.serialize_state()`'s shape

- **AC: mark_dirty wiring on phase change**
  - Given: the real `SaveSystem` Autoload, its debounce timer stopped
  - When: an `on_action_completed` call that actually advances the variety gate or the phase fires
  - Then: `SaveSystem._debounce_timer.is_stopped()` becomes `false` (same pattern as `mark_dirty_call_sites_test.gd`)
  - Edge cases: a repeat-type call in `phase_pure_action` that does NOT advance the gate must NOT mark dirty; any call in `phase_normal` (terminal, no mutation) must NOT mark dirty

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/onboarding/onboarding_persistence_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Live Wiring) — persists the fully-wired system's state
- Unlocks: None — final story; completing it makes the Onboarding/Tutorial epic fully done (last unbuilt MVP system)
