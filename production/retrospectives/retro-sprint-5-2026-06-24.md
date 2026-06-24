## Retrospective: Sprint 5 — Doc-Sync + Offline Progress System
Period: 2026-07-07 — 2026-07-11 (scheduled)
Generated: 2026-06-24

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 2 (5-1, 5-2) | 2 | 0 |
| Completion Rate | — | 100% | — |
| Effort Days | 2.25 (0.25 + 2.0 provisional) | ~2.25 | ~0 |
| Bugs Found | — | 4 (caught in code review, none after) | — |
| Bugs Fixed | — | 4 | — |
| Unplanned Tasks Added | — | 0 | — |
| Commits | — | 5 (1 chore, 1 plan, 1 feat, 2 docs, all clean) | — |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 3 | 4 | 4 | 100% |
| 4 | 4 | 4 | 100% |
| 5 (current) | 2 | 2 | 100% |

**Trend**: Stable. Five sprints in a row at 100% Must Have completion.

### What Went Well
- **The 3-sprint-stale doc-sync task finally closed** — slotted first per Sprint 4's retro action item, exactly as planned. Breaking that pattern was this sprint's explicit goal, and it held.
- **Producer's CONCERNS (epic-level 2.0-day estimate, same pattern as Sprint 4's Decision Card System) resolved cleanly** — the single resulting story (Story 001) landed at the estimate with no overrun, validating "run `/create-stories` before trusting an epic-level estimate" as a now-established practice across 2 sprints.
- **Found and corrected a real stale-ADR claim before it could mislead anyone**: ADR-0006 described `ResourceFormulas` as something Story 001 creates, but it already existed in full from the Resource System epic. Caught by checking the codebase before writing new code, not after — avoided duplicating already-tested formula logic.
- **Mid-session cost intervention**: switched `review-mode.txt` from `full` to `lean`, directly in response to user concern about subagent-spawn costs. This immediately reduced the gate overhead for the rest of Sprint 5's work (Story 001 onward) — no QL-STORY-READY/PR-SPRINT/QL-TEST-COVERAGE subagent spawns, only the 2 specialist reviews that add real value (engine specialist + qa-tester) during `/code-review`.
- **`/code-review`'s 2 specialist spawns (not gated by review mode) found 4 real, non-trivial test coverage gaps** — order-of-operations proof, a buffer-threshold boundary, an observable side effect, and a small-duration edge case — all fixed same-session.

### What Went Poorly
- **The reentrancy AC drop required a judgment call mid-session that should have been caught earlier** — the GDD's own Open Questions section flagged this as unresolved back when the GDD was written, with a stated target of "resolve before `/architecture-decision`." Neither ADR-0003 nor ADR-0006 ever actually resolved it, and nobody caught that gap until `/create-stories` for this exact story. A GDD's stated resolution target that's silently missed should probably surface earlier (e.g., during `/architecture-review`).
- **No QA plan existed upfront for Sprint 5 either** (same Sprint 4 weak spot) — though this time the gap was caught and explicitly surfaced by `/sprint-plan`'s Phase 5 QA Plan Gate, and `/qa-plan sprint` was run immediately afterward, before any implementation began. Improvement over Sprint 4, but the underlying habit (running `/qa-plan` proactively, not because a gate demanded it) still isn't automatic.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| GDD's reentrancy AC described a scenario structurally unreachable in the real architecture | One clarifying question to user | User decided: drop the AC, document why, rather than add a guard with no real trigger path | Established as a one-off resolution to a known GDD gap, not a recurring pattern |
| User flagged credit/cost concern mid-session | Immediate | Switched review-mode to `lean` | Standing change for all future sprints — `production/review-mode.txt` now reads `lean` |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| Doc-sync (5-1) | 0.25 days | ~0.25 days | 0 | Matched — scope correctly narrowed to key-identifier drift, not full translation |
| Offline Progress System (5-2, pre-breakdown) | 2.0 days (provisional, CONCERNS flagged) | ~2.0 days (1 story) | 0 | 3rd consecutive epic where producer's CONCERNS on an epic-level estimate resolved to the original number once broken into real stories |

**Overall estimation accuracy**: 2/2 within estimate.

### Carryover Analysis
None — no Must Have items carried into Sprint 6. (A future Boot/Scene-Management epic for TR-off-002 is a new forward-looking item, not a carryover.)

### Technical Debt Status
- TODO/FIXME/HACK in `src/` + `tests/`: **0** (clean, same as all prior sprints)
- Tech-debt register: 19 entries total, 4 RESOLVED (including entry #1, closed this sprint), **15 open** — net shrinkage this sprint (closed 1, opened 0)
- Trend: **shrinking** — first sprint where the register's open count went down, not up

### Previous Action Items Follow-Up

| Action Item (from Sprint 4) | Status | Notes |
|---|---|---|
| Pick up 4-3/5-1 (doc-sync) FIRST in Sprint 5 | Done | Closed first, exactly as planned |
| Fix ADR-0005's stale code samples | Not Started | Carried — not blocking, low urgency |
| Run `/qa-plan sprint` at the START of sprints | Partially done | Ran after `/sprint-plan`, before implementation — better than Sprint 4's fully-retroactive plan, but still gated by `/sprint-plan`'s prompt rather than a standing habit |
| Write the cross-call lint check | Not Started | Low priority, unchanged since Sprint 1 |

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Keep `review-mode.txt` at `lean` going forward — re-evaluate only if a real defect slips through that `full` mode would likely have caught | solo dev | High | Ongoing |
| 2 | Decide Sprint 6 scope: either start a Boot/Scene-Management epic (unlocks TR-off-002 + a real playable scene) or continue backend (Action UI / Card UI groundwork) | solo dev | High | Start of Sprint 6 |
| 3 | Fix ADR-0005's stale code samples (carried from Sprint 4, still not urgent) | solo dev | Low | When convenient |
| 4 | Write the cross-call lint check (carried since Sprint 1) | solo dev | Low | When convenient |

### Process Improvements
1. **`lean` review mode is now the standing default** — full mode's per-story subagent gate overhead (QL-STORY-READY, PR-SPRINT, QL-TEST-COVERAGE, LP-CODE-REVIEW) was costing more than it was finding; the 2 specialist reviews inside `/code-review` (not gated by review mode) are catching real bugs just as reliably at a fraction of the spawn count.
2. **Checking the existing codebase before implementing, not just before/after** continues to pay off — this sprint's `ResourceFormulas`-already-exists discovery avoided real duplicate work, the second time this exact pattern (story doc assumes something doesn't exist that actually does) has been caught this project.

### Summary
A clean, fast sprint — both stories closed at exactly their estimates, the multi-sprint doc-sync debt finally cleared, and a real mid-session course correction (switching to lean review mode) responded directly to the user's cost concern without sacrificing the things that actually catch bugs (tests, `/code-review`'s specialist spawns). The single most important decision now is **what Sprint 6 targets**: continuing backend systems keeps velocity high but delays a real playable build; starting Boot/Scene-Management work is riskier (more design surface, first real scene/UI work) but is the actual remaining blocker to "first playable."
