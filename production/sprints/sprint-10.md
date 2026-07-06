# Sprint 10 — 2026-07-07 to 2026-07-13

## Sprint Goal
Prove the web platform is viable (fail-fast on the ≤10 MB / load-time gate) and pay the twice-carried performance debt — King of Cringe runs measurably well in a browser at 9:16 and on a real Android device.

## Capacity
- Total days: 5
- Buffer (20%): 1 day
- Available: 4 days
- Note: Sprints 8-9 ran 2-3× under estimate on well-specified stories — estimates below already assume design pre-work happens in-story (spike format), not as a separate design day.

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 10-1 | **Web-export spike** (FIRST — retro AI #2): Compatibility renderer validation (full visual pass of all screens), HTML5 export preset, measure initial download vs ≤10 MB and cold-load time vs ~20-30s (Poki bars), iframe embed test | solo dev | 1 | — | Documented GO/NO-GO verdict with measured numbers in `docs/spikes/web-export-spike.md`; if NO-GO, options analysis for the user |
| 10-2 | **9:16 portrait web presentation** (user decision 2026-07-06): canvas stays portrait on ALL web contexts; desktop gets pillarboxed portrait + styled background (not bare black bars); mobile browser gets native full-view | solo dev | 0.5 | 10-1 GO | Portrait canvas centered + background treatment on 16:9 desktop; mobile-browser viewport correct; no layout reflow of game UI |
| 10-3 | **Performance pass** (carried ×2 → escalated, retro AI #3): frame-budget measurement on target Android device; set the Memory Ceiling in technical-preferences (open since setup); bundle AC-6 badge-readability device recheck | solo dev | 0.5 | — | Frame times documented vs 16.6ms budget; memory ceiling value set; AC-6 recheck logged in evidence doc |

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 10-4 | Mouse swipe-threshold feel-test: 30%-width commit + 800px/s flick evaluated with mouse drag in browser; tune constants if mouse feels off | solo dev | 0.5 | 10-1 GO | Documented feel verdict; any tuning covered by existing CardSwipeMath unit tests updated in sync |
| 10-5 | 15-second onboarding — `/quick-design`: should web builds present the first card near-instantly? (Poki time-to-judgment rule vs current 2-action cooldown) | solo dev | 0.5 | — | Quick Design Spec written with a decision; implementation only if trivially small, else scheduled |

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| 10-6 | Bug register bootstrap: create `production/qa/bugs/` convention + retro-file the two same-session-fixed bugs (Sprint 8 S2, Sprint 9 S1) for the historical record | solo dev | 0.1 | — | Register exists; 2 historical entries filed as Fixed |

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| Performance pass | Carried ×2 (Sprints 8, 9) — escalated to Must Have per retro | 0.5d |
| AC-6 device recheck | Carried from Sprint 8 — bundled into 10-3 | (included) |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **10-1 NO-GO**: Godot 4 wasm runtime alone may exceed the 10 MB initial bar | Med | High | Spike runs FIRST; brotli hosting + options analysis (accept slower CTP / progressive load / revisit engine features) prepared for the user decision — no silent scope death |
| Compatibility renderer visual drift (Forward+ → WebGL2) | Med | Med | Full-screen visual pass is an explicit 10-1 AC; game uses simple 2D Controls — low surface area |
| Device unavailable for 10-3 | Low | Med | Editor-based profiling as fallback; device pass rescheduled, NOT re-carried silently |

## Dependencies on External Factors
- Physical Android device for 10-3 (user's hardware)

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-10.md`) — run `/qa-plan sprint` after 10-1's spike doc exists
- [ ] All Logic/Integration stories have passing tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1/S2 bugs open
- [ ] **Commit after every story close (retro AI #1)** — no end-of-day batches
- [ ] Design documents updated for any deviations

> ⚠️ **QA plan note**: spike-heavy sprint — run `/qa-plan sprint` once 10-1's measurements exist (its "tests" are documented measurements, not unit files).
