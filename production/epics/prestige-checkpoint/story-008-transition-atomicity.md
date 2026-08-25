# Story 008: Transition Atomicity

> **Epic**: Prestige/Checkpoint System
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: L (4h+ — app-kill simulation is inherently fiddly to set up as a test)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-15


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

*From GDD §Transition Atomicity, narrowed 2026-07-15 to what the shipped `on_burnout_accepted()` sequence actually contains (see Scope Note below) — original ACs referenced `_card_pending` and a "Challenge Selection" step that do not exist in code (BurnoutSystem/ChallengeSystem are unimplemented, TR-pcs-007). Deferred to a follow-up story once those systems exist.*

- [ ] GIVEN `on_burnout_accepted()` is invoked through the grant+sweep+increment steps (all in-memory) but `save_now()` has not yet run, WHEN the app is killed and restarts, THEN the restored state (from the last completed save, which predates this transition) is the pre-transition state exactly: `era_count` NOT incremented, no META_BONUS granted, previous era's resources/affiliation intact
- [ ] GIVEN the AC-1 restored (pre-transition) state, WHEN `on_burnout_accepted()` is invoked again, THEN it executes exactly once from the top — META_BONUS granted exactly once total across both attempts (the killed attempt contributes nothing, since nothing from it was ever persisted), no partial-application artifacts survive
- [ ] GIVEN the full sequence has completed and `save_now()` has run (`era_transitioned` fired), WHEN the app is killed at any point afterward and restarts, THEN the restored state reflects the fully-transitioned era: `era_count` incremented, sweep defaults applied, `burnout_accepted_era_N` milestone present
- [ ] GIVEN the sequence's execution, WHEN `SaveSystem`'s suppression state is inspected across the call, THEN `resume_autosave()` is called strictly before `era_transitioned.emit()` — the suppression window brackets only the synchronous steps, never extends past them

---

## Scope Note (2026-07-15)

Original acceptance criteria described kill-timing around a `_card_pending` boot-reentry flag and a "Challenge Selection (step 7)" confirmation step. Neither exists in the shipped `PrestigeSystem`/`DecisionCardSystem` code — `on_burnout_accepted()`'s real sequence is exactly 7 steps ending at `save_now() → resume_autosave() → era_transitioned.emit()`, with no Challenge Selection step, and no card-pending flag gating re-presentation on boot (that belongs to BurnoutSystem's own boot-integration, not yet built per TR-pcs-007's ADR gap). Rather than inventing stub mechanisms to make the original ACs testable, this story is narrowed to the atomicity guarantee that's actually implementable today: kill-before-save vs kill-after-save, and the suppression-window boundary. A follow-up story (post-BurnoutSystem/ChallengeSystem ADR) should cover the card-re-presentation and Challenge Selection kill-timing cases from the original ACs.

---

## Implementation Notes

*Derived from ADR-0012 §2 and ADR-0002's Autosave suppression window:*

Test setup: since a real app-kill can't be simulated in a headless test run, model this as "invoke `on_burnout_accepted()`'s logic up to a point, then simulate a fresh boot by constructing a new `PrestigeSystem` instance and calling `restore_state()` against whatever `SaveSystem` had persisted at that point" — the same technique used for `save-persistence-system.md`'s own atomic-write tests (temp-file-rename means a kill before `save_now()` completes leaves the *previous* save fully intact, by construction — this story's tests verify `PrestigeSystem`'s state machine respects that guarantee, not that the file-write mechanism itself is atomic, which ADR-0002 already covers). Since `on_burnout_accepted()` has no internal step-by-step resumability seam, "kill mid-sequence" is modeled as: capture `SaveSystem`'s persisted state before calling the method, invoke the method fully (it always runs to completion once called — there's no yield point per the zero-await constraint), then for AC-1/AC-2 use the *pre-call* persisted snapshot as "what a kill-before-save-completes would have left on disk" (valid because `save_now()` is the only write in the whole method, and it's the last synchronous statement before the emit).

The re-confirm case (AC-2) is the one genuinely novel risk here: verify that calling `on_burnout_accepted()` a second time against the AC-1 pre-transition state runs the *entire* sequence again from scratch — there is no "resume from step 3" logic, only "run again from the top against whatever state was actually persisted."

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- The actual `suppress_autosave()`/`resume_autosave()` mechanism — already implemented via ADR-0002 (not part of this epic's stories, already shipped as part of the propagate-design-change work)
- Story 007: the sweep's own internal correctness (this story assumes the sweep works and tests only the kill/restore envelope around it)
- Card re-presentation on boot after a killed Choice A, and Challenge Selection kill-timing — deferred per the Scope Note above, pending BurnoutSystem/ChallengeSystem's own ADR (TR-pcs-007)

---

## QA Test Cases

**Integration — automated test specs:**

- **AC-1 (kill before save_now, restore to pre-transition state)**:
  - Given: `SaveSystem`'s persisted state captured before calling `on_burnout_accepted()`
  - When: a fresh `PrestigeSystem.restore_state()` runs against that pre-call snapshot (modeling "kill before save_now() ever wrote")
  - Then: `era_count` unchanged, all META_BONUS totals unchanged, previous era's resources/affiliation intact

- **AC-2 (re-confirm runs exactly once, no double-grant)**:
  - Given: the AC-1 pre-transition restored state
  - When: `on_burnout_accepted()` is invoked (again)
  - Then: META_BONUS granted exactly once (verify the total matches a single grant's expected value, not double it — since the "killed" attempt never persisted anything, there is nothing to double)

- **AC-3 (kill after save_now, restore reflects full transition)**:
  - Given: `on_burnout_accepted()` runs to completion (`era_transitioned` fired, `save_now()` completed)
  - When: fresh `PrestigeSystem.restore_state()` runs against the post-call persisted state
  - Then: `era_count` incremented, sweep defaults applied, `burnout_accepted_era_N` milestone present in the restored state

- **AC-4 (suppression window is narrow, not unbounded)**:
  - Given: `on_burnout_accepted()`'s execution
  - When: the order of `SaveSystem.suppress_autosave()`/`resume_autosave()` calls relative to `era_transitioned.emit()` is inspected (call-order spy, same technique as Story 007's AC-3)
  - Then: `resume_autosave()` is called strictly before `era_transitioned.emit()`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/prestige/prestige_atomicity_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (full orchestration sequence), Story 007 (flag sweep must exist for the post-sweep kill points to be meaningful)
- Unlocks: None

## Completion Notes
**Completed**: 2026-07-15
**Criteria**: 4/4 passing (narrowed scope per Scope Note)
**Deviations**: ADVISORY — scope narrowed at readiness time (logged as tech debt); 3 non-blocking test gaps (logged as tech debt)
**Test Evidence**: Integration — `tests/integration/prestige/prestige_atomicity_test.gd` (4 tests)
**Code Review**: Complete — APPROVED
