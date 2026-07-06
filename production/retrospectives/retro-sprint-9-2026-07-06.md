# Retrospective: Sprint 9 — Juice/Feedback + Retro Debt
Period: 2026-07-06 — 2026-07-12 (closed early: 2026-07-06, ONE working day)
Generated: 2026-07-06

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 5 (3 MH + 1 SH + 1 NTH) | 5 done | 100% incl. Should Have AND Nice to Have |
| Effort Days | 3.5 (4 available) | ~1 | -2.5d |
| Bugs Found | — | 1 (**S1** — test suite deleting the real player save, pre-existing since ~Sprint 3) | — |
| Bugs Fixed | — | 1 (same-session, regression-verified) | — |
| Unplanned Work | — | 3 (shake retune after feel-test; web platform docs/decisions; 5 gap-closure tests from review) | — |
| Test count | 360 → 401 | +41 | — |
| Commits | — | **0 — all Sprint 9 work uncommitted at close** | process gap |

## Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 7 | 2 | 2 | 100% |
| 8 | 4 executable | 4 | 100% |
| 9 (current) | 5 | 5 | 100% |

**Trend**: Stable at 100% for the 9th consecutive sprint; actual effort consistently ~2-3× under estimate when design pre-work (ADR + QA specs) is complete.

## What Went Well
- **Two multi-sprint carryovers killed**: PL→EN audit (carried ×3 — verdict PASS, the per-story English discipline had already converged the surface) and ADR-0005 stale samples (carried ×4 — rewritten to match shipped code).
- **Sprint 8's "test the wiring" rule paid off immediately**: the combined epic code review caught 2 call-site-level WARNINGs (count-up start fabricated under resource clamping; stale shake-tween reference) that module-level tests missed — both fixed + covered same-day.
- **Feel-test loop worked end-to-end**: developer session → QA colleague video review → "As Designed / Needs Tweak" verdict → retune (6-12px/0.3-0.4s) → second video review approval — all within hours, GDD synced.
- **Web platform intelligence captured properly**: target confirmed → memory + technical-preferences + reference doc (Poki metrics) + 9:16-portrait decision — nothing left in conversation-only state this time.

## What Went Poorly
- **S1 data-loss bug lived since ~Sprint 3**: save-persistence tests hardcoded `user://save.json` in cleanups, silently DELETING the developer's real save on every test run. Invisible because "vanished save" reads as "fresh start". Found only because 9-3's isolation work made the file's lifecycle visible.
- **Platform decision lost to compaction**: the user had stated the web/CrazyGames target earlier; it fell out of context and had to be re-stated. Fixed structurally (memory-first rule for scope decisions), but it cost a confused exchange.
- **Zero commits during the entire sprint day** — all work sat uncommitted through an S1 discovery, a retune, and 4 story closures. One crash would have been expensive.

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| Playtest save polluting suite (2nd incident) | ~15 min | Isolation implemented (9-3) | Closed permanently |
| Save tests deleting real save (S1) | ~30 min diagnosis | Hardcoded paths → SaveSystemScript vars | Test-code review rule: no hardcoded user:// paths |
| `class_name` not in global cache for headless runs | ~10 min ×2 | preload consts in consumers | Known pattern now — document in test conventions |

## Estimation Accuracy
Everything at 2-3× under estimate (9-2 est. 1.5d → ~0.5d actual). Same signal as Sprint 8: well-specified stories (ADR + embedded QA specs) execute mechanically. Sprint 10 planned tighter accordingly.

## Previous Action Items Follow-Up (Sprint 8 retro)

| Action Item | Status |
|-------------|--------|
| Test isolation from user save | **Done** (9-3, + found the S1) |
| Wiring-AC rule for new Autoloads | Respected (ADR-0011 deliberately has NO Autoload; rule noted in sprint DoD) |
| Stale-test grep on UI-contract changes | Not triggered this sprint (no UI-contract changes to closed stories) |
| PL→EN audit — schedule or drop | **Done** (9-4, PASS) |
| ADR-0005 samples — fix or delete | **Done** (9-5) |

**All 5 previous action items addressed — first clean sweep.**

## Technical Debt Status
- TODO/FIXME/HACK in src/: 0 (register-based tracking holds)
- New: `# TODO: art-bible-pending` tokens (flash color, stinger streams) — intentional, tracked via art-bible dependency
- Known limitation logged: editor-panel test runs bypass save isolation (CLI/CI is the gate)

## Action Items for Next Iteration

| # | Action | Priority | Deadline |
|---|--------|----------|----------|
| 1 | **Commit after every /story-done** — not end-of-day batches; an S1 discovery day with zero commits is unacceptable risk | High | Immediately |
| 2 | Web-export spike FIRST in Sprint 10 — the ≤10 MB initial-download measurement is a fail-fast gate for the whole web strategy | High | Sprint 10 day 1 |
| 3 | Performance pass escalated to Must Have (carried ×2 — do not let it become the next ADR-0005) | High | Sprint 10 |
| 4 | Scope/platform decisions → memory immediately at utterance (adopted mid-sprint; keep the habit) | Medium | Ongoing |

## Process Improvements
1. **Feel-tests are a first-class gate for juice work** — automated tests proved parameters correct while the effect was invisible; only human eyes caught it. Budget a feel pass into every Visual/Feel-adjacent story, not just evidence-doc paperwork.
2. **Hardcoded environment paths in tests are now a review flag** — the S1 pattern (`user://` literals in test cleanup) is cheap to grep for during code review.

## Summary
The most productive sprint yet: a full Presentation-layer epic (design→APPROVED sign-off) plus three debt items in one day, with a first-ever unconditional QA APPROVED and a critical data-loss bug eliminated. The single most important change: **commit discipline** — the work was excellent and entirely unprotected for a full day.
