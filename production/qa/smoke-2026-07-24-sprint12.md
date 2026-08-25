# Smoke Check Report
**Date**: 2026-07-24
**Sprint**: 12 — Close-out & Gate-Readiness
**Engine**: Godot 4.6.3 (Mono build, `/Users/magda/Downloads/Godot_Mono_4.6.3/Godot_mono.app`)
**QA Plan**: `production/qa/qa-plan-sprint-12-2026-07-23.md`
**Argument**: sprint

---

## Automated Tests

**Status**: PASS WITH ONE KNOWN FLAKE — 660 test cases, 657 consistently green, 1 test intermittently fails (~33% flake rate observed across 3 runs), 0 deterministic failures. First real headless execution in this environment — every prior sign-off this sprint (Sprint 10, 11, and this one's own QA plan) was a desk review of file presence only, per the Sprint 10-11 retro's own finding.

**Real bugs found and fixed during this run** (not pre-existing — introduced or exposed by Sprint 12's own card wave 2 / challenge screen work, caught only because the suite actually ran):
1. `weighted_selection_test.gd` — 16 failing assertions. Root cause: card wave 2 (12-6) added 4 new "always"-eligible cards (12→16), and this test's uniform-probability/exact-weight/pool-total constants were hardcoded to the old count. Fixed: `1.0/12.0` → dynamic `1.0/pool.size()`; `_EXPECTED_WEIGHTS_AT_100`/`_EXPECTED_PROBABILITIES_AT_100` extended with the 4 new cards' real values; pool total `336.0` → `457.0`, all 8 original cards' probabilities recomputed against the new denominator.
2. `challenge_selection_screen_test.gd` — 1 failing assertion (`test_zero_selected_confirm_uses_multiplier_1_and_emits_swap`), self-authored this sprint. Root cause: a genuine GDScript gotcha, not a production bug — the test's signal-handler lambda captured an outer `String` local by value, so writes inside the lambda never reached the outer scope (confirmed via debug print: captured value was empty while the failure report misleadingly showed identical-looking strings on both sides). Fixed: switched to the standard container-capture idiom (mutate a `Dictionary`'s keys instead of a bare local var).

**Known flake, filed not fixed** (pre-existing, unrelated to Sprint 12 scope):
- `BUG-004` — `card_feedback_test.gd`'s `test_backgrounding_during_resolving_leaves_clean_state`. Root cause diagnosed: the test's single `await get_tree().process_frame` is not a reliable way to land inside the Tween-driven `RESOLVING` state window (Tweens run on real wall-clock duration, not frame count) — under light system load the resolution beat can complete before the notification fires, causing `card_screen.gd`'s (correct) `_notification()` handler to take its early-return path instead. This is a test-timing race, not a `card_screen.gd` bug — confirmed by reading the production handler, which is logically sound. See `production/qa/bugs/BUG-004-card-feedback-backgrounding-test-flake.md` for the fix candidates (not applied — out of Sprint 12 scope).

---

## Test Coverage (Sprint 12)

| Story | Type | Test File | Coverage Status |
|-------|------|-----------|------------------|
| 12-2 Challenge-selection screen | Integration | `tests/integration/challenge/challenge_selection_screen_test.gd` (6/6) | COVERED, 1 self-authored bug found+fixed |
| 12-6 Card wave 2 | Config/Data | `tests/unit/card_content_database/card_content_database_test.gd` (21 cards, all ACs) | COVERED |
| ADR-0017 backend (compute_next_grant/get_last_grant) | Logic + Integration | `tests/unit/prestige/prestige_grant_preview_test.gd`, `tests/integration/prestige/prestige_last_grant_test.gd` | COVERED |
| 12-4, 12-5, 12-7, 12-8 | Process | N/A — documentation/tracking stories | EXPECTED |

**Summary**: 4 covered (2 with real bugs found+fixed during first execution), 4 expected (process stories), 1 known pre-existing flake filed as BUG-004.

---

## Manual Smoke Checks

Not performed — this smoke check covers automated test execution only. No live game session was run as part of this pass. Sprint 12 story 12-3 (playtest) is the scheduled manual verification and has not yet occurred.

---

## Follow-ups (non-blocking, carried/new)

1. BUG-004 (card feedback backgrounding test flake) — fix candidates filed, not applied.
2. Sprint 12 story 12-3 (playtest of the full era loop) — now unblocked, since 12-2 is confirmed working by both integration tests and this real test run.
3. Retroactively, the Sprint 10/11 QA sign-offs (`qa-signoff-sprint-10-2026-07-24.md`, `qa-signoff-sprint-11-2026-07-24.md`) can now be considered fully satisfied for their "condition to close" — this run confirms 11-2/11-4's test files (desk-reviewed at the time) do in fact pass.

---

## Verdict: **PASS**

657/660 test cases deterministically green; the 1 flaky case (3 sub-assertions) is filed as a known, diagnosed, non-blocking issue (BUG-004) unrelated to any Sprint 12 delivered scope. Both real bugs found during this run were introduced by Sprint 12's own work and are now fixed and re-confirmed green.
