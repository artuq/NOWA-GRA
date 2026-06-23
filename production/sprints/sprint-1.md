# Sprint 1 — 2026-06-23 to 2026-07-04

## Sprint Goal
Implement Resource System's core mutation mechanism and all 5 formulas (A-E) in src/, with passing unit tests for every story — the foundation every other Core/Foundation system depends on.

## Capacity
- Total days: 10 (2 weeks, solo dev)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 1-1 | Core Resource Mutation & Clamping | solo dev | 1 | None | production/epics/resource-system/story-001-core-resource-mutation.md |
| 1-2 | Hatersi Passive Growth Rate (Formula A) | solo dev | 0.5 | 1-1 | production/epics/resource-system/story-002-haters-growth-rate.md |
| 1-3 | Morale Drain Rate (Formula B) | solo dev | 0.5 | 1-1 | production/epics/resource-system/story-003-morale-drain-rate.md |
| 1-4 | Action Effectiveness Multiplier (Formula C) | solo dev | 0.5 | 1-1 | production/epics/resource-system/story-004-effectiveness-multiplier.md |
| 1-5 | Passive Zasięgi/Reach Income (Formula D) | solo dev | 0.5 | 1-4 | production/epics/resource-system/story-005-passive-income.md |
| 1-6 | Cringe Delta Clamping (Formula E) | solo dev | 0.5 | 1-1 | production/epics/resource-system/story-006-cringe-clamping.md |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 1-7 | Sponsorzy/Sponsors Acquisition (Placeholder) | solo dev | 0.25 | 1-1 | production/epics/resource-system/story-007-sponsors-acquisition.md |

### Nice to Have
*(none this sprint — scope is intentionally thin, single-epic discipline per Producer's PR-EPIC and PR-SPRINT guidance)*

## Carryover from Previous Sprint
*(none — first sprint)*

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| GDScript static type inference on built-in math functions causes new parser errors (recurring issue during this project's vertical slice) | Medium | Low | Control Manifest documents the explicit-type-annotation rule; apply proactively, not reactively |
| Art bible stub doesn't get expanded before Production needs real assets | Medium | Medium | Tracked separately, not this sprint's scope — `/art-bible` flagged as the next creative action |
| First-sprint velocity data point (vertical slice) doesn't transfer to pure-formula story work | Low | Low | PR-SPRINT explicitly flagged this — treat the 3.25-day estimate as trustworthy on its own, recalibrate Sprint 2 once real data exists |

## Dependencies on External Factors
- None

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## PR-SPRINT Feasibility Verdict

**REALISTIC** — single-epic discipline correct, dependencies shallow (1-1 is the only blocker), slack is a deliberate first-sprint hedge, not padding. Watch item: if this sprint finishes in 1-2 days flat, use that as real velocity data to calibrate Sprint 2 upward.
