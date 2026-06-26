# ADR-0009: Offline Report Screen — Standalone Scene, Transient Result Hand-off, Dismiss

## Status
Proposed

## Date
2026-06-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | UI / Scene Management |
| **Knowledge Risk** | LOW — standard `Control` UI + `change_scene_to_file`; no post-cutoff APIs |
| **References Consulted** | `docs/architecture/adr-0003-scene-management-boot-order.md`, `docs/architecture/adr-0007-action-ui-scene-structure-autoload-binding.md`, `docs/engine-reference/godot/VERSION.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | Scene-transition timing on a real cold start (boot → report → main) on target Android hardware before production |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Accepted — defines the Boot scene + the conditional branch that loads this screen and the `change_scene_to_file` hand-off), ADR-0007 (Accepted — the UI-zone-consumes-Autoload-directly pattern this extends), ADR-0001 (Accepted — Autoload direct-call/read pattern), ADR-0006 (Accepted — `simulate_offline` result shape) |
| **Enables** | Offline Report Screen epic (Boot & Offline Report) |
| **Blocks** | The Offline Report Screen epic cannot be marked complete until this is Accepted |
| **Ordering Note** | ADR-0003 already specifies the boot orchestration and even names this screen's scene path; this ADR fills the remaining gap (TR-ors-001) for the screen *itself* — its scene structure, how it reads the simulation result, and its dismiss path |

## Context

### Problem Statement
The Offline Progress System computes offline earnings correctly (`simulate_offline()`, ADR-0006), but nothing surfaces the result to the player — `offline-report-screen.md`'s screen is designed but unbuilt, and the architecture review flagged TR-ors-001 as having no ADR. ADR-0003 already designs the *boot orchestration* (when `simulate_offline` runs and when the report scene is loaded), but leaves the report screen's own architecture undecided: how it receives the result, how it's structured, and how dismiss returns to gameplay.

### Constraints
- The game currently boots straight into `action_screen.tscn`; the Boot/Main scene flow from ADR-0003 is not yet implemented (this ADR's epic implements it).
- `simulate_offline()` returns `{final_H, final_M, total_Z_gained, capped}` — it does **not** carry `elapsed_seconds`, which the screen needs for `format_duration` (GDD Formulas).
- The screen is launch-only: it appears once at cold start when `Δt ≥ MIN_REPORT_THRESHOLD_SECONDS` (300s), before any gameplay scene exists.
- Mobile, touch-only; dismiss via tap-anywhere OR a "Continue!" button, both equivalent (GDD).

### Requirements
- Show `total_Z_gained` (headline), `final_H - H0` (ΔHaters), Morale band, offline duration, and a `capped` message when `capped=true` (GDD Layout).
- Reuse Action UI's number format (`ActionUIFormatting.format_number`) — do not invent a second K/M convention.
- Dismiss is the only close; first tap wins, subsequent taps during dismissal are ignored (GDD Edge Case).

## Decision

**1. The Offline Report Screen is a standalone full-screen scene, not a modal overlay.**
`res://scenes/offline_report/offline_report.tscn`, root `Control` (`class_name OfflineReportScreen`, script `offline_report.gd`), reached by `change_scene_to_file()` from `BootController` (ADR-0003). On dismiss it calls `change_scene_to_file("res://scenes/main/main.tscn")`. This deliberately differs from Card UI (ADR-0008), which is a `mouse_filter=STOP` modal layered over the *live* Action UI: at boot there is no gameplay scene beneath to preserve, the report is a one-shot gate *before* play begins, and a full scene swap is the simpler, correct lifecycle. (Card UI must preserve the running Action UI state beneath; the report must not — opposite requirements, opposite mechanism.)

**2. Data hand-off via the existing transient Autoload field, augmented with `elapsed_seconds`.**
`BootController` calls `simulate_offline(elapsed)`, then writes the payload to `OfflineProgressSystem.last_simulation_result` as the result dict **plus** an added `"elapsed_seconds"` key (the screen needs it for `format_duration`; the raw result lacks it). The screen reads `OfflineProgressSystem.last_simulation_result` directly in `_ready()` (Autoload read, ADR-0001/0007 pattern) — no constructor args, no scene-transition userdata. This reuses the field the offline system already exposes as its launch-only transient holder (ADR-0003 §6: "an Autoload-held transient variable … never persisted").

