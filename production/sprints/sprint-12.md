# Sprint 12 — 2026-07-24 to 2026-07-30

## Sprint Goal
Close the gap between shipped code and tracked status, finish the two pieces of Sprint 11 that never landed (card wave 2, challenge-selection UI), and get the two pieces of evidence the Production → Polish gate is actually blocked on: a green test run and a documented playtest of the complete era loop.

## Capacity
- Total days: 5
- Buffer (20%): 1 day
- Available: 4 days

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 12-1 | Run full test suite headless (`godot --headless --script tests/gdunit4_runner.gd`), fix any red | solo dev | 0.5 | — | 64 unit+integration tests reported, all green or failures fixed same-session |
| 12-2 | **Carried from 11-5, corrected status** — Era-start/challenge-selection screen implementation, per already-approved `design/ux/challenge-selection-screen.md` | ui-programmer, gameplay-programmer | 1 | 12-1 | Screen implemented, wired to `ChallengeSystem`; challenge selection playable end-to-end, not just backend-tested |
| 12-3 | Playtest the full era loop (burnout → reset → meta-bonus → challenge selection) | solo dev | 1 | 12-2 | ≥1 session logged in `production/playtests/` via `/playtest-report`, using existing `playtest-question-guide.md` |
| 12-4 | Retroactive QA plan + sign-off, Sprint 10 and Sprint 11 | qa-lead | 1 | 12-1 | `qa-plan-sprint-10/11.md` + `qa-signoff-sprint-10/11.md`, verdict APPROVED or APPROVED WITH CONDITIONS |
| 12-5 | Sync `sprint-status.yaml` + prestige-checkpoint/burnout-challenge story files to actual shipped state | producer | 0.3 | — | 11-1/11-2/11-4 marked `done`; 11-3/11-5 marked accurately (not silently closed); story file checkboxes match real test files on disk |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 12-6 | **Carried from 11-3, unstarted** — Card wave 2: write and add new decision cards toward the doubled-pool goal (exact count TBD — was 12, may be re-scoped smaller) | narrative-director, writer | 1 | — | New cards in `card_content_database.gd` with `resolution_reaction` + `path_tags`, English, path_tags confirmed with user |
| 12-7 | Retro, Sprint 10+11 combined | producer | 0.3 | 12-5 | `retro-sprint-10-11.md` written, open AIs carried forward |
| 12-8 | Stand up `production/risk-register/` | producer | 0.2 | — | Register exists with current known risks (perf-pass block, solo-playtester signal strength, card-pool gap) |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 12-9 | 10-3 perf pass + memory ceiling — only if an Android device becomes available | solo dev | 0.5 | device | Frame times vs 16.6ms budget documented, memory ceiling set |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| 11-3 (Card wave 2) | Never started — ledger incorrectly marked ready-for-dev, no work done | 1 day (12-6) |
| 11-5 (Era-start/challenge-selection screens) | Backend shipped, UI never built — UX spec now exists (approved 2026-07-22) | 1 day (12-2) |
| 10-3 (Perf pass on device) | Still blocked — no physical Android device, carried 3rd time | 0.5 (once device available) |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| 12-6 (card wave) slips past this sprint | Medium | Low | Should Have, not Must Have — the era loop is playable and testable without it; defer to Sprint 13 if capacity runs out |
| Single solo-playtester session is weak signal | High | Medium | Use the structured `playtest-question-guide.md`; log explicitly as N=1, recommend 2 more sessions before Production→Polish PASS is trusted |
| 10-3 stays blocked without hardware | High | Medium | Web-export spike (already GO) is an acceptable interim perf proxy |

## Dependencies on External Factors
- Physical Android device for 10-3/12-9 (unavailable this sprint, as in the prior two)

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-12.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] `/gate-check production` re-run returns PASS
