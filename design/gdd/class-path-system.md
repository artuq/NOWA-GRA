# Class Path System

> **Status**: Designed (revised post-review — see Revision Log below)
> **Author**: user + agents
> **Last Updated**: 2026-07-12
> **Implements Pillar**: Pillar 2 (decyzje mają pamięć), Pillar 3 (satyra przez mechanikę)
> **Creative Director Review (CD-GDD-ALIGN)**: skipped at authoring — full adversarial `/design-review` completed 2026-07-12 (verdict: MAJOR REVISION NEEDED → revised in-session, see log)

## Revision Log

**2026-07-12 — post `/design-review` (full mode, 5 specialists + creative-director synthesis).** Verdict was MAJOR REVISION NEEDED. Two blocking findings drove structural change:

1. **F2 (investment) had zero connection to decision history** — a player could buy a path's Tier 4-5 and signature card using only banked resources, having never made a single path-tagged card choice. This contradicted this GDD's own claim to implement Pillar 2 ("decisions have memory, not points") and inverted the intended satire (economy-designer: spending Cringe — a stat the player wants low anyway — made the most toxic persona the cheapest to buy). **Fix**: investment is now gated on prior card-choice history (Core Rule 4a, F2 updated) — see decision below.
2. **Counter-naming collision with History Flag System** — this GDD assumed `resolve_path_eligibility()` had already been extended to a 4-path registry with counters named `{path_id}_choices_count`, but History Flag System's actual GDD still only registers 2 paths under `risky_choices_count`/`safe_choices_count`. Two contradicting canonical names, each backed by its own tests. **Fix**: this is now explicitly documented as a blocking prerequisite requiring a `/propagate-design-change` pass (see Dependencies and Open Questions) — not silently assumed done.
3. **Invest button interaction model was unspecified** (ux-designer finding). **Fix**: locked to fixed-increment-per-tap (UI Requirements).

Also folded in from the same review: formal signal signatures for `tier_unlocked`/`active_path_changed`, a caveat on Era Reset ACs' dependency on the still-undesigned `BurnoutSystem`, a fix to AC-309's self-contradictory "BLOCKING but not executable" tag, a tuning-knob invariant note (`CARD_CONTRIBUTION_MAX` vs. `TIER_THRESHOLDS[3]`), a float-tolerance note on F4, and several missing acceptance criteria. Open, not-yet-resolved: resource non-equivalence/normalization for F2's per-path rates (needs ActionSystem income-curve data — economy-designer), and the replay-variety concern around "single active path, no stacking" (game-designer — judged real but not identity-breaking, deferred as an Open Question rather than a structural change).

## Overview

Class Path System daje graczowi widoczną warstwę tożsamości zbudowaną na dwóch strukturach danych: float afiliacji per ścieżka [0.0, 100.0] i drabinie tierów (0-5) wyprowadzonej z tego floata. Cztery satyryczne archetypy influencerów — Pato-Streamer Hazardowy, Guru-Celebryta, Ekspert Niszowy, Biznesmen Contentu — są pokazane graczowi od pierwszej minuty, matematycznie odległe, ale nigdy nie ukryte. Decyzje z kart (przez liczniki wzorców HistoryFlagManager) i opcjonalna aktywna inwestycja zasobów popychają afiliację w stronę jednej ścieżki; przekroczenie progów tierów (20/40/60/80/100) odblokowuje mnożniki akcji/zasobów specyficzne dla ścieżki, działające wyłącznie w aktywnej grze (nigdy offline, zgodnie z Pillar 4). Gracz odczuwa ten system jako "kim się staję" — widoczną, wybraną trajektorię, nie ukryty wynik. Wzorzec implementacji (Autoload/sygnał/mnożnik) jest ustalony przez ADR-0010; ten GDD definiuje CO system robi, nie JAK jest podpięty w Godocie.

**Post-review correction**: active investment (F2) is no longer an independent path to affiliation — it now only accelerates a direction the player's card choices have already established (Core Rule 4a). This closes the "buy a persona you never chose" gap identified in review.

## Player Fantasy

*`creative-director` not consulted at authoring — Lean mode. Draft derived from the quick-spec's existing framing plus the locked Beggar's Life model decision (2026-07-01). Revised 2026-07-12 per `/design-review` finding: original wording claimed the player notices the multiplier's effect "before" associating it with a tier, which directly contradicted Core Rule 5's instant tier-unlock notification. Reworded below to separate "knowing" (the notification) from "feeling" (the played experience).*

Gracz czuje dwa splecione uczucia: (1) bezpośrednie — otwierając panel ścieżek, widzi cztery jasno nazwane trajektorie, jedną liczbę afiliacji na każdą, i przycisk "Invest" który natychmiast konwertuje zasób na progres — to poczucie sprawczości, świadomego wyboru tego kim się staje; (2) pośrednie — przekroczenie progu tieru **daje graczowi natychmiastowe powiadomienie CO się odblokowało** (Core Rule 5), ale samo **odczucie JAK to się zmienia tempo gry** — "moje dramy dają teraz więcej zasięgu" — buduje się dopiero w kolejnych minutach gry, przez powtarzalne zauważanie tego samego efektu w praktyce, nie przez czytanie tekstu powiadomienia. Notyfikacja mówi graczowi fakt; granie uczy go konsekwencji. Kluczowe: gra NIGDY nie mówi graczowi że Pato-Streamer jest "zły" a Ekspert Niszowy "dobry" — pokazuje tylko mechanikę i tekst flavour, zostawiając osąd graczowi. To jest satyra strukturalna (Pillar 3): widzisz dokładnie co system nagradza, i mimo to możesz świadomie w to wejść. Model referencyjny: Beggar's Life (wszystkie ścieżki widoczne od startu, nie odkrywane stopniowo).

## Detailed Design

### Core Rules

