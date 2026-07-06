# BUG-002: Test suite deleted the real player save on every run

**Severity**: S1 — Critical (silent data loss) | **Status**: Fixed | **Found**: 2026-07-06 (during story 9-3 test-isolation work) | **Fixed**: 2026-07-06 (same session) | **Existed since**: ~Sprint 3 (save tests' creation)

## Repro (pre-fix)
1. Play the game, accumulate progress (save.json written)
2. Run the test suite (`gdUnit4 CLI` or any full run)
3. **Actual**: `user://save.json` deleted by save-persistence test cleanups — hardcoded `"user://save.json"` literals in before/after hooks of 3 test files. Invisible for weeks because a vanished save reads as a fresh start.

## Root cause
Hardcoded environment paths in test cleanup code (`save_core_test.gd`, `save_debounce_test.gd`, `onboarding_persistence_test.gd`).

## Fix
`SaveSystem` gained static path vars + gdUnit-CLI detection → tests use dedicated `user://save.test.json` (wiped once per process); the 3 test files repointed to `SaveSystemScript.SAVE_PATH`. Acceptance: full suite green WITH a real playtest save present, save intact after the run (verified 401/401).

## Prevention
Code-review flag: no hardcoded `user://` paths in tests (Sprint 9 retro process improvement #2).
