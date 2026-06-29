# Epic: Onboarding/Tutorial

> **Layer**: Core
> **GDD**: design/gdd/onboarding-tutorial.md
> **Architecture Module**: OnboardingGate (per `architecture.md` — contract already fully designed, not yet implemented)
> **Status**: Ready
> **Stories**: 3 stories created — see table below

## Overview

Implements `OnboardingGate`, the final unbuilt MVP system. It does not add new game logic — it sequences the first player session so Decision Card System stays suppressed until the player has tried all 3 action types at least once (variety, not count), then forces the cooldown to 0 so the first card appears predictably right after. Unlike Offline Report Screen, the architecture for this system was already fully decided across three Accepted ADRs (ADR-0001's signal-fan-out pattern, ADR-0003's boot/`restore_state` order, ADR-0005's `DecisionCardSystem.force_cooldown_zero()` / `is_card_suppressed()` contract) and documented extensively in `architecture.md`, `control-manifest.md`, and `docs/registry/architecture.yaml` — this epic is pure implementation against an already-locked design, no new ADR required.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: Autoload singleton vs event bus | `ActionSystem.action_completed` is a multi-subscriber signal heard by both `OnboardingGate` and `DecisionCardSystem`; `OnboardingGate` registered in the Autoload list between `OfflineProgressSystem` and `DecisionCardSystem` | LOW |
| ADR-0003: Scene management & boot order | `OnboardingGate.restore_state()` is called by `BootController` in the documented dependency order; onboarding phase persists across sessions | LOW |
| ADR-0005: Decision Card weighting & cooldown | `DecisionCardSystem` gains `force_cooldown_zero()` (called only by `OnboardingGate`) and a suppression check (`OnboardingGate.is_card_suppressed()`, an ownership-clear direct read) in `_on_action_completed()` | LOW |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-onb-001 | Decision Card suppression (Phase 1) and force-cooldown-zero (Phase 1→2) | ADR-0001, ADR-0003, ADR-0005 ✅ |

**Note**: the GDD's Acceptance Criteria section is exhaustive (variety-gate set-membership semantics, all 6 permutation orderings, save/load edge cases, rewards-never-modified) — stories reference it directly; no additional TR-IDs needed.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/onboarding-tutorial.md` are verified, including all 5 "Defined edge cases" (save/load mid-phase, fresh install, dev/QA reset, permutation-order independence)
- The Logic-classified state machine has a passing unit test in `tests/unit/onboarding/` (GDD explicitly classifies this as BLOCKING — mockable via simulated action-completed events, no real ActionSystem integration needed)
- The Integration-classified pieces (Resources/History-Flags never gated, rewards never modified, real signal wiring with `ActionSystem`/`DecisionCardSystem`, save/load persistence) have integration-test evidence
- `project.godot`'s Autoload order matches `control-manifest.md`'s documented order exactly (`OnboardingGate` between `OfflineProgressSystem` and `DecisionCardSystem`)
- Existing Decision Card System / Action System tests stay green (the `force_cooldown_zero()` and suppression-check additions are additive, must not change pre-onboarding behavior when `OnboardingGate` reports `phase_normal`)

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | OnboardingGate State Machine | Logic | Ready | ADR-0001, ADR-0005 |
| 002 | Live Wiring — ActionSystem & DecisionCardSystem | Integration | Ready | ADR-0005, ADR-0001 |
| 003 | Persistence — Save/Load & Boot Wiring | Integration | Ready | ADR-0003, ADR-0002 |

**Build order**: strictly sequential — 001 (pure state machine, mockable) → 002 (real signal wiring, Autoload reorder) → 003 (persistence, depends on 002's fully-wired system). Story 002 includes a real risk: reordering `project.godot`'s Autoload list, verified via a real headless cold-start run (not just `scene_runner`), per the lesson from Offline Report Screen Story 003.

## Next Step

Run `/story-readiness production/epics/onboarding-tutorial/story-001-onboarding-gate-state-machine.md` then `/dev-story` to begin.
