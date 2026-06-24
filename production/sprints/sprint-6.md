# Sprint 6 — 2026-07-14 to 2026-07-18

## Sprint Goal
Build the first real playable surface: a minimal Boot scene (enough to load save state and transition to a Main scene, deferring the Offline Report Screen branch) plus Action UI — the game's primary screen, where the select-and-wait core loop becomes touchable for the first time.

## Capacity
- Total days: 5
- Buffer (20%): 1
- Available: 4

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| 6-1 | Action UI — epic-level (provisional, re-size via `/create-stories` before treating as committed) | game-designer → ui-programmer | 3.0 (provisional) | Action System (Complete); minimal Boot/Main scene scaffolding (new, this sprint) | Per `design/gdd/action-ui.md`; Resource HUD + 6-slot Action Grid + Running Action Overlay; manual evidence required (UI story type) |

### Should Have
None this sprint — first UI/scene work in this codebase, keeping scope tight given the real unknowns (first Control nodes, first touch input, first scene transitions).

### Nice to Have
None this sprint.

## Carryover from Previous Sprint
None — Sprint 5 closed with no Must Have carryover.

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| First UI/scene work in the entire project — no established Godot scene/Control-node patterns yet to follow, unlike the backend epics which had 4+ precedents | High | Medium | Treat `/create-stories` breakdown as essential, not optional, even more than past epics — expect the real split to separate "Boot/Main scene scaffolding" from "Action UI screen" into distinct stories |
| Action UI's acceptance criteria will need manual evidence (UI story type, ADVISORY gate) since this is the first Visual/Feel-adjacent work — no automated test precedent for screen verification in this codebase yet | Medium | Low | Follow `coding-standards.md`'s UI evidence requirement (`production/qa/evidence/[slug]-evidence.md`); budget time for this explicitly, it's new overhead |
| Touch-only input requirement (`technical-preferences.md`: large touch areas, no hover-only) is untested in practice — first real input-handling code | Medium | Medium | Reference the GDD's explicit touch requirements; test on the actual target input model, not mouse-as-touch-proxy assumptions |

## Dependencies on External Factors
None.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-6.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] UI stories have manual evidence docs in `production/qa/evidence/` (first sprint this requirement applies)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
