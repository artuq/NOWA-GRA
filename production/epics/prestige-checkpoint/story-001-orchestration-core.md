# Story 001: PrestigeSystem Orchestration Core

> **Epic**: Prestige/Checkpoint System
> **Status**: Blocked
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (4h+)
> **Manifest Version**: 2026-06-20
> **Last Updated**:

**BLOCKED**: ADR-0012 is Proposed — run `/architecture-review` in a fresh session to move it to Accepted before starting this story.

## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §1-2 (PrestigeSystem Autoload, synchronous orchestration)
**ADR Decision Summary**: New Core Autoload `PrestigeSystem`, registered below `ClassPathSystem`, `DecisionCardSystem`, `SaveSystem`, `HistoryFlagManager`. Single entry point `on_burnout_accepted()` performs the entire read-then-reset-then-grant-then-sweep-then-save sequence synchronously — zero `await`, zero `CONNECT_DEFERRED`, anywhere in the call graph.

**Engine**: Godot 4.6.3 | **Risk**: LOW (highest ordering-risk story in this epic — see Risks)
**Engine Notes**: Typed Dictionary syntax (`Dictionary[StringName, float]`) is 4.4+, safe in 4.6.3.

**Control Manifest Rules (this layer)**:
- Required: implement as Autoload singleton (ADR-0001); use `restore_state(data: Dictionary)` boot protocol (ADR-0003)
- Forbidden: no `await`/`CONNECT_DEFERRED`/`call_deferred` anywhere in `on_burnout_accepted()` or its call graph (ADR-0012, binding constraint) — this is a project-specific addition to the Core layer's forbidden list for this story only
- Guardrail: `on_burnout_accepted()` runs once per era transition (rare event) — no per-frame cost

---

## Acceptance Criteria

*From GDD `design/gdd/prestige-checkpoint-system.md` §Critical Ordering, scoped to this story:*

- [ ] GIVEN `pato_streamer` is at Tier 3 when Choice A is confirmed, WHEN `PrestigeSystem` processes the transition, THEN `get_active_path()`/`get_tier()` are read and captured before `reset_era_state()` is invoked — the tier value used downstream is `3`, not `0`
- [ ] GIVEN the same transition, THEN `era_transitioned` fires only after the meta-bonus read+grant step completes — any listener observes already-updated `META_BONUS_total` values
- [ ] GIVEN the real (non-mocked) `ClassPathSystem` and `PrestigeSystem` integrated together, WHEN a Tier-3 `pato_streamer` burnout's Choice A resolves, THEN the tier value captured end-to-end through the real `reset_era_state()` call chain is verified to be `3`, with no `call_deferred` anywhere in the path — **must be on the Vertical Slice QA checklist, real collaborators required**
- [ ] `PrestigeSystem` registered as Autoload below its 4 dependencies in `project.godot`
- [ ] Static grep check (code review): zero `await`/`CONNECT_DEFERRED` matches across `prestige_system.gd`, `class_path_system.gd`'s `get_active_path`/`get_tier`/`reset_era_state`, `ChallengeSystem.get_combined_meta_multiplier()`, `HistoryFlagManager`'s sweep calls, and `SaveSystem.save_now()`/`resume_autosave()` call graphs

---

## Implementation Notes

*Derived from ADR-0012 §1-2:*

```gdscript
func on_burnout_accepted() -> void:
    var path_id: StringName = ClassPathSystem.get_active_path()
    var tier: int = ClassPathSystem.get_tier(path_id) if path_id != &"" else 0
    var challenge_mult: float = ChallengeSystem.get_combined_meta_multiplier()
    SaveSystem.suppress_autosave()
    ClassPathSystem.reset_era_state()
    # ... grant computation (Story 003/004), flag sweep (Story 007) ...
    era_count += 1
    SaveSystem.save_now()
    SaveSystem.resume_autosave()
    era_transitioned.emit()
```

This story implements the skeleton and the ordering contract only — the grant computation (calls into `PrestigeFormulas`) and the flag sweep are stubbed/no-op placeholders here, filled in by Stories 003/004 and 007 respectively. The critical deliverable of this story is the ordering guarantee itself, independently testable against a mocked `PrestigeFormulas`/`HistoryFlagManager`.

`PrestigeSystem` is the *caller*, not a *listener* — see ADR-0012 §2's "Why not a signal-driven design" for the rationale.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003/004: actual `PrestigeFormulas.grant_magnitude()` computation and stacking
- Story 007: the real flag classification sweep (stub only here)
- Story 008: autosave suppression window correctness under app-kill (this story wires the calls; Story 008 tests the atomicity guarantee)

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (read-before-reset)**:
  - Given: mocked `ClassPathSystem` returning Tier 3 for `pato_streamer`
  - When: `on_burnout_accepted()` runs
  - Then: the captured tier value (passed to the stub grant computation) is `3`, verified via spy/mock assertion, not by re-querying `ClassPathSystem` after reset
  - Edge cases: `ClassPathSystem.reset_era_state()` mock immediately zeroes state — test must fail if implementation reads tier after calling reset

- **AC-2 (signal timing)**:
  - Given: mocked collaborators
  - When: `on_burnout_accepted()` runs
  - Then: `era_transitioned` signal is connected to a spy; spy confirms it fires only after all mocked grant/sweep/save calls have been made, in order

- **AC-3 (real collaborators end-to-end)**:
  - Given: real `ClassPathSystem` at Tier 3 for `pato_streamer`
  - When: `on_burnout_accepted()` runs
  - Then: grant computation receives tier `3` (verify via `PrestigeSystem.get_meta_bonus_total()` post-transition, since Story 003 will have real formulas by the time this AC is exercised — if run before Story 003, assert via a temporary spy on `PrestigeFormulas.grant_magnitude()`'s tier argument)

- **AC-4 (Autoload order)**: manual/code-review check — `project.godot`'s Autoload list has `PrestigeSystem` after its 4 dependencies

- **AC-5 (static await check)**: code review, not a runtime test — grep as specified in Validation Criteria

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/prestige/prestige_orchestration_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (foundational — first story in this epic)
- Unlocks: Stories 002-009 (all call into or extend `on_burnout_accepted()`)