**3. No new signal or state machine on OfflineProgressSystem.**
The GDD frames the lifecycle as OfflineProgressSystem `presenting → idle`, but the implemented system has no state machine, and adding one would be ceremony: the lifecycle is already expressed by the **scene flow** (Boot → Offline Report → Main). The screen reads the transient result and, on dismiss, transitions scenes — there is nothing for an OfflineProgressSystem state to gate. (Documented deviation from the GDD's conceptual `presenting/idle` framing; behaviour is equivalent.) This is strictly simpler than Card UI, which *did* need an additive `card_presented` signal precisely because it is a modal over a live scene with no scene-transition to mark its lifecycle.

**4. Formatting: reuse the number format, add one testable duration helper.**
- Headline number → `ActionUIFormatting.format_number(total_Z_gained)` (the existing K/M convention, per GDD).
- `format_duration(elapsed_seconds: int) -> String` is a genuine new display derivation (GDD Formulas) → a stateless static utility `res://src/ui/offline_report_formatting.gd`, `class_name OfflineReportFormatting`, headlessly unit-testable against the GDD's exact ACs (same precedent as `CardSwipeMath` / `ResourceFormulas` / `ActionUIFormatting`). Formula: pick the largest unit U ∈ {hours, minutes} where `Δt ≥ U.seconds`, floor, render `"N unit(s)"` (no "days" — capped at 24h). Singular/plural handled.

**5. Threshold gating stays in BootController, not the screen.**
The `Δt ≥ 300s` decision lives in `BootController` (ADR-0003 §6) — the screen is only ever loaded when the threshold is met, so it renders unconditionally from `last_simulation_result` and never re-checks the threshold.

**6. Dismiss: tap-anywhere + button, single-fire latch.**
The root interactive surface is a **full-rect `Button`** (the report content is laid out as its children), with a child "Continue!" `Button` as the explicit affordance (per ADR-0007: standard `Button`, never `TouchScreenButton`) — idiomatic on touch and avoiding the double-fire/focus-routing pitfalls of raw `_gui_input`/`_unhandled_input` (engine-specialist note, 2026-06-26). Both `pressed` signals call one `_dismiss()` guarded by a `_dismissing` bool that latches on the first call and ignores the rest (GDD multi-tap edge case). `_dismiss()` → `change_scene_to_file(main)`. The `_dismissing` latch lives on the screen, not the Autoload — a single-instance, single-shot UI concern.

### Architecture Diagram
```
BootController (ADR-0003)
  simulate_offline(Δt) -> {final_H, final_M, total_Z_gained, capped}
  apply result to ResourceManager
  OfflineProgressSystem.last_simulation_result = result + {elapsed_seconds: Δt}
  Δt >= 300s ? change_scene_to_file(offline_report.tscn) : change_scene_to_file(main.tscn)
                       |
        OfflineReportScreen._ready()
          reads OfflineProgressSystem.last_simulation_result
          renders: format_number(total_Z), ΔH, Morale band, format_duration(Δt), [capped msg]
                       |
        tap-anywhere OR "Continue!" -> _dismiss() [single-fire latch]
                       |
        change_scene_to_file(main.tscn)
```

### Key Interfaces
```gdscript
# Read (existing, ADR-0006): result shape on the Autoload transient field
# OfflineProgressSystem.last_simulation_result == {
#   final_H: float, final_M: float, total_Z_gained: float, capped: bool,
#   elapsed_seconds: int   # ADDED by BootController for the screen's format_duration
# }

class_name OfflineReportFormatting
extends RefCounted
static func format_duration(elapsed_seconds: int) -> String: ...  # "6 hours", "23 minutes"
```

## Alternatives Considered

### Alternative 1: Modal overlay (reuse Card UI's ADR-0008 pattern)
- **Description**: Mount the report as a `mouse_filter=STOP` modal over the main scene, like Card UI.
- **Pros**: One UI pattern across the project.
- **Cons**: Requires the main scene to already be loaded and then suppressed at boot; the report is a *gate before* play, not an interruption *of* play — a modal inverts the natural flow and leaves a live, idle gameplay scene running behind a screen the player must clear first.
- **Rejection Reason**: Wrong lifecycle. The full scene swap matches "launch-only gate"; the modal matches "interrupt live play" (Card UI). Forcing one pattern onto both costs clarity.

### Alternative 2: Add a `presenting/idle` state machine + signal to OfflineProgressSystem
- **Description**: Mirror Card UI exactly — add an OfflineProgressSystem state and a `report_ready` signal the screen subscribes to.
- **Pros**: Literal match to the GDD's `presenting/idle` wording; symmetric with Card UI.
- **Cons**: Pure ceremony here — the scene transition already marks the lifecycle, and no other system reads such a state. Card UI needs its signal because it's a modal with no scene transition to mark the event; the report has the transition.
- **Rejection Reason**: Adds state with no reader. Simpler to let the scene flow be the lifecycle.

## Consequences

### Positive
- Closes TR-ors-001 and makes the offline backend finally visible (Pillar 4).
- Implementing it delivers ADR-0003's Boot/Main scene flow as a side effect — the project gains a real cold-start sequence (save restore + offline sim) and a boot→main navigation skeleton, replacing the hardcoded `action_screen` main scene.
- Reuses existing formatting and the existing transient field; one small new testable util.

### Negative
- The epic is larger than a pure screen: it must build `BootController` + `boot.tscn` + `main.tscn` (a thin wrapper hosting the existing `action_screen` content) + `offline_report.tscn`, and repoint `run/main_scene` to the boot scene.
- Modules' `restore_state(data)` methods (ADR-0003 §3) must exist/be wired for the boot sequence to be correct — any module missing one is surfaced by this epic.

### Risks
- **Boot-order regressions**: moving the main scene from `action_screen` to `boot` could break the current direct-launch behaviour. *Mitigation*: `main.tscn` wraps the existing `action_screen` content unchanged; interaction tests for Action UI continue to target the same node structure.
- **Transient field misuse**: `last_simulation_result` must never be persisted to save. *Mitigation*: it is launch-only (ADR-0003 §6); SaveSystem already does not read it.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| offline-report-screen.md | Show `total_Z_gained`, ΔHaters, Morale band, duration, `capped` message | Screen reads `last_simulation_result` (+`elapsed_seconds`) and renders all five, reusing `ActionUIFormatting.format_number` + new `format_duration` |
| offline-report-screen.md | Appears only when `Δt ≥ 300s`, once at boot | BootController gates loading the scene (ADR-0003); screen renders unconditionally |
| offline-report-screen.md | Dismiss via tap or button, first-tap-wins | Full-rect tap + "Continue!" Button → single-fire `_dismiss()` → `change_scene_to_file(main)` |
| offline-report-screen.md | `format_duration` derivation | `OfflineReportFormatting.format_duration`, stateless + unit-tested |

## Performance Implications
- **CPU/Memory**: negligible — a static screen, no `_process`. Scene swap frees the boot scene.
- **Load Time**: one extra scene transition at cold start only; the gameplay scene loads either way.

## Migration Plan
1. Build `OfflineReportFormatting` + unit tests.
2. Build `offline_report.tscn` + `offline_report.gd` (reads transient field, renders, dismiss).
3. Build `BootController` + `boot.tscn`; wrap `action_screen` content in `main.tscn`; repoint `run/main_scene` to `boot.tscn`; wire `simulate_offline` + `restore_state` per ADR-0003.
4. Keep Action UI interaction tests green (same node structure under `main.tscn`).

## Validation Criteria
- `format_duration` unit tests pass for the GDD's boundary cases (5 min, 59 min, 1 hour, 23 hours, 24-hour cap).
- Interaction test: with a stub `last_simulation_result`, the screen renders the expected strings and dismiss transitions away.
- Cold-start playtest: a >5-minute gap shows the report with correct numbers; a <5-minute gap goes straight to gameplay.

## Related Decisions
- ADR-0003 (boot order + scene transitions), ADR-0006 (offline simulation), ADR-0007 (UI-zone-consumes-Autoload pattern), ADR-0008 (Card UI modal — contrast: this is a scene swap, not a modal).
