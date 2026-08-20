# Quick Design Spec: Live Resource Loop and Sponsor Shield UI

**Type**: Completion + Addition
**System**: Resource System + Save/Persistence System + Action UI
**GDD Reference**: `design/gdd/resource-system.md`, `design/gdd/offline-progress-system.md`, `design/gdd/save-persistence-system.md`
**Date**: 2026-08-05

## Change Summary

Complete the time-based resource loop during active play and expose the already
designed Sponsor Shield to the player. While `ActionScreen` exists, a fixed
one-second logical tick advances Haters, ambient Morale drain, and passive
Reach using the same stateless transition used by the offline simulation.

No balance constants or formulas change. This spec connects the existing
Formula A/B/D design to live play and makes the existing Sponsor cost, duration,
stacking, and buffer bonus visible and usable.

## Motivation

The current active screen changes resources only when an action or card
resolves. Formula A/B/D already define a continuous chain, but that chain only
runs at cold-start through offline simulation. As a result, the game feels
static between actions, `META_HATERS_RESIST` has no live effect, and Sponsor
Shield cannot be activated anywhere in production UI.

The live loop adds readable motion to the core economy without adding another
mechanic. Sponsor Shield then becomes a meaningful, visible decision: spend
five Sponsors now to protect Morale, or keep them for Staff and path investment.

## Design Delta

### Shared simulation step

One pure transition owns the exact order:

1. `H1 = H0 + final_haters_rate(Cringe) * dt_minutes`
2. `M1 = max(effective_floor, M0 - morale_drain_rate(int(H1), buffer) * dt_minutes)`
3. `mult = action_effectiveness_multiplier(M1)`
4. `Reach_gain = passive_zasiegi_income(H1, mult, dt_seconds)`

The transition keeps resource state as `float`. The existing `int(H1)` inside
Formula B remains the only intentional truncation. A Morale floor prevents
ambient drain from crossing the floor but never raises Morale that was already
below it.

### Live lifecycle and modifiers

- `LiveResourceTicker` is a child `Node` of `ActionScreen`, not an Autoload.
- It accumulates frame deltas and executes complete 1.0-second logical steps.
- Leaving `ActionScreen` destroys the ticker; boot, start, offline report, and
  challenge selection accrue no live time.
- Live Haters use Class Path ambient growth, Staff Troll, and
  `META_HATERS_RESIST`.
- Live Morale uses Class Path ambient drain/floor and the current Sponsor Shield
  buffer.
- Staff Assistant remains offline-only. Challenge modifiers,
  `META_REACH_MULT`, and action reward multipliers never affect passive Reach.
- Offline simulation retains 60-second steps and the 24-hour cap, but calls the
  same pure transition.

### Sponsor Shield presentation

- A persistent compact control sits with the Resource HUD.
- Inactive state shows the 3-to-8 Haters buffer, five-minute duration, and exact
  cost (`5 Sponsors`).
- Active state shows a `ceil`-based countdown and offers additive `+5:00`
  extension. Durations of one hour or more render as `H:MM:SS`.
- The button remains visible when unaffordable, is disabled, and states the
  exact number of missing Sponsors.
- Every successful activation or extension emits refreshed shield state.
- Offline elapsed time consumes the persisted shield timer using the real
  elapsed duration, even when resource simulation itself is capped at 24 hours.

### Persistence and feedback

- Ambient ticks use the existing resource mutation funnel with an explicit
  ambient context.
- The existing two-second trailing autosave remains unchanged for ordinary
  changes. Continuous ambient changes also start a non-restarting ten-second
  checkpoint so repeated one-second ticks cannot postpone persistence forever.
- Application pause flushes either pending timer immediately.
- Resource HUD labels update on ambient changes, but ambient ticks do not start
  pop, count-up, or flash effects. Action-completion feedback is unchanged.
- `RunningActionOverlay` is presentation-only and ignores pointer input on its
  entire subtree, so actions and Shield remain tappable while an action runs.

## Tuning Knobs

| Knob | Value | Source |
|------|-------|--------|
| Live logical step | 1.0 s | This spec; responsiveness, no formula change |
| Continuous save checkpoint | 10.0 s | This spec; bounds unsaved live progress |
| Shield cost | 5 Sponsors | Existing Sponsor Shield spec |
| Shield duration | 300 s per purchase | Existing Sponsor Shield spec |
| Shield buffer bonus | +5 Haters (3 to 8) | Existing Sponsor Shield spec |
| Offline logical step | 60 s | Existing Offline Progress GDD; unchanged |

## Acceptance Criteria

- [x] `ActionScreen` advances Haters, Morale, and passive Reach once per complete
  logical second; fractional frame time is retained.
- [x] The live and offline paths call one pure Haters-to-Morale-to-Reach step.
- [x] No resource is rounded in storage, and a Class Path Morale floor never
  raises an already-lower value.
- [x] Live modifiers include Class Path ambient effects, Troll, Shield, and
  `META_HATERS_RESIST`; exclude Assistant, Challenges, and `META_REACH_MULT`.
- [x] No live accrual occurs when `ActionScreen` is absent.
- [x] Continuous one-second mutations save no later than the fixed checkpoint,
  while ordinary two-second trailing debounce behavior remains unchanged.
- [x] Ambient ticks update HUD text without pop/count-up/flash; action feedback
  remains unchanged and reconciles to the latest resource value.
- [x] Sponsor Shield can be bought and extended from the HUD, always displays
  its exact cost/status, and exposes an accessible touch target of at least
  44x44 px.
- [x] Offline elapsed time is removed from Shield remaining time, including
  elapsed time beyond the 24-hour resource-simulation cap.
- [x] `RunningActionOverlay` never consumes pointer input.
- [x] Existing offline worked-example values and all balance constants remain
  unchanged within their current tolerances.

## GDD and Architecture Update Required?

Yes. Synchronize the Resource, Offline Progress, Save/Persistence, and Class
Path GDDs; amend ADR-0006 and ADR-0007; record the live child and persistence
flow in `architecture.md` and `control-manifest.md`; close the corresponding
entry in `docs/tech-debt-register.md` after verification.