1. **All four paths are always visible** in the Class Path panel — no path is hidden or locked. The player always knows where they could go before they can get there (Beggar's Life model, locked 2026-07-01).
2. **Affiliation is a float [0.0, 100.0] per path**. Only one path can be in active-tier status (Tier 1+) at a time. A player is "unaffiliated" until any path reaches Tier 1.
3. **Two additive mechanisms push affiliation**: (a) card resolution automatically increments path-tagged pattern counters via HistoryFlagManager (`card_contribution`); (b) the player can actively spend resources to accelerate investment in any path *the player has already begun choosing via cards* (`investment_contribution` — see Core Rule 4a). `affiliation[path] = card_contribution[path] + investment_contribution[path]`, capped at 100.0.
4. **Card contribution alone cannot reach the top of the ladder** — it is capped at `CARD_CONTRIBUTION_MAX` (60.0 default), forcing conscious active investment to cross into the top tiers (Beggar's Life "must consciously invest" principle). **Design invariant** (see Tuning Knobs): `CARD_CONTRIBUTION_MAX` must stay ≥ `TIER_THRESHOLDS[3]` (60.0) for this rule to mean "investment required past Tier 3" as intended — if the cap is tuned below that threshold, the rule's effective meaning shifts to a lower tier; re-validate this invariant whenever either value changes.
5. **Tier boundaries are hard thresholds** (20/40/60/80/100) — crossing one triggers a tier-unlock notification and activates that tier's bonus. Affiliation only increases within an era, matching HistoryFlagManager's pattern-counter immutability contract — tiers cannot be lost mid-era. **Note**: this notification announces the unlock immediately; it does not imply the player consciously feels the multiplier's effect at that same instant (see Player Fantasy).
6. **Only the active path contributes multipliers.** The active path is the highest-affiliation path that has crossed Tier 1 (≥20). If two paths are within `PATH_AFFILIATION_TIE_BREAK_MARGIN` of each other at Tier 1+, no multiplier applies and the UI shows "Ambiguous — keep investing to commit," alongside the numeric gap remaining to resolve it (see UI Requirements — this was a review gap: the margin math must be visible, not just the state label). Secondary paths never stack (prevents multi-path-maxing). *Open Question: this creates a rational incentive to commit to one path immediately and never touch card choices tagged to the other three — flagged as a replay-variety concern in Open Questions, not resolved by a rule change in this pass.*
7. **Path multipliers are active-play only by default** (Pillar 4) — offline simulation uses the same flat formula regardless of path/tier. A `PATH_MULTIPLIER_OFFLINE` flag exists for a future single flat offline-efficiency modifier per tier, off by default, evaluated only after profiling shows it won't confuse offline reports.
8. **No explicit moral score** (Anti-Pillar). Affiliation is shown as a neutral progress bar labeled with tier names — never "good" vs. "evil." The satire lives entirely in flavor text and what the multipliers reward, not in UI framing.
9. **Era reset clears all era-local state** (affiliation, tiers, path-tagged counters, signature cards, active-path multipliers) but writes permanent meta-flags first (`best_tier_reached`, `eras_spent_as`) that persist across eras and feed the Prestige/Checkpoint System's meta-bonus calculation.

#### Core Rule 4a — Investment requires prior card-choice history (added 2026-07-12, post-review)

Active investment in a path is only possible once the player has made **at least one** path-tagged card choice in that path this era, i.e. `card_contribution[path] > 0`. Until then:

- The path's "Invest" control is **disabled** in the Class Path Panel (visibly present — per Core Rule 1, all four paths stay visible — but not interactable, with a short tooltip/label explaining why, e.g. "Make a [Path] choice first").
- No resource is deducted and no affiliation is added if an investment attempt is somehow made against a `card_contribution[path] == 0` path (defensive — the UI should prevent reaching this state, but the system-level rule holds regardless of UI state, same defensive pattern as the at-100.0 case in Edge Cases).

**Why**: this is the direct fix for the review finding that investment let players buy tier progress and signature cards in a path they had never actually chosen via cards — a "points, not memory" mechanic that contradicted this system's Pillar 2 claim. Gating investment on prior card-choice history means active investment is always an *acceleration of a direction the player already established*, not an independent, decision-free path to progress.

#### The Four Paths

| Path (ID) | Tagline | Primary resource pattern | Investment resource | Card counter |
|---|---|---|---|---|
| Pato-Streamer Hazardowy (`pato_streamer`) | "Chaos to content. Hejt to zasięg. Jutro się przepraszam." | High Haters, high Cringe, spiky Reach | Cringe (10/point) | `pato_streamer_choices_count` |
| Guru-Celebryta (`guru_celebryta`) | "Buduję markę. Marka buduje mnie." | High Morale, low Haters, premium Sponsors | Sponsors (5/point) | `guru_celebryta_choices_count` |
| Ekspert Niszowy (`ekspert_niszowy`) | "Tysiąc wiernych fanów warte więcej niż milion przypadkowych." | Slow stable Reach, very low Haters/Cringe | Morale (8/point) | `ekspert_niszowy_choices_count` |
| Biznesmen Contentu (`biznesmen_contentu`) | "Content to produkt. Widzowie to rynek." | Max Sponsors, detached from Morale | Reach (50/point) | `biznesmen_contentu_choices_count` |

> **⚠️ Naming note (blocking, see Dependencies/Open Questions)**: the counter names above (`{path_id}_choices_count`) are **not yet the canonical names** in History Flag System's actual GDD, which still registers only 2 paths under `risky_choices_count`/`safe_choices_count`. This table states Class Path System's intended target naming — it is a required prerequisite, not a completed fact. See Open Questions.

#### Tier Bonuses by Path (T1–T5, thresholds 20/40/60/80/100)

| Tier | Pato-Streamer | Guru-Celebryta | Ekspert Niszowy | Biznesmen Contentu |
|---|---|---|---|---|
| T1 | +30% Reach from "Zrób dramę" | +20% Sponsor income | +15% passive Reach floor | +25% Sponsor income, -10% acquisition cooldown |
| T2 | +25% Haters→Reach conversion | Morale floor raised to 20 | +20% Reach per "Nagraj vloga" | Card-choice Morale costs -25% |
| T3 | "Hazardowi" sponsor tier unlocked | "Przeproś" recovers +50% more Morale | Haters gain rate -30% | Haters→Sponsor conversion enabled |
| T4 | "Zrób dramę" duration -20% | Passive Reach floor 15% of peak | +1 Action Slot | Action unlock cost -20% |
| T5 | Signature card "Viral Moment" | Signature card "Brand Deal of the Century" | Signature card "Kult Niszowy" | Signature card "IPO Influencera" |

Multipliers are **additive within the same resource**, never multiplicative (a future +10% event stacks onto T1 Pato's +30% as +40% total, not ×1.1×1.3).

### States and Transitions

**Per-path tier state** (0–5, monotonic within an era):

| State | Description | Transition |
|---|---|---|
| Tier 0 | Starting state, no bonus | → Tier 1 when affiliation crosses 20.0 |
| Tier 1 | T1 bonus active; HUD indicator appears (first path to reach T1 only) | → Tier 2 at 40.0 |
| Tier 2 | T2 bonus active | → Tier 3 at 60.0 |
| Tier 3 | T3 bonus active (new sponsor tier / mechanic per path) | → Tier 4 at 80.0 |
| Tier 4 | T4 bonus active | → Tier 5 at 100.0 |
| Tier 5 | Signature card added to Decision Card pool | Terminal within the era — no further transition until era reset |

**Era-level transition**: `BurnoutSystem.era_transitioned` fires → `ClassPathSystem.reset_era_state()` runs → all path tiers reset to 0, all affiliation floats reset to 0.0, era-local HistoryFlagManager counters reset to 0, signature cards removed from the Decision Card pool, active-path multipliers deactivated. Meta-persistent flags (`best_tier_reached`, `eras_spent_as`) are written before the reset completes and are never cleared by it.

### Signals (added 2026-07-12, post-review — qa-lead finding: these were used in Acceptance Criteria but never formally defined)

| Signal | Signature | Fires when |
|---|---|---|
| `tier_unlocked` | `tier_unlocked(path_id: StringName, tier: int)` | A path's tier increases (once per tier crossed, even if multiple tiers are crossed in one update — see Acceptance Criteria) |
| `active_path_changed` | `active_path_changed(path_id: StringName)` | The resolved active path changes — including from `∅` (ambiguous/none) to a real path, from a real path to `∅`, or from one path to another |
| `signature_card_unlocked` | `signature_card_unlocked(card_id: StringName)` | A path reaches Tier 5 this era |
| `signature_card_removed` | `signature_card_removed(card_id: StringName)` | A Tier-5 path's signature card is removed (era reset, or — not currently possible mid-era since tiers are monotonic) |

### Interactions with Other Systems

- **HistoryFlagManager** (hard, read+write) — ClassPathSystem reads path-tagged pattern counters (`{path_id}_choices_count`) to compute card contribution; `resolve_path_eligibility()` (extended to the full 4-path registered set, replacing the 2-path stub) remains HistoryFlagManager's query, not ClassPathSystem's — ClassPathSystem owns the affiliation float, HistoryFlagManager owns the counter and eligibility resolution. **This extension is not yet reflected in History Flag System's own GDD — see Open Questions; treat as a blocking prerequisite, not a completed dependency.**
- **Decision Card System** (hard, read+write) — every card resolution with a `path_tag` calls `HistoryFlagManager.increment_counter(path_tag + "_choices_count", 1)`. At Tier 5, ClassPathSystem emits `signature_card_unlocked(card_id)` / `signature_card_removed(card_id)` for DecisionCardSystem to add/remove the path's signature card from the pool. **`path_tag` does not yet exist as a schema field in Card Content Database — same blocking prerequisite as above.**
- **Resource Manager** (soft, read+write) — active investment spends the path's investment resource via the existing `apply_delta()`; no structural change required, but gated per Core Rule 4a.
- **Action System** (soft, read) — queries `ClassPathSystem.get_active_multiplier(action_id) -> float` at action-completion reward resolution time. Returns `1.0` when there is no active path (unaffiliated or ambiguous) or when `action_id` has no bonus under the active path's tier.
- **Burnout System** (hard, signal) — ClassPathSystem listens for `era_transitioned` and runs `reset_era_state()` before the listener chain completes (ordering matters — see Prestige/Checkpoint System, currently paused pending this GDD).
- **Save System** (hard, read+write) — affiliation floats, tier ints, and meta-persistent records (`best_tier_reached`, `eras_spent_as`) are part of the serialize/restore cycle.

## Formulas

*Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode. Re-consulted 2026-07-12 during full `/design-review`.*

Affiliation is computed from two additive contributions, converted to a discrete tier via
hard thresholds, and used to resolve a single active path via a margin-based tie-break. All
formulas below operate per-path (`path ∈ {pato_streamer, guru_celebryta, ekspert_niszowy,
biznesmen_contentu}`) unless otherwise noted, and all are pure functions of current state — no
formula here decreases affiliation or a tier (monotonicity is enforced by the calling code,
per Core Rule 5).

### F1. Card Contribution

`card_contribution[path] = min( choice_count[path] * CARD_AFFILIATION_PER_CHOICE, CARD_CONTRIBUTION_MAX )`

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `choice_count[path]` | int | 0 – unbounded, monotonically non-decreasing within an era | Value of the HistoryFlagManager counter `{path_id}_choices_count`; incremented once per resolved Decision Card tagged with this path |
| `CARD_AFFILIATION_PER_CHOICE` | float (tuning knob) | 2.0 – 8.0 (default 4.0) | Affiliation granted per path-tagged card choice |
| `CARD_CONTRIBUTION_MAX` | float (tuning knob) | 40.0 – 75.0 (default 60.0) | Hard ceiling on affiliation earned from card choices alone |
| `card_contribution[path]` | float | 0.0 – `CARD_CONTRIBUTION_MAX` | Card-derived portion of this path's affiliation |

**Output range**: `[0.0, CARD_CONTRIBUTION_MAX]` — clamped by `min()`. At default values this is `[0.0, 60.0]`. Choices beyond the point where the cap is reached contribute zero additional affiliation; the counter itself keeps incrementing (immutable/monotonic per HistoryFlagManager contract), it simply stops moving `card_contribution`.

**Worked example**: `choice_count = 15`, `CARD_AFFILIATION_PER_CHOICE = 4.0` → `raw = 60.0` → `card_contribution = min(60.0, 60.0) = 60.0` (cap reached exactly at 15 choices). A 16th path-tagged choice still increments `choice_count` to 16, but `card_contribution` remains 60.0. **Note (systems-designer, 2026-07-12)**: this "15 choices" figure holds only at default tuning — at `CARD_AFFILIATION_PER_CHOICE=2.0` it takes 30 choices; at `8.0` it takes 8. Don't treat "15" as a locked design target, only as the default-tuning illustration.

### F2. Investment Contribution (revised 2026-07-12, post-review — see Core Rule 4a)

```
investment_contribution[path] =
  0                                                        if card_contribution[path] == 0
  resource_spent[path] * INVESTMENT_AFFILIATION_RATE[path]  otherwise
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `card_contribution[path]` | float | 0.0 – `CARD_CONTRIBUTION_MAX` (F1 output) | Gate condition — see Core Rule 4a |
| `resource_spent[path]` | float | 0.0 – unbounded, cumulative and monotonic within an era | Total units of this path's investment resource spent via the Invest button this era. Cannot be spent at all while the gate condition above holds (UI disables the control; system rejects the spend defensively even if reached) |
| `INVESTMENT_AFFILIATION_RATE[path]` | float (tuning knob, **per-path**, **canonical stored value — not a derived cost**; see Tuning Knobs note) | path-dependent — see table below | Affiliation granted per unit of investment resource spent |
| `investment_contribution[path]` | float | 0.0 – unbounded (pre-clamp) | Investment-derived portion, before the total-affiliation clamp in F3 |

**Output range**: `0` while gated; otherwise unbounded on its own — always re-clamped by F3's `min(..., 100.0)`. Once `card_contribution[path] + investment_contribution[path]` reaches 100.0, further spend still deducts the resource but yields zero marginal affiliation (Edge Case — Invest button should stop offering marginal-gain preview at that point).

**Design correction vs. quick-spec**: the quick-spec proposed a single global `INVESTMENT_AFFILIATION_RATE = 0.1` for all four paths — this contradicts its own "Investment Cost Scale" table, which prices each path's resource differently (10 Cringe / 5 Sponsors / 8 Morale / 50 Reach per affiliation point; a single global rate can only reproduce one of those four costs). `INVESTMENT_AFFILIATION_RATE` is corrected here to a **per-path array**, derived as the reciprocal of the Investment Cost Scale table:

| Path | Cost per 1 affiliation (quick-spec table) | Derived `INVESTMENT_AFFILIATION_RATE[path]` |
|------|-------------------------------------------|-----------------------------------------------|
| `pato_streamer` | 10 Cringe | 0.1 |
| `guru_celebryta` | 5 Sponsors | 0.2 |
| `ekspert_niszowy` | 8 Morale | 0.125 |
| `biznesmen_contentu` | 50 Reach | 0.02 |

These four derived rates are candidate values only — the underlying "cost per 1 affiliation" figures are economy-design territory (flagged in Open Questions as blocking-before-Alpha, strengthened after review — see below), not locked here.

**Not yet resolved by this revision (economy-designer, 2026-07-12)**: the four investment resources are not economically equivalent — Cringe and Morale are bounded [0,100] meters with feedback effects elsewhere in the economy (Resource System), while Sponsors and Reach are unbounded accumulating stockpiles at very different natural income velocities. A flat "cost per affiliation point" in raw units, without normalizing for each resource's scarcity/income rate, risks making one path (candidate: `pato_streamer`, since spending Cringe may be near-free or even beneficial for a player who wants Cringe low anyway) structurally dominant regardless of the stated rate. Core Rule 4a's history-gate mitigates the worst exploit (buying a path with zero card history) but does **not** by itself fix this economic asymmetry. This requires ActionSystem/`balance.json` income-curve data not available to this GDD pass — remains an explicit Open Question, owner economy-designer, before Alpha.

**Worked example**: `pato_streamer`, `card_contribution = 20.0` (gate satisfied), `resource_spent = 200` Cringe, `RATE = 0.1` → `investment_contribution = 200 * 0.1 = 20.0`.

### F3. Total Affiliation

`affiliation[path] = min( card_contribution[path] + investment_contribution[path], 100.0 )`

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `card_contribution[path]` | float | 0.0 – `CARD_CONTRIBUTION_MAX` (F1 output) | Card-derived contribution |
| `investment_contribution[path]` | float | 0.0 – unbounded (F2 output, pre-clamp) | Investment-derived contribution |
| `affiliation[path]` | float | 0.0 – 100.0 | Canonical value read by `ClassPathSystem.get_affiliation()` |

**Output range**: `[0.0, 100.0]`, hard-clamped. This is the value stored, serialized, and compared against `TIER_THRESHOLDS` in F4.

**Worked example**: continuing F1/F2 — `card_contribution = 60.0`, `investment_contribution = 20.0` → `affiliation = min(80.0, 100.0) = 80.0`.

### F4. Tier Resolution

`tier[path] = max( { t ∈ {0,1,2,3,4,5} | affiliation[path] ≥ TIER_THRESHOLDS[t] } )` where `TIER_THRESHOLDS = [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]`

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `affiliation[path]` | float | 0.0 – 100.0 | F3 output |
| `TIER_THRESHOLDS` | float[6] (constant) | fixed: `[0, 20, 40, 60, 80, 100]` | Inclusive minimum affiliation per tier index |
| `tier[path]` | int | 0 – 5 | Highest tier whose threshold has been met or exceeded |

**Output range**: `[0, 5]`, integer. `tier[path]` is a pure function of `affiliation[path]` at query time; because `affiliation[path]` only increases within an era, `tier[path]` is guaranteed non-decreasing within an era without an explicit clamp.

**Worked example**: `affiliation = 80.0` → largest `t` with `TIER_THRESHOLDS[t] ≤ 80.0` is `t=4` → Tier 4. `affiliation = 79.9` → Tier 3. `affiliation = 100.0` → Tier 5.

**Float-tolerance note (systems-designer, 2026-07-12)**: `affiliation[path]` is a cumulative sum of many discrete float additions (each card choice, each investment spend). Comparisons against `TIER_THRESHOLDS` use `≥`, not exact equality, so no epsilon is needed for correctness — but implementers should be aware a threshold crossing could in principle land a few ULPs short of an intended-exact value after many accumulated spends (e.g. `59.999999999997` instead of `60.0`). Not a defect in this formula, just a note for whoever implements the accumulator: prefer summing in a stable order or rounding to a fixed decimal precision (e.g. 2 decimal places) at write time if this is ever observed in practice.

### F5. Active Path Resolution and Tie-Break

```
E = { p | tier[p] ≥ 1 }                                        (eligible set)

active_path =
  ∅                                    if E = ∅
  p1                                   if |E| = 1, where p1 = argmax_{p ∈ E} affiliation[p]
  p1                                   if |E| ≥ 2 and (a_max − a_2nd) ≥ M
  ∅ ("ambiguous")                      if |E| ≥ 2 and (a_max − a_2nd) < M
```

| Symbol | Type | Range | Description |
|--------|------|-------|--------------|
| `E` | set of path IDs | 0 – 4 elements | Paths currently at Tier 1 or above |
| `a_max` | float | 0.0 – 100.0 | Highest affiliation among eligible paths |
| `a_2nd` | float | 0.0 – 100.0 (undefined if `\|E\| < 2`) | Second-highest affiliation among eligible paths |
| `M` (`PATH_AFFILIATION_TIE_BREAK_MARGIN`) | float (tuning knob) | 2.0 – 10.0 (default 5.0) | Minimum lead `p1` must hold over `p2` to be confirmed as sole active path |
| `active_path` | StringName or `∅` | one of 4 path IDs, or none | Path whose tier multipliers apply; `∅` means "Ambiguous — keep investing to commit" |

**Output range**: one of 4 path IDs, or `∅`. Deterministic given the current affiliation snapshot; recomputed on every card resolution and every successful investment. Since `a_max ≥ a_2nd` always holds by construction, an exact tie always falls into the "ambiguous" branch regardless of `M`. **Verified 2026-07-12 (systems-designer)**: no paradox at `M`'s range extremes (2.0, 10.0) or with 3+ simultaneously eligible paths — `a_2nd` is always the true second-highest across the full eligible set, so a third, lower path never affects the ambiguity check.

**Worked example (ambiguous)**: `pato_streamer=45.0` (T2), `guru_celebryta=42.0` (T2). `diff=3.0 < M(5.0)` → `active_path = ∅`, UI shows "Ambiguous."
**Worked example (resolved)**: same but `guru_celebryta=38.0` → `diff=7.0 ≥ 5.0` → `active_path = pato_streamer`.

### Design Target Validation

**"25 card choices fully fills card contribution to 100"** (quick-spec) does not hold under the quick-spec's own `CARD_CONTRIBUTION_MAX=60.0` cap introduced two paragraphs later — stale text predating the cap. Corrected: **15 card-only choices reach the cap of 60.0 at default tuning — exactly the Tier 3 threshold.** A card-only player reaches Tier 3 but needs active investment for Tier 4-5, matching Core Rule 4 — **provided `CARD_CONTRIBUTION_MAX` stays ≥ 60.0 (see the invariant note under Core Rule 4 and Tuning Knobs)**.

**"Active investment reaches Tier 3 within 30 minutes"**: requires `investment_contribution = 60.0`, which additionally now requires `card_contribution[path] > 0` first per Core Rule 4a (i.e. at least one path-tagged card choice already made). Using F2's derived rates: `pato_streamer` needs 600 Cringe (20/min), `guru_celebryta` 300 Sponsors (10/min), `ekspert_niszowy` 480 Morale (16/min), `biznesmen_contentu` 3000 Reach (100/min). Whether these rates are achievable in a 30-min session depends on ActionSystem/balance.json income curves — outside this section's scope, flagged in Open Questions for economy-designer.

## Edge Cases

*Specialist not consulted at authoring — Lean mode. Re-reviewed 2026-07-12 during full `/design-review` (qa-lead, systems-designer).*

- **If a player invests resources after affiliation is already at 100.0**: the resource is still deducted (the Invest button does not block the transaction), but `investment_contribution` adds zero marginal affiliation (F3's clamp absorbs it). The Invest button's UI should stop showing a ">0 affiliation gain" preview once a path is at 100.0, to avoid implying wasted spend is productive.
- **If a player attempts to invest in a path with `card_contribution[path] == 0`** (added 2026-07-12, Core Rule 4a): the Invest control is disabled in the UI for that path; defensively, even if an investment call somehow reaches the system in this state, no resource is deducted and no affiliation is added. This is distinct from the at-100.0 case above — one is "too late to matter," this one is "too early to be allowed."
- **If two paths are within `PATH_AFFILIATION_TIE_BREAK_MARGIN` of each other at Tier 1+**: no active path is set (F5), no multiplier applies to either, UI shows "Ambiguous — keep investing to commit" plus the numeric gap remaining. This is a known current gap in shipped code — see BUG-003.
- **If a path's `card_contribution` is already at `CARD_CONTRIBUTION_MAX` and the player keeps making path-tagged card choices**: `choice_count` keeps incrementing (HistoryFlagManager counters are immutable/monotonic and must never be capped at the source), but `card_contribution` does not move past the cap — only investment can push affiliation further.
- **If `BurnoutSystem.era_transitioned` fires while a card modal is open**: `reset_era_state()` must not fire mid-resolution of an in-flight card (would desync the path-tag increment from the era it was meant to count toward). Ordering contract: `reset_era_state()` runs only after the current card's resolution (including its `increment_counter` call) fully completes — this is a listener-ordering requirement on `era_transitioned`, not a new state.
- **If the player reaches Tier 5 on a path, then investment continues (they keep spending)**: no further effect — Tier 5 is terminal within the era (States and Transitions). The Invest button remains functional (spend still works, e.g. player wants to bank resources elsewhere) but affiliation cannot exceed 100.0 and no Tier 6 exists.
- **If `PATH_MULTIPLIER_OFFLINE` is toggled true mid-era**: the flag change only affects future offline simulations from that point forward — it does not retroactively recompute prior offline reports. (No retroactive-recompute mechanism exists elsewhere in the game either, e.g. Offline Progress System doesn't replay past sessions.)
- **If a save is loaded from before this system existed (schema migration)**: all affiliation floats default to 0.0, all tiers to 0, no active path — equivalent to a fresh-era unaffiliated state. This must be handled the same way `SaveSystem`'s existing schema-fallback pattern handles other new-field migrations (no special-case logic needed beyond the standard default-on-missing-key pattern already used by `OnboardingGate`/`SettingsSystem`).
- **If the active path's signature card (Tier 5) is present in the Decision Card pool and era resets mid-way through that exact card being displayed to the player**: the card modal is allowed to resolve normally (same ordering contract as above); the signature card is removed from the pool only after the current resolution completes, so the player is never shown a card that "shouldn't exist" mid-interaction.

## Dependencies

**Depends on:**
- **History Flag System** (hard) — reads path-tagged pattern counters (`{path_id}_choices_count`); `resolve_path_eligibility()` (extended to the 4-path registered set) is HistoryFlagManager's query, not owned here. **⚠️ Blocking prerequisite, not yet done**: History Flag System's own GDD still only registers 2 paths under `risky_choices_count`/`safe_choices_count` — see Open Questions.
- **Decision Card System** (hard) — every card needs a `path_tag: StringName` schema field; card resolution triggers the counter increment this system reads. **⚠️ Blocking prerequisite, not yet done**: no such field exists in Card Content Database's current schema — see Open Questions.
- **Resource Manager** (soft) — active investment spends resources via existing `apply_delta()`, gated per Core Rule 4a.
- **Action System** (soft) — reads `get_active_multiplier(action_id)` at reward-resolution time; functions identically (no multiplier) if this system were absent.
- **Save/Persistence System** (hard) — affiliation floats, tiers, and meta-persistent records are part of the serialize/restore cycle.
- **Prestige/Checkpoint System's `BurnoutSystem` component** (hard, signal) — listens for `era_transitioned` to run `reset_era_state()`. **Currently undesigned** (this GDD was authored specifically to unblock it — see Open Questions). Provisional assumption: the signal signature `era_transitioned(new_era: int, meta_bonus_granted: StringName)` from the Final Burnout quick-spec is treated as the expected contract until the Prestige/Checkpoint GDD locks it. **Acceptance Criteria that depend on this signal (Era Reset section) are marked BLOCKING but should be understood as blocking-pending-a-stub — write tests against a mocked `era_transitioned` emitter, not the real undesigned system, same caveat as AC-309 below.**

**Depended on by:**
- **Prestige/Checkpoint System** (Alpha, Designed 2026-07-12) — reads `best_tier_reached[path]` and `eras_spent_as[path]` meta-flags for informational/era-summary UI display only *(corrected 2026-07-13, `/design-review` on `prestige-checkpoint-system.md` found this line contradicted that GDD's own locked Formulas — the actual META_BONUS magnitude formula (F1) reads only live `get_active_path()`/`get_tier()` at burnout time, never these two lifetime-meta flags)*. This is the dependency this GDD exists to unblock.
- **Cosmetic Persona Customization** (Full Vision, undesigned) — expected to read active path for cosmetic-flavor gating (provisional — no contract defined yet, flagged for that system's own GDD).

## Tuning Knobs

All values live in `assets/data/balance.json` under the `class_path` key (matching the existing MVP convention).

| Knob | Default | Range | What Changes Outside It |
|------|---------|-------|--------------------------|
| `CARD_AFFILIATION_PER_CHOICE` | 4.0 | 2.0–8.0 | Too low: path progress feels invisible over normal play. Too high: Tier 5 reachable on card choices alone, defeating Core Rule 4's "active investment required past Tier 3" |
| `CARD_CONTRIBUTION_MAX` | 60.0 | 40.0–75.0 | Too low: active investment feels mandatory too early (friction). Too high: card-only players approach Tier 5 without ever investing (removes agency from the investment mechanic). **Invariant (added 2026-07-12)**: must stay ≥ `TIER_THRESHOLDS[3]` (60.0) for Core Rule 4's "past Tier 3" framing to hold literally — if tuned into the 40.0–59.9 sub-range, Core Rule 4's guarantee silently shifts to "past Tier 2." Re-validate this specific interaction before shipping a tuning change here. |
| `INVESTMENT_AFFILIATION_RATE[path]` (per-path array) | `{0.1, 0.2, 0.125, 0.02}` (pato/guru/ekspert/biznesmen) | path-dependent, ±50% from default | Too low on any path: investing in it feels pointless (economy-designer territory, see Open Questions). Too high: resource-rich players buy tiers instantly, devaluing card-driven progress. **Canonical-value note (systems-designer, 2026-07-12)**: `RATE` (affiliation per resource unit) is the value actually stored and tuned — not "cost per point." If a future balance pass instead stores cost-per-point and derives rate as `1/cost` at runtime, note that a symmetric ±50% swing in cost produces an *asymmetric* swing in rate (−33%/+100%), and a misconfigured `cost=0` would produce `rate=∞`. Tune `RATE` directly; don't reintroduce the cost-table as the stored value. |
| `PATH_AFFILIATION_TIE_BREAK_MARGIN` | 5.0 | 2.0–10.0 | Too low: two-path players resolve to a winner too easily (loses the "ambiguous" tension). Too high: players feel stuck in "Ambiguous" limbo too long even when meaningfully ahead |
| `PATH_MULTIPLIER_OFFLINE` | `false` | bool | Enable only after profiling confirms offline-report complexity from path multipliers doesn't confuse the report's readability (Pillar 4 constraint) |
| `TIER_THRESHOLDS` | `[0, 20, 40, 60, 80, 100]` | fixed structure, values could shift | Changing spacing changes how "gated" progression feels tier-to-tier; asymmetric spacing (e.g. wider gap T4→T5) is a valid future tuning direction not yet explored |

Not duplicated here (owned by History Flag System GDD, referenced not redefined): `margin` (global HistoryFlagManager tie-break, currently 2) and `threshold_min` per path (currently 5, the card-count floor before a path becomes eligible via `resolve_path_eligibility()`).

## Visual/Audio Requirements

**Audio**: none — this game ships with no sound effects or music, permanently (locked project decision, 2026-07-12). No audio hooks needed anywhere in this system.

**Visual** (per art-bible.md, already locked — no new style decisions needed here):
- Four path icons at 32×32, outline+flat-fill style (art-bible §7) — not yet specced; candidate for a future icon wave (semantic concepts: chaotic/spiky mark for Pato-Streamer, polished badge for Guru-Celebryta, small focused mark for Ekspert Niszowy, briefcase/chart mark for Biznesmen Contentu — final silhouettes deferred to `/asset-spec` when this wave is prioritized). **Added 2026-07-12 (ux-designer finding)**: when specced, these 4 icons must pass the same grayscale-distinguishability check already used for the wave-1 resource icons — since color-coding by path is banned (Anti-Pillar), silhouette alone must carry full distinguishability, including for a zero-affiliation "muted" state (must not rely on saturation/color changes alone to signal inactive).
- Affiliation bars use the existing stadium-pill vocabulary (art-bible §3) — a neutral progress-bar fill, NOT a resource-hue-coded fill (Anti-Pillar: no moral-score coloring). Tier-crossing should get a `self_modulate` flash using the existing `color_activity` token (art-bible §4), consistent with how resource pills already flash on change (Juice/Feedback System) — reuses established juice vocabulary rather than inventing new visual feedback.
- HUD indicator: small persistent chip, same visual family as the existing resource pills, sized within the touch-target minimum (art-bible §7 UX correction) even though it's tap-to-navigate rather than a direct action button. **Added 2026-07-12 (ux-designer finding)**: this chip sits alongside 5 existing resource pills on a mobile portrait HUD — the forced touch-target minimum has not yet been checked against that row's layout budget for crowding/wrapping risk. Requires an actual HUD layout pass (not just a size floor) before this ships; flagged as a prerequisite for the `/ux-design` pass already required below, not resolved in this GDD.

## UI Requirements

- **Class Path Panel** (new full screen, not a pop-up — player navigates to it, doesn't have it interrupt play): vertical card list on mobile portrait, four path rows always visible, collapsed-by-default with tap-to-expand detail (full layout already specified in `design/quick-specs/class-path-system-2026-07-01.md` §Path UI — this GDD does not restate the ASCII mockups, they remain the source of truth until a `/ux-design` pass formalizes them).
- **Invest control (locked 2026-07-12, post-review — ux-designer finding: this was previously unspecified)**: fixed-increment-per-tap. Each tap of a path's Invest button spends one fixed unit of that path's investment resource (exact unit size is a tuning value, not specified here — matches the touch-first mobile input model per this project's technical preferences) and shows a live preview of that tap's marginal affiliation gain, recomputed each time the button is shown/refreshed. The preview reads zero and the control becomes visually (not just functionally) disabled in two cases: `card_contribution[path] == 0` (Core Rule 4a gate) and `affiliation[path] == 100.0` (Edge Cases cap) — both must be visually distinguishable from the normal enabled state, not just non-functional.
- **Ambiguous-state gap display (added 2026-07-12, post-review — game-designer + ux-designer convergent finding)**: when the panel shows "Ambiguous — keep investing to commit" for two tied paths, it must also show the numeric gap remaining to resolve the tie (`M − (a_max − a_2nd)`, i.e. how much more lead the front path needs) — showing only the text label without the number was flagged as opaque/frustrating in review.
- **HUD Indicator**: persistent small element on the main HUD's top bar, alongside the existing resource pill row — appears only once any path reaches Tier 1, absent before. Tapping navigates to the Class Path Panel. See Visual Requirements above for the layout-crowding flag.
- Both UI pieces are currently unbuilt (quick-spec's own Alpha vs MVP Scope Split marks the full panel as Vertical Slice+ work; only the MVP's 2-path HUD indicator concept exists, and even that isn't wired into a scene yet per the earlier Settings/Avatar session — needs its own dev-story once prioritized).

> **📌 UX Flag — Class Path System**: This system has real UI requirements (a new full screen + a HUD element) with two specific open UX questions flagged above (ambiguous-gap display, HUD crowding). Per this project's process, run `/ux-design` to create a formal UX spec for the Class Path Panel before writing implementation stories — the quick-spec's ASCII mockups are a strong starting point but aren't a substitute for a proper UX pass with interaction-flow detail.

> **📌 Asset Spec** — Visual requirements above are defined enough to run `/asset-spec system:class-path-system` when this UI wave is prioritized (produces the 4 path icons + any additional chrome as ready-to-paste Nano Banana prompts, following the now-locked outline+flat-fill wave-1/wave-2 pipeline) — remember the grayscale-distinguishability check flagged above.

## Acceptance Criteria

*Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode. Re-reviewed 2026-07-12 during full `/design-review`; several ACs added/fixed below.*

### Affiliation Tracking — Card Contribution (F1)

- **GIVEN** `pato_streamer_choices_count = 0` at era start, **WHEN** 15 Decision Cards tagged `path_tag = "pato_streamer"` resolve consecutively, **THEN** `ClassPathSystem.get_affiliation("pato_streamer")` returns exactly `60.0` (15 × `CARD_AFFILIATION_PER_CHOICE` 4.0 = 60, hitting `CARD_CONTRIBUTION_MAX` exactly). **[Logic — BLOCKING]**
- **GIVEN** `pato_streamer` card contribution is already at the `60.0` cap, **WHEN** a 16th `pato_streamer`-tagged card resolves, **THEN** `HistoryFlagManager.get_counter("pato_streamer_choices_count")` increments to 16 but `get_affiliation("pato_streamer")` remains `60.0`. **[Logic — BLOCKING]**
- **GIVEN** `pato_streamer_choices_count = 5`, **WHEN** `get_affiliation("pato_streamer")` is called, **THEN** it returns `20.0` (5 × 4.0). **[Logic — BLOCKING]**

### Affiliation Tracking — Investment Contribution (F2, per-path rate, gated per Core Rule 4a)

- **GIVEN** `pato_streamer` has `card_contribution = 0` (no path-tagged card choice made yet this era), **WHEN** the player attempts to invest any amount of Cringe into `pato_streamer`, **THEN** no resource is deducted, `investment_contribution["pato_streamer"]` remains `0`, and the Invest control for that path reports itself disabled. **[Logic — BLOCKING]** *(new 2026-07-12, covers Core Rule 4a)*
- **GIVEN** `pato_streamer` has `card_contribution = 20.0` (gate satisfied) and 0 investment contribution, **WHEN** the player invests 200 Cringe, **THEN** `investment_contribution["pato_streamer"]` becomes `20.0` (200 × 0.1). **[Logic — BLOCKING]**
- **GIVEN** the same 200-unit spend is applied to `guru_celebryta` (rate 0.2) and `biznesmen_contentu` (rate 0.02) instead, both with their gate already satisfied, **WHEN** each invest resolves, **THEN** `guru_celebryta` gains `40.0` affiliation and `biznesmen_contentu` gains `4.0` — confirming four independent per-path rates, not one shared global constant. **[Logic — BLOCKING]** *(regression test for the quick-spec's stale single global rate)*
- **GIVEN** a path's total affiliation is already `100.0`, **WHEN** the player invests further resource into it, **THEN** the resource is still deducted via Resource Manager but `get_affiliation(path)` remains `100.0`. **[Integration — BLOCKING]**
- **GIVEN** the player cannot afford a path's investment cost, **WHEN** they tap Invest, **THEN** no resource is deducted and no affiliation change occurs. **[Integration — BLOCKING]**

### Affiliation Tracking — Total Affiliation Clamp (F3)

- **GIVEN** `card_contribution["pato_streamer"] = 60.0` and the player invests enough Cringe to add `50.0` more investment contribution, **WHEN** `get_affiliation("pato_streamer")` is queried, **THEN** it returns `100.0` (`min(60+50, 100) = 100`), not `110`. **[Logic — BLOCKING]**

### Tier Unlocks (F4)

- **GIVEN** a path's affiliation crosses from `19.9` to `20.0`, **WHEN** tier is recomputed, **THEN** `get_tier(path)` returns `1` and `tier_unlocked(path_id, 1)` fires exactly once. **[Logic — BLOCKING]**
- **GIVEN** affiliation `= 79.9`, **THEN** `get_tier(path)` returns `3`; **GIVEN** affiliation `= 80.0`, **THEN** it returns `4`; **GIVEN** affiliation `= 100.0`, **THEN** it returns `5`. **[Logic — BLOCKING]**
- **GIVEN** a path jumps from Tier 0 directly to affiliation `45.0` in one update, **WHEN** tier progression runs, **THEN** `tier_unlocked` fires twice in the same pass — once for Tier 1, once for Tier 2 — never skipping an intermediate tier. **[Logic — BLOCKING]**
- **GIVEN** a path is at Tier 2, **THEN** no code path may ever set `get_tier(path)` back below 2 within the same era. **[Logic — BLOCKING]**

### Active Path Resolution and Tie-Break (F5) — regression coverage for BUG-003

- **GIVEN** `pato_streamer` at Tier 2, affiliation `45.0`, and `guru_celebryta` at Tier 2, affiliation `42.0` (diff `3.0 < M(5.0)`), **WHEN** active path is recomputed, **THEN** `get_active_path()` returns empty ("ambiguous") — **NOT** `pato_streamer`. **[Logic — BLOCKING]** *This is the exact case BUG-003 documents: shipped code's strict `a > best_affil` comparison currently returns `pato_streamer` here, which is the bug.*
- **GIVEN** the same two paths but `guru_celebryta = 38.0` (diff `7.0 ≥ M`), **WHEN** active path is recomputed, **THEN** `get_active_path()` returns `pato_streamer`. **[Logic — BLOCKING]**
- **GIVEN** two paths at Tier 1+ with exactly equal affiliation (diff `= 0.0`), **WHEN** active path is recomputed, **THEN** `get_active_path()` returns empty — exact ties always fall into "ambiguous," regardless of `M`. **[Logic — BLOCKING]**
- **GIVEN** the system is in an ambiguous state, **WHEN** `get_active_multiplier(action_id)` is called for either tied path's action, **THEN** it returns `1.0` for both. **[Logic — BLOCKING]** *(guards against a partial fix where `get_active_path()` returns empty but `get_active_multiplier` still reads a stale internal `_active_path`)*
- **GIVEN** three or more paths are simultaneously at Tier 1+, **WHEN** active path is resolved, **THEN** only the top two affiliations (`a_max`, `a_2nd`) determine ambiguity — a third, lower-affiliation Tier-1+ path never affects the result. **[Logic — BLOCKING]** *(relevant once the system extends past today's 2-path MVP)*
- **GIVEN** an ambiguous state resolves because further investment breaks the tie, **WHEN** the gap crosses the margin threshold, **THEN** `active_path_changed` fires exactly once with the newly-resolved path_id. **[Integration — BLOCKING]**
- **GIVEN** no path has ever reached Tier 1 (`E = ∅`), **THEN** `get_active_path()` returns empty and `get_active_multiplier(action_id)` returns `1.0` for every `action_id`. **[Logic — BLOCKING]** *(new 2026-07-12 — baseline unaffiliated case, previously uncovered)*
- **GIVEN** `pato_streamer` is the resolved active path (Tier 2, no ambiguity) and `ekspert_niszowy` is also at Tier 1 but not tied with `pato_streamer` (diff ≥ M), **WHEN** `get_active_multiplier` is queried for an `ekspert_niszowy`-tier-bonus action, **THEN** it returns `1.0` — `ekspert_niszowy`'s tier bonus never applies while it isn't the active path, confirming secondary paths never stack (Core Rule 6). **[Logic — BLOCKING]** *(new 2026-07-12 — "secondary paths never stack" previously uncovered)*

### Signature Cards (Tier 5)

- **GIVEN** a path's affiliation first reaches `100.0` this era, **WHEN** its tier resolves to 5, **THEN** `ClassPathSystem` emits `signature_card_unlocked(card_id)` exactly once and `DecisionCardSystem`'s pool contains that card afterward. **[Integration — BLOCKING]**
- **GIVEN** era reset fires while a path is at Tier 5, **WHEN** `reset_era_state()` completes, **THEN** `signature_card_removed(card_id)` has been emitted and the card is no longer in the pool. **[Integration — BLOCKING]**

### Era Reset

*Note (added 2026-07-12, qa-lead finding): the following criteria depend on `BurnoutSystem.era_transitioned`, which the Dependencies section flags as provisional (Prestige/Checkpoint System is undesigned). Treat these as BLOCKING against a **mocked** `era_transitioned` emitter — not the real system, which doesn't exist yet — same caveat as AC-309 below.*

- **GIVEN** `era_transitioned` fires with the player at `pato_streamer` Tier 3, affiliation `65.0`, **WHEN** `reset_era_state()` completes, **THEN** `get_affiliation("pato_streamer") == 0.0`, `get_tier("pato_streamer") == 0`, `get_active_path()` is empty, and `HistoryFlagManager.get_counter("pato_streamer_choices_count") == 0`. **[Logic — BLOCKING, against a mocked `era_transitioned` emitter]**
- **GIVEN** the same pre-reset state (Tier 3 reached), **WHEN** reset completes, **THEN** milestone flags `class_path.pato_streamer.best_tier.1/.2/.3` are all set and are **not** cleared by the reset. **[Logic — BLOCKING, against a mocked `era_transitioned` emitter]**
- **GIVEN** `pato_streamer` was the active path at era end, **WHEN** reset completes, **THEN** `class_path.pato_streamer.era_completed` is set. **[Logic — BLOCKING, against a mocked `era_transitioned` emitter]**
- **GIVEN** a Decision Card modal is mid-resolution when `era_transitioned` fires, **WHEN** the card's resolution (including its `increment_counter` call) completes, **THEN** `reset_era_state()` runs only afterward. **[Integration — BLOCKING, against a mocked `era_transitioned` emitter]**
- **GIVEN** a save is loaded that predates this system (schema migration case), **WHEN** `ClassPathSystem` initializes, **THEN** all affiliation floats read `0.0`, all tiers read `0`, and `get_active_path()` returns empty — equivalent to a fresh unaffiliated era, with no special-case migration code beyond the standard default-on-missing-key pattern. **[Integration — BLOCKING]** *(new 2026-07-12 — save-migration edge case previously uncovered)*

### UI

- **GIVEN** the active path is ambiguous, **WHEN** the player opens the Class Path Panel, **THEN** both tied paths' cards show "Ambiguous — keep investing to commit." with the numeric gap remaining, and neither shows an active-tier multiplier. **[UI — ADVISORY, manual walkthrough]**
- **GIVEN** all four paths exist with varying (including zero) affiliation, **WHEN** the Class Path Panel opens, **THEN** all four are visible and legible — none hidden (Core Rule 1). **[UI — ADVISORY]**
- **GIVEN** no path has reached Tier 1, **THEN** the HUD indicator is absent. **GIVEN** a path reaches Tier 1, **THEN** the HUD indicator appears with tier badge + path name. **[UI — ADVISORY]**
- **GIVEN** a path has `card_contribution == 0`, **WHEN** the player views that path's Invest control, **THEN** it renders visually disabled with an explanatory label, not merely non-functional. **[UI — ADVISORY]** *(new 2026-07-12, covers Core Rule 4a's UI surface)*

### Pillar Compliance

- **GIVEN** `PATH_MULTIPLIER_OFFLINE = false` (default), **WHEN** offline simulation runs regardless of active path/tier, **THEN** resulting resource deltas are identical to a simulation with no active path at all (Pillar 4). **[Integration — BLOCKING]**
- **GIVEN** any path/tier state, **THEN** no UI string in the Class Path Panel or HUD contains "dobry"/"zły"/"good"/"evil"/"moral" or an equivalent. **[UI — ADVISORY, text-audit walkthrough]**
- **GIVEN** an arbitrary sequence of card resolutions and investments within one era, **THEN** affiliation for every path is non-decreasing at every step. **[Logic — BLOCKING]**
- **GIVEN** `pato_streamer` is active at T1 (+30% Reach on "Zrób dramę") and a second, independent Reach modifier source also applies +10% to the same action, **WHEN** the action resolves, **THEN** the combined bonus is +40% (additive: `base × 1.40`), never `base × 1.3 × 1.1`. **[Logic — BLOCKING]** — no second modifier source exists in the codebase yet; **implement this test now against a stubbed/mocked second bonus source** (per this project's DI-over-singletons testability standard), rather than deferring it as not-executable. *(Revised 2026-07-12: previously tagged "currently not executable," which qa-lead flagged as a self-contradictory permanently-blocking-on-nothing state — a mocked second source makes it genuinely testable today.)*

### Story Type Classification (test evidence gating)

The large majority are **Logic** — pure formula/state, unit-testable in isolation (F1–F5 core math, tier progression, era-reset state clearing, monotonicity). Reclassified as **Integration** where the criterion inherently spans systems or depends on event ordering: investment resource deduction, signature card pool mutation, the mid-card era-reset ordering contract, offline-simulation parity, save-migration, and the "fires exactly once" signal-timing check. UI criteria are **ADVISORY** manual-walkthrough — the Class Path Panel itself doesn't exist yet (Vertical Slice scope), so those are only executable once that UI ships. **Confirmed 2026-07-12 (qa-lead)**: this classification matches `testing-standards.md`'s gate table (Logic=BLOCKING unit test, Integration=BLOCKING integration/playtest, UI=ADVISORY) — no misclassification found.

**Not tested here by design**: `resolve_path_eligibility()` stays HistoryFlagManager's owned query (per Interactions section) — its tests belong to that system's GDD, not this one.

**BUG-003 relationship**: several F5 criteria will *fail* against the currently shipped MVP code — expected, since BUG-003 is open. These should become the literal acceptance criteria for whatever story closes it.

## Open Questions

- **BLOCKING — counter-name collision with History Flag System** (added 2026-07-12, `/design-review`) — this GDD's `{path_id}_choices_count` naming (`pato_streamer_choices_count` etc.) is not yet the canonical naming in History Flag System's own GDD, which still registers only 2 paths under `risky_choices_count`/`safe_choices_count`. Card Content Database's `counter_increments` schema and the 8 existing risky/safe cards also use the old naming with no `path_tag` field at all. **This must be resolved via a `/propagate-design-change` pass touching History Flag System (registered_paths table + counter rename to the 4-path scheme), Decision Card System (add `path_tag: StringName` to the card schema, described in this GDD's Interactions section), and Card Content Database (retag existing cards) before any implementation story picks up this system.** *Owner: whoever runs that propagation pass — recommended before the Vertical Slice full-4-path implementation story begins. Do not treat the naming in this GDD's tables as already-true upstream.*
- **BLOCKING-before-Alpha — per-path investment economic normalization** (strengthened 2026-07-12, economy-designer) — F2's derived rates (0.1/0.2/0.125/0.02) are reciprocals of the quick-spec's rough "Investment Cost Scale" table, explicitly marked there as "deliberately rough — need a playtest pass before Alpha lock." The four investment resources are not economically fungible (bounded feedback meters vs. unbounded stockpiles at different velocities); flat per-unit pricing risks a structurally dominant path (candidate: `pato_streamer`) independent of the stated rate. Core Rule 4a's history-gate mitigates the "buy a path you never chose" exploit but does not fix this normalization gap. Also flagged: potential sink collision on Sponsors between `guru_celebryta`'s investment cost, the existing Sponsor Shield sink, and the future (undesigned) Team/Staff Management system. *Owner: economy-designer, before Alpha implementation of active investment — needs real ActionSystem/balance.json income-curve data.*
- **Replay-variety concern with "single active path, no stacking"** (added 2026-07-12, game-designer, judged real but not identity-breaking by creative-director) — since affiliation never decays and only one path ever contributes multipliers, the rational strategy is committing to one path immediately and never touching the other three paths' cards again. This may undercut exploring all four satirical personas across replays/eras. No rule change made in this pass — flagged for consideration alongside the Prestige/Checkpoint System design (per-era path variety could become a meta-progression incentive there) or a future revision if playtesting confirms the concern. *Owner: unassigned — revisit at Prestige/Checkpoint System design or post-Vertical-Slice playtest.*
- ~~**This GDD was authored specifically to unblock Prestige/Checkpoint System**~~ — **RESOLVED 2026-07-12**: `design/gdd/prestige-checkpoint-system.md` is now Designed. It reads `best_tier_reached`/`eras_spent_as` for informational/era-summary display only, not as meta-bonus formula inputs *(corrected 2026-07-13 — see Dependencies above; the original wording here overstated the coupling)*.
- **`PATH_MULTIPLIER_OFFLINE` evaluation** — off by default per Pillar 4; the quick-spec defers enabling it until profiling confirms it won't confuse offline-report readability. No target date; revisit once Offline Report Screen has path-aware content to show. *Owner: unassigned, Alpha-tier.*
- **Cosmetic Persona Customization** (systems-index #18, Full Vision, undesigned) is listed as depending on this system, but no contract exists yet for what "active path" means to that system. *Owner: that system's own future `/design-system` pass.*
- **Signature card copy is placeholder** (per quick-spec) — final Polish text for the 4 Tier-5 cards is a narrative-director/writer task deferred to Alpha, not blocking this GDD.
