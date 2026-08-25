# Quick Design Spec: Class Path System (Influencer Archetypes)

**Type**: New Small System
**Scope**: Defines the four visible influencer archetypes, affiliation tracking via the existing
HistoryFlagManager, the Beggar's Life-style path UI, tier structure with multipliers, and era
reset semantics. Does **not** implement Prestige/Checkpoint meta-bonuses — this spec is the
design anchor the Prestige/Checkpoint GDD builds around (same relationship as Final Burnout →
Prestige/Checkpoint). Full content authoring (path-specific card text, Tier 5 signature card
copy) deferred to Alpha.
**Date**: 2026-07-01
**Estimated Implementation**: Alpha — full implementation ~3–4 weeks alongside
Prestige/Checkpoint System; Tier 1 MVP subset (affiliation tracking + minimal indicator) can
ship earlier as a Vertical Slice story

---

## Overview

The Class Path System gives the player a visible "what am I becoming?" identity layer. Four
satirical influencer archetypes are shown to the player from minute one — mathematically
distant, but visible. Card decisions and active resource investment shift the player's
affiliation toward one path. Reaching affiliation tiers unlocks path-specific multipliers.

The satirical statement is structural: the player can see "Pato-Streamer Hazardowy" from the
start, understand exactly what it rewards, and choose to pursue it anyway. The game does not
hide the toxic path behind a surprise reveal — it presents all four options clearly and asks
the player to invest in their own archetype. This directly implements Pillar 3 (satyra przez
mechanikę, nie przez wykład) and Pillar 2 (decisions have memory).

This spec extends HistoryFlagManager's existing Path Resolution Algorithm from its current
2-path stub to the full 4-path set, and adds the active-investment and UI layers the GDD
deliberately left to this document.

---

## Core Rules

