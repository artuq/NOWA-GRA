# Story 002: Offline Report Screen

> **Epic**: Offline Report Screen (+ Boot Flow)
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M (3-4h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-26

## Context

**GDD**: `design/gdd/offline-report-screen.md`
**Requirement**: `TR-ors-001` — Offline simulation result presentation screen with dismiss gesture (this story builds the screen + rendering + dismiss; the boot flow that loads it is Story 003)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 (primary); ADR-0007 (secondary)
**ADR Decision Summary**: Standalone full-screen `Control` scene (`scenes/offline_report/offline_report.tscn`, `class_name OfflineReportScreen`) reads `OfflineProgressSystem.last_simulation_result` (a Dictionary `{final_H, final_M, total_Z_gained, capped, elapsed_seconds}`) in `_ready()`, renders the report, and dismisses via a full-rect `Button` + a "Continue!" `Button` (single-fire latch) → `change_scene_to_file("res://scenes/main/main.tscn")`. No new signal/state on OfflineProgressSystem.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: Reading an Autoload field in a freshly-loaded scene's `_ready()` is safe — Autoloads finish init before any scene node's `_ready()`, and BootController writes the field before the scene swap (engine-specialist confirmed, 2026-06-26). Use standard `Button`, never `TouchScreenButton` (ADR-0007). `change_scene_to_file` is the right deferred swap for this flow. The full-rect `Button` as the root interactive surface avoids the double-fire/focus-routing pitfalls of raw `_gui_input`.

**Control Manifest Rules (this layer — Presentation)**:
- Required: PascalCase `class_name` (`OfflineReportScreen`); consume `OfflineProgressSystem` via direct Autoload read (ADR-0001/0007 pattern); standard `Button`
- Forbidden: re-deriving the K/M number format (reuse `ActionUIFormatting.format_number`); re-checking the 300s threshold here (BootController already gated it — Story 003)
- Guardrail: no `_process()` — the screen is static, fully event-driven

---

## Acceptance Criteria

*From GDD `design/gdd/offline-report-screen.md` Display rules + State transitions + Defined edge cases, scoped to this story (rendering + dismiss; threshold gating is Story 003):*

**Display rules:**
- [ ] Headline renders `total_Z_gained` via `ActionUIFormatting.format_number` exactly (e.g. 1,500,000 → "1.5M") — contract reuse, not re-derived
- [ ] Hatersi delta: `final_H - H0` shown signed — final_H=394, H0=5 → "+389"
- [ ] final_H = H0 → "+0" displayed (shown, not hidden)
- [ ] Morale: current band label always shown; if the band changed during offline, a change indicator is shown alongside it; if unchanged, only the current band label (no indicator)
- [ ] Offline duration line uses `OfflineReportFormatting.format_duration(elapsed_seconds)` (Story 001)
- [ ] capped=true → a capped message displayed in addition to the standard fields; capped=false → no capped message
- [ ] total_Z_gained=0 (with Δt≥300s) → screen still renders, shows "0" (or formatted equivalent), no special-case messaging

**Dismiss / state transitions:**
- [ ] Tapping the "Continue!" button OR tapping anywhere on the screen dismisses → `change_scene_to_file("res://scenes/main/main.tscn")`; both input sources trigger the identical single dismiss path
- [ ] Multi-tap during dismissal: only the first tap initiates the transition and fires dismiss exactly once; subsequent taps during the window are no-ops (single-fire latch)
- [ ] No auto-dismiss — the screen stays until the player acts

---

## Implementation Notes

*Derived from ADR-0009 Decision §1, §2, §4, §6:*

**Scene**: `res://scenes/offline_report/offline_report.tscn`, root a **full-rect `Button`** named `OfflineReportScreen` (`class_name OfflineReportScreen`, script `offline_report.gd`), dark background consistent with the app (see the Card UI / Action UI dark tokens). The report content (headline Label, ΔHaters Label, Morale band Label + optional change-indicator, duration Label, optional capped Label, and a child "Continue!" `Button`) are children of the root Button.

**In `_ready()`**: read `var r: Dictionary = OfflineProgressSystem.last_simulation_result`. Compute `H0`/`M0` — **note**: the result carries `final_H`/`final_M` but not the pre-offline baselines. The baseline for ΔHaters/Morale-band-change must come from what the screen knows: pass `h0`/`m0`/initial-band into the transient payload too if needed, OR compute the delta from values BootController captured. Confirm the exact payload keys with Story 003 (BootController owns what goes into `last_simulation_result`) before finalising — if `H0`/`M0` aren't available, surface it (the GDD's "+389" AC requires the baseline). Render all fields per the ACs. Reuse `ActionUIFormatting.format_number` for the headline and `OfflineReportFormatting.format_duration` for the duration.

**Dismiss**: both the root Button's `pressed` and the child "Continue!" Button's `pressed` connect to one `_dismiss()`. Guard with `var _dismissing := false`: first call latches it true and calls `change_scene_to_file("res://scenes/main/main.tscn")`; subsequent calls return early. The `_dismissing` latch lives on the screen.

**Design-direction checkpoint (epic DoD)**: before finalising the `.tscn` visual layout (headline size, secondary-stat arrangement, capped-message styling, Continue affordance), confirm the look with the user — do not freelance the visuals (Card UI / Action UI lesson).

**main.tscn dependency**: dismiss targets `res://scenes/main/main.tscn`, which Story 003 creates. For this story's interaction test, the dismiss assertion can verify the latch + that `change_scene_to_file` is invoked (e.g. via a test seam or by checking `_dismissing`), without requiring `main.tscn` to exist yet.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 001 (Offline Report Formatting): the `format_duration` util — this story calls it
- Story 003 (Boot Flow): `BootController`, `boot.tscn`, `main.tscn`, repointing `run/main_scene`, the 300s threshold gate, calling `simulate_offline`, and populating `last_simulation_result` — this story reads that field but does not write it or gate on the threshold

---

## QA Test Cases

*Interaction-test specs via GdUnit4 `scene_runner()` — stub `OfflineProgressSystem.last_simulation_result` then instance the scene.*

- **AC: rendering from the transient result**
  - Given: `last_simulation_result` stubbed with known values (e.g. `{total_Z_gained: 1500000, final_H: 394, final_M: ..., capped: false, elapsed_seconds: 85620}` + whatever baseline keys Story 003 provides)
  - When: the scene is instanced via scene_runner
  - Then: headline == `ActionUIFormatting.format_number(1500000)`; ΔHaters label == "+389"; duration label == "23 hours"; no capped message
  - Edge cases: final_H==H0 → "+0"; Morale band unchanged → no indicator; band changed → indicator present; total_Z_gained==0 → "0" rendered, no special message

- **AC: capped message**
  - Given: `last_simulation_result.capped == true`
  - When: rendered
  - Then: the capped message is present; with capped==false it is absent

- **AC: single-fire dismiss**
  - Given: the screen shown
  - When: the dismiss Button (or a root tap) fires once, then again rapidly
  - Then: the dismiss path runs exactly once (`_dismissing` latches; second call is a no-op) — verified without requiring `main.tscn` (assert the latch + that the scene-change was requested once)
  - Edge cases: button tap and background tap both route to the same single dismiss

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `tests/integration/offline_report/offline_report_screen_test.gd` — interaction test via scene_runner

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (Offline Report Formatting) — uses `format_duration`
- Unlocks: Story 003 (Boot Flow) — routes to this scene when `Δt ≥ 300s`; this scene's dismiss routes to Story 003's `main.tscn`
