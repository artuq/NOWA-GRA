# Quick Design Spec: First-Card Hook (15-Second Onboarding)

**Type**: Change (onboarding pacing)
**System**: Onboarding/Tutorial + Decision Card System (consumer side only)
**GDD Reference**: `design/gdd/onboarding-tutorial.md` (States and Transitions — REVISION REQUIRED, see below)
**Motivation source**: `design/reference/web-publishing-best-practices-2026-07-06.md` (Poki: player judgment within 15–20 s INCLUDING load)
**Date**: 2026-07-06 (user decision, Sprint 10 task 10-5)

## Change Summary

The first Decision Card of a NEW game appears immediately after the **1st completed action** (~6–10 s into play) instead of after the variety gate (3 distinct action types) + one more action (~20–28 s). Applies to the first card of a fresh run only — every subsequent card keeps the normal 2-action cooldown and pool rules. All platforms (no web/mobile branch).

## Rationale (user, 2026-07-06)

- The first card is the game's identity moment (Reigns-style hook) — it must land inside the portal player's 15–20 s judgment window
- Hook first, teach after: the variety gate's didactic role (try different actions) is already served post-hook by the gated slots 4–6 (risky/safe counters) and can be reused by a future explicit tutorial
- One consistent experience on Android and web — no platform branching

## Design Delta

Current (`onboarding-tutorial.md`): `PURE_ACTION` (suppress cards until 3 DISTINCT action types completed) → `FIRST_CARD_PENDING` → first card after the NEXT completed action (4th minimum).

New: a fresh game boots directly in `FIRST_CARD_PENDING` with the card cooldown pre-zeroed → the 1st completed action triggers the first card presentation. `PURE_ACTION` phase machinery is retained in code (future tutorial hook) but is skipped for new games. Restored saves keep whatever phase they persisted (no retroactive change mid-run).

## New Rules / Values

1. New game boot: `OnboardingGate.phase = FIRST_CARD_PENDING` + `DecisionCardSystem.force_cooldown_zero()` (deferred, same ordering guarantee as the existing Phase-1→2 call)
2. First card: presented right after action #1 resolves (pool rules unchanged — weighted pick from all eligible)
3. Cards #2+: unchanged (2-action cooldown, suppression rules as-is)
4. `FIRST_CARD_PENDING → NORMAL` transition: unchanged (first card resolved)
5. Variety tracking (`_completed_types`) keeps recording — data stays available for a future tutorial layer

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| OnboardingGate (`onboarding_gate.gd`) | New-game phase init + boot-time cooldown zero | Code (small) |
| DecisionCardSystem | None — existing `force_cooldown_zero()` API reused | None |
| onboarding-tutorial.md GDD | States/Transitions section describes the 3-variety gate as the first-card condition — now stale | **GDD revision required** alongside implementation |
| Onboarding unit/integration tests | Variety-gate-blocks-first-card assertions describe the OLD contract | Update in the implementing story (Sprint 9 retro rule: grep tests on contract change) |

## Acceptance Criteria

- [ ] **GIVEN** a fresh game (no save), **WHEN** the 1st action completes, **THEN** a Decision Card is presented (no variety requirement)
- [ ] **GIVEN** the first card resolves, **THEN** subsequent cards follow the normal 2-action cooldown
- [ ] **GIVEN** a restored save mid-run, **THEN** phase behavior is unchanged from what was persisted
- [ ] **GIVEN** the time from new-game boot to first card on-screen, **THEN** it is bounded by one action duration (≤ ~10 s with the shortest actions)
- [ ] Variety tracking still records distinct action types (future tutorial data)

## Open Question (carried)

- Future explicit tutorial: what replaces the variety gate's teaching role formally? Candidate: a Phase-based hint layer using the retained `_completed_types` data. *Owner: game-designer session when tutorial work is scheduled (Vertical Slice).*

## Implementation Sizing

NOT trivially small (touches onboarding contract + its test suite) → scheduled as a story, not inlined in 10-5. Estimate: 0.5d including test updates and GDD revision.
