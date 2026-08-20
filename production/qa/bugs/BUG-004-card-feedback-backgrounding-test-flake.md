# BUG-004: `test_backgrounding_during_resolving_leaves_clean_state` was flaky — fixed deterministic lifecycle seam

**Severity**: S4 — Test flakiness only, no player-facing impact confirmed | **Status**: Fixed 2026-08-05 | **Found**: 2026-07-24 (Sprint 12 story 12-1, first real headless test-suite execution in this environment) | **Existed since**: unknown — Sprint 9 (Juice/Feedback epic) most likely, never caught before because this is the first time the suite has actually been run headlessly against real Godot rather than reviewed by file presence.

## Repro
Run `tests/integration/card_ui/card_feedback_test.gd` repeatedly (observed 1 failure in 3 runs — roughly 33% flake rate in this environment):
```
GODOT_BIN=<path> addons/gdUnit4/runtest.sh -a tests/integration/card_ui/card_feedback_test.gd
```
`test_backgrounding_during_resolving_leaves_clean_state` intermittently fails with:
```
Expecting: 'false' but is 'true'   (pulse tween still running)
Expecting: 'false' but is 'true'   (shake tween still running)
Expecting: '(1.0, 1.0)' but was '(1.07..., 1.07...)'   (scale not reset)
```

## Root cause
The test (lines 203-217) does:
```gdscript
screen.resolve(0)
await get_tree().process_frame  # intends to land mid-pulse/shake, state == RESOLVING
screen.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
assert_bool(screen._juice_pulse_tween.is_running()).is_false()
...
```
`card_screen.gd`'s `_notification()` handler is logically correct: `if state == State.RESOLVING: _kill_juice_tweens(); _card_node.scale = Vector2.ONE; ...`. The bug was in the TEST's timing assumption, not the production code. The helper shortened the resolution beat to `0.05 s`, while the pulse lasts `0.20 s` and shake can last `0.40 s`. A single `await get_tree().process_frame` did not reliably land inside `RESOLVING`: when a headless frame exceeded `0.05 s`, the beat changed the screen to `HIDDEN` while both tweens were still running. `_notification()` then correctly skipped its `RESOLVING` branch, producing all three failures.

## Fix
The test now calls `notification()` immediately after `resolve()`. That seam is deterministic because `resolve()` synchronously enters `RESOLVING` and creates both tweens before its first `await`. Explicit precondition assertions prove the expected state and live tween handles. The card scale is then set to a non-default mid-pulse value without advancing wall time, so the final `Vector2.ONE` assertion proves the reset branch actually ran rather than passing vacuously.

Verification on 2026-08-05: isolated `card_feedback_test.gd` 11/11 green, then full GdUnit4 736/736 green (85/85 suites; 153 pre-existing orphan nodes remain a separate harness baseline).

## Prevention
Do not use one rendered frame as a clock for sub-frame test tuning. When the production seam is synchronous before its first `await`, assert and exercise that seam directly; simulate the intermediate visual value explicitly when needed to prove cleanup. Any future desk-review-only QA sign-off should still state that it cannot catch timing-dependent flakiness — only a real run can.
