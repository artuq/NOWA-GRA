# Story 002: Action Reward Resolution & Morale Scaling

> **Epic**: Action System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/action-system.md`
**Requirement**: `TR-act-001`

**ADR Governing Implementation**: ADR-0004: Action System timer and single-concurrency enforcement *(primary)*; ADR-0001: Autoload singleton architecture & direct-call mutation *(secondary)*
**ADR Decision Summary**: On resolution, `ActionSystem._on_action_timeout()` reads the current Morale via `ResourceManager.get_resource(&"Morale")`, scales the base Reach reward by `ResourceFormulas.action_effectiveness_multiplier()` (round-half-away-from-zero via `roundf`), assembles the final `Dictionary[StringName, float]` deltas, writes them with `ResourceManager.apply_delta()` (direct call — ADR-0001 pattern), then emits `action_completed` carrying the final applied deltas. *(ADR-0004 was amended 2026-06-23 to correct a stale code sample that emitted base rewards without scaling/writing — see ADR-0004 "Correction (2026-06-23)".)*

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: `roundf()` rounds half-AWAY-from-zero in Godot (e.g. 7.5→8, 2.5→3) — this is the GDD's intended "round-half-up" for the non-negative reward values here. The half-band cases are the highest-risk part of the formula; test them explicitly.

**Control Manifest Rules (Core layer)**:
- Required: Offline/online resource formulas live in one stateless static utility class (`ResourceFormulas`); call `action_effectiveness_multiplier()` from there, never re-derive the band lookup here — source: ADR-0006
- Required: Resource mutation is a direct `ResourceManager.apply_delta()` call from the owning module; `action_completed` is notification-only — source: ADR-0001

---

## Acceptance Criteria

*From GDD `design/gdd/action-system.md` (Reward formula at each Morale band, Cringe/Morale flat lookups, defined edge cases). Reward keys use the production English key `&"Reach"` (the GDD's "Zasięgi"):*

- [ ] The 3 actions have a static reward table keyed by `action_id`: Nagraj vloga (duration 6s, base Reach +5, Cringe +2, Morale 0); Zrób dramę (9s, +10, +20, -3); Przeproś w internecie (4s, +6, -15, +5). Values match the GDD reward table exactly.
- [ ] `final_reach = roundf(base_reach × action_effectiveness_multiplier(current_morale))`. Verified cases: Zrób dramę base 10 at High (1.0) → 10; at Normal (0.9) → 9 (10×0.9=9.0); Nagraj vloga base 5 at Low (0.75) → 4 (3.75→4); Przeproś base 6 at Critical (0.5) → 3 (3.0).
- [ ] On resolution, `_on_action_timeout()` writes ALL of the final scaled Reach + flat Cringe + flat Morale deltas to `ResourceManager.apply_delta()` in ONE atomic call, as a `Dictionary[StringName, float]` with keys `&"Reach"`, `&"Cringe"`, `&"Morale"`.
- [ ] The Morale multiplier read at resolution is exactly one of `{0.5, 0.75, 0.9, 1.0}` — never interpolated (delegated to `ResourceFormulas.action_effectiveness_multiplier()`, not re-derived here).
- [ ] GIVEN Cringe is already 100, WHEN Zrób dramę (Cringe Δ +20) resolves, THEN ActionSystem passes +20 unmodified to `apply_delta()`; the resulting Cringe is governed solely by Resource System's clamp (final Cringe stays 100). ActionSystem applies no special-casing.
- [ ] `action_completed(action_id: StringName, rewards: Dictionary)` is emitted AFTER the `apply_delta()` write, and its `rewards` payload is the final applied deltas (post-scaling), per the ADR-0004 2026-06-23 correction — not the raw base values.

---

## Implementation Notes

*Derived from ADR-0004 (corrected Decision code) + ADR-0001 direct-call pattern:*

Extend Story 001's `_on_action_timeout()` to scale and write rewards:

```gdscript
func _on_action_timeout() -> void:
    var completed_id := current_action_id
    current_action_id = &""
    var base_rewards: Dictionary = ACTION_REWARDS[completed_id]
    var morale := ResourceManager.get_resource(&"Morale")
    var multiplier := ResourceFormulas.action_effectiveness_multiplier(morale)
    var scaled_reach := roundf(base_rewards[&"Reach"] * multiplier)
    var deltas: Dictionary[StringName, float] = {
        &"Reach": scaled_reach,
        &"Cringe": base_rewards[&"Cringe"],
        &"Morale": base_rewards[&"Morale"],
    }
    ResourceManager.apply_delta(deltas)
    action_completed.emit(completed_id, deltas)
