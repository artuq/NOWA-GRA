# BUG-001: Class Path progression silently lost on restart (save wiring missing)

**Severity**: S2 — Major | **Status**: Fixed | **Found**: 2026-07-05 (Story 8-3 AC-7 manual walkthrough) | **Fixed**: 2026-07-05 (same session)

## Repro (pre-fix)
1. Reach Tier 1+ on any class path (badge visible)
2. Quit and relaunch
3. **Expected**: badge visible immediately. **Actual**: badge gone; affiliation resets to 0 until the next path-tagged card re-derives it from counters.

## Root cause
`ClassPathSystem.restore_state()/serialize_state()` existed and were unit-tested, but neither `SaveSystem` nor `BootController` ever called them — module verified, caller never wired (the "test the wiring, not just the module" lesson, Sprint 8 retro).

## Fix
`src/core/save_system.gd` + `src/core/boot_controller.gd`: `class_path` key added to save payload + restore chain. Regression 72/72; re-verified manually on device.
