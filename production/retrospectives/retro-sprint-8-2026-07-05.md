# Retrospective: Sprint 8 — Class Path System MVP
Period: 2026-07-02 — 2026-07-08 (closed early: 2026-07-05)
Generated: 2026-07-05

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 5 (3 MH + 1 SH + 1 NTH) | 4 done + 1 blocked-by-design | 8-5 deliberately deferred to Alpha |
| Completion Rate (executable) | — | 100% (4/4) | — |
| Effort Days | 3.5 | ~2 | -1.5d (faster) |
| Bugs Found | — | 1 (S2) | — |
| Bugs Fixed | — | 1 | — |
| Unplanned Tasks Added | — | 2 (3 stale-test repairs; Trash Streamer rename) | — |
| Commits | — | 3 (clean, conventional) | — |

## Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 6 | 4 | 4 | 100% |
| 7 | 2 | 2 | 100% (closed WITHOUT a retrospective) |
| 8 (current) | 4 executable | 4 | 100% |

**Trend**: Stable. Eighth consecutive sprint at 100% Must Have completion.

## What Went Well
- **Full pipeline in ~2 working days**: ADR-0010 → epic → stories → implementation → code review → story-done → QA sign-off — no gate skipped, review mode lean throughout.
- **Manual walkthrough caught a real S2** (path progression state silently lost on restart — ClassPathSystem never wired into SaveSystem/BootController) that 32 passing automated tests did not surface. Direct proof of the manual-evidence requirement's value for UI stories.
- **Collaborative design loop worked as intended**: "Pato-Streamer" display name questioned by user → options presented → "Trash Streamer" decided → applied + saved to project memory. Card path_tag mapping reviewed together.
- **Test suite healed**: 360/360 after repairing 3 stale tests; discovered gdUnit4 aborts a suite on first failure (earlier "337 tests" runs were truncated) and that the suite reads the real user save at boot (3 false failures from playtest-save pollution).

## What Went Poorly
- **Save-wiring gap (S2)**: `restore_state()`/`serialize_state()` were written and unit-tested, but no one wired the calls into SaveSystem/BootController. It passed dev-story, TWO code reviewers, and 32 tests — everyone verified the module, no one verified the caller.
- **Stale sprint entry 8-4**: Action Queue was planned into Sprint 8 despite being fully implemented a week earlier (action-system story-003, 2026-06-30). Sprint planning did not check existing code/stories before scoping.
- **Test-health illusion**: 3 failures introduced by Sprint 7's Story 005 (deliberate locked-slot contract change, tests never updated) slipped through that story's closure; abort-on-first-failure masked the blast radius.
- **Sprint 7 was closed without a retrospective** — process gap, no velocity/action-item record for that sprint.

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| Playtest save polluting test assertions (3 false failures) | ~30 min diagnosis | Save moved aside (`save.json.bak`); suite re-run clean | Action item #1 (test isolation) |
| Implementation agent interrupted mid-write (2/7 files landed) | ~10 min | Remaining 5 files completed inline | Environment incident — none needed |

## Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| 8-2 Class Path Core | 1.5d | ~0.5d | -1.0d | ADR-0010 + QA plan pre-work made implementation mechanical |
| 8-4 Action Queue | 0.5d | 0d | -0.5d | Already implemented pre-sprint — planning error, not estimation error |

**Overall**: everything at-or-under estimate. Consistent over-estimation when design pre-work (ADR + QA specs) is complete — future sprints can plan tighter for well-specified stories.

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| Polish→English content audit | Sprint 6 retro AI #3 | 3 | Never scheduled as a scoped story | Schedule in Sprint 9 planning or consciously drop |
| ADR-0005 stale code samples | Sprint 3 (~) | 4+ | Low priority, never picked up | 15-min fix in Sprint 9 or delete the item |

## Technical Debt Status
- Current TODO/FIXME/HACK count in src/: **0** (tracked debt lives in `docs/tech-debt-register.md` instead — healthy pattern)
- New debt logged this sprint: test isolation from user save (follow-up), physical-device AC-6 recheck, performance pass due before Polish gate
- Trend: Stable

## Previous Action Items Follow-Up (Sprint 6 retro — most recent)

| Action Item | Status | Notes |
|-------------|--------|-------|
| Start Card UI epic | Done | Shipped in Sprint 7 |
| Ask before visual/design decisions | Done / ongoing | Followed this sprint (name + card-tag decisions) |
| Polish→English content pass as scoped task | Not Started (3rd carry) | Ad-hoc progress only (Trash Streamer rename) |
| Fix ADR-0005 stale code samples | Not Started (4th carry) | Recurring unaddressed item — process smell |

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Isolate tests from `user://save.json` (redirect user:// for test runs, or snapshot/restore in a global test hook) | solo dev | High | Sprint 9 |
| 2 | Process rule: any new Autoload with `restore_state()` gets an explicit **wiring AC** (SaveSystem serialize + restore call sites), not just a method-level AC | solo dev / process | High | Immediately |
| 3 | When closing a story that changes a UI contract, grep the test suite for assertions on the OLD contract before /story-done (prevents Story-005-style stale tests) | solo dev / process | Medium | Immediately |
| 4 | Polish→English content audit: schedule as a Sprint 9 story or consciously drop (3rd carry) | solo dev | Medium | Sprint 9 planning |
| 5 | ADR-0005 stale samples: 15-min fix or delete the item (4th carry) | solo dev | Low | Sprint 9 planning |

## Process Improvements
1. **Test the wiring, not just the module** — the save-wiring S2 and the stale Story-005 tests are two faces of the same failure: locally green, integrationally broken. Integration call-site checks belong in story ACs and code-review scope.
2. **Sprint planning checks existing code first** — before scoping a quick-spec into a sprint, grep for an existing implementation (8-4 was already done). One glob would have saved a planning slot.

## Summary
A very good sprint: the entire Class Path MVP (design → QA sign-off) landed in 2 working days at 100% executable completion, with the single bug found and fixed before close. The most important change going forward: **verify integration wiring, not just module correctness** — both of this sprint's real defects were caller-side gaps invisible to module-level tests.
