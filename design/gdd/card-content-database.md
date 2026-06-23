# Card Content Database

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 2 — Decyzje mają pamięć, nie punkty / Pillar 3 — Satyra przez mechanikę

## Overview

Card Content Database to schemat i zawartość kart decyzji moralnych — strukturalna definicja "co to jest karta" (warunki wyzwalania, tekst, opcje wyboru, koszty/nagrody zasobów, flagi do zapisania) oraz konkretna treść MVP (10-15+ kart). To jest czysto danowa warstwa — logika *kiedy* karta się pojawia i *jak* jest wagowana należy do przyszłego Decision Card System, nie tutaj. Dla gracza to jest jednak najbardziej bezpośrednio odczuwalny moment narracyjny w grze: tekst karty i dwie opcje wyboru są tym, co faktycznie czyta i przeżywa, w przeciwieństwie do niewidzialnej infrastruktury Resource System czy History Flag System.

Bez tego systemu Decision Card System nie ma żadnej treści do wyświetlenia — to trzeci fundament, ale jedyny z nich bezpośrednio "czytany" przez gracza.

## Player Fantasy

Karty decyzji są momentem, w którym gracz przestaje optymalizować liczby i zaczyna *wybierać kim jest jako influencer*. Tekst karty (sytuacja, dwie opcje) jest bezpośrednio czytany i przeżywany — to satyryczny rdzeń gry (Pillar 3: satyra przez mechanikę, nie wykład). Pod tą warstwą leży schemat danych (koszty, nagrody, flagi), niewidoczny dla gracza, ale to on gwarantuje, że każda karta ma realną, mechaniczną konsekwencję — gracz czuje "to ja wybrałem, i to coś znaczy", nie "to losowy event bez wagi".

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents (game-designer, narrative-director) not consulted — Lean mode. Review manually before production.*

### Core Rules

**Card schema:**

```yaml
card:
  id: string                    # unique, e.g. "exposed_friend"
  trigger_condition: string     # query expression evaluated by Decision Card System, e.g. "always" or "risky_choices_count >= 3"
  text: string                  # the situation presented to the player
  options: [option_A, option_B] # exactly 2 — Reigns-style binary choice, no more
option:
  label: string                 # short choice text, e.g. "Zrób to dla zasięgów"
  resource_deltas: Dict[string, int]    # e.g. { Zasięgi: +10, Cringe: +15 }
  counter_increments: Dict[string, int] # e.g. { risky_choices_count: 1 }
  milestone_to_set: string?     # optional, e.g. "card.exposed_friend.chosen_risky"
  resolution_reaction: string?  # added by juice-feedback-system.md — short text shown in place
                                 # of the card's question text for payoff_duration() seconds after
                                 # resolution; optional (missing = skip the payoff state, per that
                                 # GDD's Edge Cases). Tone: flat, observational "algorithm logic
                                 # report" — never moralizing, regardless of which option's reaction
                                 # this is (per the no-valence-coding anti-pillar).
```

**Rules:**
1. Every card has **exactly 2 options** — no 1-option or 3+-option cards in MVP (per the Reigns-style reference from `game-concept.md`).
2. `resource_deltas` refers only to resources defined in Resource System (Zasięgi, Cringe, Hatersi, Morale, Sponsorzy) — cards never invent new resources ad-hoc.
3. `counter_increments` refers only to counters registered in History Flag System (`risky_choices_count`, `safe_choices_count`, or future counters registered via the same convention).
4. `milestone_to_set` is optional — used only when a specific choice should be remembered as a one-time narrative fact (e.g., to prevent repetition, or to let another card reference it).
5. A card has no logic for *when* it appears beyond `trigger_condition` as a declarative string — evaluation belongs to Decision Card System.
6. **Not every card is a moral test.** Cards are split into two kinds: **risky/safe cards** (one option increments `risky_choices_count`, the other increments `safe_choices_count`) and **neutral cards** (neither option touches any counter — purely tactical/economic trade-offs). This prevents every decision from being flattened into a binary morality test.

