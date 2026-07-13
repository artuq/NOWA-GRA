# Prestige/Checkpoint System

> **Status**: Designed (pending independent review — run `/design-review` in a fresh session)
> **Author**: user + agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 2 (decyzje mają pamięć), Pillar 4 (offline pierwszą klasą)
> **Creative Director Review (CD-GDD-ALIGN)**: skipped — Lean mode

## Overview

Prestige/Checkpoint System to warstwa meta-progresji zbudowana na dwóch już w pełni zaprojektowanych podkomponentach: BurnoutSystem (wymuszona karta decyzji gdy Cringe utrzymuje się na 100 przez `BURNOUT_THRESHOLD` sekund, oferująca Accept-and-reset albo Defer-once — `design/quick-specs/final-burnout-2026-07-01.md`) i ChallengeSystem (opcjonalna warstwa trudności wybierana na starcie ery, wymieniająca gorsze mnożniki nagród akcji na większy mnożnik meta-bonusu — `design/quick-specs/challenge-era-runs-2026-07-01.md`). Realny nowy zakres TEGO GDD jest węższy niż te dwa podkomponenty: definiuje CZYM faktycznie jest jeden trwały META_BONUS z resetu ery i jak się stackuje, dokładną klasyfikację flag era-local vs meta-persistent od której zależy logika resetu każdego innego systemu, oraz API `DecisionCardSystem.inject_priority_card()` potrzebne zarówno BurnoutSystem jak i przyszłym mechanikom wymuszonych kart. Mechanicznie gracz odczuwa to jako nieuniknioną sufit swojego imperium: buduj, uderz w ścianę (widoczną przez ostrzegawczy countdown), i wybierz albo spieniężenie w świeżą erę z jednym trwałym zyskiem, albo kupienie kolejnej chwili czasu za realny koszt Morale. To Pillar 2 (decyzje mają pamięć) doprowadzony do strukturalnego wniosku — reset ery to nie porażka, to wypłata za wszystko co gracz po drodze wybrał.

## Player Fantasy

*`creative-director` not consulted — Lean mode.*

Gracz czuje dwa etapy tego samego uczucia: (1) pośrednie — narastający, widoczny countdown ostrzegawczy (`BURNOUT_WARNING_THRESHOLD`) buduje napięcie w tle zwykłej gry, bez przerywania jej, zamieniając "Cringe=100" z liczby w realne, tykające zagrożenie; (2) bezpośrednie — moment karty Wypalenie to jedyny naprawdę ciężki wybór w grze: zaakceptować (stracić wszystko bieżące, zyskać coś trwałego) albo odroczyć raz (zapłacić Morale, kupić czas). Zgodnie z DDR-0001 #5, to nigdy nie jest game-over — to narracyjny checkpoint, punkt na osi czasu imperium, nie jego koniec. Gracz zawsze wybiera; nic nie jest mu zrobione bez zgody (Pillar 2). Reset ery to też ukryta szansa projektowa: skoro Class Path System (Open Questions) flagował że gracz raz wybrawszy ścieżkę nigdy nie wraca do pozostałych trzech, era reset to naturalny punkt zachęty do spróbowania innej ścieżki w nowej erze — nie wymuszony, ale meta-bonus może to subtelnie nagradzać (patrz Formuły).

## Detailed Design

### Core Rules

*Specialists not consulted — Lean mode (not a Section D/H HIGH-risk section). BurnoutSystem and ChallengeSystem mechanics below are locked by their own quick-specs and restated only in summary — those specs remain the source of truth for their internals; this GDD adds only what they explicitly deferred.*

**BurnoutSystem (locked, `final-burnout-2026-07-01.md`)**: trigger on `Cringe=100` sustained `BURNOUT_THRESHOLD` seconds → forced "Wypalenie" card via `inject_priority_card()` (Rule 6 below) → Accept (era reset + meta-bonus) or Defer-once (Morale cost). Not restated in full here.

**ChallengeSystem (locked, `challenge-era-runs-2026-07-01.md`)**: optional era-start difficulty picker, ratio-multiplier action penalties, produces `get_combined_meta_multiplier()` consumed by Rule 2 below. Not restated in full here.

1. **META_BONUS is path-typed** — when Choice A (Accept Burnout) resolves, the granted bonus's *type* is determined by `ClassPathSystem.get_active_path()` at that exact moment. If no path is active (nobody at Tier 1, or ambiguous per Class Path System F5), no meta-bonus is granted this cycle (see Edge Cases) — the run still resets, just without a permanent reward.

2. **META_BONUS magnitude formula** (see Formulas for the full derivation): scales with `ClassPathSystem.get_tier(active_path)` at burnout time and `ChallengeSystem.get_combined_meta_multiplier()`. A player who burns out at Tier 1 on a normal (no-challenge) run gets the smallest possible grant; a Tier 5 burnout under stacked challenges gets the largest.

3. **Each of the 4 paths grants a thematically distinct permanent bonus type**, extending that path's own tier-bonus flavor (Class Path System §Tier Bonuses by Path) into something that persists across the reset the tier bonuses themselves don't survive:

   | Path | Permanent meta-bonus type |
   |---|---|
   | `pato_streamer` | `META_REACH_MULT` — permanent multiplier on active-play Reach income |
   | `guru_celebryta` | `META_SPONSOR_MULT` — permanent multiplier on Sponsor income |
   | `ekspert_niszowy` | `META_HATERS_RESIST` — permanent reduction on Haters growth rate |
   | `biznesmen_contentu` | `META_SPONSOR_FLOOR` — permanent minimum Sponsor income floor (never drops to 0, even at era start) |

