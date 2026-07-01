# Quick Design Spec: Sponsor Network Shield

**Type**: Addition
**System**: Resource System
**GDD Reference**: `design/gdd/resource-system.md` — Formula B (Morale Drain Rate), Sponsors Acquisition
**DDR Reference**: `design/decisions/ddr-0001-post-mvp-mechanics-pillar-rulings.md` — #6
**Date**: 2026-06-30

## Change Summary

The player spends Sponsors to activate a time-limited shield that raises Formula B's buffer
threshold (`N_buffer`) from 3 to 8 for the duration. When the shield expires, `N_buffer`
reverts. This creates the first ongoing Sponsors sink, closing the no-sink/no-faucet tech debt
DDR-0001 flagged for Sponsors.

## Motivation

Sponsors currently accumulate without limit and have zero consequence — a dead resource that
violates Pillar 1 (every resource matters) and Pillar 4 (meaningful decisions). The shield
converts Sponsors into a periodic strategic spend: protect Morale now vs. save for next shield.
Time-limiting is mandatory per DDR-0001: a permanent N_buffer 3→10 makes the first ~10 Haters
free of Morale cost, a dominant strategy that trivializes the Cringe→Haters→Morale chain.

## Design Delta

**Current GDD says** (`resource-system.md`, Sponsors Acquisition):
> Flat 1–3 Sponsorzy per qualifying Decision Card […] No consumption formula yet — explicitly
> a placeholder pending Team/Staff Management GDD (Alpha tier).

**This spec adds:** the player may spend SHIELD_COST Sponsors to add SHIELD_DURATION seconds
to `_shield_remaining_seconds`. While `_shield_remaining_seconds > 0`, Formula B uses
`effective_n_buffer = M_BUFFER + SHIELD_BUFFER_BONUS` (= 8) instead of `M_BUFFER` (= 3).
When the timer reaches 0, effective buffer reverts. Activating while already active is additive
(stacks duration, no artificial cap — Sponsors cost is the natural ceiling).

## New Rules

1. **Activation**: Spend exactly SHIELD_COST Sponsors. Rejected (button disabled) if
   Sponsors < SHIELD_COST. No partial spend.
2. **Duration**: Each activation adds SHIELD_DURATION seconds to the timer (starts from 0 if
   inactive; adds to remainder if active).
3. **Effective buffer**: `effective_n_buffer = M_BUFFER + SHIELD_BUFFER_BONUS` while timer > 0;
   `= M_BUFFER` otherwise.
4. **Formula B change**: `morale_drain_rate()` gains an optional `effective_buffer: int = M_BUFFER`
   second parameter (backwards-compatible — existing callers without it get the base constant).
   Callers that need the shield effect pass `ResourceManager.get_shield_effective_buffer()`.
5. **Tick**: `_shield_remaining_seconds` decrements each frame in `ResourceManager._process(delta)`,
   clamped at 0.
6. **Persistence**: `_shield_remaining_seconds` is included in the SaveSystem save/load payload.
   Shield survives app close.
7. **Offline**: At offline sim start, if `_shield_remaining_seconds > 0`, OfflineProgressSystem
   runs two segments: shielded drain for `min(shield_remaining, offline_delta)` seconds, then
   unshielded drain for the remainder. Avoids per-tick buffer check in the 1440-iteration loop.
8. **Signal**: `shield_changed(is_active: bool, remaining_seconds: float)` emitted by
   ResourceManager on activation and on expiry. HUD wires to this — separate UI story.

## Tuning Knobs

| Knob | Default | Range | Rationale |
|------|---------|-------|-----------|
| SHIELD_COST | 5 Sponsors | 3–10 | ~2-5 qualifying cards — meaningful but achievable |
| SHIELD_DURATION | 300 s | 60–900 | 5-min session window; expires naturally between play sessions |
| SHIELD_BUFFER_BONUS | +5 | +2 to +7 | Effective N_buffer = 8; strong but N > 8 still drains |

**Worked example with shield active at N=10 Haters:**
- Without shield: `0.15 × (10−3)^1.3 ≈ 1.78 %/min`
- With shield:    `0.15 × (10−8)^1.3 = 0.15 × 2^1.3 ≈ 0.37 %/min`
- At N=8:         drain = 0 (fully buffered by shield)

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `src/core/resource_formulas.gd` | `morale_drain_rate()` optional `effective_buffer` param | Modify |
| `src/core/resource_manager.gd` | Shield fields, `activate_sponsor_shield()`, `_process()`, `shield_changed` signal | Modify |
| `src/core/offline_progress_system.gd` | 2-segment drain when shield partially covers offline delta | Modify |
| SaveSystem payload | Add `shield_remaining_seconds` to save/load | Modify |
| HUD / UI | Reads `shield_changed` | Separate story |

## Acceptance Criteria

- [ ] Spending SHIELD_COST Sponsors (≥ cost available) activates the shield for SHIELD_DURATION seconds
- [ ] Spending while already active adds SHIELD_DURATION to remaining time
- [ ] `morale_drain_rate(N)` uses `M_BUFFER + SHIELD_BUFFER_BONUS` as buffer while shield active
- [ ] `morale_drain_rate(N)` without second arg is identical to pre-shield Formula B (no regression)
- [ ] Timer decrements in real time; stops at 0, never negative
- [ ] Shield state (`_shield_remaining_seconds`) persists across save/load
- [ ] `shield_changed` emitted on activation and on expiry
- [ ] Offline simulation uses 2-segment approximation for partial-shield offline periods
- [ ] Activation rejected (no Sponsors spent) when current Sponsors < SHIELD_COST

## GDD Update Required?

Yes — `design/gdd/resource-system.md`:
- **Sponsors Acquisition section**: replace "No consumption formula yet" with shield activation rule
- **Formula B section**: add `effective_buffer` override note
- **Tuning Knobs table**: add SHIELD_COST, SHIELD_DURATION, SHIELD_BUFFER_BONUS rows
