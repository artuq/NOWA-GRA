# Sprint 4 — 2026-06-30 to 2026-07-04

## Sprint Goal
Build the remaining Core-layer backend (Card Content Database + Decision Card System) so Sprint 5 can wire up the Boot scene and minimal UI for a true first-playable build — the next correct increment toward closing the gap the Production→Polish gate-check flagged (2026-06-24, verdict FAIL, all four directors NOT READY).

## Capacity
- Total days: 5 (1 week, solo dev)
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|---------------|---------------------|
| 4-1 | Card Content Database — static `CardContentDatabase` Autoload, 12 cards (8 risky/safe + 4 neutral) | narrative-director → godot-gdscript-specialist | 1.0 | None (Foundation, pure data) | Per `design/gdd/card-content-database.md`; data-validation test |
| 4-2 | Decision Card System — `DecisionCardSystem` Autoload (card selection, resolution, cooldown) | game-designer → godot-gdscript-specialist | 2.0 (provisional — re-size after `/create-stories`) | 4-1, History Flag System (Complete), Resource System (Complete) | Per `design/gdd/decision-card-system.md` + ADR-0005 (weighting/cooldown, Accepted); unit/integration tested |

### Should Have
None — full Must Have already uses 3.0 of 4.0 available days.

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Acceptance Criteria |
|----|------|-------------|-----------|---------------------|
| 4-3 | Doc-sync: Polish→English resource keys (tech debt, 3 sprints overdue) | solo dev | 0.25 | Tech debt entry closed |

Card Content Database was originally deferred from Sprint 3; it's now a hard prerequisite for Decision Card System, so it leads this sprint.

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| Doc-sync: Polish→English resource keys (was 3-4) | Never started in Sprint 3 — stayed in backlog all sprint | 0.25 days (unchanged), now tracked as 4-3 |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Decision Card System's 2.0-day estimate is pre-story-breakdown; the system has real complexity (weighted RNG, trigger-condition parsing, cross-system write ordering across 3 Autoloads) — flagged CONCERNS by the PR-SPRINT producer gate | Medium | Medium | Run `/create-stories decision-card-system` before treating 2.0 days as committed; if story-level sizing overflows, drop 4-3 (Nice to Have) without hesitation rather than touching the buffer |
| This sprint still does not produce a playable build (no UI/scenes) | High (known, accepted) | Low | Explicitly accepted — Sprint 5 is scoped for Boot scene + minimal UI once this backend exists; not claiming "first playable" this sprint |
| No Sprint 3 retrospective exists yet (skipped in favor of running `/gate-check` directly) | Low | Low | Run `/retrospective sprint-3` retroactively if useful, or fold any Sprint 3 learnings into Sprint 4's own retro |

## Dependencies on External Factors
None.

## QA Plan
No QA plan exists yet for this sprint. Run `/qa-plan sprint` after `/create-stories` produces story-level acceptance criteria.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-4-[date].md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Working tree is clean (all sprint work committed)
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] **Not claiming "first playable" this sprint** — that target is explicitly deferred to Sprint 5

> ⚠️ **No QA Plan**: This sprint was started without a QA plan. Run `/qa-plan sprint`
> before the last story is implemented. The Production → Polish gate requires a QA
> sign-off report, which requires a QA plan.