4. **Bonuses stack additively per type, across eras, uncapped in count but capped in magnitude** — burning out twice on `pato_streamer` in different eras adds a second `META_REACH_MULT` increment to the *same* running total (not two separate multipliers multiplying each other); burning out once on `pato_streamer` and once on `guru_celebryta` produces two independent permanent bonuses that both apply simultaneously. Each bonus type has its own `META_BONUS_MAX` ceiling (Tuning Knobs) — further grants of an already-capped type are absorbed with no effect (same "capped, not wasted-resource-refunded" pattern as Class Path's affiliation clamp).

5. **META_BONUSes are permanent from the moment they're granted** — they are never reduced, reset, or removed by any future era transition. This is the one piece of state in the entire game that survives every reset; everything else (Class Path affiliation, era-local flags, active Challenges) resets to zero each time.

6. **`DecisionCardSystem.inject_priority_card(card_id: StringName)` (new API)** — bypasses the normal card pool, weighting, and cooldown entirely; presents the given card on the next available frame; blocks all normal card presentation until resolved (`_card_pending`-style guard, mirroring BurnoutSystem's own flag). This is a general-purpose injection path, not Burnout-specific — any future forced-card mechanic reuses this same API rather than inventing its own.

7. **Flag classification (the blocking gap both quick-specs deferred to this GDD)**:
   - **Era-local** (cleared on every `era_transitioned`): all 5 resources, all Class Path affiliation/tier state, all Class Path path-tagged card counters, all active Challenge flags, `BurnoutSystem._deferred_this_era`.
   - **Meta-persistent** (never cleared): `era_count`, all granted META_BONUS values (by type), Class Path's `best_tier_reached[path]` / `eras_spent_as[path]`, all `burnout_accepted_era_N` / `burnout_deferred_era_N` milestone flags.
   - This classification is the canonical answer other systems' GDDs deferred to this one — Class Path System's Era Reset section and BurnoutSystem's own spec both point here.

### States and Transitions

**Era lifecycle** (extends BurnoutSystem's own state machine with the meta-bonus grant step):

| State | Description | Transition |
|---|---|---|
| `active_era` | Normal play, Challenges (if any) applied, Class Path progressing | → `burnout_warning` when Cringe sustains near threshold (BurnoutSystem) |
| `burnout_warning` | Countdown visible, no interruption to play | → `burnout_card_presented` at full threshold, or back to `active_era` if Cringe drops |
| `burnout_card_presented` | Forced card blocking normal play | → `era_transitioning` on Choice A, → `active_era` (deferred) on Choice B |
| `era_transitioning` | **New state this GDD adds** — the ordering window between Choice A confirming and the new era's first frame: (1) `ClassPathSystem.reset_era_state()` runs, reading `active_path`/`tier` for the meta-bonus type/magnitude *before* it clears them; (2) meta-bonus is computed and granted; (3) era-local flags clear; (4) `era_transitioned` signal fires; (5) `ChallengeSystem` shows the Challenge Selection screen | → `active_era` once Challenge Selection is confirmed (or immediately if the player has no challenges available yet) |

**Critical ordering note**: Rule 1's "path active at burnout time" read MUST happen before Class Path's `reset_era_state()` clears the affiliation/tier state it depends on. This GDD's `PrestigeSystem` (new Autoload) is the one that calls `ClassPathSystem.get_active_path()`/`get_tier()` and *then* triggers the reset sequence — it does not passively listen to `era_transitioned` for this read, because by the time that signal fires (per Class Path's own spec), the state is already cleared. `PrestigeSystem` owns the orchestration order of Choice A's resolution; `era_transitioned` is emitted only after `PrestigeSystem` has done its meta-bonus read.

### Interactions with Other Systems

- **Class Path System** (hard, read then triggers reset) — `PrestigeSystem` reads `get_active_path()`/`get_tier()` at the moment Choice A resolves (before reset), then calls `ClassPathSystem.reset_era_state()` (or emits the signal that triggers it — ordering per States and Transitions above). Also reads `best_tier_reached[path]`/`eras_spent_as[path]` meta-flags, though those are informational/UI (e.g. an era-summary screen) rather than inputs to the magnitude formula itself (see Formulas — magnitude uses the *at-burnout* tier, not the lifetime-best tier, to keep the incentive tied to "how far did you push THIS era," not a one-time lifetime max).
- **Decision Card System** (hard, new API) — `inject_priority_card()` (Rule 6) is a new method this GDD requires; BurnoutSystem's forced card and any future forced-card mechanic depend on it existing.
- **History Flag Manager** (hard, read+write) — owns the flag classification sweep (Rule 7); `PrestigeSystem` is the system that knows which flags belong to which bucket, but the actual clear/preserve mechanics run through HistoryFlagManager's existing API.
- **Challenge System** (hard, read) — `get_combined_meta_multiplier()` scales the magnitude formula (Rule 2/Formulas).
- **Resource Manager** (hard, write) — era-start reset writes the 5 default values (already specified in `final-burnout-2026-07-01.md` §4.2); META_BONUS effects apply as ongoing multipliers/floors at the point resources are computed each era, not as one-time grants.
- **Action System** (soft, read) — `META_REACH_MULT`/`META_SPONSOR_MULT` apply at action-reward resolution, alongside Class Path's own active-path multiplier and Challenge modifiers (three independent multiplicative layers — see Formulas for stacking order).
- **Save/Persistence System** (hard, read+write) — `era_count`, all META_BONUS values by type, and the meta-persistent flag set are part of the serialize/restore cycle.

## Formulas

*Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

META_BONUS magnitude is computed once per accepted burnout from two already-locked inputs (`ClassPathSystem.get_tier(active_path)` at burnout time, `ChallengeSystem.get_combined_meta_multiplier()`), added to a per-type running total that is capped and never reduced (Core Rules 4/5), then consumed at four distinct resolution points — one per bonus type — because the four types are not mechanically equivalent (two are reward-resolution multipliers, one is a growth-rate resistance, one is a one-time era-start floor). F3's sub-formulas are written as *extensions* of already-locked formulas (Challenge spec's `final_reach = base_reach × Mult(M) × challenge_modifier`, Resource System's `H_rate(C)`) — they insert new factors into existing pipelines rather than redefining them.

### F1. META_BONUS Grant Magnitude

`bonus_increment[type] = BASE_INCREMENT[type] × tier_at_burnout × (combined_meta_multiplier)^META_CHALLENGE_SCALING_EXPONENT`

| Symbol | Type | Range | Description |
|---|---|---|---|
| `type` | enum | `{META_REACH_MULT, META_SPONSOR_MULT, META_HATERS_RESIST, META_SPONSOR_FLOOR}` | Bonus type, resolved by `ClassPathSystem.get_active_path()` at Choice A (Core Rules 1/3) |
| `tier_at_burnout` | int | 1–5 | `ClassPathSystem.get_tier(active_path)`, read at the moment Choice A resolves, before `reset_era_state()` (States and Transitions ordering) |
| `combined_meta_multiplier` | float | `{1.0} ∪ [1.5, ~15]` at current Challenge catalogue + `CHALLENGE_MAX_ACTIVE=3` | `ChallengeSystem.get_combined_meta_multiplier()`, read at the same moment; 1.0 if no challenges active |
| `BASE_INCREMENT[type]` | float (tuning knob, per-type array) | see table below | Base grant per tier-point, before challenge scaling |
| `META_CHALLENGE_SCALING_EXPONENT` | float (tuning knob) | 0.3–1.0, default **0.5** | Dampens `combined_meta_multiplier`'s contribution. `1.0` = linear (a single extreme-challenge Tier-5 burnout can consume most of a type's cap in one grant). `0.5` (locked default) = square-root — rewards challenge-stacking clearly without letting one cycle dominate the multi-era stacking arc (Core Rule 4) |
| `bonus_increment[type]` | float | `> 0` (grant only fires when a path is active, i.e. `tier_at_burnout ≥ 1`, per Core Rule 1) | Amount added to the type's running total this cycle, before F2's cap |

**`BASE_INCREMENT[type]` (proposed defaults):**

| Type | `BASE_INCREMENT` | Units |
|---|---|---|
| `META_REACH_MULT` | 0.02 | fractional multiplier (2% per unit) |
| `META_SPONSOR_MULT` | 0.025 | fractional multiplier (2.5% per unit) |
| `META_HATERS_RESIST` | 0.015 | fractional reduction (1.5% per unit) |
| `META_SPONSOR_FLOOR` | 3.0 | flat Sponsors |

**Output range**: `> 0`, unbounded above at the formula level (bounded in practice by the Challenge catalogue's max stackable multiplier and `CHALLENGE_MAX_ACTIVE`). Not itself capped — F2 applies the hard per-type ceiling.

**Worked example (Tier 1, no challenge — "small but real")**: `META_REACH_MULT`, `tier=1`, `multiplier=1.0` → `0.02 × 1 × 1.0^0.5 = 0.02` (2%).
**Worked example (Tier 3, one challenge)**: `tier=3`, `multiplier=2.0` → `0.02 × 3 × 1.414 = 0.0849` (8.5%).
**Worked example (Tier 5, stacked challenges — "meaningful, clearly larger")**: `bez_tlumu` (3.0) × `drama_bez_granic` (2.5) × `wypalony_ale_core` (2.0) = 15.0. `tier=5` → `0.02 × 5 × 15.0^0.5 = 0.02 × 5 × 3.873 = 0.3873` (38.7%) — roughly 19× the Tier-1 baseline, still under the type's cap.

### F2. Per-Type Running Total (Stacking + Cap)

`META_BONUS_total[type] = min( META_BONUS_total_prev[type] + bonus_increment[type], META_BONUS_MAX[type] )`

| Symbol | Type | Range | Description |
|---|---|---|---|
| `META_BONUS_total_prev[type]` | float | `[0.0, META_BONUS_MAX[type]]` | Running total before this grant — permanent, never reduced (Core Rule 5) |
| `bonus_increment[type]` | float | `> 0` (F1 output) | This cycle's grant |
| `META_BONUS_MAX[type]` | float (tuning knob, per-type) | see table below | Hard ceiling. Grants past the cap are absorbed with **no effect** (same pattern as Class Path's `CARD_CONTRIBUTION_MAX` clamp) |
| `META_BONUS_total[type]` | float | `[0.0, META_BONUS_MAX[type]]` | Canonical stored value, read by F3 |

**`META_BONUS_MAX[type]` (proposed defaults, deliberately non-uniform):**

| Type | Cap | Units | Rationale |
|---|---|---|---|
| `META_REACH_MULT` | 0.50 (50%) | fractional multiplier | Reach is the primary currency; permanent ceiling roughly matching one strong Class Path T1 bonus (+30%) is proportionate for something earned over many eras |
| `META_SPONSOR_MULT` | 0.60 (60%) | fractional multiplier | Slightly more generous — Sponsors currently has **no consumption sink** (registry note), so inflated Sponsor income carries less economic risk today. Revisit once Team/Staff Management exists |
| `META_HATERS_RESIST` | 0.40 (40%) | fractional reduction | Deliberately well below 100% — must never fully stop Haters growth (extends DDR-0001 #2's "never zero a core resource flow" principle by analogy — confirmed as intentional extension, not automatic restatement) |
| `META_SPONSOR_FLOOR` | 100.0 | flat Sponsors | Meaningful but bounded head start; heavily provisional given Sponsors has no sink yet |

**Output range**: `[0.0, META_BONUS_MAX[type]]`, monotonically non-decreasing across the game's lifetime — never cleared by era reset (Core Rule 5).

**Worked example**: `META_REACH_MULT` from `0.0`: Tier-1 grant → `0.02`. Tier-5-stacked grant (+0.3873) → `0.4073`. A third similar grant computes `0.7946` → clamped to `0.50`; `0.2946` absorbed with no effect.

### F3. Final Reward Stacking

**General principle**: each contributing system computes exactly **one** factor via its own internal combination rule (Class Path tier bonuses: additive within Class Path; Challenge modifiers: multiplicative within Challenge; META_BONUS: additive within type per F2). These system-level factors combine **multiplicatively across systems** at the resource's resolution point. Rationale: keeps each layer independently visible/auditable (each panel shows its own number); avoids additive cross-blending with sub-1.0 Challenge nerfs (risk of negative/non-monotonic totals); product of independently-capped factors stays bounded — Pillar 1's "fair predictable math" without uncontrolled compounding. All rounding (round-half-up, per `action_ui_number_format`) happens **once**, at the end of the full product, never per layer.

#### F3a. Reach Reward Stacking (active-play only)

`final_reach(action_id) = base_reach(action_id) × Mult(M) × class_path_multiplier(action_id) × challenge_modifier(action_id) × (1 + META_REACH_MULT_total)`

| Symbol | Type | Range | Description |
|---|---|---|---|
| `base_reach(action_id)` | float | per `action_zasiegi_base` (5/10/6) | Locked, Action System |
| `Mult(M)` | float | `{0.50, 0.75, 0.90, 1.00}` | Locked, Resource System (Morale band) |
| `class_path_multiplier(action_id)` | float | ≥ 0 | `ClassPathSystem.get_active_multiplier(action_id)` — existing API, opaque input, not redefined here |
| `challenge_modifier(action_id)` | float | `[0.05, unbounded)` (floor: `CHALLENGE_MODIFIER_FLOOR`) | ChallengeSystem's product of active modifiers, opaque input |
| `META_REACH_MULT_total` | float | `[0.0, 0.50]` (F2 output) | This GDD's new contribution |
| `final_reach(action_id)` | float → round-half-up → int | ≥ 0 | Reach granted on action completion |

**Worked example (no challenge)**: `zrob_drame`, base 10, `Mult=1.00`, path `1.30` (pato T1), challenge `1.0`, meta `0.3873` → `10 × 1.00 × 1.30 × 1.0 × 1.3873 = 18.03` → **18 Reach** (vs. 13 with Class Path alone).
**Worked example (all four layers)**: same action, `Mult=0.90`, path `1.30`, challenge `0.5` (`bez_tlumu`), meta `0.02` → `10 × 0.90 × 1.30 × 0.5 × 1.02 = 5.967` → **6 Reach**.

#### F3b. Sponsor Income Stacking (active-play only, card-resolution scoped)

`final_sponsors = round_half_up( base_sponsors_roll × class_path_sponsor_multiplier × (1 + META_SPONSOR_MULT_total) )`

| Symbol | Type | Range | Description |
|---|---|---|---|
| `base_sponsors_roll` | int | 1–3 | Existing `sponsorzy_per_qualifying_card` random roll |
| `class_path_sponsor_multiplier` | float | thematically ≥ 1.0 | Class Path guru/biznesmen Sponsor tier bonuses — **⚠️ no resolution API defined yet, see Open Questions** |
| `META_SPONSOR_MULT_total` | float | `[0.0, 0.60]` (F2 output) | This GDD's new contribution |
| `final_sponsors` | int | ≥ 0 | Sponsors granted on qualifying-card resolution |

No `challenge_modifier` factor — the current Challenge catalogue defines no sponsor axis; if added later it slots in per F3a's pattern.

**Worked example (endgame)**: roll 3, guru T1 `1.20`, meta capped `0.60` → `round(3 × 1.20 × 1.60) = round(5.76)` → **6 Sponsors** (vs. 4 with Class Path alone).

#### F3c. Haters Growth Rate Resistance — applies online AND offline (locked decision, 2026-07-12)

`H_rate_final(C) = H_rate(C) × (1 − META_HATERS_RESIST_total)`

| Symbol | Type | Range | Description |
|---|---|---|---|
| `H_rate(C)` | float | per Resource System's locked formula | Existing, unmodified |
| `META_HATERS_RESIST_total` | float | `[0.0, 0.40]` (F2 output) | This GDD's new contribution |
| `H_rate_final(C)` | float | `[0.60 × H_rate(C), H_rate(C)]` | Effective Haters growth rate |

**Scope (locked)**: unlike Class Path multipliers and Challenge modifiers (both active-play-only by their own rules), this resistance applies to **both active-play and offline** Haters growth. Rationale: those systems are era-local and per-action (complex for offline sim — Pillar 4 demands offline simplicity); META_HATERS_RESIST is meta-persistent and a single flat rate factor — simpler than anything the offline sim already computes, fully transparent in the offline report. Side benefit, explicitly intended: this is the game's one lever that softens the known offline Morale-drain spiral (Haters growth → `M_drain(N)`), giving `ekspert_niszowy` burnouts a distinctly "calmer offline" long-term identity.

**Worked example**: `C=80` → `H_rate = 0.02 + 0.8² × 1.0 = 0.66`. With `META_HATERS_RESIST_total = 0.30`: `0.66 × 0.70 = 0.462` Haters/min (~30% slower).

#### F3d. Sponsor Floor at Era Start

`sponsors_at_era_start = max( 0.0, META_SPONSOR_FLOOR_total )`

Overrides Final Burnout's default era-start reset (`Sponsors = 0`, `final-burnout-2026-07-01.md` §4.2) for this one resource only. Applied once, at the exact moment `era_transitioning`'s resource-reset step writes Sponsors — not an ongoing rate.

| Symbol | Type | Range | Description |
|---|---|---|---|
| `META_SPONSOR_FLOOR_total` | float | `[0.0, 100.0]` (F2 output) | This GDD's new contribution |
| `sponsors_at_era_start` | float | `[0.0, 100.0]` | Sponsors value written at era-start reset, replacing the flat 0 default |

**Worked example**: total `9.0` (three Tier-1 grants across three eras) → new era starts with `Sponsors = 9` instead of `0`.

## Edge Cases

*Specialist not consulted — Lean mode (not a Section D/H HIGH-risk section).*

- **If Choice A (Accept Burnout) resolves with no active path** (nobody at Tier 1, or ambiguous per Class Path F5): no META_BONUS is granted this cycle. The era still resets normally — reset is never blocked by the absence of a reward. The Wypalenie card's presentation SHOULD surface this before the player confirms ("No active path — this burnout grants no permanent bonus"), so the player can knowingly choose Defer instead; exact copy is a writer task.
- **If all four META_BONUS types are at their caps**: further burnouts grant nothing (absorbed per F2), but the burnout mechanic itself is unchanged — the card still fires, Defer still costs Morale, the era still resets. No softlock: the trigger is Cringe-driven, not reward-driven.
- **If the app is killed mid-`era_transitioning`** (after Choice A confirmed, before the new era's first frame): the entire transition sequence (meta-bonus read+grant → resource reset → flag sweep → `era_transitioned` → Challenge Selection) must be **atomic with respect to the save cycle** — `SaveSystem.save_now()` is called only after the full sequence completes, never between its steps. If the app dies mid-sequence, the restored save is the pre-transition state with `_card_pending = true` (BurnoutSystem's existing persistence), and the Wypalenie card re-presents on boot — the player re-confirms and the whole sequence re-runs from the top. No partial-transition state is ever persisted.
- **If Challenge Selection is interrupted** (app killed after `era_transitioned` fired but before challenges confirmed): per the atomicity rule above this state is never persisted mid-sequence; on restore the era is already transitioned (the save happened post-sequence) and challenge flags are whatever was confirmed — or none, since zero-challenge is a valid, safe default state. ChallengeSystem's own restore-from-flags reconstruction (its quick-spec Rule 3.3) handles this without new machinery.
- **If Choice B (Defer) is taken with Morale below `BURNOUT_DEFER_MORALE_COST`**: Morale clamps at 0 per the Final Burnout spec (survivable, not a death spiral) — restated here only to note META_BONUS is untouched by Defer; no grant, no read of path state.
- **If a save predates this system**: `era_count` defaults to 0, all `META_BONUS_total[type]` default to 0.0, no meta-persistent burnout flags exist — standard missing-key default pattern (same as `OnboardingGate`/`SettingsSystem`/Class Path migration). The player is treated as being in their first era, which is exactly true.
- **If `inject_priority_card()` is called while another priority card is already pending**: rejected (returns `false`/error, no queueing). Contract: at most one priority card in flight; today's only caller (BurnoutSystem) already guards with `_card_pending`, so a second concurrent injection indicates a caller bug, not a game state to support. Revisit only if a second forced-card mechanic ever ships.
- **If offline simulation runs with a nonzero `META_HATERS_RESIST_total`**: the resistance applies to the offline Haters growth (F3c's locked online+offline scope) using the value as-of-save-time — grants only ever happen in active play (Choice A is an active-play interaction), so the total cannot change during an offline window; there is no mid-simulation value ambiguity.
- **If `BASE_INCREMENT` or `META_BONUS_MAX` is misconfigured to 0 or negative in balance.json**: grants compute to ≤ 0 — clamp `bonus_increment` to `max(0.0, computed)` at grant time (a zero grant is safe; a negative grant would violate Core Rule 5's never-reduced guarantee). Log a config warning; do not crash.

## Dependencies

**Depends on:**
- **Class Path System** (hard, read-then-reset) — `get_active_path()`/`get_tier()` read at Choice A before `reset_era_state()` (ordering owned by PrestigeSystem, States and Transitions); `best_tier_reached`/`eras_spent_as` meta-flags read for era-summary UI. **⚠️ Inherits that GDD's blocking prerequisite**: the counter-naming propagation pass (History Flag System 2→4 paths, `path_tag` card schema) must land before implementation.
- **Decision Card System** (hard, new API) — `inject_priority_card(card_id)` (Core Rule 6) must be added; single-card-in-flight contract per Edge Cases.
- **Challenge System** (hard, read) — `get_combined_meta_multiplier()` consumed by F1. ChallengeSystem itself is a sub-component of this epic (its quick-spec is locked; this GDD owns its meta-bonus consumption side).
- **History Flag Manager** (hard, read+write) — the era-local vs meta-persistent flag sweep (Core Rule 7) runs through its existing API; this GDD owns the classification, HistoryFlagManager owns the mechanics.
- **Resource Manager** (hard, write) — era-start reset writes 5 defaults (per Final Burnout spec §4.2, with F3d's Sponsor-floor override); `META_HATERS_RESIST` inserts into the Haters growth pipeline (F3c).
- **Action System** (soft, read) — F3a's `META_REACH_MULT` factor at reward resolution; functions identically without this system.
- **Offline Progress System** (soft, read) — F3c's resistance applies in offline simulation (locked scope decision); the offline sim reads one flat factor, nothing per-action.
- **Save/Persistence System** (hard, read+write) — `era_count`, per-type totals, meta-persistent flags; atomicity contract per Edge Cases (save only post-transition, never mid-sequence).

**Depended on by:** none downstream in systems-index — this is the top of the Progression chain. (Cosmetic Persona Customization depends on Class Path, not on this system.)

## Tuning Knobs

All values in `assets/data/balance.json` under a `prestige` key. BurnoutSystem's own knobs (`BURNOUT_THRESHOLD`, `BURNOUT_WARNING_THRESHOLD`, `BURNOUT_DEFER_MORALE_COST`) and ChallengeSystem's catalogue live in their quick-specs' tables — referenced, not duplicated here.

| Knob | Default | Range | What Changes Outside It |
|------|---------|-------|--------------------------|
| `BASE_INCREMENT[type]` (per-type array) | `{0.02, 0.025, 0.015, 3.0}` (reach/sponsor_mult/haters_resist/sponsor_floor) | ±50% | Too low: burnout reward feels ceremonial, era reset reads as pure loss (breaks the "payout, not failure" fantasy). Too high: caps fill in 2-3 eras, killing the long meta-arc |
| `META_CHALLENGE_SCALING_EXPONENT` | 0.5 | 0.3–1.0 | At 1.0: one stacked-challenge Tier-5 burnout consumes most of a cap (pacing collapse). Below 0.3: challenge-stacking barely rewards, undermining ChallengeSystem's entire trade |
| `META_BONUS_MAX[type]` (per-type array) | `{0.50, 0.60, 0.40, 100.0}` | see F2 rationale column | Reach/Sponsor caps too high: permanent inflation dwarfs era-local play. `META_HATERS_RESIST` above ~0.6: approaches zeroing a core resource flow (DDR-0001 #2 territory). Floor cap too high: era-start stops feeling like a reset |
| `era_start_defaults` (5 resources) | Cringe=0, Morale=100, Haters=0, Reach=0, Sponsors=0 (locked, Final Burnout §4.2) | fixed | Owned by the Burnout spec; F3d's floor overrides Sponsors only. Changing Morale=100 interacts with `BURNOUT_DEFER_MORALE_COST` — never tune independently |

**Knob interactions**: `BASE_INCREMENT` × `META_CHALLENGE_SCALING_EXPONENT` × `META_BONUS_MAX` jointly set "eras to cap" — the single most important pacing number this system owns (target: a typical mixed-play player caps their first type in ~8–12 eras; validate in playtest). Tuning any one alone shifts it; economy-designer owns the joint pass (Open Questions).

## Visual/Audio Requirements

**Audio**: none — this game ships with no sound effects or music, permanently (locked project decision, 2026-07-12). No audio hooks needed anywhere in this system, including the Wypalenie card's full-screen emphasis presentation.

**Visual** (per art-bible.md, no new style decisions needed):
- **Burnout warning countdown**: HUD element per `final-burnout-2026-07-01.md`'s `burnout_warning_changed` signal — same visual family as the existing resource pills, but this is a genuine "something is escalating" signal, closer in urgency register to a system-critical indicator than a calm stat readout. Still must NOT use red/danger coloring per Anti-Pillar (no good/bad visual register) — countdown urgency should read through **numeric proximity and/or a neutral pulse rate increase** (reusing `color_activity` token, faster pulse = closer to threshold), never a color shift toward alarm-red.
- **Wypalenie card**: "mechanically identical to a normal card but with different scene/chrome" per the Burnout spec — the differentiation should stay within the locked deadpan-dashboard register (art-bible §1), not escalate into a dramatic/cinematic full-screen treatment that would read as a moral/emotional beat rather than a metric event. Candidate: same card-modal chrome, wider dim-scrim (art-bible §2 Card modal state) to signal "this one is different," no new visual language invented.
- **Challenge Selection screen**: new screen, era-start only. Should reuse the Class Path Panel's card-list vocabulary (art-bible §3 stadium-pill / card-row patterns) rather than inventing a third selection-screen pattern — this project now has two (Class Path Panel, this one); a third distinct pattern would fragment the UI language.
- **Era-summary content** (mentioned in Interactions — reads `best_tier_reached`/`eras_spent_as` for display): no dedicated screen specified yet; candidate to fold into the Challenge Selection screen as a "last era" recap before the new challenge picker, rather than a fifth new screen.

## UI Requirements

- **Burnout warning HUD indicator**: persistent countdown element, appears only when `burnout_warning_changed(true, ...)` fires, shows `seconds_remaining`, disappears if Cringe drops below 100 before the threshold. New UI story per Burnout spec's own note ("HUD wires to this signal — separate UI story, same pattern as `shield_changed`").
- **Wypalenie card presentation**: full-screen emphasis variant of the existing Card UI modal — cannot be dismissed without choosing A or B (no swipe-to-background), Choice B shown greyed with tooltip when already used this era. New UI story, reuses Card UI's existing modal infrastructure per the Burnout spec.
- **Challenge Selection screen** (new): shown immediately after `era_transitioned` fires, before normal play resumes. Displays the challenge catalogue (5 entries per `challenge-era-runs-2026-07-01.md`), lets the player pick 0–`CHALLENGE_MAX_ACTIVE`, confirm button required even for zero selections. Candidate home for the era-summary recap (Visual Requirements above).
- **Meta-bonus visibility**: no dedicated screen specified — the four running `META_BONUS_total[type]` values need to be visible somewhere (candidate: a small permanent-bonuses panel, possibly folded into a future Settings/Profile area, possibly its own row on the Challenge Selection screen). **Not designed here** — flagged as an open UI question below rather than guessed at.

> **📌 UX Flag — Prestige/Checkpoint System**: Three new/modified UI surfaces (burnout countdown, Wypalenie card variant, Challenge Selection screen) plus one undesigned one (meta-bonus visibility). Run `/ux-design` before implementation stories — in particular the meta-bonus visibility question needs a real answer, not a placeholder, since it's the primary way the "permanent progress across eras" fantasy (Player Fantasy section) becomes visible to the player at all.

> **📌 Asset Spec** — Visual requirements above don't introduce new icon needs beyond what Class Path System already flagged (no new asset types), but the Wypalenie card and Challenge Selection screen will need their own chrome once `/ux-design` locks their layout — run `/asset-spec system:prestige-checkpoint-system` at that point.

## Acceptance Criteria

*Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Scope note**: BurnoutSystem and ChallengeSystem each own their own Acceptance Criteria lists (`final-burnout-2026-07-01.md`, `challenge-era-runs-2026-07-01.md`) — not restated here. The criteria below cover only what this GDD newly defines: META_BONUS grant/stacking/caps (F1/F2), the path→type selection rule, the read-before-reset ordering contract, F3a–d's four application points, the flag classification sweep, transition atomicity, and the `inject_priority_card()` contract.

**Testability note**: `PrestigeSystem` (this GDD's new Autoload), `BurnoutSystem`, and `ChallengeSystem` are all unimplemented — specs only. Nearly every criterion below is **BLOCKING against mocked collaborators** (mocked `ClassPathSystem.get_active_path()`/`get_tier()`/`reset_era_state()`, mocked Choice A trigger, mocked `get_combined_meta_multiplier()`, mocked `DecisionCardSystem`, mocked `SaveSystem.save_now()`) — same pattern as `class-path-system.md`'s Era Reset section. These convert to real integration tests once `PrestigeSystem` and collaborators exist, not permanently deferred.

### META_BONUS Grant Magnitude (F1)

- **GIVEN** active path `pato_streamer`, `tier_at_burnout = 1`, `combined_meta_multiplier = 1.0` (no active challenges), **WHEN** Choice A resolves and F1 computes `bonus_increment[META_REACH_MULT]`, **THEN** it equals `0.02` (`0.02 × 1 × 1.0^0.5`). **[Logic — BLOCKING]**
- **GIVEN** `tier_at_burnout = 3`, `combined_meta_multiplier = 2.0`, **THEN** `bonus_increment[META_REACH_MULT] = 0.0849` (`0.02 × 3 × 2.0^0.5`). **[Logic — BLOCKING]**
- **GIVEN** `tier_at_burnout = 5`, `combined_meta_multiplier = 15.0` (`bez_tlumu` 3.0 × `drama_bez_granic` 2.5 × `wypalony_ale_core` 2.0), **THEN** `bonus_increment[META_REACH_MULT] = 0.3873` (`0.02 × 5 × 15.0^0.5`) — roughly 19× the Tier-1 baseline. **[Logic — BLOCKING]**
- **GIVEN** `META_CHALLENGE_SCALING_EXPONENT` is read from `balance.json`, **WHEN** it changes from `0.5` to `1.0` for the same Tier-5/multiplier-15.0 inputs, **THEN** the result changes to `0.02 × 5 × 15.0 = 1.5` (pre-cap) — confirms it's a live tuning knob, not baked into the formula. **[Logic — BLOCKING]**

### META_BONUS Stacking, Caps, and Absorption (F2)

- **GIVEN** `META_REACH_MULT_total_prev = 0.4073`, **WHEN** a further grant of `0.3873` is applied, **THEN** the total clamps to `0.50`, absorbing `0.2946` with no effect and no compensating grant elsewhere. **[Logic — BLOCKING]**
- **GIVEN** `total = 0.0`, **WHEN** two grants (`0.02`, then `0.3873`) resolve in separate eras, **THEN** the running total is `0.02` after the first and `0.4073` after the second — plain additive stacking below the cap. **[Logic — BLOCKING]**
- **GIVEN** a player accepts burnout once while `pato_streamer` is active and once (different era) while `guru_celebryta` is active, **THEN** `META_REACH_MULT_total` and `META_SPONSOR_MULT_total` both hold independent nonzero values simultaneously — neither multiplies into the other. **[Logic — BLOCKING]**
- **GIVEN** `META_HATERS_RESIST_total` is already at cap `0.40`, **WHEN** a further `ekspert_niszowy` burnout grants an increment, **THEN** the total remains exactly `0.40`, no exception. **[Logic — BLOCKING]**
- **GIVEN** all four `META_BONUS_total[type]` are already at their caps, **WHEN** Choice A resolves with a valid active path, **THEN** the burnout still resolves normally (`era_count` increments, resources reset, `era_transitioned` fires) but the grant is fully absorbed with zero effect — no softlock, the trigger is Cringe-driven, not reward-driven. **[Integration — BLOCKING]**

### Bonus Type Selection by Active Path (Core Rule 1/3)

- **GIVEN** Choice A resolves while each of the four paths is, in turn, active, **THEN** the grant targets `META_REACH_MULT` / `META_SPONSOR_MULT` / `META_HATERS_RESIST` / `META_SPONSOR_FLOOR` respectively — never a mismatched type. **[Logic — BLOCKING]**
- **GIVEN** `ClassPathSystem.get_active_path()` returns empty at the exact moment Choice A resolves (no Tier-1 path, or ambiguous per Class Path F5), **WHEN** the burnout resolves, **THEN** no META_BONUS of any type is granted, all four totals remain unchanged, **AND** the era still resets normally — reset is never blocked by the absence of a reward. **[Integration — BLOCKING]**

### Critical Ordering — Read Before Reset (States and Transitions)

- **GIVEN** `pato_streamer` is at Tier 3 when Choice A is confirmed, **WHEN** `PrestigeSystem` processes the transition, **THEN** `get_active_path()`/`get_tier()` are read and captured *before* `reset_era_state()` is invoked — the tier value used in F1's computation is `3`, not `0`, even though `get_tier()` would already return `0` if queried right after reset. **[Integration — BLOCKING]** *Guards against the regression where a naive implementation passively listens to `era_transitioned` for the read and observes already-cleared state, silently granting the wrong bonus or none.*
- **GIVEN** the same transition, **THEN** `era_transitioned` fires only *after* the meta-bonus read+grant step completes — any listener observes already-updated `META_BONUS_total` values. **[Integration — BLOCKING]**
- Choice A's baseline resolution mechanics (resource reset, `era_count` increment, signal shape) are covered by `final-burnout-2026-07-01.md`'s own ACs — this GDD's criteria cover only the *ordering* of the meta-bonus read relative to that resolution.

### F3a–d — Final Reward Stacking Application Points

- **GIVEN** `zrob_drame` (base `10`), `Mult(M)=1.00`, `class_path_multiplier=1.30` (pato T1), `challenge_modifier=1.0`, `META_REACH_MULT_total=0.3873`, **THEN** `final_reach = 18` (`10×1.00×1.30×1.0×1.3873=18.03`→round→18), vs. `13` with Class Path alone. **[Logic — BLOCKING]**
- **GIVEN** the same action with `Mult(M)=0.90`, `challenge_modifier=0.5` (`bez_tlumu`), `META_REACH_MULT_total=0.02`, **THEN** `final_reach = 6` (`10×0.90×1.30×0.5×1.02=5.967`→6) — confirms all four multiplicative layers compose correctly together. **[Logic — BLOCKING]**
- **GIVEN** `base_sponsors_roll=3`, `class_path_sponsor_multiplier=1.20` (guru T1), `META_SPONSOR_MULT_total=0.60` (capped), **THEN** `final_sponsors = 6` (`round(3×1.20×1.60)=round(5.76)=6`), vs. `4` with Class Path alone. **[Logic — BLOCKING against a mocked `class_path_sponsor_multiplier` — no resolution API exists yet, see Open Questions]**
- **GIVEN** `C=80` (`H_rate(C)=0.66`) and `META_HATERS_RESIST_total=0.30`, **THEN** `H_rate_final = 0.462` Haters/min during active play (`0.66×0.70`). **[Logic — BLOCKING]**
- **GIVEN** `META_SPONSOR_FLOOR_total=9.0` at the moment era-start resource reset runs, **THEN** Sponsors is set to `9`, overriding the default `0`. **[Logic — BLOCKING]**
- **GIVEN** `META_SPONSOR_FLOOR_total=0.0`, **THEN** Sponsors is `0`, unchanged from default — confirms the override is conditional. **[Logic — BLOCKING]**

### F3c — Offline/Online Parity Scope (locked decision, 2026-07-12)

- **GIVEN** `META_HATERS_RESIST_total=0.30` and `OfflineProgressSystem.simulate_offline()` runs for an elapsed window, **WHEN** offline Haters growth is computed, **THEN** the accrual is exactly `0.70×` of what the same window produces with `META_HATERS_RESIST_total=0.0` — the resistance applies identically online and offline. **[Integration — BLOCKING]** *Contrast: Class Path's `PATH_MULTIPLIER_OFFLINE=false` and Challenge's Formula-D exclusion both assert offline output is IDENTICAL with or without the system — this asserts offline output DIFFERS by exactly the resistance factor. Intentional divergence per F3c's locked scope, not a bug.*

### Flag Classification Sweep (Core Rule 7)

- **GIVEN** a Choice A transition begins with concrete era-local state (all 5 resources nonzero, `pato_streamer` affiliation `65.0`/tier `3`, `pato_streamer_choices_count=12`, `challenge_active_bez_tlumu` set, `_deferred_this_era=true`), **WHEN** the flag sweep completes, **THEN** all 5 resources are at era-start defaults, Class Path affiliation/tier are zeroed, the counter is `0`, the challenge flag is cleared, and `_deferred_this_era=false`. **[Integration — BLOCKING]**
- **GIVEN** the same transition, **THEN** `era_count` is incremented and preserved, all four `META_BONUS_total[type]` are unchanged, `best_tier_reached`/`eras_spent_as` for `pato_streamer` are preserved, and `burnout_accepted_era_N` (matching the completed era) is set and preserved. **[Integration — BLOCKING]**

### Transition Atomicity

- **GIVEN** the app is killed mid-sequence (after Choice A confirmed, before `save_now()`), **WHEN** the app restarts, **THEN** the restored state is the pre-transition state exactly (`era_count` NOT incremented, no META_BONUS granted, previous era's resources/affiliation intact) with `_card_pending=true`, and the Wypalenie card re-presents on boot. **[Integration — BLOCKING against a mocked `SaveSystem`]**
- **GIVEN** the player re-confirms Choice A after such a restore, **WHEN** the sequence re-runs, **THEN** it executes exactly once from the top — META_BONUS is granted exactly once total across both attempts, no partial-application artifacts survive. **[Integration — BLOCKING]**
- **GIVEN** the app is killed after `era_transitioned` fires but before Challenge Selection is confirmed, **WHEN** the app restarts, **THEN** the era is already transitioned (save happened post-sequence) and the challenge set is either empty (safe default) or whatever was already confirmed — never partially-selected. **[Integration — BLOCKING]**

### `inject_priority_card()` Contract (Core Rule 6)

- **GIVEN** no priority card is pending, **WHEN** `inject_priority_card("final_burnout")` is called, **THEN** it presents on the next available frame, bypassing pool selection, weighting, and cooldown entirely. **[Integration — BLOCKING]**
- **GIVEN** a priority card is pending, **WHEN** a normal pool-selected card would present, **THEN** presentation is blocked until the priority card resolves. **[Integration — BLOCKING]**
- **GIVEN** a priority card is pending, **WHEN** `inject_priority_card()` is called again with a different `card_id`, **THEN** the call is rejected (returns `false`/error), no queueing, the originally pending card remains sole. **[Logic — BLOCKING]**

### Misconfiguration Guard

- **GIVEN** `BASE_INCREMENT[META_REACH_MULT]` is misconfigured to `-0.02` (or `0`), **WHEN** F1 computes a Tier-3 grant, **THEN** it clamps to `max(0.0, computed)=0.0`, no exception, a config warning is logged. **[Logic — BLOCKING]**
- **GIVEN** such a clamped zero grant, **THEN** the running total is unchanged — Core Rule 5's never-reduced guarantee holds even under misconfiguration. **[Logic — BLOCKING]**

### Persistence — Save Migration

- **GIVEN** a save predates this system (no `prestige` key), **WHEN** `PrestigeSystem` initializes, **THEN** `era_count` defaults to `0`, all four `META_BONUS_total[type]` default to `0.0`, no meta-persistent burnout flags exist — same default-on-missing-key pattern as `OnboardingGate`/`SettingsSystem`/Class Path migration. **[Integration — BLOCKING]**

### Story Type Classification (test evidence gating)

Majority are **Logic** — pure formula/state math against mocked inputs: F1's magnitude, F2's stacking/cap, F3a–d's stacking formulas, the path→type mapping, `inject_priority_card`'s second-call rejection, and the misconfiguration clamp. **Integration** where the criterion spans systems, event ordering, or save/restore: the read-before-reset ordering, no-active-path grant suppression, F3c's offline parity, the flag sweep, all transition-atomicity criteria, `inject_priority_card`'s presentation-blocking, and save migration. No UI/Visual criteria yet — UI Requirements and Visual/Audio Requirements are still to be designed below; add ADVISORY criteria once that lands.

**Not tested here by design**: Choice A/B's baseline mechanics and Challenge Selection/modifier math belong to the two locked quick-specs' own ACs — this GDD's criteria only cover the new orchestration/formulas layered on top.

## Open Questions

- **BLOCKING — `class_path_sponsor_multiplier` has no resolution API (F3b)** — Class Path System's `guru_celebryta`/`biznesmen_contentu` T1 Sponsor tier bonuses have no defined hook into card-resolution Sponsor grants; `ClassPathSystem.get_active_multiplier(action_id)` only covers Action-System-driven rewards. This is a pre-existing gap in Class Path System's own Interactions section, surfaced here while writing F3b — not something this GDD can resolve unilaterally. **Same `/propagate-design-change` pass already required for the counter-naming collision (Class Path System Open Questions) should also resolve this** — likely a new `get_active_sponsor_multiplier()` API or an extension of `get_active_multiplier()` to non-action contexts. *Owner: whoever runs that propagation pass, before either GDD's Vertical Slice/Alpha implementation begins.*
- **BLOCKING-before-Alpha — joint pacing tuning pass** — `BASE_INCREMENT` × `META_CHALLENGE_SCALING_EXPONENT` × `META_BONUS_MAX` together determine "eras to cap" (target: ~8-12 eras for a typical mixed-play player, stated as a design intent in Tuning Knobs, not yet validated). Also inherits Class Path System's own open per-path investment normalization question (that pacing feeds how often each META_BONUS type gets granted). *Owner: economy-designer, needs real playtest data on burnout frequency/tier distribution — cannot be resolved from design alone.*
- **Meta-bonus visibility UI is undesigned** (see UI Requirements) — the four permanent `META_BONUS_total[type]` values have no confirmed display surface. This directly affects how legible the "permanent progress across eras" fantasy actually is to the player — not a minor gap. *Owner: next `/ux-design` pass on this system.*
- **Replay-variety concern (partially addressed)** — Class Path System's Open Questions flagged that committing to one path early removes incentive to explore the other three. This GDD's path-typed META_BONUS (Core Rule 3: each path grants a *different* bonus type) creates a real incentive to burn out under different paths across different eras to collect all four types — but does not force variety, and a player who only ever wants `META_REACH_MULT` can still ignore the other three paths forever. Judged a genuine but partial mitigation, not a full resolution. *Owner: revisit after Vertical Slice playtest — if variety still doesn't emerge, consider a stronger incentive (e.g. a 5th "completionist" meta-bonus for having nonzero totals in all four types).*
- **Era-summary screen content is a placeholder concept** (Visual Requirements) — "fold into Challenge Selection as a recap" is a candidate, not a locked decision. *Owner: `/ux-design` pass.*
- **`inject_priority_card()` is designed as single-purpose today** (rejects concurrent calls, Edge Cases) — fine for BurnoutSystem as the only caller, but if a second forced-card mechanic is ever designed, this contract will need revisiting (a real queue, priority ordering, etc.). Not a current problem — flagged so it isn't silently assumed extensible. *Owner: whoever designs the next forced-card mechanic, if one is ever proposed.*
