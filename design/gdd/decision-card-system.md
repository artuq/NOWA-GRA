# Decision Card System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 2 — Decyzje mają pamięć, nie punkty / Pillar 3 — Satyra przez mechanikę

## Overview

Decision Card System to logika selekcji i wagowania kart decyzji — odpowiada na pytania "która karta z Card Content Database powinna się teraz pojawić?" i "jak Cringe wpływa na tę pulę?". Ewaluuje `trigger_condition` każdej karty, stosuje wagowanie zależne od aktualnego poziomu Cringe (przesunięcie w stronę ryzykownych wariantów przy wysokim Cringe), prezentuje wybraną kartę graczowi, a po rozwiązaniu zapisuje `counter_increments`/`milestone_to_set` do History Flag System i `resource_deltas` do Resource System. Dla gracza to moment, w którym pętla idle przerywa się na chwilę refleksji — to jest punkt, w którym satyra (Pillar 3) ma szansę zostać zauważona, nie tylko zoptymalizowana.

Bez tego systemu 12 kart z Card Content Database to martwe dane — nic nie decyduje, kiedy i które się pojawiają.

## Player Fantasy

Gracz bezpośrednio doświadcza karty — czyta sytuację, wybiera opcję, widzi konsekwencję. To jest jedyny moment w grze, gdzie gracz czuje, że **wybiera, kim jest**, nie tylko optymalizuje liczby. Pod tą warstwą leży niewidoczna logika wagowania (Cringe przesuwa pulę kart w stronę ryzykownych wariantów) — gracz nie widzi tego mechanizmu wprost, ale *czuje* jego efekt: gdy gra coraz częściej proponuje ryzykowne karty, to nie przypadek, to konsekwencja jego własnej historii wyborów (Pillar 2). To jest moment, w którym satyra ma szansę "trafić" — gracz może zauważyć, że system go "czyta" i odpowiada na jego wzorzec, dokładnie jak prawdziwy algorytm social media.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents (game-designer, narrative-director) not consulted — Lean mode. Review manually before production.*

### Core Rules

**Cooldown + threshold mechanism:**
1. After a card resolves, a cooldown of 2 completed actions is set.
2. Once the cooldown elapses, on the next action completion, the system checks all cards whose `trigger_condition` is `true` and which are not "exhausted" (see Edge Cases for milestone-bearing cards).
3. From the available pool, **one card is chosen via weighted random selection** (see below) and presented to the player.
4. If no card satisfies `trigger_condition`, the cooldown resets and the check repeats on the next action (no card = no interruption to the loop).

