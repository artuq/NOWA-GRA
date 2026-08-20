# Algorithm Contract Return Loop

> **Status**: In Design
> **Author**: user + Codex/CCGS
> **Last Updated**: 2026-08-10
> **Implements Pillar**: Pillar 1 — uczciwa matematyka, Pillar 3 — satyra przez mechanikę, Pillar 4 — offline jako pierwsza klasa obywatelska

## Overview

Algorithm Contract Return Loop is the player-facing meta-progression layer that
connects a deliberate end-of-session choice to the next return. The player
always sees the current and next rung of the persistent Creator Empire ladder,
then arms one of three transparent offline contracts before leaving. On the
next qualifying return, the existing Offline Progress System resolves that
chosen strategy, the Offline Report explains its cause-and-effect outcome and
career progress, and the contract becomes unarmed until the player chooses the
next plan. The ladder survives Burnout resets. The first implementation slice
contains no random rewards, expiring rewards, login streaks, collections, or
online social systems.

## Player Fantasy

The player is a strategist operating inside a transparent but ethically warped
Algorithm. Before leaving, they decide what the empire should optimize; on
return, they receive an honest account of what that choice earned, what it
cost, and what kind of creator it is making them. Every report proves that the
plan mattered, while the persistent Creator Empire ladder turns repeated
strategies into a career history that survives Burnout.

The anchor moment is not "the game gave me an offline reward," but "that
happened because of the contract I chose." Contract selection serves Autonomy,
legible cause-and-effect resolution serves Competence, and persistent career
movement serves Expression and Narrative without judging the player as good or
bad.

## Detailed Design

### Core Rules

1. The player may arm exactly one of three offline contracts or remain on the
   unchanged neutral offline baseline.
2. A contract is one-shot. It may be replaced or cancelled for free until a
   qualifying absence begins.
3. An absence qualifies at the existing inclusive Offline Report threshold of
   300 seconds. A shorter return runs the neutral simulation, does not execute
   or consume the armed contract, and grants no Creator Empire progress.
4. The existing 24-hour cap limits economy simulation. Arriving later never
   deletes a contract, reward, or career progress.
5. Neutral offline remains exactly the current baseline and is never weakened
   to coerce contract use.
6. The three mutually exclusive contracts are:
   - **Rozkręć Dramę**: the Haters -> Morale -> Reach loop remains active, with
     increased Haters growth creating additional Reach indirectly. It never
     also adds a second direct Reach multiplier. Existing Troll, Assistant,
     Class Path, and Prestige Haters-resistance composition remains active.
   - **Domknij Biznes**: passive Reach production and Haters growth are paused;
     the contract produces deterministic Sponsors. It may consume applicable
     Class Path and permanent Sponsor-income bonuses, but not Sponsor Manager,
     whose existing scope remains card-resolution-only.
   - **Digital Detox**: no Reach or Sponsors are produced; the contract
     deterministically reduces Haters (floored at zero) and restores Morale
     (capped at 100). Troll never improves recovery.
7. On a qualifying return the system computes both the chosen contract outcome
   and a neutral counterfactual from the same starting snapshot. The report
   shows exact total deltas and the portion attributable to the contract.
8. A qualifying contract result, its Creator Empire credit, and consumption
   occur exactly once as one atomic player-facing outcome. Closing the process
   before acknowledgement can neither grant nor lose that outcome. The
   transaction mechanism is an architecture concern and will be fixed by ADR.
9. After the report the player may repeat the last contract, choose another,
   or continue unarmed. No choice blocks entry into active play.
10. The persistent Creator Empire ladder never decreases and survives Burnout.
    Its seven rungs are:
    1. Telefon od kuzyna
    2. Lokalny Influencer
    3. Dom Contentu
    4. Agencja Dram
    5. Sieć Medialna
    6. Własna Platforma
    7. Republika Zasięgu
11. Ladder advancement uses three transparent inputs: completed eras, Class
    Path mastery milestones, and successfully resolved qualifying contracts.
    Reach alone never advances the ladder. Contract returns alone are never
    sufficient for a rung.
12. In the first implementation slice, rungs grant a persistent title and
    career-presentation change only. They add no new economic multiplier.
13. Offline time may produce resources and recovery, but never simulates
    actions, cards, decision counters, Class Path card contribution, active
    investment, Challenge progress, Burnout sustained time, completed eras, or
    more than one contract credit. Active play remains the only route through
    those progression gates.
14. A resource stockpile may accelerate Class Path investment but may not
    replace decision history. The active-investment ceiling in F6 is a required
    companion balance change before this return loop ships.

### States and Transitions