1. **All four paths are always visible** in the Class Path panel — no path is hidden or locked.
   The player always knows where they could go before they can get there (Beggar's Life model).

2. **Affiliation is a float [0.0, 100.0] per path**. Only one path can be in active-tier
   status (Tier 1+) at a time. A player is "unaffiliated" until any path reaches Tier 1.

3. **Two mechanisms push affiliation**: (a) card resolution automatically increments
   path-tagged pattern counters via HistoryFlagManager; (b) the player can actively spend
   resources to accelerate investment in any path. Both contribute to the same affiliation score.

4. **Tier boundaries are hard thresholds** — reaching 20/40/60/80/100 affiliation on a path
   triggers a tier unlock notification. Affiliation can only increase (monotonically), matching
   the immutability contract of HistoryFlagManager pattern counters.

5. **Path action multipliers are active-play only.** Named ambient effects (Haters growth,
   Morale drain and Morale floor) apply identically in live and offline simulation. Offline
   never replays actions or applies action reward/speed bonuses (superseded 2026-08-05 by
   the canonical GDD and ADR-0020).

6. **No explicit moral score** (Anti-Pillar). The UI shows affiliation as a neutral progress
   bar labeled with tier names, not "good" vs "evil" framing. The satire comes from the flavor
   text and what the multipliers reward.

---

## The Four Paths

### Path 1 — Pato-Streamer Hazardowy
**ID**: `pato_streamer`
**Polish name**: Pato-Streamer Hazardowy
**Tagline** (shown in UI): *"Chaos to content. Hejt to zasięg. Jutro się przepraszam."*
**Satirical flavor**: Maximum short-term engagement at the cost of everything else. Burnout
is your business model. Sponsors are slot machines. This is the path the algorithm rewards and
social norms punish — visible, profitable, self-destructive.

**Primary resource pattern**: High Haters, high Cringe, spiky Reach bursts.
**Card counter this path writes to**: `pato_streamer_choices_count` (risky/drama choices)
**Active investment cost**: Cringe (spend Cringe to buy affiliation — "lean into the chaos")

**Path multipliers by tier**:
| Tier | Threshold | Multiplier / Bonus |
|------|-----------|--------------------|
| 0 | 0 | — (no bonus) |
| 1 | 20 | +30% Reach from "Zrób dramę" action |
| 2 | 40 | +25% Haters income → Reach conversion rate |
| 3 | 60 | Sponsor offers include "hazardowi" sponsor tier (high payout, random variance) |
| 4 | 80 | "Zrób dramę" action duration −20% (faster drama cycle) |
| 5 | 100 | Signature card "Viral Moment" added to Decision Card pool |

---

### Path 2 — Guru-Celebryta
**ID**: `guru_celebryta`
**Polish name**: Guru-Celebryta
**Tagline** (shown in UI): *"Buduję markę. Marka buduje mnie. I tak w kółko."*
**Satirical flavor**: Aspirational, brand-safe, premium. The face of clean content — which
the game reveals costs constant emotional labor and creative compromise. The sponsors love you.
The algorithm is indifferent. Your Morale is the price.

**Primary resource pattern**: High Morale, low Haters, stable Reach, premium Sponsors.
**Card counter this path writes to**: `guru_celebryta_choices_count` (safe/brand-positive choices)
**Active investment cost**: Sponsors (spend Sponsor income to buy affiliation — "invest in
the brand")

**Path multipliers by tier**:
| Tier | Threshold | Multiplier / Bonus |
|------|-----------|--------------------|
| 0 | 0 | — |
| 1 | 20 | +20% Sponsor income across all sponsor slots |
| 2 | 40 | Morale floor raised to 20 (Morale cannot drop below 20 while at Tier 2+) |
| 3 | 60 | "Przeproś w internecie" action recovers +50% more Morale |
| 4 | 80 | Passive Reach floor: Reach never drops below 15% of its session peak |
| 5 | 100 | Signature card "Brand Deal of the Century" added to Decision Card pool |

---

### Path 3 — Ekspert Niszowy
**ID**: `ekspert_niszowy`
**Polish name**: Ekspert Niszowy
**Tagline** (shown in UI): *"Tysiąc wiernych fanów warte więcej niż milion przypadkowych."*
**Satirical flavor**: The counter-culture choice. Rejects virality, builds slow and deep.
Satirically: the game rewards this path, but it's the slowest — and the algorithm doesn't
care about loyalty. A comment on how platforms structurally devalue genuine expertise.

**Primary resource pattern**: Slow but stable Reach growth, very low Haters, very low Cringe,
negligible Sponsor income early but premium Sponsors later.
**Card counter this path writes to**: `ekspert_niszowy_choices_count` (knowledge/craft choices)
**Active investment cost**: Morale (spend Morale to buy affiliation — "invest in craft")

**Path multipliers by tier**:
| Tier | Threshold | Multiplier / Bonus |
|------|-----------|--------------------|
| 0 | 0 | — |
| 1 | 20 | +15% passive Reach floor: Reach never drops below 10% of session peak |
| 2 | 40 | "Nagraj vloga" action generates +20% Reach per cycle |
| 3 | 60 | Haters gain rate reduced by 30% (niche audience filters out trolls) |
| 4 | 80 | One additional Action Slot unlocked (niche expertise = higher output capacity) |
| 5 | 100 | Signature card "Kult Niszowy" added to Decision Card pool |

---

### Path 4 — Biznesmen Contentu
**ID**: `biznesmen_contentu`
**Polish name**: Biznesmen Contentu
**Tagline** (shown in UI): *"Content to produkt. Widzowie to rynek. Emocje to koszty."*
**Satirical flavor**: Pure optimization. The path that treats the audience as a resource to
extract. Sponsors-first, authenticity-last. Satirically: this is the path that looks most
like running a real business — and therefore reveals what the content-business actually is.

**Primary resource pattern**: Maximum Sponsors, moderate Reach, detached from Morale, low
Haters (brand-managed), cold efficiency.
**Card counter this path writes to**: `biznesmen_contentu_choices_count`
(sponsor-maximizing/transactional choices)
**Active investment cost**: Reach (spend Reach to buy affiliation — "monetize your audience")

**Path multipliers by tier**:
| Tier | Threshold | Multiplier / Bonus |
|------|-----------|--------------------|
| 0 | 0 | — |
| 1 | 20 | +25% Sponsor income; Sponsor acquisition cooldown −10% |
| 2 | 40 | Morale costs from card choices reduced by 25% ("emotions are a business expense") |
| 3 | 60 | Haters income → Sponsor conversion: Haters now generate small Sponsor income |
| 4 | 80 | Action unlock cost reduced by 20% (milestone-gated action slots cheaper) |
| 5 | 100 | Signature card "IPO Influencera" added to Decision Card pool |

---

## Path Affiliation Tracking

### Hybrid Model (Flags + Active Investment)

Affiliation on each path is a float [0.0, 100.0] derived from two additive sources:

```
affiliation[path] = card_contribution[path] + investment_contribution[path]
```

Both contributions are capped such that `affiliation[path]` never exceeds 100.0.

**1. Card Contribution (automatic, via HistoryFlagManager)**

Every time a Decision Card resolves with a path-tagged choice, DecisionCardSystem calls:
```
HistoryFlagManager.increment_counter(path_id + "_choices_count", 1)
```

Card contribution formula:
```
card_contribution[path] = get_counter(path_id + "_choices_count") * CARD_AFFILIATION_PER_CHOICE
```

Where `CARD_AFFILIATION_PER_CHOICE` is a tuning knob (default: 4.0). At this default, 25
card choices in a path fully fills card contribution to 100 — but active investment can
accelerate it.

Card contribution is capped at `CARD_CONTRIBUTION_MAX` (default: 60.0). The player cannot
reach Tier 5 on card choices alone — active investment is required to push past Tier 3.
This ensures the Beggar's Life model: the player must consciously invest to reach the top.

**2. Active Investment (explicit resource spend)**

A "Invest" button appears next to each path in the Class Path panel. Spending the path's
investment resource (see path catalogue above) converts directly to affiliation:

```
affiliation_gained = INVESTMENT_RESOURCE_SPENT * INVESTMENT_AFFILIATION_RATE
```

Where `INVESTMENT_AFFILIATION_RATE` is a tuning knob (default: 0.1 per unit of resource).
The cost curve is linear for simplicity. The rate should be tuned so that a player who
actively invests exclusively in one path can reach Tier 3 within a 30-minute session.

**3. Path Resolution Algorithm (extending history-flag-system.md)**

The existing `resolve_path_eligibility()` algorithm in HistoryFlagManager remains the
canonical query for "which path is this player eligible for?" — but Class Path System
extends it to four registered paths using the new `_choices_count` counters:

```
registered_paths = [
  { path: "pato_streamer",       counter: "pato_streamer_choices_count",       threshold_min: 5 },
  { path: "guru_celebryta",      counter: "guru_celebryta_choices_count",      threshold_min: 5 },
  { path: "ekspert_niszowy",     counter: "ekspert_niszowy_choices_count",     threshold_min: 5 },
  { path: "biznesmen_contentu",  counter: "biznesmen_contentu_choices_count",  threshold_min: 5 },
]
```

The `margin = 2` tie-break remains. This replaces the two-path stub currently in
history-flag-system.md's Path Resolution Algorithm.

**Important**: `resolve_path_eligibility()` answers "which path is the player eligible for
based on card pattern?" — it is a query, not the affiliation score. ClassPathSystem owns
the affiliation float; HistoryFlagManager owns the counter and the eligibility resolution.

**4. Active Path vs Affiliation**

A player can have non-zero affiliation on multiple paths simultaneously (they've made
some choices in multiple directions). However, only the path with the highest affiliation
that has crossed Tier 1 (≥20) is considered the "active path" for multiplier purposes.
In case of a tie in affiliation score at Tier 1+, no active path multiplier is applied
until the tie is broken. The UI shows this as "Ambiguous — keep investing to commit."

---

## Path UI (Beggar's Life Style)

### Screen Layout — Class Path Panel

The Class Path Panel is a dedicated screen, accessible from the main HUD via a persistent
tab or button (exact chrome deferred to UI story). It is NOT a pop-up — it is a full panel
that the player navigates to.

On mobile (portrait, small screen), the panel uses a **vertical card list**: four path cards
stacked, each collapsed to a summary row by default, expandable to full detail on tap.

**Collapsed row (always visible, all 4 paths)**:
```
[ Path Icon ]  [ Polish Name ]          [ Tier Badge ]  [ Affiliation Bar ]
  (32px)       Pato-Streamer Haz.         T1              ████░░░░░░  28%
```

**Expanded card (one at a time, tap to expand/collapse)**:
```
┌─────────────────────────────────────────────┐
│ PATO-STREAMER HAZARDOWY                 T1  │
│ "Chaos to content. Hejt to zasięg."         │
├─────────────────────────────────────────────┤
│ Affiliation:  ████████░░  28 / 40 (next T2) │
│                                             │
│ ACTIVE BONUS                                │
│  T1: +30% Reach from "Zrób dramę"  ✓ ACTIVE│
│                                             │
│ NEXT TIER (T2 at 40)                        │
│  +25% Haters → Reach conversion             │
│  Need: 12 more affiliation                  │
│  Ways: ~3 drama cards OR invest Cringe      │
│                                             │
│ [Invest Cringe: 50 → +5 affiliation]        │
│ (You have: 312 Cringe)                      │
└─────────────────────────────────────────────┘
```

**Key UI rules**:
- The "Invest" button is always shown with current resource cost and affiliation gain preview.
  If the player cannot afford, it is greyed with the shortfall shown ("Need 38 more Cringe").
- "Ways to advance" hint updates dynamically based on current card counter velocity (estimated
  remaining decisions based on recent card resolution rate).
- Tier 5 is always shown as a teaser row: "T5 — Signature Card (???)" with a lock icon until
  Tier 4 is reached. On reaching Tier 4, the lock is removed and the signature card name is
  revealed.
- Paths the player has zero affiliation in are shown in a visually muted state (greyed icon,
  muted bar) but are NOT hidden. The tagline is always legible.
- No moral framing anywhere in the UI. "Good"/"Evil" labels do not exist. Only tier names,
  affiliation numbers, and mechanical effects.

### HUD Indicator (persistent, minimal)

A small persistent element on the main HUD shows only the active path name and tier badge:
```
[ T1 Pato-Streamer ]
```
This element appears only after the player reaches Tier 1 on any path. Before Tier 1:
nothing is shown (no "unaffiliated" label). Tapping this indicator navigates to the
Class Path Panel.

---

## Tier Structure and Multipliers

### Tier Thresholds (universal — same for all paths)

| Tier | Affiliation Required | Unlock Event |
|------|---------------------|--------------|
| 0 | 0.0 | Starting state — no bonus |
| 1 | 20.0 | Path-specific T1 bonus activates; HUD indicator appears |
| 2 | 40.0 | Path-specific T2 bonus activates |
| 3 | 60.0 | Path-specific T3 bonus activates (often a new sponsor tier or mechanic) |
| 4 | 80.0 | Path-specific T4 bonus activates |
| 5 | 100.0 | Signature card added to Decision Card pool |

### Multiplier Application Rules

- Multipliers are **additive within the same resource**, not multiplicative. If a future
  system also grants a Reach bonus, the bonuses sum (e.g., T1 Pato +30% + future event +10%
  = +40% total Reach from "Zrób dramę"), never compound.
- Only the **active path** (highest-affiliation path at Tier 1+) contributes multipliers.
  Secondary paths do not stack. This prevents a multi-path-maxing exploit and keeps balance
  tractable.
- Offline progress applies only the active path's named ambient effects. Action reward and
  speed multipliers never apply because offline simulation does not replay actions.
- Tier unlock is permanent within an era. Affiliation cannot decrease, so tiers cannot
  be lost during normal play.

### Signature Cards (Tier 5)

Each path's Tier 5 unlocks one signature card added permanently to the Decision Card pool
for the remainder of the era. Signature cards are high-impact, path-flavored cards that
reinforce the satirical identity of the path:
- **Pato-Streamer**: "Viral Moment" — Reach triples for 60 seconds; Cringe immediately jumps
  to 80.
- **Guru-Celebryta**: "Brand Deal of the Century" — Sponsors +200% for 120 seconds; Morale
  cost: 30.
- **Ekspert Niszowy**: "Kult Niszowy" — Reach floor raised permanently by 5% for this era;
  Haters reduced by 20%.
- **Biznesmen Contentu**: "IPO Influencera" — All Sponsor income doubled for 90 seconds;
  Reach gain paused during this time (you're not making content, you're cashing out).

Signature card copy is placeholder — final Polish text authored in Alpha by narrative-director.

---

## Era Reset Interaction

This section extends the Final Burnout quick-spec's deferred point about "flag classification
(era-local vs meta-persistent)" for path-related state.

### What Resets on Era Transition (Choice A — Accept Burnout)

| State | Reset Behavior |
|-------|----------------|
| `affiliation[path]` (float 0–100) | **Reset to 0.0** for all paths |
| `_active_tier[path]` (int 0–5) | **Reset to 0** for all paths |
| Path-specific pattern counters in HistoryFlagManager (`pato_streamer_choices_count`, etc.) | **Reset to 0** (era-local counters) |
| Signature card in Decision Card pool | **Removed** at era reset |
| Active path multipliers | **Deactivated** (no active path at era start) |

### What Persists Across Eras (Meta-persistent)

| State | Persist Behavior |
|-------|-----------------|
| `best_tier_reached[path]` (int 0–5, per path) | **Preserved** as a meta-record |
| `eras_spent_as[path]` (count of eras where this was the active path) | **Preserved** |
| `burnout_accepted_era_N` milestone flags | Already preserved by Final Burnout spec |

The meta-persistent records (`best_tier_reached`, `eras_spent_as`) are stored as
HistoryFlagManager milestone flags with the naming convention:
`class_path.{path_id}.best_tier.{N}` (set when Tier N is first reached on path_id, never unset).
`class_path.{path_id}.era_completed` (set each era where path_id was the active path at era end).

These meta flags are the input to the Prestige/Checkpoint System's META_BONUS calculation —
exactly how they translate into bonuses is deferred to the Prestige/Checkpoint GDD.

### Path Memory (Narrative Hook)

When a new era begins, if the player's previous era active path is recorded in meta flags,
the era-start screen can surface a flavor line referencing it (e.g., *"Era 2: Zaczynasz od
nowa, ale Algorytm pamięta, kim byłeś."*). This is a narrative-director story, not a
mechanical requirement — flagged here as a hook, implemented in Alpha.

---

## Tuning Knobs

All values in `assets/data/balance.json` under the `class_path` key.

| Knob | Default | Range | What Changes Outside It |
|------|---------|-------|------------------------|
| `CARD_AFFILIATION_PER_CHOICE` | 4.0 | 2.0–8.0 | Too low: path progress feels invisible; too high: Tier 5 reachable on cards alone (invalidates active investment) |
| `CARD_CONTRIBUTION_MAX` | 60.0 | 40.0–75.0 | Too low: active investment feels mandatory (friction); too high: Tier 5 reachable without investing (removes agency) |
| `INVESTMENT_AFFILIATION_RATE` | 0.1 | 0.05–0.2 | Too low: active investment feels pointless; too high: rich players buy tiers instantly (kills card relevance) |
| `PATH_AFFILIATION_TIE_BREAK_MARGIN` | 5.0 | 2.0–10.0 | Too low: two-path players get the higher path bonus too easily; too high: players feel "stuck between paths" too long |
| `margin` (HistoryFlagManager tie-break) | 2 | 1–4 | See history-flag-system.md — set globally, affects 4-path resolution |
| `threshold_min` per path | 5 | 3–10 | See history-flag-system.md — eligibility floor; too low = paths resolve before player has a pattern |

### Investment Cost Scale (per path, in balance.json)

Each path's active investment is priced in its own resource. The cost-per-affiliation-point
should be tuned so that a player with a healthy resource stockpile can buy ~5 affiliation
points per active-session minute spent investing. Starting reference costs (before playtesting):

| Path | Resource | Cost per 1 affiliation |
|------|----------|------------------------|
| pato_streamer | Cringe | 10 Cringe |
| guru_celebryta | Sponsors | 5 Sponsors |
| ekspert_niszowy | Morale | 8 Morale |
| biznesmen_contentu | Reach | 50 Reach |

These are deliberately rough — they need a playtest pass before Alpha lock.

---

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| HistoryFlagManager | 4-path counter registration; `resolve_path_eligibility()` updated from 2-path stub to 4-path | Update registered_paths array in algorithm; add era-reset logic for era-local counters |
| DecisionCardSystem | Each card resolution must increment one `{path_id}_choices_count` counter | Card data schema needs a `path_tag: StringName` field; resolver calls `increment_counter` after resolution |
| ResourceManager | Active investment reads and spends resources | Uses existing `apply_delta()` — no structural change |
| ClassPathSystem (new Autoload) | Owns affiliation floats, tier state, active path resolution, investment logic, signals | New Autoload — see Acceptance Criteria for full API surface |
| SaveSystem | ClassPathSystem state (affiliation, tiers, meta-persistent records) added to serialize/restore cycle | Add at implementation time |
| ActionSystem | Tier multipliers applied to action completion rewards | ClassPathSystem exposes `get_active_multiplier(action_id) → float` — ActionSystem queries it on completion |
| BurnoutSystem | Era reset triggers ClassPathSystem.reset_era_state() | BurnoutSystem emits `era_transitioned` — ClassPathSystem connects to it |
| DecisionCardSystem | Signature cards added/removed from pool | ClassPathSystem emits `signature_card_unlocked(card_id)` / `signature_card_removed(card_id)` signals |
| UI (Class Path Panel) | New screen — all path data, affiliation bars, invest buttons | UI story: wires to ClassPathSystem signals; reads affiliation and tier via ClassPathSystem API |
| UI (HUD Indicator) | Small persistent active-path badge | UI story: wires to `active_path_changed` signal |

---

## Acceptance Criteria

### Affiliation Tracking
- [ ] **GIVEN** a card resolves with `path_tag = "pato_streamer"`, **WHEN** DecisionCardSystem
  completes resolution, **THEN** `HistoryFlagManager.get_counter("pato_streamer_choices_count")`
  increments by 1.
- [ ] **GIVEN** `pato_streamer_choices_count = 5`, **WHEN** `ClassPathSystem.get_affiliation("pato_streamer")`
  is called, **THEN** returns 5 * `CARD_AFFILIATION_PER_CHOICE` (e.g., 20.0 at default 4.0).
- [ ] **GIVEN** card contribution is at `CARD_CONTRIBUTION_MAX`, **THEN** additional card choices
  do not increase affiliation beyond that cap.
- [ ] **GIVEN** player invests 50 Cringe in pato_streamer (at default rate 0.1), **WHEN** invest
  is confirmed, **THEN** affiliation increases by 5.0 and Cringe decreases by 50.
- [ ] **GIVEN** player cannot afford investment cost, **THEN** invest button is greyed and
  non-interactive; no resource is deducted on tap.

### Tier Unlocks
- [ ] **GIVEN** pato_streamer affiliation crosses 20.0, **THEN** `ClassPathSystem.get_tier("pato_streamer")`
  returns 1 and `tier_unlocked(path_id, tier)` signal is emitted.
- [ ] Tiers unlock in order 1→2→3→4→5; no tier can be skipped or set directly.
- [ ] Tier unlock is permanent within an era — affiliation cannot decrease, so tiers cannot
  be lost.

### Active Path and Multipliers
- [ ] **GIVEN** only one path is at Tier 1+, **THEN** that path is the active path and its T1
  multiplier is applied to the relevant action.
- [ ] **GIVEN** two paths are both at Tier 1+ with affiliation within `PATH_AFFILIATION_TIE_BREAK_MARGIN`,
  **THEN** no multiplier is applied and UI shows "Ambiguous — keep investing."
- [ ] **GIVEN** pato_streamer is active at T1, **WHEN** "Zrób dramę" completes, **THEN**
  Reach reward = base * 1.30.
- [ ] **GIVEN** an active path has a named ambient effect, **THEN** live and offline
  simulation apply that effect identically, while action reward/speed bonuses remain live-only.

### UI
- [ ] All four paths are visible in the Class Path Panel at all times, including paths with 0
  affiliation.
- [ ] Collapsed rows show: icon, name, tier badge, affiliation bar.
- [ ] Expanded card shows: current tier bonus (✓ ACTIVE), next tier bonus, affiliation needed,
  invest button with cost and gain preview.
- [ ] Tier 5 bonus is shown as a locked teaser until Tier 4 is reached; at Tier 4, the
  signature card name is revealed.
- [ ] HUD indicator appears only after a path reaches Tier 1; absent before.
- [ ] No moral framing ("good"/"evil"/"toxic") appears anywhere in the UI.

### Era Reset
- [ ] **GIVEN** `era_transitioned` signal is emitted by BurnoutSystem, **WHEN**
  `ClassPathSystem.reset_era_state()` runs, **THEN** all affiliation floats reset to 0.0,
  all tiers reset to 0, all era-local counters in HistoryFlagManager reset to 0.
- [ ] **GIVEN** player reached T3 on pato_streamer before reset, **THEN**
  `class_path.pato_streamer.best_tier.3` milestone flag is set and NOT cleared by reset.
- [ ] **GIVEN** active path at era end, **THEN** `class_path.{path_id}.era_completed`
  milestone flag is set and NOT cleared by reset.

### Pillar Compliance
- [ ] Named ambient path effects apply offline; action reward and speed multipliers do not.
- [ ] No UI element uses the words "good," "evil," "moral," or equivalent Polish equivalents
  as path descriptors (Pillar 3 / Anti-Pillar: no explicit moral score).
- [ ] Path affiliation and tier cannot decrease within an era (Pillar 2: decisions have memory).

---

## Alpha vs MVP Scope Split

### MVP (can ship with 2-path version, upgrading to 4 in Alpha)
- Affiliation tracking for 2 paths (pato_streamer, guru_celebryta) via existing
  HistoryFlagManager stub — the algorithm already supports this.
- Tier 1 and Tier 2 bonuses only.
- Minimal UI: no Class Path Panel; HUD indicator only, showing active path name.
- No active investment mechanic — card contributions only.

### Vertical Slice addition
- Full 4-path registration in HistoryFlagManager.
- Active investment mechanic (Invest button).
- Class Path Panel (collapsed-row view; expanded cards are Alpha).

### Alpha (full spec)
- Full tier structure (T1–T5) for all 4 paths.
- Signature cards (Tier 5).
- Expanded card UI with "ways to advance" hints.
- Era reset with meta-persistent flag writing.
- Narrative hook on era-start screen.

---

## Systems Index / DDR Reference

**Extends**: history-flag-system.md — Path Resolution Algorithm updated from 2-path stub to
4-path full registration. The `margin` and `threshold_min` open questions in that GDD's
Open Questions section are answered here: `margin` remains global (2); `threshold_min`
remains per-path (5 for all four paths at launch), per-path configurable in balance.json.

**Builds toward**: Prestige/Checkpoint System (systems-index.md #17, Alpha) — the
`best_tier_reached` and `eras_spent_as` meta flags written by this system are the primary
inputs to META_BONUS calculation. Prestige/Checkpoint GDD must read this spec for flag
naming conventions.

**Companion spec**: final-burnout-2026-07-01.md — this spec connects to the `era_transitioned`
signal defined there. `ClassPathSystem.reset_era_state()` must be called before `era_transitioned`
listener chain completes.

**DDR-0001 #3 ruling** (milestone-gated action slots): Ekspert Niszowy Tier 4 grants an
additional Action Slot unlock. This interacts with the milestone-gated action slot system
(DDR-0001 #3 / quick-spec cd60055). The exact unlock mechanic (does it bypass the milestone
gate entirely, or reduce the resource cost of an existing gate?) is deferred to the
milestone-gated action slot implementation story — flag for cross-spec review.

**No systems-index.md update required** for this spec alone — ClassPathSystem is a sub-system
of the existing Class Path System entry (#TBD in systems-index.md). Confirm entry exists and
update status to "Specced" when this spec is approved.
