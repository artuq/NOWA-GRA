# Epic: Card UI

> **Layer**: Presentation
> **GDD**: design/gdd/card-ui.md
> **Architecture Module**: CardScreen (full-screen modal Control + CardSwipeMath static utility, per ADR-0008)
> **Status**: Ready
> **Stories**: 3 stories created — see table below

## Overview

Implements Card UI — the full-screen modal swipe-to-decide screen that finally surfaces `DecisionCardSystem`'s already-complete backend (cooldown, weighted selection, resolution) in actual play. A card appears when `DecisionCardSystem` enters `PRESENTING` (via the new `card_presented` signal, ADR-0008), the player drags it left/right with a 1:1 finger-tracking preview and a slight tilt, and a commitment threshold (≥30% screen width OR ≥800px/s flick velocity) confirms the choice — calling `DecisionCardSystem.resolve_choice()`. The modal blocks the Resource HUD / Action Grid beneath it while shown and releases them once hidden. This is the project's first modal and first touch-gesture UI.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008: Card UI modal, swipe gesture, DecisionCardSystem integration | `card_presented` signal as entry trigger; full-rect `mouse_filter=STOP` modal over ActionScreen; swipe math (rotation ±12°, commitment ≥30%/≥800px-s) in stateless `CardSwipeMath`, gesture state machine in `card_screen.gd` | MEDIUM |
| ADR-0007: Action UI scene structure and Autoload binding | UI zone = Control scene consuming Autoloads directly; precedent this extends to a modal + gesture context | LOW |
| ADR-0001: Autoload singleton architecture | Direct-call/signal consume pattern; `resolve_choice()` is the ownership-clear write Card UI calls on commit | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-cui-001 | Swipe/drag modal card presentation with commitment threshold | ADR-0008 ✅ |

**Note**: the GDD has substantially more acceptance criteria (state machine, rotation/commitment formulas, bounce-back, multi-touch rejection, defined edge cases) than the single registered TR-ID — stories reference the GDD's Acceptance Criteria section directly where no dedicated TR-ID exists (same registry-completeness gap noted for Action UI; not blocking).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/card-ui.md` are verified
- The Logic-classified swipe math (rotation + commitment formulas) has a passing unit test in `tests/`
- The UI/Integration-classified pieces (modal, gesture state machine, DecisionCardSystem wiring) have interaction-test evidence via GdUnit4 `scene_runner()` (the standing UI-evidence method, per Action UI's precedent)
- **Explicit design-direction confirmation with the user before any Card UI scene file is created** (carried from Sprint 7's DoD and the collaborative-design lesson from the Action UI redesign) — the card's visual appearance and swipe feedback look are confirmed, not freelanced

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Card Swipe Math | Logic | Ready | N/A (pure utility, structure per ADR-0008) |
| 002 | Card Screen Modal & Resolution | Integration | Ready | ADR-0008, ADR-0001 |
| 003 | Swipe Gesture Interaction | UI | Ready | ADR-0008 |

**Build order**: 001 (math) and 002 (modal shell) are independent and can be done in either order; 003 (gesture) depends on both. Story 002 is the playability win on its own (cards appear and resolve via a method seam); 003 adds the swipe feel.

**Design-direction reminder**: per this epic's DoD, confirm the card's visual appearance + swipe-feedback look with the user before creating `card_screen.tscn` (Story 002) — do not freelance the visuals (lesson carried from the Action UI redesign).

## Next Step

Run `/story-readiness production/epics/card-ui/story-001-card-swipe-math.md` then `/dev-story` to begin implementation.
