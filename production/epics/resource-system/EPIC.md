# Epic: Resource System

> **Layer**: Foundation
> **GDD**: design/gdd/resource-system.md
> **Architecture Module**: ResourceManager
> **Status**: Ready
> **Stories**: 7 stories created

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Core Resource Mutation & Clamping | Logic | Ready | ADR-0001 |
| 002 | Hatersi Passive Growth Rate (Formula A) | Logic | Ready | ADR-0006 |
| 003 | Morale Drain Rate (Formula B) | Logic | Ready | ADR-0006 |
| 004 | Action Effectiveness Multiplier Lookup (Formula C) | Logic | Ready | ADR-0006 |
| 005 | Passive Zasięgi/Reach Income (Formula D) | Logic | Ready | ADR-0006 |
| 006 | Cringe Delta Clamping (Formula E) | Logic | Ready | ADR-0001 |
| 007 | Sponsorzy/Sponsors Acquisition (Placeholder) | Config/Data | Ready | N/A |

## Overview

Implements the `ResourceManager` Autoload that owns the 5 currencies (Zasięgi/Reach,
Cringe, Hatersi/Haters, Morale, Sponsorzy/Sponsors) referenced by every other Core
and Feature system. Provides `get_resource()`/`apply_delta()` with internal
clamping for Cringe/Morale to [0,100], Morale band lookup, and the shared
`ResourceFormulas` static utility class (haters_growth_rate, morale_drain_rate,
action_effectiveness_multiplier, passive_zasiegi_income) used identically by both
live-play (Action System) and offline simulation (Offline Progress System) call
sites, guaranteeing the two contexts can never silently diverge.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Autoload singleton architecture | `ResourceManager` is an Autoload; direct calls for ownership-clear writes | LOW |
| ADR-0006: Offline simulation loop | `ResourceFormulas` stateless static utility, shared by live/offline call sites | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-res-001 | Resource mutations traceable to trigger; formulas shared between live play and offline | ADR-0001, ADR-0006 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/resource-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Next Step

Run `/create-stories resource-system` to break this epic into implementable stories.
