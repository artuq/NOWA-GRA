# Epic: Offline Progress System

> **Layer**: Core
> **GDD**: design/gdd/offline-progress-system.md
> **Architecture Module**: OfflineProgressSystem
> **Status**: Ready
> **Stories**: 1 story created — see table below

## Overview

Implements the `OfflineProgressSystem` Autoload — a single synchronous `while`
loop (`simulate_offline()`, max 1440 iterations, 60s steps, 24h cap) that
re-derives Hatersi growth, Morale drain, and passive Zasięgi/Reach income for
the elapsed offline duration, using the same `ResourceFormulas` static utility
class consumed by live-play (Action System), guaranteeing the two contexts can
never diverge. Called once by `BootController` at launch (per ADR-0003's boot
sequence), before any gameplay UI is shown.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Scene management and module boot order | `simulate_offline()` called as boot step 4, before any UI shows | LOW |
| ADR-0006: Offline simulation loop implementation | Synchronous while loop, max 1440 iterations, no threading; shared `ResourceFormulas` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-off-001 | Stepped 1-minute simulation, capped at 1440 iterations (24h) | ADR-0006 ✅ |
| TR-off-002 | Launch-time init sequencing (load, restore, simulate, conditional report) | ADR-0003 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/offline-progress-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Stepped Offline Simulation | Logic | Ready | ADR-0006, ADR-0003 (secondary, deferred) |

**Note**: TR-off-002 (launch-time boot sequencing, ADR-0003) is explicitly out of scope for Story 001 — it requires `BootController`, the Offline Report Screen, and the Main scene, none of which exist yet. Deferred to a future Boot/Scene-Management epic. The GDD's reentrancy acceptance criterion ("a second app-start event... not invoked a second time concurrently") was dropped from Story 001 — it describes a scenario structurally unreachable given ADR-0003's actual boot model (runs once per process) and ADR-0006's synchronous sub-millisecond loop; this was a known unresolved open question in the GDD itself, never resolved by either ADR.

## Next Step

Run `/story-readiness production/epics/offline-progress-system/story-001-stepped-offline-simulation.md` then `/dev-story` to begin implementation.
