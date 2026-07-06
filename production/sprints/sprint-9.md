# Sprint 9 — 2026-07-06 to 2026-07-12

## Sprint Goal
The game starts to *feel* alive: Juice/Feedback System (audio + reward animations) wired into the action/card loop, plus paying down the Sprint 8 retro's process debt.

## Capacity
- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 9-1 | Juice/Feedback — design day: ADR + epic + stories (GDD `design/gdd/juice-feedback-system.md` already Designed) | solo dev | 0.5 | — | ADR Accepted via independent /architecture-review; epic + stories written |
| 9-2 | Juice/Feedback — core implementation (feedback on `action_completed` / `card_resolved` / `tier_unlocked`) | solo dev | 1.5 | 9-1 | Stories done; automated tests pass; manual feel-check evidence |
| 9-3 | Test isolation from `user://save.json` (Sprint 8 retro AI #1) | solo dev | 0.5 | — | Full suite green regardless of the real playtest save's state |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 9-4 | Polish→English content audit (carried ×3 — do it or consciously drop) | solo dev | 0.5 | — | All player-facing strings English; audit report written |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 9-5 | ADR-0005 stale code samples fix (carried ×4) | solo dev | 0.1 | — | Samples match the shipped implementation |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| Polish→English audit | Never scheduled as a scoped story (3 retros running) | 0.5d |
| ADR-0005 samples | Low priority, never picked up (4 retros running) | 0.1d |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Juice = first audio code in the project (AudioStreamPlayer, tweens) — new engine patterns | Med | Med | ADR-first + godot-specialist review; MVP scope: audio + simple tweens, no particle VFX |
| Tier-unlock feedback touches Sprint 8's HUD | Low | Low | Signals already exist (`tier_unlocked`); additive subscription only |
| 8-5 / Burnout still deferred — Alpha backlog accumulating | Low | Med | Deliberate — Alpha opens with Prestige/Checkpoint `/design-system` |

## Dependencies on External Factors
- None

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-9.md`) — generate via `/qa-plan sprint` after 9-1 stories exist
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] **New rule (Sprint 8 retro)**: any new Autoload with `restore_state()` carries an explicit wiring AC (SaveSystem serialize + restore call sites)

> ⚠️ **QA plan note**: This sprint was planned before its stories exist (9-1 is the design day). Run `/qa-plan sprint` immediately after 9-1 completes, before 9-2 implementation begins — same pattern as Sprint 8.
