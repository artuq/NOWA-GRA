# BUG-004: `test_backgrounding_during_resolving_leaves_clean_state` is flaky — test-timing race, not a production bug

**Severity**: S4 — Test flakiness only, no player-facing impact confirmed | **Status**: Found, not fixed | **Found**: 2026-07-24 (Sprint 12 story 12-1, first real headless test-suite execution in this environment) | **Existed since**: unknown — Sprint 9 (Juice/Feedback epic) most likely, never caught before because this is the first time the suite has actually been run headlessly against real Godot rather than reviewed by file presence.

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
`card_screen.gd`'s `_notification()` handler (lines 228-236) is logically correct: `if state == State.RESOLVING: _kill_juice_tweens(); _card_node.scale = Vector2.ONE; ...`. The bug is in the TEST's timing assumption, not the production code: the pulse/shake Tweens run on real wall-clock durations (0.08s/0.12s), not frame counts. A single `await get_tree().process_frame` does not reliably land inside the `RESOLVING` window — under light system load (fast frame processing), the resolution beat can complete and transition `state` away from `RESOLVING` before the notification fires, so `_notification()` takes its early-return path instead of the reset branch, leaving the tween running and scale un-reset. This matches the observed symptom exactly.

## Fix (not yet done — out of Sprint 12 scope, filed for later)
The test needs to deterministically land in `RESOLVING` before asserting, not rely on a single frame's timing. Candidate approaches: (a) assert `screen.state == CardScreen.State.RESOLVING` immediately after the `await` and fail fast with a clear message if the precondition wasn't met (converts a silent flake into a loud, diagnosable one), or (b) stub/lengthen the resolution beat duration for this specific test so the timing window is wide enough to be reliable regardless of system load, matching the pattern other tests in this suite already use for lowered test-only tuning knobs (see `test_payoff_beat_clamps_to_gdd_bounds_at_default_knobs`'s own comment about "lowered test values").

## Prevention
This is the first time `tests/` has been executed against real headless Godot in this environment (all prior Sprint 10-11 QA sign-offs were desk reviews of file presence only, per the Sprint 10-11 retro). Flag: any future desk-review-only QA sign-off should explicitly note it cannot catch timing-dependent flakiness like this — only a real run can.
