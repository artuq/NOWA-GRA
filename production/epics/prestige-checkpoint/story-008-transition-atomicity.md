# Story 008: Transition Atomicity

> **Epic**: Prestige/Checkpoint System
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (4h+ — app-kill simulation is inherently fiddly to set up as a test)
> **Manifest Version**: 2026-06-20
> **Last Updated**:


## Context

**GDD**: `design/gdd/prestige-checkpoint-system.md`
**Requirement**: `TR-pcs-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 §2 (orchestration, suppression window) + ADR-0002 (`suppress_autosave()`/`resume_autosave()`, already Accepted)
**ADR Decision Summary**: `SaveSystem.suppress_autosave()` brackets only steps 1-5 of the transition (all synchronous, same-frame) — narrowed per `/design-review`'s second re-review so an unbounded Challenge Selection wait is never inside the suppression window (mobile background-kill risk).

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: atomic temp-file-rename save pattern (ADR-0002) — this story doesn't change that mechanism, only when it's suppressed
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD §Transition Atomicity, scoped to this story:*

- [ ] GIVEN the app is killed mid-sequence (after Choice A confirmed, before `save_now()`), WHEN the app restarts, THEN the restored state is the pre-transition state exactly (`era_count` NOT incremented, no META_BONUS granted, previous era's resources/affiliation intact) with `_card_pending=true`, and the Wypalenie card re-presents on boot
- [ ] GIVEN the player re-confirms Choice A after such a restore, WHEN the sequence re-runs, THEN it executes exactly once from the top — META_BONUS granted exactly once total across both attempts, no partial-application artifacts survive
- [ ] GIVEN the app is killed after `era_transitioned` fires but before Challenge Selection is confirmed, WHEN the app restarts, THEN the era is already transitioned (`save_now()` completed at step 5, before `era_transitioned` fired) and the challenge set is either empty (safe default) or whatever was already confirmed — never partially-selected
- [ ] GIVEN the era-transition sequence (steps 1-5) has completed and `save_now()` has run, WHEN the app is killed at any point during Challenge Selection (step 7) before it is confirmed, THEN autosave suppression has already been lifted — this is an ordinary post-transition autosave gap, not an atomicity violation

---

## Implementation Notes

*Derived from ADR-0012 §2 and ADR-0002's Autosave suppression window:*

Test setup: since a real app-kill can't be simulated in a headless test run, model this as "invoke `on_burnout_accepted()` up to step N, then simulate a fresh boot by constructing a new `PrestigeSystem` instance and calling `restore_state()` against whatever `SaveSystem` had persisted at that point" — the same technique used for `save-persistence-system.md`'s own atomic-write tests (temp-file-rename means a kill before `save_now()` completes leaves the *previous* save fully intact, by construction — this story's tests verify `PrestigeSystem`'s state machine respects that guarantee, not that the file-write mechanism itself is atomic, which ADR-0002 already covers).

The re-confirm-after-restore case (AC-2) is the one genuinely novel risk here: verify the restored `_card_pending=true` state means the *entire* `on_burnout_accepted()` sequence runs again from scratch on re-confirm, not a partial resume — there is no "resume from step 3" logic, only "run again from the top against whatever state was actually persisted."

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The actual `suppress_autosave()`/`resume_autosave()` mechanism — already implemented via ADR-0002 (not part of this epic's stories, already shipped as part of the propagate-design-change work)
- Story 007: the sweep's own internal correctness (this story assumes the sweep works and tests only the kill/restore envelope around it)

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (kill before save_now, restore to pre-transition state)**:
  - Given: `on_burnout_accepted()` invoked through step 4 (reset+grant+sweep, no save yet), simulated kill
  - When: fresh `PrestigeSystem.restore_state()` runs against the last-persisted save (which predates the transition, since `save_now()` never ran)
  - Then: `era_count` unchanged, all META_BONUS totals unchanged, previous era's resources/affiliation intact, `_card_pending=true`

- **AC-2 (re-confirm runs exactly once, no double-grant)**:
  - Given: the AC-1 restored state
  - When: Choice A is re-confirmed and the sequence re-runs to completion
  - Then: META_BONUS granted exactly once (not twice — verify by checking the total matches a single grant's expected value, not double it)

- **AC-3 (kill after era_transitioned, before Challenge Selection confirmed)**:
  - Given: full sequence through step 6 (`era_transitioned` fired, `save_now()` already completed), simulated kill during step 7
  - When: fresh restore
  - Then: era is fully transitioned in the restored state; challenge set is empty or matches whatever was confirmed — never a partial selection

- **AC-4 (suppression window is narrow, not unbounded)**:
  - Given: sequence past step 5
  - When: `SaveSystem.suppress_autosave()`'s state is checked during step 7 (Challenge Selection)
  - Then: suppression is already lifted — assert `resume_autosave()` was called before `era_transitioned` fired, not after Challenge Selection confirms

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/prestige/prestige_atomicity_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (full orchestration sequence), Story 007 (flag sweep must exist for the mid-sequence kill points to be meaningful)
- Unlocks: None
