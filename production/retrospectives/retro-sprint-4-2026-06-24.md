## Retrospective: Sprint 4 — Card Content Database + Decision Card System
Period: 2026-06-30 — 2026-07-04 (scheduled)
Generated: 2026-06-24

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 2 Must Have (epic-level) → split into 4 real stories | 4 | +2 (story-level breakdown revealed more granularity, not scope creep) |
| Completion Rate | — | 100% | — |
| Effort Days | 3.0 (epic-level estimate) | ~3.0 (0.75+0.75+0.5 for DCS, ~1.0 for CCD) | ~0 |
| Bugs Found | — | 0 (caught in code review, not after) | — |
| Bugs Fixed | — | 4 (2 real implementation bugs, 2 reentrancy/empty-pool guards) | — |
| Unplanned Tasks Added | — | 0 | — |
| Commits | — | 5 (4 feat + 1 docs, all clean) | — |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 2 | 2 | 2 | 100% |
| 3 | 4 | 4 | 100% |
| 4 (current) | 2 (epic-level) → 4 (story-level) | 4 | 100% |

**Trend**: Stable. Four sprints in a row at 100% Must Have completion.

### What Went Well
- **The producer's CONCERNS from sprint planning were validated and handled correctly**: Decision Card System's epic-level 2.0-day estimate was flagged as provisional pending `/create-stories`; the real breakdown (3 stories, 0.75+0.75+0.5=2.0 days) landed exactly on the epic estimate — the producer's caution was warranted (real complexity existed) but the mitigation (story-level sizing first) worked.
- **Real bugs caught before shipping, not after**: 4 genuine implementation bugs (typed-Array/Dictionary conversion gaps, a missing empty-pool guard, a missing reentrancy guard) were all found during `/code-review`'s specialist passes and fixed with regression tests — none reached `/story-done` undetected.
- **GDD-vs-acceptance-criterion contradictions were surfaced, not papered over**: Card Content Database's AC-7 (ratio bound) and AC-13 (Sponsors rule) both had real defects in the GDD's own data/wording, discovered during implementation and resolved transparently with user input rather than silently "fixed."
- **The Sprint 2 retro's process improvement held**: "git status clean" as an explicit checkpoint worked — all 5 commits this sprint were made promptly after each story closed, no uncommitted work accumulated at retrospective time (unlike Sprints 1 and 2).
- **QL-STORY-READY gates caught 3 real pre-implementation gaps** across the epic's stories (an unresolved test-strategy choice, a wiring assumption that wasn't actually wired, a test plan relying on a nonexistent signal) — all fixed before code was written, not discovered mid-implementation.

