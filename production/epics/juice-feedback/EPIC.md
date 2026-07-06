# Epic: Juice/Feedback System

> **Layer**: Presentation
> **GDD**: design/gdd/juice-feedback-system.md
> **Architecture Module**: FeedbackMath (stateless static utility) + additive effects in ResourceHud/CardScreen — deliberately NO Autoload of its own (ADR-0011)
> **Status**: Complete (2026-07-06; audio stinger assets pending art bible — structural pipeline shipped)
> **Stories**: 3 stories (all Complete)

## Overview

Juice/Feedback System makes events *feel* their size. Every `action_completed` and card resolution carries a magnitude [0.0–1.0] computed by the stateless `FeedbackMath` (linear ratio for bounded resources, log-compressed for unbounded, max-of-contributions, hard clamp). Two mutually exclusive sensory channels consume it: the **Action channel** in ResourceHud (number count-up + a 150–200ms `self_modulate` flash on the pill chrome — never shake) and the **Card channel** in CardScreen (scale-pulse + visual-offset shake + layered audio stinger, all magnitude-tiered). The system's central guarantee is **no valence coding**: a huge win and a huge disaster at equal magnitude produce frame-for-frame identical feedback — `FeedbackMath` reads `abs(delta)` only, making the rule a testable pure-function property (and a registered forbidden pattern).

Scope discovered smaller than the GDD assumed (ADR-0011 codebase check): `resolution_reaction` content exists on all 12 cards and CardScreen's resolution payoff beat is already live — this epic builds only the magnitude formula and the sensory channels. Audio stinger assets await the art bible (`/asset-spec`); the structure ships now with an explicit null-stream guard (silent no-op).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0011: Juice/Feedback — Stateless FeedbackMath + Additive UI-Node Effects | No new Autoload/signal; FeedbackMath static class + additive effect code in ResourceHud (action channel) and CardScreen (card channel); count-up reconciled with resource_changed snap; self_modulate flash; scale reset + pivot guards | LOW |
| ADR-0007: Action UI zone ownership (secondary) | Each UI zone owns its own chrome — why a conductor node was rejected | LOW |
| ADR-0006: ResourceFormulas precedent (secondary) | Stateless static utility pattern FeedbackMath follows | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-juice-001 | Magnitude formula (linear/log, max, clamp [0,1]) | ADR-0011 ✅ |
| TR-juice-002 | Two mutually-exclusive channels (Action vs Card) | ADR-0011 ✅ |
| TR-juice-003 | No-valence-coding, structurally testable | ADR-0011 ✅ |
| TR-juice-004 | Zero-magnitude still plays lowest-tier effect | ADR-0011 ✅ |
| TR-juice-005 | Payoff duration formula clamp [1.5, 2.5]s | ADR-0011 ⚠️ partial — existing CardScreen beat; verify clamp bounds match in-story |
| TR-juice-006 | Backgrounding leaves clean state, no persisted state | ADR-0011 ✅ |
| TR-juice-007 | resolution_reaction content per card/option | ADR-0011 ✅ (already exists, verified) |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/juice-feedback-system.md` (sensory-channel scope) are verified
- All Logic and Integration stories have passing test files in `tests/`
- Visual/Feel evidence doc with sign-off in `production/qa/evidence/` (shake/pulse feel per tier; touch targets undisplaced)
- The no-valence-coding sign-invariance unit test exists and passes (`tests/unit/feedback/`)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | FeedbackMath — Magnitude Formula + Tier Functions | Logic | Complete | ADR-0011 (primary), ADR-0006 |
| 002 | Action Channel — ResourceHud Count-Up + Flash | Integration | Complete | ADR-0011 (primary), ADR-0007, ADR-0004 |
| 003 | Card Channel — Scale-Pulse + Shake + Stinger Structure | Integration | Complete | ADR-0011 (primary), ADR-0008, ADR-0007 |

## Next Step

Run `/qa-plan sprint` (per sprint-9.md's QA note), then `/story-readiness production/epics/juice-feedback/story-001-feedback-math.md` → `/dev-story`.
