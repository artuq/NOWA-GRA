# Epic: Prestige/Checkpoint System

> **Layer**: Core (Progression)
> **GDD**: design/gdd/prestige-checkpoint-system.md
> **Architecture Module**: PrestigeSystem (new Autoload)
> **Status**: Ready
> **Stories**: 9 stories (all Ready — ADR-0012 Accepted 2026-07-14)

## Overview

Meta-progression layer sitting on top of two already-locked sub-specs: BurnoutSystem (forced "Wypalenie" card on sustained Cringe=100, Accept/Defer-once) and ChallengeSystem (optional era-start difficulty picker). This GDD's own new scope is narrower than those two: a permanent, path-typed META_BONUS granted on accepted burnout, the era-local vs meta-persistent flag classification every other system's reset logic depends on, and `DecisionCardSystem.inject_priority_card()`. `PrestigeSystem` (new Autoload, ADR-0012) is the single orchestrator: reads Class Path state before it's cleared, triggers the reset, computes and grants the bonus, sweeps flags, saves, then signals. The read-then-reset sequence has a hard same-frame, no-signal, no-await constraint — this is the highest ordering-risk system built so far.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0012 | New `PrestigeSystem` Autoload; synchronous `on_burnout_accepted()` orchestration; `PrestigeFormulas` stateless static methods; `inject_priority_card()` on DecisionCardSystem | LOW |
| ADR-0002 §Autosave suppression | `suppress_autosave()`/`resume_autosave()` bracket the era-transitioning window | LOW |
| ADR-0010 | `PrestigeSystem` is a hard caller of `ClassPathSystem.get_active_path()`/`get_tier()`/`reset_era_state()` | LOW |
| ADR-0001 / ADR-0003 | Autoload + `restore_state()` patterns (inherited) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-pcs-001 | `PrestigeSystem` orchestrates era transition via single synchronous entry point | ADR-0012 ✅ |
| TR-pcs-002 | F1/F1b/F2/F3a-d META_BONUS formulas, independently testable | ADR-0012 ✅ |
| TR-pcs-003 | `inject_priority_card()` — general-purpose forced-card injection | ADR-0012 ✅ |
| TR-pcs-004 | Flag classification sweep (era-local vs meta-persistent) | ADR-0012 ✅ |
| TR-pcs-005 | Save/restore of `era_count`, per-type totals, meta flags | ADR-0012 ✅ |
| TR-pcs-006 | Autosave suppressed for era-transitioning window only | ADR-0002 + ADR-0012 ✅ |
| TR-pcs-007 | BurnoutSystem / ChallengeSystem core mechanics themselves | ❌ No ADR — their own quick-specs are locked but never got an architecture pass. Stories touching Burnout's threshold/warning/defer logic or Challenge's picker/multiplier logic are Blocked until a follow-up ADR exists; stories touching only `PrestigeSystem`'s consumption of their outputs (`get_combined_meta_multiplier()`, Choice A trigger) are not blocked. |

## Definition of Done

This epic is complete when:
- All non-Blocked stories are implemented, reviewed, and closed via `/story-done`
- Acceptance Criteria in `design/gdd/prestige-checkpoint-system.md` are verified for: META_BONUS Grant Magnitude (F1), Variety Bonus (F1b), Stacking/Caps (F2), Bonus Type Selection, Critical Ordering (read-before-reset), F3a-d application points, Flag Classification Sweep, Transition Atomicity, `inject_priority_card()` contract
- The static `await`/`CONNECT_DEFERRED` check (ADR-0012 Validation Criteria) passes across the full `on_burnout_accepted()` call graph
- `PrestigeSystem` registered as Autoload below `ClassPathSystem`, `DecisionCardSystem`, `SaveSystem`, `HistoryFlagManager` in `project.godot`

## Out of Scope (belongs to other epics)

- BurnoutSystem/ChallengeSystem's own core mechanics (threshold detection, warning countdown, difficulty picker UI, ratio multipliers) — Blocked pending TR-pcs-007's ADR
- Class Path Panel era-summary display of `best_tier_reached`/`eras_spent_as` — UI polish, not required for this epic's DoD
- Team/Staff Management Sponsor sink (Alpha, systems-index #15) — this epic ships `META_SPONSOR_MULT`/`META_SPONSOR_FLOOR` with a known zero-sink gap, accepted for Vertical Slice per Dependencies

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | PrestigeSystem Orchestration Core | Integration | Complete | ADR-0012 §1-2 |
| 002 | inject_priority_card() Contract | Integration | Complete | ADR-0012 §4 |
| 003 | META_BONUS Grant Magnitude + Variety Bonus (F1/F1b) | Logic | Ready | ADR-0012 §3 |
| 004 | META_BONUS Stacking/Caps + Bonus Type Selection (F2) | Logic | Ready | ADR-0012 §3 |
| 005 | F3a-d Final Reward Stacking Application Points | Logic | Ready | ADR-0012 §3, ADR-0010 §5a |
| 006 | Choice B (Defer) — Morale Floor, No Grant | Logic | Ready | ADR-0012 §2 |
| 007 | Flag Classification Sweep (Core Rule 7) | Integration | Ready | ADR-0012 §5 |
| 008 | Transition Atomicity | Integration | Ready | ADR-0012 §2, ADR-0002 |
| 009 | Misconfiguration Guard + Save Migration | Logic | Ready | ADR-0012 §6 |

## Next Step

ADR-0012 Accepted (2026-07-14, independent `/architecture-review`, verdict CONCERNS overall but no conflicts against this ADR). All 9 stories are Ready. Start with Story 001 (PrestigeSystem Orchestration Core) — everything else in this epic depends on it directly or transitively.
