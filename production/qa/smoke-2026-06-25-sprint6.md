## Smoke Check Report
**Date**: 2026-06-25
**Sprint**: Sprint 6 — Boot scene scaffolding (descoped) + Action UI
**Engine**: Godot 4.6.3
**QA Plan**: `production/qa/qa-plan-sprint-6-2026-06-24.md`
**Argument**: sprint

---

### Automated Tests

**Status**: PASS (206 tests, 206 passing)

Run via `bash addons/gdUnit4/runtest.sh -a tests --godot_binary [Godot 4.6.2 binary]`, confirmed multiple times this sprint (after each story's implementation and after each code-review fix).

22/22 test suites executed, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans.

---

### Test Coverage

| Story | Type | Test File | Coverage Status |
|-------|------|-----------|----------------|
| 6-1a Number Formatting & Progress Bar Math | Logic | `tests/unit/action_ui/action_ui_formatting_test.gd` | COVERED |
| 6-1b Resource HUD | UI | `tests/integration/action_ui/resource_hud_interaction_test.gd` | COVERED |
| 6-1c Action Grid | UI | `tests/integration/action_ui/action_grid_interaction_test.gd` | COVERED |
| 6-1d Running Action Overlay | UI | `tests/integration/action_ui/running_action_overlay_interaction_test.gd` | COVERED |

**Summary**: 4 covered, 0 manual, 0 missing, 0 expected.

Note: all 3 UI-type stories use automated GdUnit4 `scene_runner()` interaction tests rather than manual evidence docs — established this sprint as the standing approach for UI stories in this project (the implementing session has no way to actually view a rendered scene; see `docs/tech-debt-register.md`'s Story 002 entry).

---

### Manual Smoke Checks

First sprint with real `.tscn` scene files (`scenes/action_screen/`), but `project.godot` still has no `run/main_scene` configured — there is no launchable build yet. `action_screen.tscn` is fully runnable and testable standalone (confirmed via the 18 automated interaction tests across the 3 UI zones), just not wired as the project's entry point. That wiring is explicitly deferred to a future Boot/Scene-Management epic (TR-off-002 from the Offline Progress System epic shares this same dependency).

- [-] Core stability (launch, input) — N/A, no project entry point configured yet
- [x] Primary mechanic (Action UI: Resource HUD + Action Grid + Running Action Overlay) — PASS, fully exercised by 18 automated interaction tests (scene-runner based, not manual)
- [-] Regression check — N/A, no prior UI to regress; `ActionSystem`'s existing 13 tests (11 original + 2 new for `action_started`) all still pass, confirming the new signal didn't disturb existing behavior
- [-] Save/load — N/A, no SaveSystem changes this sprint
- [-] Performance — N/A, no running build to profile; `RunningActionOverlay`'s `_process()` discipline (zero cost while idle) is verified by test, not measured on real hardware

---

### Missing Test Evidence

None. All 4 Sprint 6 stories have complete, appropriate evidence for their type.

---

### Verdict: PASS

All automated tests pass (206/206), all 4 Sprint 6 stories have complete test coverage, and the manual smoke checklist items are correctly N/A given no project entry point exists yet — not failures. This sprint marks a real milestone: the first scene files and the first genuinely interactive UI in the project, fully covered by automated headless interaction tests rather than manual claims. Two real implementation gaps (not just test gaps) were caught and fixed during code review this sprint: Action Grid's truncation/ellipsis behavior was entirely unimplemented, and a real flaky-test cause (`simulate_frames()`'s real-timing variance) was found and resolved.