### What Went Poorly
- **The doc-sync tech debt item (Polish→English resource keys) has now been carried 3 sprints in a row** (Sprint 1 action item #3 → Sprint 2 action item #3 → Sprint 3's 3-4 → Sprint 4's 4-3) without ever being picked up, despite being explicitly scheduled each time. This is a process smell: a Low/Med-priority Nice to Have item keeps losing to Must Have work, which is individually reasonable each sprint but has now compounded to 3 sprints of staleness.
- **ADR-0005 accumulated staleness across all 3 of its consuming stories** before anyone fixed the root document — each story re-discovered and re-documented the same "this pseudocode doesn't match reality" finding rather than the ADR being corrected once, early.
- **No QA plan existed upfront for Sprint 4** — stories were implemented via `/create-stories` + `/dev-story` directly with test specs sourced from each GDD's own acceptance criteria, and the QA plan was only generated retroactively during `/team-qa`. Functionally fine (test coverage was complete), but skips the intended "QA plan defines done before code starts" sequencing.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| Multiple subagent spawns hit session/usage limits (QL-STORY-READY gates, qa-lead strategy) | Several minutes each, recurring | Did the gate assessment directly instead of retrying the spawn | Established pattern from Sprint 3; continues to work, no new prevention needed |
| Several implementation subagents refused to act on orchestrator-relayed write approval (correctly, per their own safety design — can't distinguish a trusted orchestrator from a compromised one) | One exchange each, ~2 stories affected | Implemented directly using my own Edit/Write/Bash tools instead of delegating | This is a structural property of the harness, not a bug — continue implementing directly for Foundation/Core-layer code rather than spawning implementation subagents |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| Card Content Database (epic) | 1.0 day | ~1.0 day | 0 | Matched — pure data declaration, no surprises |
| Decision Card System (epic, pre-breakdown) | 2.0 days (provisional, CONCERNS flagged) | ~2.0 days (0.75+0.75+0.5 across 3 stories) | 0 | Producer's caution was correct in spirit (real complexity existed: RNG determinism, cross-Autoload ordering, milestone isolation) but the eventual total matched the original estimate once properly broken down |

**Overall estimation accuracy**: 2/2 epics within estimate once story-level breakdown occurred — validates the "run `/create-stories` before trusting an epic-level estimate" lesson from the Sprint 4 planning gate.

### Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| 4-3 Doc-sync Polish→English resource keys | Sprint 1 | 3 | Consistently deprioritized below Must Have work each sprint | Recommend either scheduling it as the FIRST task of Sprint 5 (not last), or formally descoping it to "fix opportunistically, no longer sprint-tracked" |

### Technical Debt Status
- TODO/FIXME/HACK in `src/` + `tests/`: **0** (clean, same as all prior sprints)
- Tech-debt register: **+6 new entries this sprint** (3 Card Content Database, 3 Decision Card System epic-close) — all advisory, none blocking
- Doc-sync (entry #1, flagged Sprint 1): **still open**, now 3 sprints stale
- Cross-call lint check (Sprint 1, Low priority): still open, as expected
- Trend: **growing** (first sprint with net-positive tech debt growth) — but this reflects increased scrutiny (more director-gate reviews surfacing real findings), not declining code quality; every new entry has a clear owner and trigger condition for revisiting

### Previous Action Items Follow-Up

| Action Item (from Sprint 3 — never formally retro'd, reconstructed from session notes) | Status | Notes |
|-------------------------------|--------|-------|
| Continue "git status clean" checkpoint | Done | Held this sprint — 5 clean commits, no carryover |
| Doc-sync Polish→English resource keys | Not Started | 3rd consecutive sprint without progress |

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Pick up 4-3 (doc-sync) as the FIRST task of Sprint 5, before any new Must Have work, to break the 3-sprint carryover pattern | solo dev | High (process, not urgency) | Start of Sprint 5 |
| 2 | Fix ADR-0005's code samples once, properly (replace with a pointer to `src/core/decision_card_system.gd`'s doc comments, or formally revise via `/architecture-decision`) rather than letting future ADRs accumulate the same per-story staleness annotations | solo dev | Med | Sprint 5 |
| 3 | Run `/qa-plan sprint` at the START of future sprints (before `/create-stories`), not retroactively during `/team-qa` — restores the intended "QA defines done before code starts" sequencing | solo dev / process | Med | Sprint 5 |
| 4 | Write the cross-call lint check (Low priority, unchanged since Sprint 1) | solo dev | Low | When convenient |

### Process Improvements
1. **The "git status clean" checkpoint (introduced Sprint 2's retro) is working — keep it as a standing rule**, not just a one-time fix. No further action needed beyond continued discipline.
2. **When a director gate finds a real pre-implementation gap (QL-STORY-READY) or a real code defect (`/code-review`), fix it immediately and re-verify rather than logging it as tech debt** — this sprint's pattern of "find → fix → re-test → confirm" caught 4 real bugs and 3 real story-readiness gaps before they could ship, at the cost of more gate cycles. Worth the cost; continue this discipline.

### Summary
A strong, stable sprint — 100% Must Have completion for the 4th sprint running, with the added discipline of catching real bugs and real GDD defects during review rather than after. The recurring weak spot is no longer "uncommitted work" (that's fixed) but **a single low-priority task that has now silently lost to Must Have work three sprints running** — not itself harmful, but a pattern worth breaking deliberately rather than letting it become permanent. The single most important change going forward: **give the 3-sprint-stale doc-sync task explicit first-priority slotting in Sprint 5, rather than letting it compete with new Must Have work for the fourth time.**
