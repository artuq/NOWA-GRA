# Epic: Decision Card System

> **Layer**: Core
> **GDD**: design/gdd/decision-card-system.md
> **Architecture Module**: DecisionCardSystem
> **Status**: Complete
> **Stories**: 3 stories created — see table below

## Overview

Implements the `DecisionCardSystem` Autoload — weighted-random card selection
scaled by current Cringe (`magnitude`/`card_selection_weight` formula family),
an action-count cooldown (int counter, not a Timer) decremented on
`ActionSystem.action_completed`, and `force_cooldown_zero()` (called only by
`OnboardingGate`). Owns a per-instance `RandomNumberGenerator` with a
`set_seed()` test hook for deterministic testing. Reads card data from Card
Content Database and resource state from Resource Manager; resolves choices by
applying deltas and recording the choice in History Flag Manager.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Autoload singleton architecture | `DecisionCardSystem` is an Autoload; consumes `ActionSystem.action_completed` per the locked signal contract | LOW |
| ADR-0005: Decision Card weighting and cooldown implementation | int-counter cooldown (not Timer); per-instance RNG; force_cooldown_zero() called only by OnboardingGate | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-dcs-001 | Weighted-random pick scaled by current Cringe | ADR-0005 ✅ |
| TR-dcs-002 | Cooldown counted in completed actions (not time), default 2 | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/decision-card-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Cooldown Mechanism & Pool Eligibility | Logic | Complete | ADR-0005, ADR-0001 |
| 002 | Weighted Card Selection Formula | Logic | Complete | ADR-0005, ADR-0001 |
| 003 | Card Presentation & Resolution | Integration | Complete | ADR-0005, ADR-0001 |

**Note**: ADR-0005's Implementation Guidelines pseudocode is stale relative to what's actually built (assumes Resource-object cards with `.intensity`/`.id`, a `HistoryFlagManager.record_choice()` method, and `OnboardingGate.is_card_suppressed()` — none of which exist). All 3 stories implement against the real `Dictionary`-based `CardContentDatabase` API and `HistoryFlagManager`'s actual `set_milestone()`/`increment_counter()` methods instead. `OnboardingGate` integration is explicitly out of scope (zero GDD acceptance criteria reference it) — deferred to a future story once that epic exists.

## Next Step

Epic complete. Card UI (future epic) can now call `DecisionCardSystem.resolve_choice()`; Class Path System (future Vertical Slice epic) can rely on the `risky_choices_count`/`safe_choices_count` writes this epic produces.
