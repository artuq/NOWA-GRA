# Test Infrastructure

**Engine**: Godot 4.6.3
**Test Framework**: GdUnit4
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-06-19

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
  evidence/       # Screenshot logs and manual test sign-off records
```

## Running Tests

```
godot --headless --script tests/gdunit4_runner.gd
```

## Installing GdUnit4

1. Open Godot → AssetLib → search "GdUnit4" → Download & Install
2. Enable the plugin: Project → Project Settings → Plugins → GdUnit4 ✓
3. Restart the editor
4. Verify: `res://addons/gdunit4/` exists

## Test Naming

- **Files**: `[system]_[feature]_test.gd`
- **Functions**: `test_[scenario]_[expected]`
- **Example**: `onboarding_variety_gate_test.gd` → `test_repeat_action_type_stays_in_phase_pure_action()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `tests/evidence/` |
| UI | Manual walkthrough OR interaction test | `tests/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging.

## Determinism note (per ADR-0005)

Any test exercising `DecisionCardSystem`'s weighted-random pick must call
`set_seed()` on its RNG before asserting on outcomes — never rely on
`randomize()`'s OS-entropy seed in a test, per `coding-standards.md`'s
"no random seeds" determinism rule.

## Local dev gotcha: delete the real save file before repeated test runs

**Symptom**: re-running the full suite locally (not in CI) intermittently fails
a test that asserts a milestone/flag starts `false` (e.g.
`card_resolution_test.gd`'s `test_resolution_applies_resources_before_history_flags`),
even though the same test passes cleanly the first time or in isolation.

**Root cause**: `SaveSystem._ready()` unconditionally calls `load_save()` +
`restore_state()` on the real `ResourceManager`/`HistoryFlagManager` Autoloads
at Autoload init — this runs automatically for *every* Godot process,
including every `runtest.sh` invocation, regardless of `run/main_scene` or the
`-s` script override, and **before any test code can run**. Since the
2026-06-29 `mark_dirty()` wiring fix, many tests that mutate the real
Autoloads (`ResourceManager.apply_delta`, `HistoryFlagManager.set_milestone`/
`increment_counter`) arm `SaveSystem`'s real 2-second debounce timer; most
test files now stop that timer in `after_test()` as a defensive measure, but
a few real-`Timer`-driven tests (action durations of several real seconds)
can still let it fire *mid-test*, writing live (test-fixture-polluted) state to
the real `user://save.json`. The *next* local test invocation then inherits
that stale save file at Autoload init, before its own tests get a chance to
isolate themselves.

This is **not a production bug** (loading the real save at boot is correct)
and **not a CI bug** (CI runners start from a clean `user://` every time) —
it is a local, repeated-manual-run artifact only.

**Fix**: delete the real save file before re-running the suite locally:

```bash
# macOS
rm -f "$HOME/Library/Application Support/Godot/app_userdata/King of Cringe/save.json" \
      "$HOME/Library/Application Support/Godot/app_userdata/King of Cringe/save.tmp"
```

(On Linux: `~/.local/share/godot/app_userdata/King of Cringe/`. On Windows:
`%APPDATA%/Godot/app_userdata/King of Cringe/`.)