| State | Meaning | Valid transitions |
|---|---|---|
| `UNARMED` | No contract selected; neutral offline applies | Select one contract -> `ARMED` |
| `ARMED` | One contract is persisted for the next qualifying absence | Replace/cancel -> `ARMED`/`UNARMED`; short return -> `ARMED`; qualifying return -> `RETURN_PENDING` |
| `RETURN_PENDING` | Contract and neutral outcomes are staged for the enhanced report | Acknowledge -> `COMMITTING`; process closes -> replay safely from the last committed save |
| `COMMITTING` | Resource result, ladder credit, contract consumption, and save are resolved once | Successful commit -> `UNARMED`; failure -> remain recoverable without applying twice |

- Accepting Burnout clears `ARMED` and asks for a fresh plan for the new era.
  Deferring Burnout does not clear it.
- New Game clears both contract and Creator Empire state.
- An invalid or unknown persisted contract restores safely as `UNARMED`.
- Creator Empire state is persistent, monotonic, and excluded from the Burnout
  era-local reset sweep.

### Interactions with Other Systems

| System | Direction | Contract |
|---|---|---|
| Offline Progress System | hard, read | Reuses its deterministic stepped simulation and existing 300-second/24-hour boundaries; does not fire actions or cards or change offline Cringe |
| Resource System | hard, read/write | Supplies starting Reach/Haters/Morale/Sponsors state and receives the once-only committed deltas with existing floors/caps |
| Save/Persistence System | hard, read/write | Persists the armed contract revision/terms and Creator Empire progress; commit must be crash-safe and observable |
| Offline Report Screen | hard, read + acknowledgement | Renders staged totals, neutral comparison, contract identity, and ladder before/after; calculates no economy values |
| Team/Staff Management | soft, read | Troll and Assistant compose only where declared; Sponsor Manager retains its card-only scope |
| Class Path System | hard, read | Supplies current offline modifiers and persistent best-tier mastery milestones |
| Prestige/Checkpoint System | hard, read + lifecycle trigger | Supplies era count/permanent modifiers; Burnout clears an armed contract but never resets the ladder |
| Main Navigation/Screen Flow | hard, presentation | Exposes current/next rung and the optional Away Plan surface without blocking active play |

Every contract preview and report must be derived from the same declared rules
as the simulation. If a displayed contract delta cannot be reproduced from the
same starting snapshot, that contract is not shippable.

## Formulas

All new tuning constants in this section are **provisional first-playtest
defaults**. Existing registered formulas and modifier caps remain authoritative.

### F1 — Rozkręć Dramę

The Drama Haters-rate formula is defined as:

`H_rate_drama = H_rate(C) * P_H * T_H * (1 - R_H) * D_H`

The existing stepped Morale and passive Reach formulas then run unchanged.
`D_H` never appears in the Reach formula; extra Reach arises only from the
additional Haters entering the existing Haters -> Morale -> Reach loop.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Fixed offline Cringe | `C` | float | `[0,100]` | Input to registered `haters_growth_rate` |
| Base Haters rate | `H_rate(C)` | float | `[0.02,1.02]`/min | Registered Resource formula |
| Class Path factor | `P_H` | float | existing registered range | Ambient path modifier |
| Troll factor | `T_H` | float | `[1.0,2.5)` | Existing Staff multiplier |
| Permanent resistance | `R_H` | float | `[0,0.40]` | Existing Prestige resistance |
| Drama factor | `D_H` | float | default `1.50`; safe `[1.25,1.60]` | Contract-only Haters multiplier |
| Step duration | `dt` | float | `(0,60]` sec | Existing offline step |

**Output Range:** Haters and Reach remain non-negative and unbounded over the
save lifetime. With `C=50`, `H0=5`, `M0=80`, and neutral modifiers, 5 minutes
produce approximately `H=7.03, Reach=6.22`; 8 hours `H=199.40,
Reach=4,939.63`; and 24 hours `H=588.20, Reach=42,763.87`. Neutral comparison
at the same inputs is respectively `H=6.35/134.60/393.80` and
`Reach=5.81/3,384.15/28,760.31`.

### F2 — Domknij Biznes

The Business Sponsor-progress formula uses authoritative integer fixed-point
units (`1000 units = 1 Sponsor`):

`earned_units = floor(B_S * 1000 * t_s / 3600 * P_S * (1 + R_S))`

`raw_business_units = remainder_units_before + earned_units`

`Sponsors_gained = floor(raw_business_units / 1000)`

`remainder_units_after = raw_business_units mod 1000`

