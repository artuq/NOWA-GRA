# Epic: Class Path System (Full — VS/Alpha delta)

> **Layer**: Core
> **GDD**: design/gdd/class-path-system.md
> **Architecture Module**: ClassPathSystem (Autoload #9, existing — extended, not replaced)
> **Status**: Ready
> **Stories**: 5 stories

## Overview

The MVP epic (`production/epics/class-path/`) shipped 2 of 4 paths, Tiers 1-2, card-contribution only, HUD indicator — and is Complete. This epic covers the remaining full-GDD scope: registering the other 2 paths and Tiers 3-5, implementing the active investment mechanic (gated on prior card-choice history per Core Rule 4a), fixing BUG-003 (the shipped tie-break logic silently picks a winner by iteration order instead of resolving to "ambiguous"), and wiring Tier-5 signature cards into the Decision Card pool via a pull-model trigger-condition grammar entry — no new pool-mutation API. All four additions are additive/data-driven extensions of the existing ClassPathSystem Autoload; none introduce a new module or a new dependency direction.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010 §8 | `invest()` goes live, gated on `card_contribution[path] > 0`; requires splitting `_recalculate_affiliation()` into tracked F1/F2 terms | LOW |
| ADR-0010 §9 | `_update_active_path()` fixed to a top-two-candidate margin comparison (BUG-003) | LOW |
| ADR-0010 §10 | Signature cards via additive `trigger_condition` grammar (`class_path_tier:{path_id}:{min_tier}`) on DecisionCardSystem — pull model, no pool-mutation API | LOW |
| ADR-0010 §11 | 4-path / Tier 1-5 `_MULTIPLIER_TABLE` expansion — pure data growth | LOW |
| ADR-0001 / ADR-0003 | Autoload + restore_state() patterns (unchanged, inherited from MVP epic) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-cps-005 | `reset_era_state()` resets era-local state, preserves meta milestone flags | ADR-0010 ⚠️ partial — API exists and is implemented; BurnoutSystem `era_transitioned` wiring deferred to Alpha BurnoutSystem epic |
| TR-cps-006 | Tier-5 signature card add/remove to Decision Card pool | ADR-0010 §10 ✅ |
| TR-cps-007 | Path multipliers excluded from offline progress by default | ADR-0006 + ADR-0010 ⚠️ partial — structurally true (OfflineProgressSystem never calls `get_active_multiplier`), no dedicated story needed here |
| TR-cps-008 | F2 Investment Contribution, gated by Core Rule 4a | ADR-0010 §8 ✅ |
| TR-cps-009 | F5 Tie-Break Resolution — BUG-003 regression fix | ADR-0010 §9 ✅ |
| TR-cps-010 | 4-path registration, Tiers 3-5 bonus table | ADR-0010 §11 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria in `design/gdd/class-path-system.md` §Acceptance Criteria are verified (Investment, Tie-Break/BUG-003, Signature Cards, Era Reset sections)
- BUG-003 (`production/qa/bugs/BUG-003-class-path-no-tiebreak-logic.md`) is closed
- `class_path_core_test.gd` (25 existing MVP tests) stays green after the F1/F2 split refactor
- All Logic and Integration stories have passing test files in `tests/`
- 4 signature cards exist in `card_content_database.gd`, each gated on its path's Tier-5 `trigger_condition`

## Out of Scope (belongs to other epics)

- BurnoutSystem `era_transitioned` → `reset_era_state()` wiring — Alpha BurnoutSystem epic (Sprint 11, Prestige/Checkpoint System dependency)
- Sponsor multiplier consumption at card resolution (`get_active_sponsor_multiplier()`, ADR-0010 §5a) — belongs to whichever epic implements Sponsor-granting card resolution, not this one
- Class Path Panel expanded UI view (investment button UI, ambiguous-gap display) — companion UI story likely needed in the same epic once `/create-stories` runs; flagged here for story decomposition, not pre-decided

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 4-Path Registration + Tier 3-5 Expansion | Logic | Complete | ADR-0010 §11 |
| 002 | Investment Contribution (F2, Core Rule 4a) | Logic | Complete | ADR-0010 §8 |
| 003 | Tie-Break Resolution Fix (F5, BUG-003) | Logic | Complete | ADR-0010 §9 |
| 004 | Signature Card Wiring (Tier 5) | Integration | Complete | ADR-0010 §10 |
| 005 | Class Path Panel — Investment & Ambiguity UI | UI | Ready | ADR-0010 §8/§9 (secondary) |

## Next Step

Run `/story-readiness production/epics/class-path-full/story-001-4-path-tier-expansion.md` then `/dev-story` to begin implementation.
