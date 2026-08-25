# ADR-0022: Sponsor Career Contract State and Scheduling

**Status:** Accepted

**Date:** 2026-08-13

## Context

The game needs multi-card narrative memory without turning the static Card
Content Database into a quest engine or allowing scripted cards to leak into
weighted RNG. The existing priority injection is reserved for immediate,
single-concurrency Burnout cards and has no queue or persistence.

## Decision

Add a focused `SponsorContractSystem` Autoload below DecisionCardSystem. It
subscribes to stable `card_resolved` and `action_completed` signals, owns the
small persisted state machine, and exposes `get_due_card_id()` plus an immutable
HUD snapshot. DecisionCardSystem checks this due id only in the production
pool path, before normal selection. Contract cards remain `never` eligible.

SaveSystem and BootController restore the module through the standard
`serialize_state`/`restore_state` protocol. The HUD listens to a typed
`contract_changed(Dictionary)` signal and performs no polling or mutations.

## Consequences

- Branch memory and cadence survive process death with a tiny save block.
- Existing weighted tests retain their override isolation.
- Priority Burnout remains higher-level concurrency: a contract is only drawn
  from the normal cooldown check after the current card returns to cooldown.
- This is deliberately not a general quest graph. A second independent chain
  should trigger review for a reusable narrative scheduler.
