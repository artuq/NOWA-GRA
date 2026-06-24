## Retrospective: Sprint 2 — Action System
Period: 2026-06-23 — 2026-06-27
Generated: 2026-06-24

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 2 (both Must Have) | 2 | 0 |
| Completion Rate | — | 100% | — |
| Effort Days | 1.0 (2 × 0.5) | ~1.0 | ~0 |
| Bugs Found | — | 0 | — |
| Bugs Fixed | — | 1 (advisory guard gap, fixed pre-closure) | — |
| Unplanned Tasks Added | — | 1 regression test (the guard fix's test) | — |
| Commits | — | 2 (`a435ddb` plan, `6d16aa0` story 2-1) | — |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 1 | 7 | 7 | 100% |
| 2 (current) | 2 | 2 | 100% |

**Trend**: Stable. Both sprints hit 100% of Must Have scope with no descoping.

### What Went Well
- Both stories closed with full automated test evidence — 74/74 tests passing, including the full Sprint 1 regression set (no signature drift in `ResourceManager`/`ResourceFormulas`).
- Action item #1 from Sprint 1 ("never report test evidence without a real run") held: every test claim this sprint was backed by an actual `runtest.sh` execution against the real Godot binary, including a re-verification after the guard fix.
- When `/code-review` and the director gates surfaced a real (if low-risk) defensive-programming gap in `_on_action_timeout()`, the user chose to fix the actual code rather than just log it as tech debt — the story closed clean, not with a deferred liability.
- ADR-0004's stale code sample was caught and corrected (2026-06-23 correction) before it could mislead implementation.

### What Went Poorly
- **Sprint 1's action item #1 — "commit completed work" — has recurred.** Sprint 1's work did get committed (`02205e4`), but Sprint 2's actual deliverable (Story 2-2's implementation: `src/core/action_system.gd` reward resolution, the new integration test file, the regression-guard fix) is still **uncommitted** in the working tree as this retrospective is written. Only Story 2-1 and the sprint plan itself were committed (`6d16aa0`, `a435ddb`). This is the same risk flagged last sprint, recurring in a smaller form.
- Sprint 1's action item #3 (sync `design/gdd/resource-system.md` / `design/registry/entities.yaml` from Polish resource keys to the English keys actually used in code) was **not addressed** — still open in the tech-debt register, now two sprints stale.
- No manual QA or playtest scope existed this sprint (by design — backend-only), which is correct but means the sprint's "QA cycle" was thin: smoke check and sign-off had nothing to manually verify, all signal came from automated tests.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| `Edit` tool's "file not read yet" state reset (hit twice mid-session) | Minutes each | Re-`Read` the file before retrying `Edit` | None needed — known harness quirk, already the standard recovery |
| QA strategy subagent spawn hit a session/usage limit | One spawn attempt | Did the QA strategy analysis directly instead of via subagent | If recurring, default to direct analysis for `qa-lead`-style read-only strategy work rather than retrying the spawn |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| Story 2-2 (Reward Resolution & Morale Scaling) | M (3-4h) | ~M, plus a small fix-the-guard cycle | + slight | The guard gap wasn't part of the original estimate — director-gate review caught it post-implementation, as designed |
| Story 2-1 (ActionSystem Core) | M (3-4h) | M | 0 | Matched estimate; no surprises (Logic story, well-specified by ADR-0004) |

**Overall estimation accuracy**: 2/2 stories within estimate range — both Sprint 2 stories landed close to their M (3-4h) sizing.

### Carryover Analysis

None — no Sprint 2 stories carried over.

### Technical Debt Status
- TODO/FIXME/HACK in `src/` + `tests/`: **0** (clean, same as Sprint 1)
- Tech-debt register: unchanged net count from Sprint 1 close (no new entries added this sprint — the guard gap was fixed in code, not logged as debt)
- Polish/English doc-sync (entry #1, flagged Sprint 1): **still open**, now 2 sprints stale
- Cross-call lint check (entry, flagged Sprint 1, Low priority): still open, as expected ("when convenient")
- Trend: stable / flat — no growth, but the one open actionable item didn't shrink either

### Previous Action Items Follow-Up

| Action Item (from Sprint 1) | Status | Notes |
|-------------------------------|--------|-------|
| 1. Commit the sprint-1 work before sprint 2 starts | Done | `02205e4` committed before Sprint 2 began — but see "What Went Poorly": the *pattern* recurred with Sprint 2's own work |
| 2. Never report test evidence without a real run | Done | Held throughout Sprint 2 — every test claim was a real `runtest.sh` execution |
| 3. Doc-sync Polish→English resource keys | Not Started | Still pending in `design/gdd/resource-system.md` / `design/registry/entities.yaml` |
| 4. Write the cross-call lint check | Not Started | Low priority, deferred as planned |

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Commit Sprint 2's outstanding work (Story 2-2 implementation + tests + story/status file updates) — currently sitting uncommitted in the working tree | solo dev | High | Before Sprint 3 starts |
| 2 | Add a close-out checklist step "git status is clean" to `/story-done` or the sprint close-out sequence, so uncommitted work can't silently carry into the next sprint twice in a row | solo dev / process | High | Sprint 3 |
| 3 | Doc-sync Polish→English resource keys (tech-debt, now 2 sprints overdue) | solo dev | Med | Sprint 3 |
| 4 | Write the cross-call lint check (Low priority, unchanged from Sprint 1) | solo dev | Low | When convenient |

### Process Improvements
1. **Add an explicit "commit your work" gate to the close-out sequence** — `/smoke-check` → `/team-qa` → `/retrospective` currently has no step that checks `git status`. This is the second sprint in a row where deliverable code sat uncommitted at retrospective time.
2. **For read-only strategy/advisory subagent spawns (e.g., `qa-lead` for QA strategy) that hit session limits, fall back to doing the analysis directly** rather than retrying the spawn — worked cleanly this sprint and avoided losing momentum.

### Summary
A clean, 100%-completion sprint with strong test discipline — both stories closed with real, re-verified automated evidence, and the team chose to actually fix a flagged defensive-programming gap rather than just log it. The recurring weak spot is process, not code: Sprint 1's "commit your work" lesson didn't fully stick, and Sprint 2's deliverable is sitting uncommitted at sprint close exactly like Sprint 1's was. The single most important change going forward: **make "git status is clean" a hard checkpoint in the close-out sequence, not something the retrospective discovers after the fact.**
