# Epic: Burnout & Challenge System

> **Layer**: Core
> **GDD**: design/gdd/prestige-checkpoint-system.md (system #17 parent) + design/quick-specs/final-burnout-2026-07-01.md + design/quick-specs/challenge-era-runs-2026-07-01.md
> **Architecture Module**: BurnoutSystem (new Autoload), ChallengeSystem (new Autoload)
> **Status**: Ready
> **Stories**: 8 stories created (2026-07-17)

## Overview

The trigger-and-selection layer that sits directly above `PrestigeSystem` (ADR-0012, shipped and
closed — prestige-checkpoint epic, 9/9 stories). `BurnoutSystem` is a thin Autoload that tracks
sustained Cringe=100 in live play, emits a warning countdown, and force-injects the mandatory
"Wypalenie" Decision Card via the already-shipped `DecisionCardSystem.inject_priority_card()`
(Story 002). The player's Accept/Defer choice routes synchronously into
`PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()` — BurnoutSystem owns none of the
reset/grant machinery, only the trigger and the card. `ChallengeSystem` is a separate Autoload
owning the optional era-start Challenge Selection screen: 0-N ratio-multiplier modifiers the
player chooses to make the incoming era harder in exchange for a larger meta-bonus on the next
accepted burnout, consumed by `PrestigeSystem` via a pull-model getter
(`get_combined_meta_multiplier()`) and by `ActionSystem` at reward resolution
(`get_modifier(action_id, axis)`).

This epic does not touch `PrestigeSystem`'s already-shipped, tested code beyond one line (the
`challenge_mult` stub → a real `ChallengeSystem` call) — see ADR-0013 for the full ownership
split and why the prestige-checkpoint epic was not reopened.

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Trigger Detection — Sustained Cringe Timer + Warning Countdown | Logic | Complete | ADR-0013 |
| 002 | Forced Card Injection with Guard Rails | Integration | Complete | ADR-0013 |
| 003 | Choice Routing into PrestigeSystem | Integration | Complete | ADR-0013 + ADR-0012 |
| 004 | BurnoutSystem Persistence | Logic | Complete | ADR-0013 + ADR-0003 |
| 005 | Challenge Catalogue + Selection Storage | Logic | Complete | ADR-0013 |
| 006 | Modifier Application at Reward Resolution | Integration | Ready | ADR-0013 |
| 007 | Meta-Bonus Multiplier Pull into PrestigeSystem | Integration | Ready | ADR-0013 + ADR-0012 |
| 008 | Era-Local Challenge Reset Wiring | Integration | Ready | ADR-0013 + ADR-0012 |

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0013 | New `BurnoutSystem`/`ChallengeSystem` Autoloads; BurnoutSystem = trigger detector + forced card only; ChallengeSystem = selection + pull-model modifier getters; both route into `PrestigeSystem`'s existing entry points, never own its state | LOW |
| ADR-0012 | `PrestigeSystem.on_burnout_accepted()`/`on_burnout_deferred()` are the locked entry points this epic calls into (dependency, not owned by this epic) | LOW |
| ADR-0010 | `get_combined_meta_multiplier()`/`get_modifier()` follow the pull-model getter precedent (`get_active_sponsor_multiplier()`) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-pcs-007 | BurnoutSystem trigger detection, forced card injection, Choice A/B routing; ChallengeSystem selection, modifier storage/stacking, application at reward resolution | ADR-0013 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- Acceptance Criteria in `design/quick-specs/final-burnout-2026-07-01.md` and
  `design/quick-specs/challenge-era-runs-2026-07-01.md` are verified, adjusted per ADR-0013's
  ownership-split table where the quick-specs' original assumptions were superseded
- The two BLOCKING risks ADR-0013 identified during validation are covered by tests:
  `inject_priority_card()`'s `bool` return is checked (no soft-lock on a misconfigured
  `BURNOUT_CARD_ID`), and injection is guarded on `DecisionCardSystem.state == COOLDOWN` (no
  clobbering an in-progress normal card)
- `BurnoutSystem` registered in `project.godot` strictly after `DecisionCardSystem` (ADR-0013
  Ordering Note)
- All Logic and Integration stories have passing test files in `tests/`

## Out of Scope (belongs to other epics)

- `PrestigeSystem`'s reset/grant/sweep machinery itself — already shipped, prestige-checkpoint epic (Complete)
- Challenge Selection screen's visual/UX design — separate UI story once this epic's data layer exists
- Warning countdown HUD display — separate UI story, same pattern as `shield_changed`

## Next Step

Run `/create-stories burnout-challenge-system` to break this epic into implementable stories.