During Business, `H_new = H_old`, passive `Reach_gained = 0`, and existing
Haters may still drain Morale through the registered stepped Morale formula.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base Sponsor rate | `B_S` | float | default `1.5`; safe `[0.75,2.0]` Sponsors/h | Contract production rate |
| Counted duration | `t_s` | int | `[300,86400]` sec | Capped qualifying time |
| Class Path multiplier | `P_S` | float | current `[1.0,2.0]` | Existing Sponsor-income path factor |
| Permanent Sponsor bonus | `R_S` | float | `[0,0.50]` | Existing `META_SPONSOR_MULT` |
| Carried progress | `remainder_units_before` | int | `[0,999]` | Era-local fixed-point work toward the next Sponsor |
| Sponsor payout | `Sponsors_gained` | int | `[0,108]` under current caps/default | Whole Sponsors committed |
| Remaining progress | `remainder_units_after` | int | `[0,999]` | Persisted and displayed fixed-point progress |

Sponsor Manager and Assistant do not apply. At default modifiers, 5 minutes
add `0.125` progress, 8 hours grant `12` Sponsors, and 24 hours grant `36`.
At the current maximum `P_S * (1 + R_S) = 3`, those values are `0.375`, `36`,
and `108`. Carrying the fractional remainder prevents both a misleading zero
result and a farmable minimum payout.

### F3 — Digital Detox

The Detox recovery formulas are defined as:

`H_final_detox = max(0, H0 - D_HOURLY * t_h)`

`M_final_detox = min(100, M0 + D_MORALE * t_h)`

`Reach_gained_detox = 0`

`Sponsors_gained_detox = 0`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Starting Haters | `H0` | float | `[0,infinity)` | Haters at the saved starting snapshot |
| Starting Morale | `M0` | float | `[0,100]` | Morale at the saved starting snapshot |
| Counted duration | `t_h` | float | `[1/12,24]` h | Capped qualifying time |
| Haters recovery | `D_HOURLY` | float | default `10`; safe `[6,15]` Haters/h | Flat transparent Haters reduction |
| Morale recovery | `D_MORALE` | float | default `12`; safe `[8,15]` Morale/h | Flat transparent recovery |

**Output Range:** `H_final_detox in [0,H0]`, `M_final_detox in [M0,100]`.
With `H0=100, M0=20`, 5 minutes produce approximately `H=99.17, M=21`; 8
hours `H=20, M=100`; and 24 hours `H=0, M=100`. Troll, Assistant, Sponsor
Manager, Sponsor Shield, and income modifiers never improve Detox.

### F4 — Neutral Counterfactual Attribution

The contract-attribution formula is defined for each reported resource `r` as:

`Contract_attribution[r] = Final_contract[r] - Final_neutral[r]`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Resource | `r` | enum | `{Reach,Haters,Morale,Sponsors}` | Reported resource |
| Contract result | `Final_contract[r]` | float | resource-valid range | Chosen contract outcome |
| Neutral result | `Final_neutral[r]` | float | resource-valid range | Existing offline outcome from the same snapshot |
| Attribution | `Contract_attribution[r]` | float | signed, resource-dependent | Exact difference caused by the contract |

Both simulations use the identical starting resources, raw/counted duration,
24-hour cap, fixed Cringe, Shield snapshot, and restored modifiers. Attribution
is report-only; the contract result is the state that commits.

### F5 — Creator Empire Ladder

First derive lifetime mastery:

`Mastery_score = sum(best_tier[p])` for all four Class Paths.

Then derive the rung:

`Ladder_rung = max({i in [1,7] | E >= E_req[i] and Mastery_score >= M_req[i] and K >= K_req[i]})`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Best path tier | `best_tier[p]` | int | `[0,5]` | Persistent best tier on path `p` |
| Mastery score | `Mastery_score` | int | `[0,20]` | Sum across four paths |
| Completed eras | `E` | int | `[0,infinity)` | Existing persistent era count |
| Qualified contracts | `K` | int | `[0,infinity)` | Successfully committed contract returns |
| Rung | `Ladder_rung` | int | `[1,7]` | Highest jointly satisfied rung |

Every threshold is inclusive and all three gates are required:

| Rung | Title | `E_req` | `M_req` | `K_req` |
|---:|---|---:|---:|---:|
| 1 | Telefon od kuzyna | 0 | 0 | 0 |
| 2 | Lokalny Influencer | 1 | 1 | 2 |
| 3 | Dom Contentu | 2 | 3 | 5 |
| 4 | Agencja Dram | 4 | 6 | 10 |
| 5 | Sieć Medialna | 6 | 10 | 18 |
| 6 | Własna Platforma | 9 | 14 | 30 |
| 7 | Republika Zasięgu | 12 | 18 | 45 |