```

**Reward table location**: `ACTION_REWARDS` and `ACTION_DURATIONS` are typed const lookups keyed by `action_id`. Per `coding-standards.md` ("gameplay values must be data-driven"), these are candidates for extraction to a `.tres` data resource — for this story a typed const dict is acceptable (mirrors the Resource System's `_CLAMPED_KEYS` precedent), but **log a tech-debt note** that the action reward/duration tables should move to an external data file once balance tuning begins.

**Dependency injection for testability**: this story calls the `ResourceManager` and `ResourceFormulas` singletons. To keep the integration test deterministic and isolated, allow the `ResourceManager` dependency to be injected (or the Morale value to be set to a known band) so each band's scaling can be tested without driving the full Resource System. `ResourceFormulas` is a stateless static utility — call it directly.

---

## Out of Scope

*Handled by neighbouring stories / other epics — do not implement here:*

- Story 001: the Timer, single-concurrency guard, and `get_progress()` — this story only extends `_on_action_timeout()`'s reward behavior.
- Resource System: the clamp itself (Formula E), the multiplier band lookup (Formula C) — both already built and called, not re-implemented here.
- Action UI epic: any display of the awarded rewards.
- Offline Progress System: applying this reward table across offline time deltas (it will query the same `ACTION_REWARDS`, but that simulation is its own epic).

---

## QA Test Cases

*Written by qa-lead (QL-STORY-READY gate, on opus). The developer implements against these.*

- **AC-1 (reward table values)**:
  - Given: the ActionSystem reward table
  - When: each action's entry is read
  - Then: values exactly match Nagraj (6s,+5,+2,0) / Zrób dramę (9s,+10,+20,-3) / Przeproś (4s,+6,-15,+5)
- **AC-2 (Morale scaling, round-half-away-from-zero)** — the highest-risk AC:
  - Given: a known Morale band → known multiplier
  - When: an action resolves
  - Then: `final_reach` matches: drama@1.0→10, drama@0.9→9, vlog(5)@0.75→4 (3.75→4), przeproś(6)@0.5→3
  - Edge: explicitly test a `.5` boundary result (e.g. a base/mult combination yielding x.5) to lock `roundf` half-away-from-zero behavior
- **AC-3 (atomic single apply_delta with correct dict shape)**:
  - Given: an action resolves at a known Morale
  - When: `_on_action_timeout()` runs
  - Then: `ResourceManager.apply_delta()` is called exactly once with a `Dictionary[StringName, float]` containing keys `&"Reach"`, `&"Cringe"`, `&"Morale"` and the final scaled/flat values
- **AC-4 (multiplier is discrete, never interpolated)**:
  - Given: Morale values across all 4 bands and at the band boundaries (0, 14, 15, 39, 40, 69, 70, 100)
  - When: resolution reads the multiplier
  - Then: the multiplier used is always exactly one of {0.5, 0.75, 0.9, 1.0}
- **AC-5 (Cringe=100 clamp passthrough)**:
  - Given: Cringe is 100, Zrób dramę resolves (Cringe Δ +20)
  - When: `apply_delta()` is called
  - Then: ActionSystem passes +20 unmodified; final Cringe (after Resource System clamp) is 100; ActionSystem does no special-casing
- **AC-6 (signal fires after write, carries final deltas)**:
  - Given: an action resolves
  - When: `action_completed` is observed
  - Then: it is emitted AFTER `apply_delta()` returns, and its `rewards` payload equals the final applied deltas dict (post-scaling), not the base values

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/action_system/action_system_reward_resolution_test.gd` — must exist and pass

**Status**: [x] Created and passing — `tests/integration/action_system/action_system_reward_resolution_test.gd`, 11/11 passing (verified via `addons/gdUnit4/runtest.sh`, 2026-06-24)

---

## Dependencies

- Depends on: Story 001 (ActionSystem core — `_on_action_timeout()` exists to extend) must be DONE; Resource System epic (`ResourceManager.apply_delta`, `ResourceManager.get_resource`, `ResourceFormulas.action_effectiveness_multiplier`) — Complete.
- Unlocks: None within this epic. Downstream: Offline Progress System (queries the same reward table); Action UI (displays awarded rewards).

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 6/6 passing (none deferred)
**Deviations**: 1 advisory, fixed before closure — `_on_action_timeout()` had no guard against firing with `current_action_id == &""` (unreachable in production, flagged by both director gates as non-blocking); added an early-return guard plus a regression test (`test_action_timeout_with_no_active_action_is_a_noop`) rather than deferring it.
**Test Evidence**: Integration — `tests/integration/action_system/action_system_reward_resolution_test.gd`, 11/11 passing (full regression 74/74 passing)
**Code Review**: Complete — inline `/code-review` APPROVED WITH SUGGESTIONS; LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
