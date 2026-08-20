# ADR-0020: ActionScreen-Scoped Live Resource Ticker and Shared Simulation Step

## Status

Accepted (2026-08-05)

## Context

Formula A/B/D define time-based Haters growth, ambient Morale drain, and
passive Reach for active and offline play. The shipped implementation executed
that chain only in `OfflineProgressSystem`, leaving active play static between
action/card resolutions and leaving Sponsor Shield without a production UI.

A live one-second mutation cadence also exposes two integration risks: the
existing two-second trailing autosave can be postponed forever, and generic
`resource_changed` juice would pulse the HUD continuously.

## Decision

1. `ResourceSimulationStep` is a stateless `RefCounted` utility. Its explicit
   inputs produce `{final_H, final_M, reach_gained}` in the fixed order
   Haters → Morale → effectiveness multiplier → Reach. It reads no Autoloads
   and stores no state.
2. `OfflineProgressSystem` retains its 60-second steps and 24-hour cap but calls
   `ResourceSimulationStep` for every step.
3. `LiveResourceTicker` is a plain `Node` directly under `ActionScreen`, not an
   Autoload. It accumulates frame delta, executes complete 1.0-second logical
   steps, preserves the remainder, and commits one ambient batch per frame.
   Scene ownership prevents accrual during boot, start, offline-report, and
   challenge-selection screens.
4. Live modifiers are Class Path ambient growth/drain/floor, Staff Troll,
   Sponsor Shield buffer, and `META_HATERS_RESIST`. Staff Assistant remains
   offline-only; Challenge modifiers, `META_REACH_MULT`, and action reward
   modifiers do not affect Formula D.
5. `ResourceManager.apply_ambient_delta()` delegates to the same clamping and
   signal funnel as `apply_delta()`. A synchronous ambient-context flag lets
   `ResourceHud` update text without pop/count-up/flash.
6. `SaveSystem.mark_dirty()` keeps its two-second trailing edge and starts a
   second one-shot 10-second maximum dirty-age Timer only on the first dirty
   event. `save_now()` and lifecycle flush stop both schedules.
7. Sponsor Shield is presented inside the Resource HUD. Every successful
   activation/extension emits `shield_changed`; `BootController` removes the
   full real offline elapsed duration from the persisted timer after using its
   protected simulation segment.

No existing balance constant changes.

## Consequences

- Online and offline sequencing cannot drift because only cadence differs.
- Live play becomes visibly active at one-second resolution without constant
  HUD animation or one save write per second.
- The ticker has no manual enable/disable gate to forget; scene lifetime is the
  gate.
- Online and offline results over a long interval are not bit-identical because
  their integration steps intentionally remain 1 s and 60 s respectively.

## Validation

- Unit contracts cover order, factors, float preservation, and Morale floor.
- Integration contracts cover accumulator/hitch behavior, modifier inclusion
  and exclusion, ActionScreen ownership, Shield UI/offline elapsed time,
  ambient HUD behavior, pointer passthrough, and autosave maximum age.
- Existing 24-hour offline worked-example regression remains unchanged.

## Related Decisions

- ADR-0002 — atomic save and autosave timing.
- ADR-0006 — offline fixed-step simulation.
- ADR-0007 — ActionScreen scene ownership and direct Autoload binding.
- `design/quick-specs/live-resource-loop-and-sponsor-shield-ui-2026-08-05.md`.
