# Epic: Card Content Database

> **Layer**: Foundation
> **GDD**: design/gdd/card-content-database.md
> **Architecture Module**: CardContentDatabase
> **Status**: Complete
> **Stories**: 1 story created — see table below

## Overview

Implements the `CardContentDatabase` Autoload — a static content table of 12
decision cards (8 risky/safe + 4 neutral), each with exactly 2 options, resource
deltas, counter increments, optional milestone flags, and (added this session,
per `juice-feedback-system.md`'s dependency) an optional `resolution_reaction`
field for the post-swipe payoff text. This module is structurally independent of
any system logic — pure data, no Autoload-to-Autoload signal wiring beyond being
read by Decision Card System and Juice/Feedback System.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Autoload singleton architecture | `CardContentDatabase` is an Autoload (read-only data access pattern) | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| — | No dedicated TR-card-* entries exist in `tr-registry.yaml` — this module is pure static data, correctly treated as low architectural risk and not separately ADR-tracked, consistent with `architecture.md`'s backlog decisions for similarly low-risk Presentation-layer modules. | N/A — by design, not a gap |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/card-content-database.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- The `resolution_reaction` field is populated for all 12 cards (currently only 3 have content — see `juice-feedback-system.md`'s Open Questions)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | MVP Card Content — Schema & 12-Card Data Table | Logic | Complete | ADR-0001 |

## Next Step

Epic complete. Decision Card System can now consume `CardContentDatabase`'s API.
