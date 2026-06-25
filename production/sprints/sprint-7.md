# Sprint 7 — 2026-07-21 to 2026-07-25

## Sprint Goal
Make decision cards actually visible and playable: build Card UI, the modal swipe-to-decide screen that surfaces `DecisionCardSystem`'s already-complete backend — closing the biggest gap between "tests pass" and "the game is playable" identified in Sprint 6's retro.

## Capacity
- Total days: 5
- Buffer (20%): 1
- Available: 4

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| 7-1 | Card UI — epic-level (provisional, re-size via `/create-stories`) | game-designer → ui-programmer | 2.5 (provisional) | Decision Card System (Complete) | Per `design/gdd/card-ui.md`; modal swipe-to-decide screen with commitment threshold, blocks background UI |

### Should Have
None this sprint — first real gesture/drag-input UI in the project (vs. Action UI's static taps); keeping scope tight given the new risk class.

### Nice to Have
None this sprint.

## Carryover from Previous Sprint
None — Sprint 6 closed with no Must Have carryover.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| First drag/swipe-gesture UI in the project — genuinely new input-handling territory (rotation-on-drag, commitment-threshold release detection, bounce-back animation), vs. Action UI's static button taps | Medium-High | Medium | `architecture.md` already pre-deferred this to implementation as "low risk" (no ADR required, `TR-cui-001` registry entry) — respect that prior call, but budget real time for gesture-handling iteration; `/create-stories` breakdown is essential here, not optional |
| **Process risk from Sprint 6's retro**: visual/design decisions must be asked about before implementing, not patched unilaterally | Low (now an explicit standing rule) | High if repeated | Check `design/art/art-bible-stub.md` AND ask the user for Card UI's specific visual direction (card style, swipe-feedback look) before writing any scene file — do not repeat the Resource HUD mistake |
| Card UI is a full-screen modal that must block Resource HUD/Action Grid beneath it — first cross-scene interaction in the project (modal over the existing `ActionScreen`) | Medium | Medium | Confirm how the modal mounts relative to `action_screen.tscn` before implementing — likely needs its own small structural decision, not necessarily a full ADR |

## Dependencies on External Factors
None.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-7.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] UI stories have interaction-test evidence (GdUnit4 `scene_runner()`, per Sprint 6's established standard)
- [ ] **Explicit design-direction confirmation with the user before any Card UI scene file is created** (Sprint 6 retro action item #2) — not just before/after a defect is found
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