**MVP content (12 cards: 8 risky/safe + 4 neutral) — concrete tuning numbers (per `systems-designer` review, calibrated against Resource System's action-level Cringe delta of -15/+20, scaled ~1.5-2x for card-level narrative beats):**

*Risky/Safe cards (8):*

| ID | Option | Zasięgi | Cringe | Morale | Sponsorzy | Counter / Milestone |
|---|---|---|---|---|---|---|
| `exposed_friend` | A (risky: publish) | +180 | +28 | -10 | — | risky_choices_count +1 |
| `exposed_friend` | B (safe: keep private) | +100 | -8 | +6 | — | safe_choices_count +1 |
| `sponsor_offer_shady` | A (risky: accept) | +160 | +22 | -8 | +3 | risky_choices_count +1 |
| `sponsor_offer_shady` | B (safe: decline) | +90 | -5 | +5 | 0 | safe_choices_count +1 |
| `hater_callout` | A (risky: hit back) | +140 | +25 | -15 | — | risky_choices_count +1 |
| `hater_callout` | B (safe: ignore) | +85 | -6 | +10 | — | safe_choices_count +1 |
| `staged_drama` | A (risky: stage it) | +220 | +35 | -18 | — | risky_choices_count +1, milestone `card.staged_drama.chosen_risky` |
| `staged_drama` | B (safe: tell the truth) | +120 | -15 | +12 | — | safe_choices_count +1 |
| `competitor_drama` | A (risky: clap back) | +170 | +24 | -10 | — | risky_choices_count +1 |
| `competitor_drama` | B (safe: ignore, keep working) | +100 | -8 | +5 | — | safe_choices_count +1 |
| `leaked_dm` | A (risky: deny aggressively) | +190 | +32 | -14 | — | risky_choices_count +1 |
| `leaked_dm` | B (safe: admit and apologize) | +105 | -12 | +10 | — | safe_choices_count +1 |
| `cancel_threat` | A (risky: mock them) | +200 | +30 | -12 | — | risky_choices_count +1 |
| `cancel_threat` | B (safe: apologize sincerely) | +110 | -10 | +8 | — | safe_choices_count +1, milestone `card.cancel_threat.apologized` |
| `apology_tour` | A (risky: ignore reputation drop) | +150 | +20 | -8 | — | risky_choices_count +1 |
| `apology_tour` | B (safe: do an apology tour) | +95 | -5 | +18 | — | safe_choices_count +1 |

*Neutral cards (4 — no counter impact, purely tactical/economic):*

| ID | Option | Zasięgi | Sponsorzy | Morale | Other |
|---|---|---|---|---|---|
| `fan_in_trouble` | A (help on stream) | +60 | -1 | — | — |
| `fan_in_trouble` | B (help privately) | +40 | -1 | +4 | — |
| `brand_deal_choice` | A (Brand X — big Sponsorzy, small Zasięgi cost) | -40 | +3 | — | — |
| `brand_deal_choice` | B (Brand Y — small Sponsorzy, small Zasięgi gain) | +40 | +1 | — | — |
| `algorithm_hack` | A (use it now) | +220 | — | — | one-time |
| `algorithm_hack` | B (save for later) | +60 | — | — | milestone `card.algorithm_hack.saved` (enables a future card) |
| `burnout_warning` | A (push through, one big action) | +130 | — | — | — |
| `burnout_warning` | B (spread into small actions) | — | — | +10 | — |

**Resolved open question (from Resource System GDD): "qualifying card" for Sponsorzy.** Only `sponsor_offer_shady` and `brand_deal_choice` qualify — the only 2 of 12 cards whose premise is directly a sponsor/brand offer. Rule for future cards: "qualifying" = the card's premise is a sponsor/brand/monetization offer, not just "any risky choice."

**Resolution reactions (`resolution_reaction` field, added by `juice-feedback-system.md`) — written for the 3 cards currently used in the vertical slice. Remaining 9 cards' reactions are an Open Question.**

| Card | Option | Resolution Reaction |
|---|---|---|
| `sponsor_offer_shady` | A (risky: accept) | "Sponsorship logged. 3 viewers asked if the product works. 0 received an answer." |
| `sponsor_offer_shady` | B (safe: decline) | "Offer declined. The algorithm notes this and moves on without comment." |
| `hater_callout` | A (risky: hit back) | "Response posted. Engagement up. So is the thread length." |
| `hater_callout` | B (safe: ignore) | "No response posted. The video is still trending without you in it." |
| `fan_in_trouble` | A (help on stream) | "Clip posted. 40,000 people watched a private moment become public." |
| `fan_in_trouble` | B (help privately) | "Message sent. No one else will ever know this happened." |

Tone note: every reaction reports a fact or a number, never a judgment — this is the GDD-level enforcement of `juice-feedback-system.md`'s no-valence-coding rule applied to written content, not just sensory effects.

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `available` | Card's `trigger_condition` is currently true | → `shown` when Decision Card System selects it for display |
| `shown` | Card is displayed to the player, awaiting a choice | → `resolved` when player picks an option |
| `resolved` | Chosen option's effects (resource deltas, counter increments, milestone) have been applied | Terminal for this instance — see Edge Cases for repeatability rules |

### Interactions with Other Systems

- **Resource System** (hard, write) → each resolved option applies its `resource_deltas` directly to Resource System's values
- **History Flag System** (hard, write) → each resolved option applies its `counter_increments` and optional `milestone_to_set`
- **Decision Card System** (downstream, hard, read) → reads the full card schema and MVP content to evaluate `trigger_condition`, select/weight cards for display, and present them to the player; owns all selection/weighting logic not specified here

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

This GDD has no formulas — it is content data, not a simulation system. Each card's `resource_deltas` and `counter_increments` are fixed authored constants, looked up by card `id`, not computed from input variables. A formula format here would be false rigor (`Δ = constant` dressed up). All concrete numbers live in the **MVP content table** under Detailed Design → Core Rules. The one piece of randomized logic in this domain (the Sponsorzy 1-3 roll) is already specified as a constant in Resource System's GDD, not here.

**Calibration note:** card-level Cringe deltas (-18 to +35 across all 12 cards) are deliberately larger than Resource System's action-level Cringe delta (-15 to +20) — cards are narrative beats meant to land harder than a single tapped action, calibrated at roughly 1.5-2x the action ceiling per `systems-designer`'s review.

**Scaling note (forward-compatibility):** flat per-card tuning is sufficient for these 12 MVP cards — no early/late-game scaling formula exists yet, since no GDD currently defines a game-stage variable. If a future meta-progression system adds one, a scaling multiplier could be layered on top of these flat values without restructuring this schema.

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If a card option has a cost (e.g., `brand_deal_choice` A: -40 Zasięgi, `fan_in_trouble`: -1 Sponsorzy) and the player has less than that cost**: Resource System defines no floor for Zasięgi/Sponsorzy (unlike Cringe/Morale, which clamp to 0-100). This is a **gap between this GDD and Resource System** — flagged as an Open Question, not resolved here.
- **If the same card could reappear after being resolved**: by default, cards *without* `milestone_to_set` may repeat (e.g., `hater_callout` is a recurring situation); cards *with* `milestone_to_set` (e.g., `staged_drama`, `cancel_threat`, `algorithm_hack`) should not repeat — but *enforcing* this belongs to Decision Card System; this GDD only declares that the milestone fact exists.
- **If `algorithm_hack` option B sets a milestone "enabling a future card" that doesn't exist in MVP**: this is a deliberate forward hook (Vertical Slice+), not a bug — the milestone is set, but has no effect until some future card queries it. Flagged in Open Questions.
- **If multiple cards have their `trigger_condition` satisfied simultaneously**: this GDD does not resolve which one appears — that is entirely Decision Card System's responsibility (selection/weighting logic).
- **If a card option has no `milestone_to_set` (most options)**: no one-time fact is recorded — only `counter_increments` and `resource_deltas` apply. This is correct, not a gap (milestone is optional by design).

## Dependencies

**Upstream (this system depends on):** None — Foundation layer (per `systems-index.md`), though its values must respect Resource System and History Flag System's existing definitions (resources, counters).

**Downstream (depends on this system):**
- **Decision Card System** (hard) — reads the full card schema and MVP content to evaluate `trigger_condition`, select/weight cards, and present them to the player.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| Per-card Zasięgi delta | 40–220 (see table) | 30–300 | Too low: cards feel weaker than actions, defeats "narrative beat" purpose. Too high: a single card decision dwarfs minutes of active play |
| Per-card Cringe delta | -18 to +35 (see table) | -40 to +40 | Too high: a single card can swing Cringe across multiple Resource System bands at once, undermining "fair core" legibility |
| Risky:Safe Zasięgi ratio per card | 1.4x–1.8x | 1.3x–2.0x | Must stay consistent with the ratio already locked in Resource System's cross-reference note for Action System — diverging here creates an inconsistent risk/reward feel between actions and cards |
| Sponsorzy per qualifying card | 1–3 (sponsor_offer_shady, brand_deal_choice only) | 1–5 | Expanding which cards "qualify" without updating the rule in Core Rules would silently break the resolved Open Question from Resource System |
| Number of MVP cards | 12 | 10–20 | Fewer than 10: card pool feels repetitive quickly. More than 20 for MVP: scope risk flagged in `game-concept.md`'s MVP definition (10-15 cards) |

**Knob interaction:** the Risky:Safe ratio knob here must stay synchronized with Resource System's Action System cross-reference note — if one changes, the other should be revisited to keep the "fair core, unfair world" feel consistent across both actions and cards.

## Visual/Audio Requirements

> *Specialist consulted: `art-director` — category is "Dialogue, quests, lore," mandatory for Visual/Audio.*
> No art bible exists yet (project is pre-production) — this section specifies functional requirements only: what the presentation must communicate and what it must never imply. Concrete style (palette, line weight, font) is deferred to the art bible.

**Presentation and input:**
- Each card is a single full-attention modal: situation `text` displayed prominently, resolved via **swipe gesture** (left = option_A, right = option_B), per the Reigns-style genre reference in `game-concept.md`. **Scope risk note:** swipe gesture recognition is higher technical risk than tap buttons for a 2-4 week MVP — flagged in Open Questions for early technical validation.
- No timer, no auto-resolve — cards wait indefinitely for player input, consistent with Pillar 1 (predictable core, no forced/randomized pressure inside the card itself).

**Resolution feedback:**
- On choice, the card gives a short, clear resolution beat (brief animation + resource counters ticking) before dismissing — "soczystość" belongs at the end of the cycle, not during reading or on every gesture.
- Resolution feedback must communicate **consequence and weight, never moral judgment**. No color-coded good/bad signaling (no red flash for "risky," no green check for "safe"), no iconography implying virtue or sin. Hard constraint from the anti-pillar ("NOT explicit moral score/HUD") and Pillar 3 — the only legitimate signal is in the resource numbers that move, not in card-resolution dressing.
- The 3 milestone-bearing cards (`staged_drama`, `cancel_threat`, `algorithm_hack`) get a visually heavier or slightly longer resolution beat than the other 9, signaling **permanence** ("this will be remembered"), not morality — same color/motion language, just more weight. Applied symmetrically regardless of whether the milestone sits on the risky or safe option (e.g., `cancel_threat`'s milestone is on the *safe* option, `staged_drama`'s is on the *risky* option).

**Card identity (no art bible yet):**
- MVP cards use a small, reusable set of category icons (sponsor-offer, drama/callout, hater, tactical/neutral) tagged per card — minimum visual hierarchy supporting the "Discovery" aesthetic without committing to a full illustration style pre-art-bible.
- No per-card unique illustration in MVP — deliberate scope guard, not an oversight.
- Neutral cards (`fan_in_trouble`, `brand_deal_choice`, `algorithm_hack`, `burnout_warning`) must read visually as *tactical*, not moral — distinguishable at a glance from the 8 risky/safe cards.

**Audio:**
- One distinct, short SFX on card resolution (per `game-concept.md`'s "Moderate" audio needs) — no per-card unique audio for MVP.
- No stinger implies moral judgment (no "wrong answer" buzzer, no "correct" chime) — same reasoning as the visual rule above.

**Out of scope for this GDD:** exact color values, typography, icon art style, animation timings — belong to the future art bible and a UI/UX visual design pass.

📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:card-content-database` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

Cards are the only modal screen in MVP besides the HUD — warrants a dedicated UX spec.

- The swipe gesture needs a visual "drag preview" (the card follows the cursor/finger with a slight tilt) before the player releases their choice — without this feedback, swiping feels uncertain/arbitrary.
- The "commitment threshold" (what % of screen width must be dragged before a choice locks in) must be defined in the UX spec, not here — implementation detail.
- A card must block other UI interactions (HUD, actions) while present — the player cannot "escape" a decision without choosing.

> 📌 **UX Flag — Card Content Database**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` for the decision card screen before writing epics. Stories referencing UI should cite `design/ux/decision-card.md`, not this GDD.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Schema validity:**
- **GIVEN** any of the 12 MVP cards, **WHEN** inspecting `options`, **THEN** it contains exactly 2 entries.
- **GIVEN** any card, **WHEN** inspecting top-level fields, **THEN** `id`, `trigger_condition`, `text`, `options` are all present and non-empty.
- **GIVEN** the full 12-card set, **WHEN** comparing `id` values, **THEN** no two cards share the same `id`.

**resource_deltas / counter_increments contract:**
- **GIVEN** any option, **WHEN** inspecting `resource_deltas`, **THEN** it is present as a Dict[str,int] (empty dict valid, missing field is not).
- **GIVEN** one of the 8 risky/safe pairs, **WHEN** inspecting both options' `counter_increments`, **THEN** exactly one increments `risky_choices_count` by 1 and the other increments `safe_choices_count` by 1 — never both, never neither.
- **GIVEN** one of the 4 neutral cards, **WHEN** inspecting both options, **THEN** `counter_increments` is absent/empty on both, and `resource_deltas` is non-empty on at least one.
- **GIVEN** a risky/safe pair, **WHEN** comparing risky vs safe Zasięgi deltas, **THEN** the ratio is between 1.4x and 1.8x for all 8 pairs.
- **GIVEN** any `counter_increments` entry, **WHEN** inspecting its value, **THEN** it is a positive integer (1, per spec).

**Milestone-bearing cards (3 specific cards):**
- **GIVEN** `staged_drama`, **WHEN** inspecting the risky option, **THEN** `milestone_to_set = "card.staged_drama.chosen_risky"`; the safe option has none.
- **GIVEN** `cancel_threat`, **WHEN** inspecting the safe option, **THEN** `milestone_to_set = "card.cancel_threat.apologized"`; the risky option has none.
- **GIVEN** `algorithm_hack`, **WHEN** inspecting the safe option, **THEN** `milestone_to_set = "card.algorithm_hack.saved"`; the risky option has none.
- **GIVEN** the remaining 9 cards, **WHEN** inspecting all options, **THEN** no `milestone_to_set` is present anywhere.

**Sponsorzy qualifying-card rule:**
- **GIVEN** all 12 cards, **WHEN** inspecting every option's `resource_deltas` for a `Sponsorzy` key, **THEN** it appears only on `sponsor_offer_shady` and `brand_deal_choice` options, absent everywhere else.
- **GIVEN** `sponsor_offer_shady` and `brand_deal_choice`, **WHEN** inspecting their options, **THEN** each has at least one option with `resource_deltas["Sponsorzy"] > 0`.

**Defined edge cases:**
- **GIVEN** an option with a negative `Zasięgi`/`Sponsorzy` value, **WHEN** checking whether this database clamps it, **THEN** the value is accepted and stored as-is — no floor exists at this layer by design (floor behavior is Resource System's open gap, not this GDD's).
- **GIVEN** milestone `card.algorithm_hack.saved`, **WHEN** searching the 12-card set for any `trigger_condition` referencing it, **THEN** no match is found — expected (forward hook), not a defect.
- **GIVEN** the 9 options without `milestone_to_set` outside the 3 milestone-bearing cards (plus the non-milestone option on each of those 3), **WHEN** checking for the field, **THEN** its absence is correct, not missing data.

**Not testable against this GDD alone (depends on undesigned Decision Card System):**
- Milestone non-repetition enforcement — no AC possible until Decision Card System exists.
- Simultaneous `trigger_condition` collision resolution — arbitration logic lives in Decision Card System, not here.
- Resource floor/clamp on negative deltas — real behavior must be tested against Resource System's spec, not this one.
- Runtime application of `resource_deltas` to a player's actual resource pool — this GDD defines the data contract on the card, not the mutation logic; testing "Sponsorzy actually increases by X after this card" belongs to Resource System's runtime, not here.

## Open Questions

- **Should Zasięgi/Sponsorzy have a floor (0)?** — gap between this GDD and Resource System; cards with costs (`brand_deal_choice` A: -40 Zasięgi, `fan_in_trouble`: -1 Sponsorzy) assume sufficient resources. *Owner: Resource System GDD (revision). Target: before Decision Card System.*
- **Technical validation of the swipe gesture before full MVP** — higher risk than tap, a quick technical spike is recommended. *Owner: `/prototype` or a mid-production spike. Target: before `/vertical-slice`.*
- **Which future card will query the `card.algorithm_hack.saved` milestone?** — forward hook with no consumer in MVP. *Owner: future Vertical Slice/Alpha cards. Target: once the card pool grows.*
- **Swipe "commitment threshold"** — implementation detail deferred to `/ux-design`. *Owner: UX spec. Target: before Pre-Production.*
- **Team/equipment upgrade cards** — out of scope for this GDD and for MVP; owned by **Team/Staff Management System** (Alpha tier per `systems-index.md`). No MVP card references team/equipment upgrades. Noted here only as a forward pointer, not duplicated. *Owner: Team/Staff Management GDD. Target: Alpha tier.*
- **`resolution_reaction` content for the remaining 9 cards** — written for `sponsor_offer_shady`, `hater_callout`, `fan_in_trouble` only (the 3 used in the vertical slice). The other 9 (`exposed_friend`, `staged_drama`, `competitor_drama`, `leaked_dm`, `cancel_threat`, `apology_tour`, `brand_deal_choice`, `algorithm_hack`, `burnout_warning`) still need reactions before they can use `juice-feedback-system.md`'s payoff state. *Owner: narrative-director/writer. Target: before the next `/vertical-slice` re-run if those cards enter scope, otherwise before full Production content pass.*
