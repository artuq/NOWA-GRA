# Sprint 2 — 2026-06-23 to 2026-06-27

## Sprint Goal
Implement the Action System backend (`ActionSystem` Autoload — single-Timer concurrency mechanism + Morale-scaled reward resolution) in `src/`, with passing unit + integration tests. This is the first system that actively *consumes* the Resource System delivered in Sprint 1 — it turns the resource backend into actual playable mechanics (the select-and-wait core loop), still headless.

## Capacity
- Total days: 5 (1 week, solo dev)
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 2-1 | ActionSystem Core — Timer, Single-Concurrency & Progress | solo dev | 0.5 | Resource System (done) | production/epics/action-system/story-001-action-core-timer-concurrency.md |
| 2-2 | Action Reward Resolution & Morale Scaling | solo dev | 0.5 | 2-1, Resource System (done) | production/epics/action-system/story-002-reward-resolution-morale-scaling.md |

### Should Have
*(none — single-epic discipline, per Sprint 1 precedent and PR-SPRINT recommendation)*

### Nice to Have
*(none)*

## Carryover from Previous Sprint
*(none — Sprint 1 fully closed: 7/7 stories Complete, QA sign-off APPROVED, committed to `feat/resource-system-epic`)*

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| ADR-0004 code sample was amended 2026-06-23 — implementer must follow the corrected version (scale + `apply_delta` + emit final deltas), not a remembered older shape | Medium | Low | Story 002 embeds the corrected code block directly; the amendment's dated correction note explains why |
| `roundf()` half-away-from-zero behavior on half-band reward results (e.g. 7.5→8, 2.5→3) is the highest-risk part of the reward math | Low | Medium | Story 002's QA test specs lock the `.5` boundary cases explicitly |
| Integration test for 2-2 needs a deterministic Morale band to test each multiplier without driving the full Resource System | Low | Low | Story 002 notes dependency-injection / Morale-set approach for test isolation |
| Sprint 1's pattern of unplanned foundational work recurring (lower now that the test harness exists, but not zero) | Low | Medium | The 1-day buffer + the deliberate capacity slack absorb this |

## Dependencies on External Factors
- None

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-2.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## PR-SPRINT Feasibility Verdict

**REALISTIC** — both stories are validated-ready (QL-STORY-READY), dependency-clean, and the Action System backend is genuinely a ~1-day epic. The capacity slack is honest, not padding.

**Producer recommendation on the small-sprint tension**: keep it small and focused (single-epic discipline, proven in Sprint 1) rather than padding scope or rushing the next epic's stories. Reserve the slack as a buffer against Sprint 1's demonstrated unplanned-work pattern. **If both stories close early and clean, spend the remaining days running `/create-stories` for the next backend epic (Decision Card System or Save/Persistence, per roadmap priority)** so Sprint 3 starts ready instead of flat-footed — converting idle capacity into pipeline prep without violating this sprint's single-epic delivery commitment.
