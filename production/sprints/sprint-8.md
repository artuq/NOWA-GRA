# Sprint 8 — 2026-07-02 to 2026-07-08

## Sprint Goal
Give the player a visible identity from minute 1: implement Class Path System MVP (2 paths — Pato-Streamer / Guru-Celebryta — visible from the start, growing through card choices, with a HUD indicator) — closing the retention gap opened by Story 005's locked slot previews.

## Capacity
- Total days: 5
- Buffer (20%): 1 day reserved for unplanned work
- Available: 4 days

## Tasks

### Must Have (Critical Path)

| ID | Task | Est. | Dependencies | Acceptance Criteria |
|----|------|------|-------------|---------------------|
| 8-1 | Class Path — ADR + Epic + Stories (design day) | 0.5d | quick-spec `design/quick-specs/class-path-system-2026-07-01.md` ✅ | ADR accepted; epic file written; stories written and ready-for-dev |
| 8-2 | Class Path Core — affiliation tracking (card auto-increment, investment tiers) | 1.5d | 8-1 complete; HistoryFlagManager ✅; DecisionCardSystem ✅ | Affiliation grows through card choices; 4 investment course tiers work; era reset zeroes affiliation; signal-driven (no polling) |
| 8-3 | Class Path HUD — active path indicator | 0.5d | 8-2 complete | HUD shows active path (highest T1+) or "Undecided"; visible from minute 0; English; touch target ≥ 48×48 dp |

### Should Have

| ID | Task | Est. | Dependencies | Acceptance Criteria |
|----|------|------|-------------|---------------------|
| 8-4 | Action Queue auto-repeat | 0.5d | ActionSystem ✅; quick-spec `design/quick-specs/action-queue-auto-repeat-2026-06-30.md` ✅ | Queue loops without tapping; toggle on/off; no regression on base action slots |

### Nice to Have

| ID | Task | Est. | Dependencies | Acceptance Criteria |
|----|------|------|-------------|---------------------|
| 8-5 | Soft Reach Cap (quick-spec `design/quick-specs/soft-reach-cap-algorithm-barrier-2026-07-01.md` ✅) | 0.5d | ResourceFormulas ✅ | Hyperbolic cap active at R>5000; data-driven threshold; no hardcoded values |

## Carryover from Previous Sprint

| Task | Reason | Action |
|------|--------|--------|
| 7-1 Card UI (epic-level placeholder) | Card UI epic is Complete from Sprint 6 (backend and UI both done); placeholder was never broken into stories | Dropped — no carryover needed |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Class Path needs ADR before implementation — may surface coupling conflicts with HistoryFlagManager or DecisionCardSystem | Med | Med | ADR is story 8-1's first deliverable; do not start 8-2 until ADR is Accepted |
| Affiliation via cards = ClassPath must listen to DecisionCardSystem signals without reverse coupling | Med | High | ADR must resolve dependency direction: ClassPath listens to card signals, not the other way |
| 2-path HUD may be hard to read on small mobile screens (Undecided / Pato-Streamer / Guru) | Low | Low | 8-3 AC includes explicit readability check; ask user to confirm visual direction before writing scene |

## Dependencies on External Factors
None.

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-8.md`) — **run `/qa-plan sprint` before implementation begins**
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] UI stories (8-3) have evidence doc in `production/qa/evidence/`
- [ ] Smoke check passed
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

> **Scope check:** Run `/scope-check class-path` before starting 8-2 to confirm Class Path System boundary.
