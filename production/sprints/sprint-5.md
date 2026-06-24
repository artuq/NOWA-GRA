# Sprint 5 — 2026-07-07 to 2026-07-11

## Sprint Goal
Close the 3-sprint-stale doc-sync tech debt first, then implement Offline Progress System — the last remaining Core-layer backend system — continuing the backend-first pattern before committing to Boot scene/UI work.

## Capacity
- Total days: 5
- Buffer (20%): 1
- Available: 4

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| 5-1 | Doc-sync: Polish→English resource keys (carried over 3x from 3-4/4-3) | solo dev | 0.25 | None | `design/gdd/resource-system.md` + `design/registry/entities.yaml` updated to match code; tech-debt entry #1 closed |
| 5-2 | Offline Progress System — `OfflineProgressSystem` Autoload (`simulate_offline()`) | game-designer → godot-gdscript-specialist | 2.0 (provisional — re-sized via `/create-stories` before treated as committed) | Resource System (Complete), Save/Persistence System (Complete) | Per `design/gdd/offline-progress-system.md`; unit/integration tested |

### Should Have
None this sprint.

### Nice to Have
None this sprint.

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| Doc-sync: Polish→English resource keys | Deprioritized 3 sprints running below Must Have work | 0.25 days — slotted FIRST this sprint per Sprint 4 retro action item #1 |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Offline Progress System's epic-level 2.0-day estimate is pre-`/create-stories`, same pattern as Decision Card System (Sprint 4) | Medium | Medium | Producer (PR-SPRINT gate) flagged CONCERNS; mitigation accepted: run `/create-stories offline-progress-system` first, re-size before treating as committed; if it exceeds 2.0 days, cut scope (e.g. defer save-data migration / UI display polish) rather than compress the loop logic or its tests |
| Doc-sync (5-1) might slip again if Offline Progress System runs long | Low | High (process) | Explicitly FIRST this time, not last |
| `simulate_offline()` depends on `ResourceFormulas`, shared with live-play Action System, at a scale (1440 iterations) ActionSystem never exercises — formula drift, cap behavior, accumulation/rounding risk | Medium | Medium | Verify via tests that exercise the same formulas both ways; treat the loop logic and its tests as the least compressible part of the estimate |

## Dependencies on External Factors
None.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-5.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
