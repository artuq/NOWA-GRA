# Retrospective: Sprint 1 — Resource System

**Period**: 2026-06-23 → 2026-07-04 (closed early on 2026-06-23)
**Generated**: 2026-06-23

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 7 (6 must-have + 1 should-have) | 7 completed | 100% |
| Completion Rate | — | 100% | — |
| Estimate (days) | 3.75 | all closed | — |
| Bugs Found | — | 2 real (in tests) + 3 GDD arithmetic errors | — |
| Bugs Fixed | — | 5/5 | — |
| Unplanned Work | — | Large (test-infra bootstrap, incident diagnosis) | — |
| Unit Tests | — | 55, all passing on real engine | — |
| Commits containing sprint work | — | 0 (uncommitted in working tree) | — |

## Velocity Trend

First sprint — no historical data. This is the baseline: 7 stories / ~3.75 planned estimate-days, but real effort was dominated by unplanned foundation repair (see "What Went Poorly").

| Sprint | Planned stories | Completed | Rate |
|--------|----------------|-----------|------|
| 1 (current) | 7 | 7 | 100% |

## What Went Well

- **100% completion, 55/55 tests green on a real Godot engine.** The entire Resource System (core mutation + all 5 formulas A-E) is delivered as production code with static typing, doc comments, and ADR linkage.
- **The sprint plan's top risk materialized exactly as predicted** (GDScript static type inference silently degrading to Variant on built-in math functions like `pow`/`max`/`clamp`) — and was caught. The control-manifest rule existed; explicit-float typing was applied; tests caught regressions.
- **Director gates caught real issues at every story**, not theatre: tautological test assertion (1-1), constant naming (1-3), missing paired-boundary tests + inline magic numbers (1-4), unlocked function signature (1-5). Each gate added value.
- **Verification discipline paid off late but decisively**: the team discovered that earlier "tests passed locally" claims were *false* — the project had no `project.godot`, no installed GdUnit4, and a runner script referencing a nonexistent `GdUnitRunner.gd` class. The whole test harness was bootstrapped, turning fictional green into real green.

## What Went Poorly (systemic, no blame)

- **HEADLINE: for stories 1-1 / 1-2 / 1-3, the test suite had NEVER actually executed** before this session. No `project.godot`, no installed GdUnit4 addon, a fictional CI runner. Earlier sessions reported passing tests that had never run. Impact: three stories were "closed" on unverified evidence and had to be retroactively verified. This is the sprint's most important lesson.
- **GDD arithmetic rot**: worked examples in `resource-system.md` carried wrong numbers (1.85 vs correct 1.882; 7.3 vs 8.341) that propagated toward test assertions. Caught during implementation, corrected in 4 locations. Formulas/constants were always correct — only prose examples were wrong.
- **Infrastructure incident (sonnet model HTTP 500s)** disrupted the director gates near sprint end. External (server-side), not a project defect — diagnosed via a 4-spawn differential test and worked around with a `model: opus` override. Documented in the tech-debt register.

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| Test harness did not exist (no project.godot / GdUnit4 / valid runner) | Discovered mid-epic | Created project.godot, installed GdUnit4, fixed runner, added .gitignore | Run a bare test execution on sprint day 1 (see Process Improvements) |
| Sonnet model 500s on subagent spawn | Late sprint, ongoing | `model: opus` override on ccgs agent spawns | Known workaround documented; transient server-side |

## Estimation Accuracy

The 6 must-have stories were tiny pure-formula tasks (0.5 day each); their *story* work landed close to estimate. But the sprint's real effort was dominated by **unestimated foundational work** — bootstrapping the entire test harness, fixing two real test bugs, correcting GDD arithmetic, and diagnosing an infra incident. None of that was in the 3.75-day plan.

**Takeaway**: the planned story estimates were fine; the gap was an unstated assumption that the test infrastructure already worked. Sprint 2 should not assume tooling is in place — verify it first.

## Technical Debt Status

- TODO/FIXME/HACK in `src/` + `tests/`: **0** (clean)
- Tech-debt register: 6 entries, 1 resolved. Remaining are advisory: Polish/English resource-key doc drift (#1), hardcoded `_CLAMPED_KEYS`, `H_EXP` whole-number constraint, the doc-only "no cross-call" guarantee (needs a lint), and the now-resolved inline-gates entry.
- Trend: baseline (first sprint).

## Definition of Done — 7/9 met

- [x] All Must Have tasks completed
- [x] All tasks pass acceptance criteria
- [x] QA plan exists
- [x] All Logic/Integration stories have passing unit tests
- [x] Smoke check passed (`production/qa/smoke-2026-06-23.md`)
- [x] No S1/S2 bugs in delivered features
- [x] Design documents updated for deviations
- [ ] **QA sign-off report (`/team-qa`) — NOT yet run**
- [ ] **Code reviewed (yes, via gates) but NOT merged — all sprint work is uncommitted**

## Previous Action Items Follow-Up

None — first sprint.

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Commit the sprint-1 work — the entire Resource System epic sits uncommitted in the working tree | solo dev | High | Before sprint 2 starts |
| 2 | Never report test evidence without a real run — require an execution log; the "passed locally" fiction was the sprint's biggest risk | solo dev / process | High | Ongoing |
| 3 | Doc-sync Polish→English resource keys (tech-debt #1) — GDD/entities.yaml still say Zasięgi/Hatersi/Sponsorzy; code uses English | solo dev | Med | Sprint 2 |
| 4 | Write the cross-call lint check once, applied to all formulas — closes story 1-5's doc-only AC4 | solo dev | Low | When convenient |

## Process Improvements

1. **Run a bare test execution at sprint START, not just end.** A single `runtest.sh` invocation on day 1 would have caught the missing `project.godot` / GdUnit4 immediately instead of mid-epic.
2. **`model: opus` override is the known workaround** for sonnet-model incidents when spawning ccgs director-gate subagents. Documented in `docs/tech-debt-register.md`.

## Summary

A strong sprint on delivery — 7/7 stories, 55 unit tests green on a real engine, the entire Resource System foundation in place. But the headline lesson is about verification: half the epic's "passing tests" had never executed until the test harness itself was built this session. The single most important change going forward: **test evidence must come from a real run, and completed work must be committed to version control.**
