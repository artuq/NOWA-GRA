# Epic: Class Path System

> **Layer**: Core
> **Quick-spec**: design/quick-specs/class-path-system-2026-07-01.md
> **Architecture Module**: ClassPathSystem (Autoload #9)
> **Status**: Complete (MVP scope, 2026-07-05)
> **Stories**: 2 stories

## Overview

Class Path System gives the player a visible identity layer from minute 1. Four satirical influencer archetypes (Pato-Streamer Hazardowy, Guru-Celebryta, Ekspert Niszowy, Biznesmen Contentu) are shown at all times. As the player makes card choices tagged to a path, their affiliation increases — reaching tier thresholds (20/40/60/80/100) unlocks path-specific multipliers. A persistent HUD indicator shows the active path once Tier 1 is reached. Sprint 8 targets the **MVP subset**: 2 paths, Tier 1–2 bonuses, HUD only, card-contribution only (no active investment). Full 4-path, Tier 1–5, investment UI, and era meta-bonuses are Vertical Slice / Alpha scope.

ClassPathSystem is implemented as an Autoload singleton (Autoload #9, below DecisionCardSystem) per ADR-0001. It owns affiliation floats and tier state, subscribes to `DecisionCardSystem.card_resolved` for affiliation re-evaluation, and exposes `get_active_multiplier(action_id)` as a pull-model query for ActionSystem. SaveSystem integration uses the ADR-0003 `restore_state()` protocol.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Autoload Singleton Architecture | All Core modules = Autoload singletons; signals for multi-subscriber events, direct calls for ownership-clear writes | LOW |
| ADR-0003: Scene Management and Boot Order | `restore_state(data: Dictionary)` called by BootController for all modules with persisted state | LOW |
| ADR-0010: Class Path System Architecture | ClassPathSystem Autoload + additive `card_resolved` signal on DecisionCardSystem + pull-model multiplier + era reset API | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-cps-001 | ClassPathSystem Autoload owns affiliation floats [0-100], tier ints [0-5], and active path resolution | ADR-0010 ✅ |
| TR-cps-002 | Card resolution drives path counter increment and affiliation recalc via additive `card_resolved` signal on DecisionCardSystem | ADR-0010 ✅ |
| TR-cps-003 | ActionSystem applies path tier multiplier via pull-model `get_active_multiplier(action_id)` — no ClassPathSystem→ActionSystem dependency | ADR-0010 ✅ |
| TR-cps-004 | ClassPathSystem save/restore of affiliation and tier via `restore_state(data)` per ADR-0003 boot protocol | ADR-0010 ✅ |
| TR-cps-005 | `reset_era_state()` resets era-local affiliation/tier/counters, preserves meta milestone flags | ADR-0010 ⚠️ partial — API defined; BurnoutSystem `era_transitioned` wiring deferred to Alpha |
| TR-cps-006 | Tier-5 signature card add/remove to DecisionCardSystem pool | ❌ No ADR — Alpha scope; stories for this requirement will be Blocked |
| TR-cps-007 | Path multipliers excluded from offline progress by default (Pillar 4); `PATH_MULTIPLIER_OFFLINE` flag off by default | ADR-0006 + ADR-0010 ⚠️ partial — offline exclusion is structural (OfflineProgressSystem never calls `get_active_multiplier`); no dedicated story needed |

## MVP Scope (Sprint 8)

Stories in this sprint target the MVP subset only:
- **2 paths** (pato_streamer, guru_celebryta) — HistoryFlagManager stub already supports 2-path resolution
- **Tier 1–2 bonuses** only
- **HUD indicator** only (no Class Path Panel)
- **Card contributions** only (no active investment mechanic)
- `path_tag` field added to card data schema (all 12 cards)
- `card_resolved` signal added to DecisionCardSystem (additive)

Vertical Slice / Alpha additions:
- Full 4-path registration
- Tier 3–5 + signature cards (TR-cps-006, requires follow-up ADR)
- Active investment UI (invest button, affiliation cost per resource)
- Class Path Panel (expanded path view)
- Era meta-bonuses (BurnoutSystem wiring)

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/quick-specs/class-path-system-2026-07-01.md` (MVP scope) are verified
- All Logic and Integration stories have passing test files in `tests/`
- UI stories have evidence docs in `production/qa/evidence/`
- ClassPathSystem Autoload registered as #9 in Project Settings → Autoload

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Class Path Core | Logic | Complete | ADR-0010 (primary), ADR-0001, ADR-0003 |
| 002 | Class Path HUD Indicator | UI | Complete | ADR-0010 (primary), ADR-0007 |

## Next Step

Run `/story-readiness production/epics/class-path/story-001-class-path-core.md` then `/dev-story` to begin implementation.
