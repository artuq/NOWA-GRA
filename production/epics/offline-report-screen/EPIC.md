# Epic: Offline Report Screen

> **Layer**: Presentation
> **GDD**: design/gdd/offline-report-screen.md
> **Architecture Module**: OfflineReportScreen
> **Status**: Ready
> **Stories**: 3 stories created — see table below

## Overview

Surfaces the result of the offline simulation to the player on cold start. The
Offline Progress System already computes offline earnings (`simulate_offline`,
ADR-0006) but nothing presents them. This epic builds the standalone full-screen
report scene that reads the transient simulation result, renders the headline
Zasięgi gain, ΔHaters, Morale band, offline duration, and a `capped` message,
then dismisses (tap-anywhere or "Continue!") via a scene swap to the main scene.

Per ADR-0009, building this also delivers ADR-0003's cold-start boot flow as a
side effect: `BootController` + `boot.tscn` orchestrate save-restore → offline
sim → conditional report, and `main.tscn` becomes a thin wrapper hosting the
existing `action_screen` content (replacing the current hardcoded direct launch
into `action_screen`).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: Offline Report Screen — scene + transient hand-off + dismiss | Standalone `Control` scene reached via `change_scene_to_file`; reads `OfflineProgressSystem.last_simulation_result` (+`elapsed_seconds` added by BootController); single-fire dismiss; new `OfflineReportFormatting.format_duration` util | LOW |
| ADR-0003: Scene management & boot order | BootController orchestrates load → restore → simulate → conditional report; gates the 300s threshold; names the report scene path | LOW |
| ADR-0006: Offline simulation loop | `simulate_offline()` result shape `{final_H, final_M, total_Z_gained, capped}` consumed by the screen | LOW |
| ADR-0007: Action UI scene structure & Autoload binding | UI-zone-reads-Autoload-directly pattern this screen follows; standard `Button`, never `TouchScreenButton` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ors-001 | Offline simulation result presentation screen with dismiss gesture | ADR-0009 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/offline-report-screen.md` are verified
  (threshold gate, `format_duration` boundary cases, display rules, single-fire dismiss)
- All Logic and Integration stories have passing test files in `tests/`
  (notably `OfflineReportFormatting.format_duration` unit tests)
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- Existing Action UI interaction tests stay green under the new `main.tscn` wrapper

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Offline Report Formatting | Logic | Complete | ADR-0009 |
| 002 | Offline Report Screen | UI | Complete | ADR-0009, ADR-0007 |
| 003 | Boot Flow & Threshold Routing | Integration | Ready | ADR-0003, ADR-0009/0006/0001 |

**Build order**: 001 (format util, independent) → 002 (report screen, uses 001) → 003 (boot flow, routes to 002 + builds its `main.tscn` dismiss target). 002 is the visible win; 003 wires it into a real cold-start sequence and delivers the boot→main skeleton.

**Design-direction reminder**: confirm the report screen's visual layout with the user before finalising `offline_report.tscn` (Story 002 DoD).

## Next Step

Run `/story-readiness production/epics/offline-report-screen/story-001-offline-report-formatting.md` then `/dev-story` to begin.
