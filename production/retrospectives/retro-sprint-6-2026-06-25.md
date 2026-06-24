## Retrospective: Sprint 6 — Action UI
Period: 2026-07-14 — 2026-07-18 (scheduled)
Generated: 2026-06-25

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 1 (epic-level, provisional) → 4 (after breakdown) | 4 | +3 (granularity, not scope creep — total estimate landed under the provisional 3.0 days) |
| Completion Rate | — | 100% | — |
| Effort Days | 3.0 (provisional) | ~1.55 (story-level sum) | -1.45 (overestimated at epic level, same recurring pattern) |
| Bugs Found | — | 4 real implementation gaps (2 in Action Grid's truncation/state, 1 flaky-test root cause, 1 post-ship UX defect found by user) | — |
| Bugs Fixed | — | 4 | — |
| Unplanned Tasks Added | — | 2 (ADR-0007 authorship, MinimalUI4 theme application) | — |
| Commits | — | 15, all clean | — |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 4 | 4 | 4 | 100% |
| 5 | 2 | 2 | 100% |
| 6 (current) | 1→4 | 4 | 100% |

**Trend**: Stable. Sixth sprint running at 100% Must Have completion.

### What Went Well
- **First UI/scene work in the entire project shipped cleanly**: 4 stories, 3 real Control-node scenes, 18 automated interaction tests via GdUnit4's `scene_runner()` — a new evidence pattern established and reused consistently across all 3 UI-type stories.
- **The "write the ADR before the epic" discipline paid off immediately**: ADR-0007 was authored, engine-specialist-reviewed (catching 2 real gaps before any code existed), and independently `/architecture-review`-accepted in a fresh session — exactly the intended workflow, no shortcuts.
- **Code review kept catching real implementation gaps, not just test gaps**: Action Grid's truncation/ellipsis was entirely unimplemented (not just untested) until review caught it; a genuine flaky-test root cause (`simulate_frames()`'s real-timing variance) was found and fixed rather than papered over.
- **Direct user feedback on the running build caught something review couldn't**: once the user actually ran the scene, two real gaps surfaced that no amount of headless testing would catch — unreadable Resource HUD (no labels) and an unused art-direction resource (`art-bible-stub.md`'s color tokens, sitting unused since before this sprint).

### What Went Poorly
- **A real process violation**: when the user reported the HUD was unreadable, the agent jumped straight to implementing a fix (text, language, formatting) without asking how it should look — directly skipping CLAUDE.md's own Collaborative Design Principle. The user had to explicitly call this out. This also surfaced that `design/art/art-bible-stub.md` had been sitting unused since Production stage began — nobody had checked it before building HUD visuals.
- **A fundamental, project-wide language assumption was wrong and discovered late**: the game's UI language is English, but a large amount of existing content (Action System's action names, Card Content Database's cards, GDD prose) was built in Polish across multiple earlier sprints, before this was ever clarified. This is now a real, unscoped backlog item — not fixed this sprint, deliberately deferred.
- **Card UI's absence wasn't visible until the user actually played the build**: `DecisionCardSystem`'s backend has existed since Sprint 4, fully tested, but nothing in any UI ever subscribes to it — so cards silently never appear in actual play. This was discoverable from `production/epics/index.md` (no `card-ui` epic exists) at any point, but wasn't surfaced as a gap until manual testing.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| ADR-0007 needed independent `/architecture-review` before stories could unblock | One fresh-session review cycle | Ran the review in a separate session as required; ADR accepted cleanly, no rework | Standard process, worked as designed |
| New `class_name` scripts invisible to headless test runner until `--import` runs | Recurring 4x this sprint (once per new class) | Run `godot --headless --path . --import` after adding any new `class_name` script, before testing | Logged as standing habit in `docs/tech-debt-register.md` (Sprint 5) |
| Agent implemented a UI fix without asking — user had to stop and redirect | One exchange | User explicitly corrected the process; both the language issue and the missing-art-bible-check were resolved through actual collaboration afterward | New memory file saved: ask before implementing visual/design decisions, check art bible first |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| Action UI (epic, pre-breakdown) | 3.0 days (provisional) | ~1.55 days (story-level sum) | -1.45 | 5th consecutive epic where the epic-level estimate overshot the real story-level total — this pattern is now fully established, not a one-off |

**Overall estimation accuracy**: epic-level estimates continue to run high; story-level breakdown remains essential before treating any number as committed.

### Carryover Analysis
None as Must Have — but **Card UI** is now an identified, real gap discovered via actual play, not formally a "carryover" since it was never scheduled, but it's the most consequential missing piece for the game being playable at all.

### Technical Debt Status
- TODO/FIXME/HACK in `src/` + `tests/`: **0** (clean, unchanged)
- Tech-debt register: 22 entries, 5 RESOLVED, **17 open** — growth resumed this sprint (new UI-specific entries: evidence-method decision, `simulate_frames()` flakiness)
- Trend: growing again after Sprint 5's one-sprint dip — consistent with "more surface area (UI) = more real findings," not declining quality

### Previous Action Items Follow-Up

| Action Item (from Sprint 5) | Status | Notes |
|---|---|---|
| Decide Sprint 6 scope: Boot/Scene-Management vs. continued backend | Done | Chose Action UI; Boot scene scaffolding was descoped early (action_screen.tscn ended up runnable standalone, no Boot needed yet) |
| Keep `review-mode.txt` at `lean` | Done | Held the whole sprint — no full-mode subagent gate spawns, only the 2 specialist reviews inside `/code-review` |
| Fix ADR-0005's stale code samples | Not Started | Still carried, low urgency |
| Write the cross-call lint check | Not Started | Low priority, unchanged since Sprint 1 |

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Start the Card UI epic — `DecisionCardSystem`'s backend has been complete and untested-in-UI since Sprint 4; this is the single biggest gap between "tests pass" and "the game is actually playable" | solo dev | High | Sprint 7 |
| 2 | Before any future UI/visual story, explicitly check `design/art/art-bible-stub.md` (and any later full art bible) FIRST, and ask the user for design direction before implementing — do not patch visual defects unilaterally | solo dev / process | High | Ongoing, starting Sprint 7 |
| 3 | Schedule a deliberate Polish→English content pass (action names, card content, relevant GDD prose) as its own scoped task — not fixed in-passing during unrelated work | solo dev | Medium | When convenient, before considering content "ready" |
| 4 | Fix ADR-0005's stale code samples (carried 3 sprints) | solo dev | Low | When convenient |

### Process Improvements
1. **"Ask before implementing visual/design decisions" is now an explicit standing rule** (saved to memory this session) — the collaborative design principle in CLAUDE.md was skipped once this sprint; treat any UI/visual fix the same as a new feature requiring Question→Options→Decision, not just a code fix.
2. **Check whether a system's UI consumer exists before assuming "backend done" means "feature done"** — `DecisionCardSystem` passing 100% of its tests for 2 sprints gave a false sense of completeness; the real signal of "is this playable" is whether a human can see/touch it, which testing alone doesn't surface.

### Summary
A genuinely good sprint on paper — 100% completion, the project's first scene/UI work shipped cleanly with strong test discipline — but the most valuable outcome came after the "done" point, when the user actually played the build and found two real gaps (unreadable HUD, invisible cards) that no test suite could have caught. The single most important change going forward: **treat "the user has actually run the build" as part of Definition of Done, not an optional afterthought** — and prioritize Card UI next, since it's the most consequential gap between what's tested and what's actually playable.
