# Story 003: Boot Flow & Threshold Routing

> **Epic**: Offline Report Screen (+ Boot Flow)
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-26

## Context

**GDD**: `design/gdd/offline-report-screen.md` (threshold gate) + ADR-0003 boot sequence
**Requirement**: `TR-ors-001` — Offline simulation result presentation screen with dismiss gesture (this story builds the cold-start sequence that runs the offline sim and routes to the report screen or the main scene)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 (primary); ADR-0009, ADR-0006, ADR-0001 (secondary)
**ADR Decision Summary**: A `boot.tscn` (new `run/main_scene`) with a `BootController` that, in `_ready()`: `SaveSystem.load_save()` → `restore_state(data)` on each module in ADR-0001 dependency order → `OfflineProgressSystem.simulate_offline(elapsed)` → apply result to `ResourceManager` → if `elapsed ≥ 300s` `change_scene_to_file(offline_report.tscn)` else `change_scene_to_file(main.tscn)`. The sim result + `elapsed_seconds` (+ the `H0`/`M0` baselines the report screen needs) are stashed in `OfflineProgressSystem.last_simulation_result` (launch-only transient, never persisted).

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Autoloads finish `_ready()` before `BootController._ready()` (Godot init order, ADR-0003 §1). `change_scene_to_file` defers the swap to end-of-frame; writing the transient field synchronously before the call is safe (engine-specialist confirmed, 2026-06-26). `elapsed_seconds = Time.get_unix_time_from_system() - data.get("last_save_timestamp", now)`.

**Control Manifest Rules (this layer)**:
- Required: `BootController` applies the sim result to `ResourceManager` via ownership-clear direct write (ADR-0001); restore order matches ADR-0001's Autoload list
- Forbidden: persisting `last_simulation_result` to the save file (it is launch-only); putting launch sequencing in the gameplay scene's `_ready()` (that's why Boot exists)
- Guardrail: the boot sequence runs once at cold start only, not on scene changes

---

## Acceptance Criteria

*From GDD `design/gdd/offline-report-screen.md` Threshold gate + ADR-0003 boot sequence, scoped to this story:*

**Threshold routing:**
- [ ] Δt = 300s exactly → routes to `offline_report.tscn` (inclusive `≥` boundary)
- [ ] Δt = 299s → routes straight to `main.tscn`, no report (boundary excluded)
- [ ] Δt < 300s → main scene directly, no player gesture required

**Boot sequence (ADR-0003):**
- [ ] At cold start, `BootController` runs: `load_save()` → `restore_state()` per module (ResourceManager, HistoryFlagManager, CardContentDatabase no-op, ActionSystem, DecisionCardSystem — ADR-0001 order) → `simulate_offline(elapsed)` → apply result to ResourceManager
- [ ] `elapsed_seconds` computed as `now - last_save_timestamp` (first session / missing timestamp → 0 → main scene)
- [ ] `OfflineProgressSystem.last_simulation_result` is populated with the sim result **plus** `elapsed_seconds` **plus** the `H0`/`M0` (and initial Morale band) baselines the report screen needs for its ΔHaters / band-change display
- [ ] `last_simulation_result` is never written to the save file

**Scene wiring & regression:**
- [ ] `run/main_scene` repointed to `res://scenes/boot/boot.tscn`
- [ ] `res://scenes/main/main.tscn` hosts the existing `action_screen` content (Resource HUD, Action Grid, Running Action Overlay, Card UI modal) with the same node structure
- [ ] All existing Action UI and Card UI interaction tests stay green under the new `main.tscn` host

---

## Discovered Deviations from ADR-0003's Illustrative Code Sample

*ADR-0003 was written before these modules reached their final implemented shape. Its `gdscript` code sample is illustrative, not literal — the real APIs differ. Documented here rather than silently smoothed over:*

