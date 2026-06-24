# Epic: History Flag System

> **Layer**: Foundation
> **GDD**: design/gdd/history-flag-system.md
> **Architecture Module**: HistoryFlagManager
> **Status**: Complete
> **Stories**: 2 stories created — see table below

## Overview

Implements the `HistoryFlagManager` Autoload — a pure data structure recording
the player's decision history as an immutable flag log plus monotonically
increasing pattern counters (`risky_choices_count`, `safe_choices_count`).
Provides the Path Resolution Algorithm (`resolve_path()`) that filters
registered class paths by threshold/margin rules and returns the highest-scoring
match, or null. This is the bottleneck system for Pillar 2 (decisions are memory,
not points) — Decision Card System and future Class Path System both depend on
its flag/counter data being correct from day one.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Autoload singleton architecture | `HistoryFlagManager` is an Autoload; state ownership locked | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-hist-001 | Flag log plus pattern counters, single Autoload owner | ADR-0001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/history-flag-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | HistoryFlagManager Core — Milestone Flags & Pattern Counters | Logic | Complete | ADR-0001 |
| 002 | Path Resolution Algorithm | Logic | Complete | ADR-0001 |

## Next Step

Epic complete. Decision Card System and Class Path System can now consume `HistoryFlagManager`'s API.