**Weighting mechanism (resolves Resource System's declaration: "Cringe skews the card pool toward risky variants"):**

`weight(card) = base_weight + (current_Cringe / 100) × intensity(card)`

where `intensity(card)` = the risky option's Cringe delta (for risky/safe cards) or `0` (for neutral cards). The higher the player's Cringe, the proportionally more often high-intensity-risk cards appear — but neutral/safe cards are never excluded (`base_weight` is always > 0 for every card).

**Rules:**
1. `trigger_condition` is evaluated as a simple logical expression over counters/resources (`"always"`, `"risky_choices_count >= 3"`, etc.) — Decision Card System implements the parser for these expressions.
2. Cards whose chosen option has `milestone_to_set` cannot reappear once that milestone is already set (checked via `has_milestone()` from History Flag System before adding the card to the pool).
3. On player choice: `resource_deltas` → Resource System, then `counter_increments`/`milestone_to_set` → History Flag System, in that order.

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `cooldown` | Card cannot appear yet | → `checking` after 2 completed actions |
| `checking` | System evaluates `trigger_condition` for all cards | → `presenting` if ≥1 card available; → `cooldown` (reset) if none |
| `presenting` | Chosen card displayed, awaiting player choice | → `resolving` once chosen |
| `resolving` | Effects applied to Resource System and History Flag System | → `cooldown` immediately |

### Interactions with Other Systems

- **Card Content Database** (hard, read) → reads the schema and content of the 12 MVP cards
- **Resource System** (hard, read+write) → reads Cringe for weighting; writes `resource_deltas` on resolution
- **History Flag System** (hard, read+write) → reads `has_milestone()` to filter non-repeatable cards; writes `counter_increments`/`milestone_to_set` on resolution
- **Action System** (upstream, hard) → emits an "action completed" event that drives the cooldown counter

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

**Card Selection Weight** is defined as:

`weight(card) = base_weight + (current_Cringe / 100) × intensity(card)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base weight | base_weight | float | 10 (locked; safe range 5–20) | Flat weight floor every eligible card receives, independent of Cringe or intensity |
| Current Cringe | current_Cringe | int | 0–100 | Player's current Cringe (Resource System) at selection time |
| Card intensity | intensity(card) | int | 0, or 20–35 | Risky option's Cringe delta (per `card_cringe_delta_band`) for risky/safe cards; 0 for neutral cards |
| Card weight | weight(card) | float | [10, 45] given current locked content | Relative selection weight |

**Output Range:** bounded below by `base_weight` (Cringe=0 or neutral card), above by `base_weight + intensity_max` (10+35=45 at Cringe=100). Naturally bounded by Cringe's [0,100] range and the locked `card_cringe_delta_band`.
**Selection probability** = `weight(card) / Σ weight(all eligible cards)`, recomputed each time the eligible pool changes (weighted random draw, not pre-normalized).

**Validated behavior at the extremes (all 12 cards eligible):**

At **Cringe=0**: scaling term is 0 for every card → all weights collapse to `base_weight=10` → uniform 8.33% per card. Variety at low Cringe is guaranteed structurally, not by tuning.

At **Cringe=100** (total pool weight=336):

| Card | Intensity | Weight | Probability |
|---|---|---|---|
| staged_drama | 35 | 45 | 13.4% |
| leaked_dm | 32 | 42 | 12.5% |
| cancel_threat | 30 | 40 | 11.9% |
| exposed_friend | 28 | 38 | 11.3% |
| hater_callout | 25 | 35 | 10.4% |
| competitor_drama | 24 | 34 | 10.1% |
| sponsor_offer_shady | 22 | 32 | 9.5% |
| apology_tour | 20 | 30 | 8.9% |
| (4 neutral cards) | 0 | 10 each | 3.0% each |

Spread at max Cringe is ~4.5x (top card vs. neutral) — a clear steering effect toward drama without making neutral cards unreachable. No cap/normalization needed at current content scale (12 cards); see Tuning Knobs for the guardrail to revisit as more cards are added.

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If the eligible pool is empty after milestone filtering** (all milestone-bearing cards already resolved, nothing else satisfies `trigger_condition`): state returns to `cooldown`, the check repeats on the next action — no card never blocks the loop.
- **If all 12 MVP cards have `trigger_condition = "always"`** (the current state — no MVP card requires a counter threshold): the pool is always full (minus exhausted milestones), so `trigger_condition` filtering is a no-op for MVP; it only becomes active once future cards (Vertical Slice+) use thresholds.
- **If only 1 card remains in the pool** (e.g., 3 of 4 milestone cards already exhausted): weighted selection degenerates to certainty (100% chance) — the formula works without a special case.
- **If the same non-milestone card appears twice in a row** after cooldown: allowed — nothing in this system prevents it; if this proves problematic in testing, it needs revision (flagged in Open Questions).
- **If Cringe=0 and only risky/safe cards happen to be available** (no neutral card eligible): all have `weight = base_weight = 10` — equal odds, no special case needed per the formula.

## Dependencies

**Upstream (this system depends on):**
- **Card Content Database** (hard) — schema and content source.
- **Resource System** (hard) — reads Cringe for weighting, writes `resource_deltas`.
- **History Flag System** (hard) — reads `has_milestone()`, writes `counter_increments`/`milestone_to_set`.
- **Action System** (hard) — "action completed" event drives the cooldown counter.

**Downstream (depends on this system):**
- **Card UI** (hard) — presents the chosen card and captures the player's choice.
- **Onboarding/Tutorial** (hard) — sequences when cards are first introduced relative to the 3 base actions.
- **Class Path System** (hard, Vertical Slice) — relies on this system writing accurate `risky_choices_count`/`safe_choices_count` for its Path Resolution Algorithm.
- **Juice/Feedback System** (hard, Vertical Slice) — provides resolution-beat feedback when a card resolves.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `base_weight` | 10 | 5–20 | Too low: low-Cringe play feels monotone toward whichever card has the lowest intensity. Too high: weighting effect from Cringe becomes negligible, undermining the "Cringe skews the pool" design goal |
| Cooldown (completed actions) | 2 | 1–5 | Too low: cards interrupt the core loop too often, feels noisy. Too high: cards feel rare, weakening the narrative pacing |
| **Guardrail (not yet a knob):** card-count scaling | N/A | — | As more cards are added (Vertical Slice 25+, Full Vision 40+), re-validate that the weight spread (currently ~4.5x at max Cringe) doesn't need a cap/normalization step — revisit this GDD's Formulas section before adding more than ~20 cards |

**Knob interaction:** `base_weight` and individual card `intensity` values (owned by Card Content Database) must be tuned together — changing the Cringe delta band there without revisiting `base_weight` here can silently flatten or exaggerate the weighting effect.

## Visual/Audio Requirements

> *Specialist consulted: `art-director` — category is "Dialogue, quests, lore," mandatory for Visual/Audio. Card *resolution* presentation is fully specified in Card Content Database — this section covers only the *selection/appearance* moment, owned by this GDD.*

- **Uniform entrance regardless of weighting**: a card's appearance must look identical whether it was selected with 8% or 45% probability. Direct extension of the anti-pillar principle (no moral/mechanical color-coding) — if a high-Cringe card had a visually distinct ("warning") entrance, the weighting mechanism would leak through chrome instead of being felt only through the *pattern* of which cards keep appearing (Player Fantasy: the player notices the system "reading" them retrospectively, not announced on arrival).
- **Minimal uniform entrance animation required** (not a flat cut): short slide-in + fade, ~150-200ms, identical for all 12 cards. Gives the cooldown's anticipation a release beat and masks any frame hitch from card-data loading. No variation rules — timing/easing only.
- Full visual treatment of card *content* (text, icons, resolution feedback) remains owned by Card Content Database — not duplicated here.

## UI Requirements

- Decision Card System has no screen of its own — it triggers presentation, but Card UI (future GDD) owns layout/interaction.
- Must expose a clear interface: "here is the chosen card + its content" at the `presenting` transition — Card UI subscribes to this event.
- `checking`/`cooldown` states require no UI at all — invisible background logic.

> 📌 **UX Flag — Decision Card System**: This system triggers UI but doesn't define it. In Phase 4, run `/ux-design` for Card UI (the card presentation screen), not this GDD.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**State transitions:**
- **GIVEN** `cooldown`, **WHEN** 2 actions complete, **THEN** → `checking`.
- **GIVEN** `checking` with ≥1 eligible card, **WHEN** evaluation completes, **THEN** → `presenting` with exactly one card selected.
- **GIVEN** `checking` with 0 eligible cards, **WHEN** evaluation completes, **THEN** → `cooldown` (reset), no card presented.
- **GIVEN** `presenting`, **WHEN** the player chooses, **THEN** → `resolving`.
- **GIVEN** `resolving`, **WHEN** effects applied, **THEN** → `cooldown` immediately.

**Cooldown mechanism:**
- **GIVEN** a card just resolved, **THEN** cooldown requires 2 completed actions before next `checking`.
- **GIVEN** `cooldown` with 1 of 2 actions done, **WHEN** 1 more completes, **THEN** → `checking` (not before).
- **GIVEN** reset to `cooldown` due to empty pool, **WHEN** 2 actions complete from that point, **THEN** → `checking` again — empty pool never permanently halts the loop.

**Weighting at Cringe=0:**
- **GIVEN** Cringe=0, all 12 eligible, **WHEN** weights computed, **THEN** every card = exactly `base_weight`=10.
- **GIVEN** the above, **WHEN** probabilities computed, **THEN** uniform 8.33% each (10/120).

**Weighting at Cringe=100:**
- **GIVEN** Cringe=100, all 12 eligible, **WHEN** weights computed, **THEN** exactly: staged_drama=45, leaked_dm=42, cancel_threat=40, exposed_friend=38, hater_callout=35, competitor_drama=34, sponsor_offer_shady=32, apology_tour=30, each neutral card=10.
- **GIVEN** the above (pool weight=336), **WHEN** probabilities computed, **THEN** exactly: staged_drama=13.4%, leaked_dm=12.5%, cancel_threat=11.9%, exposed_friend=11.3%, hater_callout=10.4%, competitor_drama=10.1%, sponsor_offer_shady=9.5%, apology_tour=8.9%, each neutral=3.0%.
- **GIVEN** Cringe=100, **WHEN** comparing top card (45) to a neutral card (10), **THEN** ratio = 4.5x.

**Milestone exclusion:**
- **GIVEN** a card's chosen option's `milestone_to_set` is already set, **WHEN** the pool is built, **THEN** excluded, zero weight.
- **GIVEN** a card has no `milestone_to_set` (or unset), **WHEN** the pool is built, **THEN** remains eligible regardless of past appearances.

**Defined edge cases:**
- **GIVEN** all milestone cards exhausted and nothing else passes `trigger_condition`, **THEN** pool empty, returns to `cooldown`, retried after next 2 actions.
- **GIVEN** all 12 MVP cards use `trigger_condition="always"`, **THEN** every non-excluded card passes — filtering is a no-op for MVP.
- **GIVEN** exactly 1 card remains eligible, **WHEN** selection runs, **THEN** selected with 100% probability, same formula, no special case.
- **GIVEN** a non-milestone card just resolved, **WHEN** cooldown elapses and `checking` runs again, **THEN** that card may be selected again — no repeat-prevention.
- **GIVEN** Cringe=0, pool contains only risky/safe cards, **WHEN** weights computed, **THEN** all = `base_weight`=10, equal probability.

**Resolution order:**
- **GIVEN** a choice made, **WHEN** entering `resolving`, **THEN** `resource_deltas` applied to Resource System strictly before `counter_increments`/`milestone_to_set` applied to History Flag System.
- **GIVEN** a chosen option has both `resource_deltas` and `milestone_to_set`, **WHEN** resolution completes, **THEN** milestone recorded only after the resource write completes; card becomes excludable starting the next `checking` cycle.

**Not testable against this GDD alone:**
- Card UI behavior (how a "choice" is captured) — Card UI is undesigned; only the state-transition consequence is testable via a mocked choice.
- `trigger_condition` parser semantics beyond `"always"` — no threshold-expression grammar specified yet for MVP.
- Class Path System's consumption of `risky_choices_count`/`safe_choices_count` — those specific counter writes live in Card Content Database's per-card schema, outside this document.
- Action System's "action completed" event contract — cooldown counting is testable in isolation with a mocked event; true integration timing is not testable from this GDD alone.
- Juice/Feedback System resolution-beat hook — no interface defined yet (Vertical Slice).
- Guardrail for >20 cards (Tuning Knobs) — explicitly deferred, no AC possible yet; flagged so it isn't dropped from a future test plan.

## Open Questions

- **Skill tree** — not planned in `systems-index.md`; raised during this session, deferred. *Owner: future `/map-systems` pass. Target: after `/vertical-slice`, if progression depth still feels thin.*
- **Should the same non-milestone card have a minimum gap before repeating?** — currently no restriction, flagged for observation during testing. *Owner: revise this GDD after `/prototype` or playtest. Target: before Vertical Slice.*
- **`trigger_condition` parser for threshold expressions** (e.g., `"risky_choices_count >= 3"`) — grammar undefined, only `"always"` used in MVP. *Owner: this GDD (revision) or `/architecture-decision`. Target: before threshold-gated cards are added in Vertical Slice.*
- **Guardrail at >20 cards** — does the weighting formula need a cap/normalization step at larger pool sizes? *Owner: revisit Formulas as Card Content Database grows. Target: before Alpha (40+ cards).*
- **Risk: satire may not be perceived** (flagged in `systems-index.md` as a Design Risk) — this GDD designs weighting to be "felt" through pattern, not announced — but that requires playtest validation, not just design. *Owner: `/playtest-report` at Vertical Slice.*
