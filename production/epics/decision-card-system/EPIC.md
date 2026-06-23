# Epic: Decision Card System

> **Layer**: Core
> **GDD**: design/gdd/decision-card-system.md
> **Architecture Module**: DecisionCardSystem
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories decision-card-system`

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

## Next Step

Run `/create-stories decision-card-system` to break this epic into implementable stories.
