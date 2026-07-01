# Quick Design Spec: Soft Reach Cap (Algorithm Barrier)

**Type**: New Small System
**Scope**: Applies a diminishing-returns multiplier to active-action Reach rewards when
cumulative Reach exceeds a tunable threshold — simulating algorithm throttling of organic
reach. Passive Reach income (Formula D: `Z_passive = N × Z_per_hater × Mult(M) × (Δt/60)`)
is completely unaffected.
**Date**: 2026-07-01
**Estimated Implementation**: Design anchor only — full build deferred to Alpha, after
Prestige/Checkpoint System exists (same tier as Final Burnout, DDR-0001 #5)

## Overview

In real influencer life the platform algorithm throttles organic reach once engagement
metrics plateau — the harder you grind, the less each individual post returns. The Soft
Reach Cap mirrors this: once the player's cumulative Reach crosses `REACH_SOFT_CAP`, every
action-based Reach reward is reduced by a smooth diminishing-returns factor. The multiplier
approaches zero asymptotically — grinding never becomes literally worthless, but the marginal
return shrinks visibly (Pillar 1: predictable math, Pillar 3: satire through mechanics). The
passive Reach stream from Haters is explicitly outside the cap: the player already paid the
Cringe → Haters → Morale risk to earn that income; throttling it would break the risk
contract (DDR-0001 #9 ruling). Offline play is naturally unaffected because offline income is
exclusively passive Formula D — no cap interaction is even possible (Pillar 4 friendly by
construction). The cap only bites at sustained high Reach, making it invisible in early/mid
play and only meaningful in era 2+ after Prestige exists.

## Core Rules

### 1. Cap formula — active action Reach only

The modifier applied to every action Reach reward at resolution:

```
cap_multiplier(R) =
    1.0                                    if R <= REACH_SOFT_CAP
    REACH_SOFT_CAP / R                     if R >  REACH_SOFT_CAP
```

Where `R` = current cumulative Reach at the moment the action completes.

The effective Reach delta for any action is:

```
Z_effective = round_half_up(Z_raw × Mult(M) × cap_multiplier(R))
```

`Mult(M)` is the existing Morale band multiplier (Resource System Formula C) — unchanged.
`cap_multiplier` is applied **after** `Mult(M)`, as a second independent modifier.

**Why this formula:**
- At `R = REACH_SOFT_CAP` → multiplier = 1.0 (no penalty, continuous, no cliff)
- At `R = 2 × REACH_SOFT_CAP` → multiplier = 0.5 (half returns)
- At `R = 10 × REACH_SOFT_CAP` → multiplier = 0.1 (steep diminish, not zero)
- Fully invertible: the player can always see the math (Pillar 1)
- Trivially implementable as a `static func` in `ResourceFormulas` with no state

### 2. Scope — what IS capped

- Every action Reach reward (`Z_raw`) resolved through `ActionSystem.action_completed`
- This includes the 3 base actions **and** the 3 milestone-gated actions (Collab, Interview,
  Course) added by DDR-0001 #3 quick-spec — they all route through the same reward
  resolution path

### 3. Scope — what is NOT capped (explicit exclusions)

| Source | Formula | Capped? | Reason |
|--------|---------|---------|--------|
| Passive Haters income | Formula D (`Z_passive`) | **NO** | DDR-0001 #9 ruling: player paid risk; throttling inverts the contract |
| Morale multiplier (Formula C) | `Mult(M)` | N/A | Not a Reach source — unchanged modifier |
| Sponsor Shield Reach bonus (if any future spec adds one) | — | **NO** | Sponsor spending is a resource transaction, not action grind |
| Decision Card Reach rewards | per-card delta | **NO** | Cards are narrative choices, not grind (capping them would punish engagement with Pillar 2 content) — revisit in Alpha if economy demands it |

### 4. Implementation location

`cap_multiplier(R)` is a new `static func` in `src/core/resource_formulas.gd`:

```gdscript
static func reach_cap_multiplier(current_reach: float) -> float:
    var cap: float = BalanceData.get_value("REACH_SOFT_CAP")
    if current_reach <= cap:
        return 1.0
    return cap / current_reach
```

Call site: `ActionSystem._resolve_reach_reward()` (or equivalent), immediately after
applying `Mult(M)` and before calling `ResourceManager.apply_delta()`.

This placement means:
- The formula is unit-testable in isolation (no ActionSystem state needed)
- Formula D (`Z_passive`) never touches this code path — exclusion is structural, not a
  conditional flag
- The cap can be disabled entirely by setting `REACH_SOFT_CAP` to a very large value
  (e.g. `999999`) without code changes

### 5. Offline behaviour

Offline simulation (`OfflineProgressSystem`) accumulates Reach exclusively via Formula D
(passive Haters income) — it does not simulate individual action completions. Therefore
`cap_multiplier` is **never called during offline simulation**. No special handling needed.
Pillar 4 is satisfied by construction.

### 6. Era-reset interaction

On Final Burnout acceptance (`BurnoutSystem`, DDR-0001 #5), all resources including Reach
reset to 0. `cap_multiplier(0)` = 1.0 — the cap is fully lifted at the start of each new
era, and only bites again once the player grinds Reach back past `REACH_SOFT_CAP`. This
creates the intended loop: each era opens with uncapped feel, the cap closes in as the
player progresses, Burnout resets everything including the cap.

### 7. Deferred activation condition

This system has no runtime gate — it is active from the moment it is implemented. The cap
only bites when `R > REACH_SOFT_CAP`, so setting `REACH_SOFT_CAP` to a high value makes it
invisible in early play. No feature flag required.

## Tuning Knobs

| Knob | Default | Range | Category | Rationale |
|------|---------|-------|----------|-----------|
| `REACH_SOFT_CAP` | 5 000 | 1 000 – 20 000 | gate | Should be unreachable in a typical MVP session (~30 min active); only meaningful after Prestige era 2+. Exact value calibrated against Action System Reach/s rates during Alpha balance pass. |
| *(curve steepness)* | n/a — formula is `CAP / R` | — | — | Steepness is implicit in the `1/R` hyperbolic curve. No separate knob needed: raising `REACH_SOFT_CAP` delays the bite; the curve shape is fixed and mathematically transparent (Pillar 1). If the team later wants a tunable exponent, extend to `(CAP/R)^k` with `k` in `balance.json` — but default is `k=1`. |

All values must live in `assets/data/balance.json`, not hardcoded.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| `ResourceFormulas` (`src/core/resource_formulas.gd`) | New `static func reach_cap_multiplier(current_reach: float) -> float` | Add function at implementation time |
| `ActionSystem` (`src/core/action_system.gd`) | Call `reach_cap_multiplier` in reward resolution, after `Mult(M)`, before `apply_delta` | Modify reward resolution path at implementation time |
| `ResourceManager` | Read-only: `get_resource(&"Reach")` already exists — no change | No action |
| `OfflineProgressSystem` | No change — does not simulate action rewards | No action |
| `balance.json` | Add `REACH_SOFT_CAP` entry | Add at implementation time |
| Prestige/Checkpoint System | Era-reset (Reach → 0) naturally lifts the cap — no extra coupling needed | No action; document in Prestige GDD's "cap interaction" note |
| `BurnoutSystem` | No direct coupling — Reach reset on burnout accept is sufficient | No action |

## Acceptance Criteria

- [ ] `ResourceFormulas.reach_cap_multiplier(R)` returns exactly `1.0` for any `R ≤ REACH_SOFT_CAP`
- [ ] `reach_cap_multiplier(2 × REACH_SOFT_CAP)` returns `0.5` (±floating-point epsilon)
- [ ] `reach_cap_multiplier(10 × REACH_SOFT_CAP)` returns `0.1` (±epsilon)
- [ ] `reach_cap_multiplier(0)` returns `1.0` (era-reset state is uncapped)
- [ ] Completing any action while `R > REACH_SOFT_CAP` applies the multiplier: effective Reach delta = `round_half_up(Z_raw × Mult(M) × cap_multiplier(R))`
- [ ] Completing any action while `R ≤ REACH_SOFT_CAP` applies **no penalty**: effective Reach delta = `round_half_up(Z_raw × Mult(M))` — identical to pre-cap behaviour
- [ ] Passive Reach income (Formula D) accumulates at its full unmodified rate regardless of current `R` — unit test: with `R = 100 × REACH_SOFT_CAP`, a timed passive tick produces `N × Z_per_hater × Mult(M) × (Δt/60)` exactly
- [ ] Offline simulation: simulating 8 hours offline with `R > REACH_SOFT_CAP` produces passive Reach equal to the Formula D result; `reach_cap_multiplier` is never called during offline simulation
- [ ] After Final Burnout acceptance resets Reach to 0, the next action reward is uncapped (multiplier = 1.0)
- [ ] `REACH_SOFT_CAP` is read from `balance.json` at runtime — changing the value without recompiling changes the cap threshold
- [ ] **No regression**: Resource System Formula D unit tests (from `resource-system.md` Acceptance Criteria) all pass unchanged

## Systems Index / DDR Reference

**DDR-0001 #9 ruling** (`design/decisions/ddr-0001-post-mvp-mechanics-pillar-rulings.md`):
> "Soft Reach cap — apply only to active action income, never to passive Haters income
> (Formula D). Capping passive income inverts the Cringe-chain's risk/reward (the player took
> the Haters risk; the reward must not be throttled). Only meaningful once Prestige exists
> (Alpha)."

**Alpha tier** — same as Final Burnout (DDR-0001 #5). Do not implement until
`BurnoutSystem` and `Prestige/Checkpoint System` exist; the era-reset interaction (Rule 6)
requires Prestige to be in place for the cap-lift behaviour to be meaningful.

**No systems-index update required** — this is a modifier function added to an existing
system (`ResourceFormulas`), not a new tracked system entry.

**Related quick-specs**:
- `final-burnout-2026-07-01.md` — era reset lifts the cap (same Alpha tier, shared
  implementation window)
- `milestone-gated-action-slots-2026-06-30.md` — slots 4–6 are also capped (same action
  reward path, no extra work required)