- **Real save keys**: `SaveSystem.load_save()` returns `{schema_version, last_saved_at, resources, history_flags, decision_card_state}` — NOT `last_save_timestamp` / `history` as the ADR's sample used.
- **`restore_state` only exists on `ResourceManager` and `HistoryFlagManager`.** `ActionSystem`, `DecisionCardSystem` have no `restore_state` method; `OnboardingGate` doesn't exist as a system in this project at all. `BootController` calls `restore_state` only on the two modules that implement it. (`DecisionCardSystem`'s save stub in `SaveSystem.save_now()` is hardcoded zeros — pre-existing gap, out of scope here; not this story's job to build Decision Card persistence.)
- **`simulate_offline()` returns absolute finals, not a deltas dict**: `{final_H, final_M, total_Z_gained, capped}`. There is no `resource_deltas` key. `BootController` must capture `h0`/`m0` (current Haters/Morale) *before* calling `simulate_offline`, then apply via `ResourceManager.apply_delta({Reach: total_Z_gained, Haters: final_H - h0, Morale: final_M - m0})` — the only write method `ResourceManager` exposes is `apply_delta`, there is no absolute setter.
- **`MIN_REPORT_THRESHOLD_SECONDS` doesn't exist as a constant anywhere** — only as prose in the GDD. Added to `OfflineProgressSystem` (sibling to its existing `MAX_OFFLINE_CAP_SECONDS`) as the tuning-knob home, even though the gate check itself runs in `BootController` (ADR-0009 §5).

## Implementation Notes

*Derived from ADR-0003 Decision (boot sequence) + ADR-0009 Decision §2, §5:*

