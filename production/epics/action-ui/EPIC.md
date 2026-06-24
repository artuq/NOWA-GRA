# Epic: Action UI

> **Layer**: Presentation
> **GDD**: design/gdd/action-ui.md
> **Architecture Module**: ActionScreen (3 sibling Control scripts per ADR-0007: ResourceHud, ActionGrid, RunningActionOverlay)
> **Status**: Ready (stories will be Blocked pending ADR-0007 acceptance)
> **Stories**: Not yet created — run `/create-stories action-ui`

## Overview

Implements Action UI — the game's primary screen, where the select-and-wait core loop becomes touchable. Three Control-node zones (Resource HUD, Action Grid, Running Action Overlay) each consume `ResourceManager`/`ActionSystem` directly per ADR-0007's no-central-bus, no-presenter-layer decision: the Resource HUD reacts to `resource_changed`, the Action Grid wires button taps to `start_action()` and reacts to `action_completed`, and the Running Action Overlay is the sole `_process()`-driven zone, polling `get_progress()` only while an action is active. This is the first Presentation-layer epic in the project — the first real scene/UI work, following 5 sprints of Foundation/Core backend.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0007: Action UI scene structure and Autoload binding pattern | 3 sibling Control scripts, one per GDD zone, no central event bus, no mediating presenter — **Status: Proposed, not yet Accepted** | MEDIUM |
| ADR-0001: Autoload singleton architecture | Direct-call/signal split, applied here at the Presentation layer for the first time | LOW |
| ADR-0004: Action System timer/concurrency | `get_progress()` polling contract, scoped by ADR-0007 to exactly the Running Action Overlay zone | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-aui-001 | Progress bar updates every frame via cheap poll, not throttled | ADR-0004 ✅ (partial — see ADR-0007 for the zone-scoping extension) |

**Note**: the GDD has substantially more acceptance criteria (3-zone layout, button enable/disable, number formatting boundaries, defined edge cases) than the TR registry has entries for — only TR-aui-001 is currently registered. This is a registry-completeness gap, not an ADR gap; stories will reference the GDD's Acceptance Criteria section directly where no TR-ID exists yet.

## Definition of Done

This epic is complete when:
- ADR-0007 is Accepted (via `/architecture-review` run in a fresh session — not this one)
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/action-ui.md` are verified
- The Logic-classified pieces (number formatting, progress-bar fill_ratio — see `production/qa/qa-plan-sprint-6-2026-06-24.md`) have passing test files in `tests/`
- The UI-classified pieces (layout, slot state, button enable/disable) have an evidence doc with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories action-ui` to break this epic into implementable stories. Stories will be marked `Status: Blocked` until ADR-0007 is Accepted.