The formula is monotonic because all three inputs are persistent and
non-decreasing. Neutral returns, sub-threshold returns, replayed pending
transactions, and duplicate acknowledgements add zero to `K`.

### F6 — Decision-Backed Class Path Investment Ceiling

To prevent a large offline Reach or Sponsor claim from purchasing an entire
Class Path after a single related choice, each path's resource-funded
investment contribution is capped by its card-earned contribution:

`I_cap = min(100 - C_card, 20 + C_card)`

`A_total = clamp(C_card + min(I_raw, I_cap), 0, 100)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Card contribution | `C_card` | float | `[0,60]` | Existing `4` affiliation per related resolved card, capped at `60` |
| Raw investment | `I_raw` | float | `[0,infinity)` | Existing resource-funded affiliation before the new ceiling |
| Investment ceiling | `I_cap` | float | `[20,60]` mathematically; effectively `(20,60]` behind the `C_card > 0` gate | Maximum resource-funded contribution allowed by decision history |
| Total affiliation | `A_total` | float | `[0,100]` | Value used by existing tier thresholds |

The existing rule that investment requires `C_card > 0` remains. With one
related choice (`C_card=4`), resources can reach at most `A_total=28` (Tier 1),
not Tier 5. Five choices permit at most `A_total=60` (Tier 3); ten choices permit
`A_total=100` (Tier 5). The same rule applies to every path and every investment
resource, so it fixes offline stockpile conversion without singling out or
silently devaluing offline rewards.

## Edge Cases

### Time and Qualification

- **If the wall clock moves backward**: treat elapsed time as `0`; run no
  simulation or report, consume no contract, add no Business progress or ladder
  credit, and never move the persisted save timestamp backward.
- **If elapsed time is `0-299` seconds**: run neutral offline only; preserve the
  armed contract and Business remainder unchanged.
- **If elapsed time is exactly `300` seconds**: the boundary is inclusive; stage
  one qualifying result and, after successful commit, exactly one contract
  credit.
- **If elapsed time is exactly `86400` seconds**: count all 24 hours with
  `capped=false`.
- **If elapsed time exceeds `86400` seconds**: count exactly 24 hours, set
  `capped=true`, display raw and counted time, and grant at most one result and
  one contract credit.
- **If a large forward clock jump occurs**: accept the single capped outcome.
  Without a trusted server it cannot be distinguished from a legitimate
  absence; a later rollback yields zero progress until time catches up.

### Transaction and Crash Recovery

- **If the process closes before report acknowledgement**: no contract-owned
  resources, Business remainder, contract credit, rung, or consumption are
  committed; the next boot stages the return again from the last committed save.
- **If acknowledgement is pressed more than once**: only the first transition
  to `COMMITTING` is accepted; every later tap/background input is ignored.
- **If the process closes before the atomic save rename succeeds**: disk still
  contains the armed pre-return state, so the next boot may safely replay it.
- **If the process closes after the atomic rename succeeds**: disk contains the
  committed result and `UNARMED`; the contract never replays even if routing to
  Main had not completed.
- **If persistence fails**: remain in `COMMITTING`, keep the report visible,
  disable normal input, expose Retry, and retry without applying deltas twice.
  Never route to Main after an unobservable or failed save.
- **If a pre-acknowledgement crash delays the next boot**: recompute using the
  later elapsed time, still capped at 24 hours. The first slice deliberately
  does not persist a pending-transaction journal.

### Burnout and Contract Lifecycle

- **If Burnout is accepted while `ARMED`**: clear the contract and Business
  fixed-point remainder in the era-transition save; grant no contract credit.
- **If Burnout is deferred while `ARMED`**: preserve both contract and remainder.
- **If Burnout is forced during `RETURN_PENDING` or `COMMITTING`**: reject it;
  the report blocks active play and the pending result remains unchanged.
- **If the player replaces or cancels a plan outside `ARMED`**: reject the
  request; controls are disabled while a return is pending or committing.

### Business Fixed-Point Progress

- **If Business earns less than one Sponsor**: grant zero whole Sponsors but
  show and persist the exact fixed-point progress; the qualifying contract still
  adds one ladder credit after commit.
- **If accumulated progress crosses one or more whole Sponsor boundaries**:
  transfer every whole Sponsor and retain only `0-999` progress units, where
  `1000 units = 1 Sponsor`, in the same atomic commit.
- **If the player cancels, runs Drama/Detox, or later returns to Business in the
  same era**: preserve the remainder.
- **If Burnout is accepted or New Game runs**: clear the remainder so
  pre-reset Sponsor work cannot cross eras.

### Invalid Data and Resource Limits

- **If a persisted contract has an unknown ID, unsupported revision, missing
  term, non-finite value, or value outside the revision's validated range**:
  restore as `UNARMED`, grant nothing, preserve valid ladder state, and never
  silently substitute current tuning for the saved promise.
- **If a known historical revision is restored**: execute its saved terms even
  after current balance values change.
- **If the common starting snapshot contains non-finite data**: abort staging,
  leave the contract armed, and commit no partial result.
- **If Drama would produce an invalid negative resource**: apply existing
  resource floors/caps; Morale still uses its existing ambient floor semantics.
- **If Business resolves**: Haters remain exactly at the starting value, Reach
  delta is exactly zero, Sponsors/remainder stay non-negative, and Morale uses
  the existing stepped drain/floor rules.
- **If Detox resolves**: floor Haters at zero, cap Morale at 100, and keep Reach
  and Sponsors deltas exactly zero.
- **When attribution is calculated**: compare post-clamp final states, never
  unclamped intermediate values.

### Dual Simulation and Ladder

- **If either neutral or contract simulation errors or returns non-finite
  output**: discard both, leave the contract `ARMED`, and show no misleading
  partial report.
- **If one return satisfies several ladder rungs**: jump directly to the final
  satisfied rung and list every crossed title; never restrict advancement to
  one rung per return.
- **If rung 7 is reached**: remain at 7 permanently and show no fake next rung.
- **If a best-tier milestone is missing**: treat that path as tier `0`; clamp
  malformed tiers to `[0,5]`, and never stack duplicate milestones.
- **If derived progress is below the persisted rung**: keep
  `max(stored_rung, derived_rung)` so migration or content loss cannot reduce
  the career.
- **If the return is neutral, short, replayed, failed to save, or acknowledged
  twice**: add zero contract credit.
- **If New Game runs**: atomically clear armed/pending state, Business progress,
  contract credits, stored rung, and all Creator Empire presentation state;
  preserve only settings allowed by the existing reset contract.

## Dependencies

| System | Type | Required contract/update |
|---|---|---|
| Resource System | hard | Supplies the validated starting snapshot and accepts the atomically committed resource deltas |
| Offline Progress System | hard | Supplies the neutral deterministic simulation and shared steps; never owns contract state |
| Save/Persistence System | hard | Persists contract terms/revision, ladder, credits, and Business remainder; exposes observable save success/failure |
| Offline Report Screen | hard | Renders result, attribution, and rung movement; performs no economy calculations |
| Class Path System | hard | Supplies applicable offline modifiers and persistent best-tier milestones |
| Prestige/Checkpoint System | hard | Supplies era count/permanent modifiers; Burnout clears armed contract/remainder but never the ladder |
| Main Navigation/Screen Flow | hard | Exposes the Away Plan surface and visible current/next career goal |
| Team/Staff Management | soft | Drama reads Troll/Assistant; Business and Detox deliberately exclude Staff modifiers |
| Networking / gameplay RNG | none | The first slice is fully local and deterministic |

Every hard dependency already has a designed and implemented production
surface. No undesigned upstream dependency blocks implementation. Cross-system
contract changes still require an ADR and propagation pass before stories.

## Tuning Knobs

| Knob | Default | Safe range | Interaction / failure mode |
|---|---:|---:|---|
| `MIN_REPORT_THRESHOLD_SECONDS` | `300` | `60-900` | Existing Offline Report owner; too low creates trivial reports, too high hides real short breaks |
| `MAX_OFFLINE_CAP_SECONDS` | `86400` | `43200-259200` | Existing Offline Progress owner; bounds economy and clock-forward exploitation |
| `DRAMA_HATERS_MULT` | `1.50` | `1.25-1.60` | Changes Reach indirectly, Haters directly, and later Morale drain; must be grid-simulated with Troll/Expert/Prestige stacks |
| `BUSINESS_SPONSORS_PER_HOUR` | `1.5` | `0.75-2.0` | Tune against Staff and Sponsor Shield costs; whole payouts use fixed-point carry |
| `BUSINESS_PROGRESS_UNITS_PER_SPONSOR` | `1000` | fixed | Fixed-point precision contract, not a balance knob |
| `DETOX_HATERS_PER_HOUR` | `10` | `6-15` | Flat recovery becomes relatively weaker at extreme unbounded Haters stockpiles |
| `DETOX_MORALE_PER_HOUR` | `12` | `8-15` | Restores a depleted meter in roughly one overnight absence at default |
| `LADDER_ERA_REQ` | `[0,1,2,4,6,9,12]` | monotonic values `0-20` | Tune against measured era duration |
| `LADDER_MASTERY_REQ` | `[0,1,3,6,10,14,18]` | monotonic values `0-20` | Must retain breadth/depth viability across four paths |
| `LADDER_CONTRACT_REQ` | `[0,2,5,10,18,30,45]` | monotonic values `0-100` | Tune against qualifying returns per era; never sufficient without other gates |
| `PATH_INVESTMENT_HISTORY_BASE` | `20` affiliation | `10-30` | Companion Class Path guardrail; too high restores one-choice tier skipping, too low makes investment feel decorative |

Any contract-formula balance change increments the contract terms revision so
an already armed plan resolves with the exact disclosed terms it saved. All
defaults remain provisional until state-grid simulation and playtesting.

### Active versus Offline Balance Target

- A week away resolves no more economy than one 24-hour claim and no more than
  one contract credit.
- For equal wall-clock time, active play receives the same ambient simulation
  plus actions, cards, and active progression; offline never strictly dominates
  a continuously active player using the same build.
- A maximum offline claim may create a large resource number, but must not alone
  complete an era, advance Creator Empire, unlock decision-gated content, or buy
  more Class Path tiers than F6 permits for existing decision history.
- Target return shape: claim -> make meaningful spend/strategy choices -> play
  at least one normal 10-20 minute decision loop before another irreversible
  progression step. The report is a launchpad for play, not a replacement for it.
- Balance regression grid must include `Cringe={0,50,100}`, elapsed
  `{5m,8h,24h,7d}`, all three contracts/neutral, no Staff/current Staff maxima,
  and early/mid/max Prestige/Class Path modifier snapshots.

## Visual/Audio Requirements

The feature extends the established **deadpan analytics dashboard** vocabulary;
it must look like an operating plan and a quarterly career report, not a loot
chest or casino reward. The current rung, next rung, three gate values, selected
contract, elapsed time, resource totals, and neutral comparison use typography,
spacing, iconography, and neutral contrast already defined by the Art Bible.

- Contract identities require distinct existing-resource glyphs and text labels;
  identity and outcome may never rely on hue alone.
- Positive and negative attribution use signed values and plain-language labels,
  not green/red moral valence. Haters gained under Drama are presented as a
  disclosed strategic cost, not an error state.
- A rung advancement may use one short opacity/scale/contrast beat and a static
  before -> after presentation. With Reduce Motion enabled it resolves instantly
  without losing information.
- The maximum rung has a deliberate terminal treatment and no empty or fabricated
  next-goal slot.
- The first slice requires no new character art, backgrounds, particles, or
  animation set. Small rung glyphs may be added only if they follow the current
  32x32 lossless, nearest-filtered icon pipeline.
- **No audio is added.** The project's permanent no-audio decision applies to
  contract selection, offline resolution, and rung advancement.

## UI Requirements

### Entry and Active-Play Status

- A persistent **Creator Empire / Away Plan strip** sits below the existing
  TopBar rather than adding a fifth TopBar button. It shows current title, next
  title, exact progress on all three next-rung gates, and `Neutral` or the armed
  contract name. At rung 7 it shows `Empire complete` and no fake next goal.
- The strip's **Set/Change Away Plan** action opens a coordinated full-screen
  `AwayPlanPanel`. It participates in `MainNavCoordinator`'s mutual-exclusion
  rules and never outranks an active Card Screen.
- Opening Away Plan never interrupts an action, card resolution, or Burnout
  prompt. The surface clearly states that doing nothing keeps neutral offline
  progress unchanged.
- The panel contains exactly four mutually exclusive full-row choices: Neutral,
  Drama, Business, and Detox. Each shows exact rule, costs/disabled sources,
  counted-time cap, current modifiers, and a shared-simulation preview. The
  selected row has a text/checkmark state; closing without confirming preserves
  the prior plan. The footer action is Arm, Replace, or Continue neutral/Cancel
  according to state; no confirmation modal is required.
- The armed state is visible on return to Main and offers **Change plan** and
  **Cancel plan**. Replacing/cancelling is immediate and free while `ARMED`.

### Enhanced Offline Report

- A qualifying contract return opens the existing full-screen Offline Report
  before active play. It shows: contract name, raw and counted absence, cap state,
  final resource deltas, signed attribution versus neutral, Business carry when
  applicable, contract-credit increase, and Creator Empire before/after state.
- The report separates **Total while away** from **Because of your plan** so the
  neutral counterfactual cannot be mistaken for an additional payout.
- If several rungs are crossed, all crossed titles are listed and the final rung
  is primary. At rung 7 the report shows a completed career state and no next
  target.
- In `RETURN_PENDING`, **Confirm result** is the only acknowledgement; tapping
  the background never commits. The first acknowledgement disables duplicate
  input and begins `COMMITTING`, displaying `Saving result...`. After a
  successful save the player may **Repeat [last contract]**, **Choose another**,
  or **Continue neutral**; all three routes reach active play. A failed save
  keeps the report open, explains that nothing will be counted twice, and
  exposes only **Retry save**. Back/Esc/background input is a no-op.
- Neutral qualifying returns retain the existing report behavior and do not imply
  a contract reward. Sub-threshold returns do not open a new contract report.

### Accessibility and Layout

- All interactive targets are at least `44x44`, keyboard/focus navigation follows
  reading order, and every icon has a text label or accessible description.
- Meaning is conveyed by label, sign, and icon together; color is supplementary.
  Dynamic numbers use tabular alignment and never require animation to read.
- The flow is scroll-safe at the project's `720x1280` portrait reference size and
  uses a scrolling body plus sticky footer with no horizontal scroll. It remains
  usable in the existing web pillarbox/aspect strategy and with 40% text
  expansion. No essential action may fall below an unreachable fold.
- Contract terms and report comparisons use plain language first, with exact
  numbers available without a tooltip-only interaction.
- Web supports Tab/Shift+Tab and Enter/Space. Focus opens on the current plan,
  returns to Set/Change after closing, starts on Confirm in the report, and moves
  to Retry after a save failure. Android Back mirrors Esc: it may close only the
  editable Away Plan panel, never bypass a pending/committing report.

## Acceptance Criteria

### Contract Lifecycle and Economy

1. **Given** no contract is armed, **when** any absence resolves, **then** the
   existing neutral offline result is unchanged and `K` does not increase.
2. **Given** a valid contract is armed, **when** elapsed time is `299` seconds,
   **then** neutral progress may resolve but the contract and Business remainder
   remain unchanged and no contract report or credit is produced.
3. **Given** a valid contract is armed, **when** elapsed time is exactly `300`
   seconds, **then** one contract result and one neutral counterfactual are staged
   from the same snapshot and exactly one `K` is eligible to commit.
4. **Given** an absence of exactly `86400` seconds, **when** it resolves, **then**
   all time is counted and the result is not marked capped; **given** `86401` or
   more seconds, **then** exactly `86400` seconds are counted and it is marked
   capped.
5. **Given** Drama with revision-1 terms, **when** it resolves, **then** its
   Haters rate is neutral rate times `1.50`, no direct Reach multiplier is added,
   and existing Troll/Assistant/Class Path/Prestige composition remains intact.
6. **Given** Business with revision-1 terms, **when** it resolves, **then** Reach
   delta and Haters growth are zero, existing Haters still drive neutral stepped
   Morale drain, whole Sponsors follow F2, and `0-999` fixed-point units carry.
7. **Given** Detox with revision-1 terms, **when** it resolves, **then** Haters
   decrease by `10/hour` to zero, Morale increases by `12/hour` to 100, Reach and
   Sponsors deltas are zero, and no Staff/income modifier improves the result.
8. **Given** any valid qualifying contract, **when** the report is built, **then**
   each attribution value exactly equals post-clamp contract final state minus
   post-clamp neutral final state from the identical snapshot.

### Persistence, Exactly-Once Commit, and Reset

9. **Given** a staged return before acknowledgement, **when** the process closes,
   **then** no contract resources, remainder, credit, rung, or consumption are
   durable and the next boot can safely stage the result again.
10. **Given** the report is acknowledged, **when** input repeats or the save is
    still in progress, **then** resource and meta deltas apply at most once and
    every acknowledgement after the first is ignored.
11. **Given** the atomic save succeeds, **when** the app restarts before normal
    scene routing completes, **then** the committed result is retained, the
    contract is `UNARMED`, and no reward or `K` replays.
12. **Given** persistence fails, **when** commit is attempted, **then** the report
    remains visible in `COMMITTING`, only Retry is actionable, active play is not
    entered, and Retry cannot double-apply deltas.
13. **Given** an armed contract, **when** Burnout is accepted, **then** the armed
    contract and Business units clear in the same transition while Creator
    Empire rung and credits survive; deferring Burnout preserves all three.
14. **Given** New Game is confirmed, **when** reset completes, **then** contract
    state, pending result, Business units, `K`, and stored rung reset atomically
    to the initial state while the existing settings-preservation contract holds.
15. **Given** an unknown or invalid saved contract, **when** restore runs, **then**
    it becomes `UNARMED`, grants nothing, preserves valid ladder/remainder state,
    and never substitutes current terms; a supported historical revision uses
    its saved terms.

### Creator Empire and Player-Facing Flow

16. **Given** `UNARMED`, **when** Drama, Business, or Detox is selected,
    **then** exactly that versioned contract and disclosed terms become `ARMED`;
    replacing or cancelling it before qualification costs and grants nothing.
17. **Given** any persistent era/mastery/contract values, **when** rung is derived,
    **then** it is the highest rung whose three inclusive gates are all met and is
    never below the highest previously stored rung.
18. **Given** one commit crosses multiple rung thresholds, **when** the report is
    shown, **then** every crossed title is listed and the final rung is stored;
    at rung 7 no next-rung requirement is displayed.
19. **Given** any rung changes in the first slice, **when** subsequent economy is
    evaluated, **then** no resource rate, reward, cap, or multiplier changes.
20. **Given** the player opens Away Plan, **when** they inspect, arm, replace, or
    cancel a contract, **then** neutral fallback and exact terms remain visible,
    the choice is free, and no active action/card/Burnout flow is interrupted.
21. **Given** a qualifying contract report, **when** it renders, **then** it shows
    contract identity, raw/counted time, cap state, total deltas, attribution,
    applicable Business carry, credit/rung movement, and after successful commit
    offers Repeat, Choose another, and Not now.
22. **Given** the UI at `720x1280`, keyboard/web input, or Reduce Motion mode,
    **when** every new surface is traversed, **then** controls remain reachable,
    at least `44x44`, focus-ordered, text-labelled, non-color-dependent, and all
    essential information remains present without animation.

### Regression and Failure Safety

23. **Given** a negative clock delta, non-finite common snapshot, or failure in
    either simulation, **when** resolution is attempted, **then** no partial
    result/report commits, the saved timestamp never moves backward, and a valid
    armed contract is not consumed.
24. **Given** existing saves without this feature's fields, **when** they restore,
    **then** they migrate to `UNARMED`, rung 1, zero contract credits and Business
    units without changing existing resources, eras, paths, staff, or settings.
25. **Given** one related Class Path choice (`C_card=4`) and an arbitrarily large
    valid resource stockpile, **when** the player invests, **then** total
    affiliation cannot exceed `28`/Tier 1; at five choices it cannot exceed
    `60`/Tier 3, and at ten choices it may reach `100`/Tier 5.
26. **Given** any offline duration and contract, **when** it resolves, **then**
    no actions, cards, decision counters, Class Path card contribution,
    Challenge progress, Burnout sustained time, or completed eras advance, and
    no more than one contract credit is granted.
27. **Given** the frozen pre-feature neutral-offline fixture matrix plus the full
    existing automated suite and new unit/integration tests,
    **when** the implementation is verified, **then** neutral offline results,
    report boundaries, Burnout, New Game, save recovery, and current navigation
    retain their previously accepted behavior.

## Open Questions

No player-facing design decision blocks architecture. The following decisions
are intentionally owned by the next workflow stages:

1. **Architecture ADR:** introduce a dedicated `AlgorithmContractSystem` as the
   owner of contract state, terms revision, Business units, credits, and rung,
   or extend an existing owner. The GDD requires one authoritative owner either
   way; `OfflineProgressSystem` remains a stateless simulator.
2. **Observable persistence:** `SaveSystem.save_now()` and its atomic write path
   currently expose no success/failure result. The ADR must define a testable
   acknowledgement/commit boundary and rollback/retry behavior before stories.
3. **Boot ordering:** `BootController` currently applies offline deltas before
   routing to the report. The ADR must replace that path for contract returns
   without regressing neutral returns or allowing double application.
4. **Navigation detail:** the UX specification must choose the exact existing
   host for Away Plan and Creator Empire status after measuring Bonuses and Team
   panel density; the top-bar non-expansion constraint is locked.
5. **Data representation:** contract terms, historical revisions, and ladder
   gates must be external, validated gameplay data. The technical design chooses
   Godot Resources versus the project's data-file convention.
6. **Copy/localization:** final English player-facing names and concise contract
   descriptions require a writing/localization pass; the Polish titles in this
   GDD are design identifiers, not permission to reintroduce mixed-language UI.
7. **Balance validation:** defaults remain provisional until automated state-grid
   simulation and at least one short/overnight/24-hour blind playtest pass. Tune
   constants by terms revision, never by silently changing an armed promise.
8. **Save migration:** the current whole-save version rejection cannot preserve
   valid meta state around a malformed contract payload. The ADR must define
   field-level defaults/validation and the schema migration path for old saves.