**`BootController`** (`res://src/core/boot_controller.gd` on `boot.tscn`, minimal/no visuals — script lives in `src/core/` per the project's directory convention, not under `scenes/`): in `_ready()`, follow ADR-0003's steps 2-7 exactly. Capture `H0 = ResourceManager.get_resource(&"Haters")` and `M0 = ResourceManager.get_resource(&"Morale")` (and the initial Morale band) **after** `restore_state` but **before** applying the sim result — these are the baselines the report screen needs (the sim result alone carries only `final_H`/`final_M`). Build the transient payload:
```gdscript
OfflineProgressSystem.last_simulation_result = result.duplicate()
OfflineProgressSystem.last_simulation_result["elapsed_seconds"] = elapsed
OfflineProgressSystem.last_simulation_result["h0"] = h0
OfflineProgressSystem.last_simulation_result["m0"] = m0
```
Then apply `result` to ResourceManager (ownership-clear write). Then route:
```gdscript
if elapsed >= 300:  # MIN_REPORT_THRESHOLD_SECONDS
    get_tree().change_scene_to_file("res://scenes/offline_report/offline_report.tscn")
else:
    get_tree().change_scene_to_file("res://scenes/main/main.tscn")
```
Confirm the exact `MIN_REPORT_THRESHOLD_SECONDS` constant home (Offline Progress System vs a shared const) before hardcoding 300.

**`main.tscn`**: wrap the *existing* `action_screen.tscn` content. Simplest: `main.tscn` instances `action_screen.tscn` as its single child (or `action_screen` is renamed/rehosted) — the key constraint is that the Action UI / Card UI node paths the existing tests target remain valid. Re-run the full suite; fix any path references, not the structure.

**`run/main_scene`**: repoint to `boot.tscn` in `project.godot`.

**`restore_state` audit**: ADR-0003 §3 assumes each persisted-state module implements `restore_state(data)`. Verify each exists; if any is missing, surface it (do not silently skip) — it's a real boot-correctness gap.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001 (Offline Report Formatting) and Story 002 (Offline Report Screen): the report scene and its rendering/dismiss — this story only loads/routes to it and supplies its data
- Save-file format / atomic write (ADR-0002) — already built; this story only calls `load_save()`
- Onboarding/first-session tutorial flow — separate system, not in this epic

---

## QA Test Cases

*Interaction-test specs via GdUnit4 — drive `BootController` with stubbed elapsed values and assert routing + payload; verify the regression with the existing suite.*

- **AC: threshold routing boundary**
  - Given: `BootController` with a controllable `elapsed_seconds` (test seam — e.g. inject the value rather than reading the real clock)
  - When: boot runs with elapsed = 300 / 299
  - Then: 300 → `change_scene_to_file` requests `offline_report.tscn`; 299 → requests `main.tscn`
  - Edge cases: exactly 300 (inclusive), 299 (excluded), 0 / first session (main)

- **AC: transient payload populated for the report screen**
  - Given: a known `restore_state` result and a stubbed `simulate_offline` returning known `{final_H, final_M, total_Z_gained, capped}`
  - When: boot runs with elapsed ≥ 300
  - Then: `OfflineProgressSystem.last_simulation_result` contains the sim result keys plus `elapsed_seconds`, `h0`, `m0`; and the result was applied to ResourceManager exactly once
  - Edge cases: confirm `h0`/`m0` are captured before the sim result is applied (so ΔHaters is true)

- **AC: regression — Action UI / Card UI under main.tscn**
  - Given: the full existing test suite
  - When: run after the `main.tscn` rehost + `run/main_scene` repoint
  - Then: all previously-green Action UI and Card UI interaction tests still pass (same node structure)
  - Pass condition: full suite green, zero regressions from the boot refactor

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/offline_report/boot_flow_test.gd` — interaction test (routing + payload), plus the full-suite regression staying green

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (Offline Report Screen) — routes to it; and its `main.tscn` is the dismiss target — and Story 001 transitively
- Unlocks: None — final story; completing it makes offline visible end-to-end and establishes the boot→main navigation skeleton

---

## Completion Notes
**Completed**: 2026-06-29
**Criteria**: all passing (9 integration tests: threshold boundary 300/299/0, transient payload baselines, sim result applied via apply_delta, restore_state called with the correct save sub-dict, first-session empty save, main.tscn regression guard; + 3 unit tests for the real elapsed-seconds computation `BootController.compute_elapsed_seconds`)
**Deviations**: (1) ADR-0003's illustrative GDScript sample was stale vs the real implemented APIs — documented in "Discovered Deviations" above (real save keys, only 2 modules have `restore_state`, `simulate_offline` returns absolute finals not a deltas dict). (2) A real crash was caught only via manual headless cold-start testing (not the automated suite, which can't reproduce it — `scene_runner` never instances a scene as the tree's *own root*): `change_scene_to_file()` called synchronously from the Main Scene's own `_ready()` errors ("Parent node is busy adding/removing children"); fixed with `.call_deferred()`. Documented as a permanent manual checklist item in `production/qa/smoke-tests.md` (new file) since no automated test can catch a regression here. (3) Added `OfflineProgressSystem.MIN_REPORT_THRESHOLD_SECONDS` constant (didn't exist in code, only as GDD prose).
**Test Evidence**: Integration — `tests/integration/offline_report/boot_flow_test.gd` (9 tests) + `tests/unit/offline_report/boot_controller_elapsed_test.gd` (3 tests), full regression 268/268. Manual: 2 real headless cold-start runs (empty save, 2h-aged save) — see `production/qa/smoke-tests.md`.
**Code Review**: Complete — godot-specialist verdict ISSUES FOUND → fixed (untyped `{}` literal passed to `apply_delta`'s `Dictionary[StringName, float]` param, now built as an explicitly-typed local with `float()` casts; stale doc path corrected). qa-tester verdict GAPS → fixed (elapsed-computation had zero coverage, now unit-tested; "restores without crashing" was a weak assertion, now verifies the actual sub-dict landed in ResourceManager via a known value) + 1 gap correctly identified as inherently non-automatable (the call_deferred bug class), documented as a standing manual smoke-test instead.
