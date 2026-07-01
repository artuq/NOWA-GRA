# Quick Design Spec: Challenge Era Runs

**Type**: New Small System
**Scope**: Defines an optional challenge layer chosen at era-start that imposes ratio-multiplier
penalties on specific action rewards in exchange for a larger meta-bonus at Final Burnout.
Does **not** define meta-bonus content (owned by Prestige/Checkpoint GDD) or the era-start UI
screen (owned by a future UX story).
**Date**: 2026-07-01
**Estimated Implementation**: Design anchor only — full build in Alpha, after
Prestige/Checkpoint System exists and `BurnoutSystem.era_transitioned` is live

## Overview

When a new era begins (immediately after `era_transitioned` fires from BurnoutSystem), the
player is presented with an optional Challenge Selection screen. They may choose zero, one, or
multiple active challenges for the incoming era. Each challenge imposes a **ratio multiplier**
(always > 0, never zero) on a specific action-reward axis — Reach, Cringe delta, or Morale
delta — making the era mechanically harder. In exchange, each active challenge raises the
meta-bonus multiplier the player earns when they next accept Final Burnout. Challenges are
era-local: they reset on every era transition and must be re-chosen each time. Multiple active
challenges stack multiplicatively, rewarding the highest-difficulty runs with the strongest
meta-bonus. This is voluntary, optional, and satirically flavored — the influencer consciously
chooses to make their own life worse for the promise of a bigger payoff later.

## Core Rules

### 1. Timing — When Challenges Are Chosen

1. `BurnoutSystem` emits `era_transitioned(new_era: int, meta_bonus_granted: StringName)`.
2. `ChallengeSystem` (new Autoload) listens for this signal and immediately shows the
   Challenge Selection screen before any other era-start logic resumes.
3. The player may pick **0, 1, or more** challenges from the available pool. Zero = normal run.
4. Once confirmed, selected challenges are stored as era-local history flags (see Rule 3) and
   the screen closes. Normal gameplay resumes.
5. The player cannot add or remove challenges mid-era. The screen is only shown at era-start.

### 2. Challenge Modifier Application

1. Challenge modifiers apply **only at action reward resolution time** — inside ActionSystem,
   after the Morale multiplier (Formula C) is applied, as a second multiplicative pass.
2. The final formula for an action's Reach reward when a challenge affects it:

   `final_reach = base_reach × Mult(M) × challenge_modifier`

   where `challenge_modifier` is the product of all active challenge multipliers that target
   Reach (e.g., two challenges both halving Reach → `0.5 × 0.5 = 0.25×`).

3. Cringe and Morale deltas are **flat lookups** in the reward table (no Morale multiplier
   applies to them). When a challenge modifies a Cringe or Morale delta, the modifier
   scales the declared delta before it is passed to ResourceManager:

   `effective_cringe_delta = declared_cringe_delta × challenge_modifier`

   The result is still subject to ResourceSystem's `clamp(C + delta, 0, 100)` — no special
   handling needed.

4. **Formula D (passive Reach from Haters) is never affected by challenge modifiers.** Passive
   income is offline-safe and must remain unmodified (Pillar 4 — offline is first-class).
   Challenge modifiers are scoped to active action income only.

5. **No modifier may produce a value ≤ 0.** All `challenge_modifier` values are clamped to
   `max(0.05, computed_value)` at application time as a hard safety rail, even if balance.json
   is misconfigured.

### 3. Storage — History Flags

1. On challenge selection confirmation, `ChallengeSystem` writes one era-local
   `HistoryFlagManager` flag per selected challenge, keyed by challenge ID:

   `HistoryFlagManager.set_flag("challenge_active_" + challenge_id)`

   Example: selecting "brak_duszy" writes `"challenge_active_brak_duszy"`.

2. These are era-local flags — cleared on the next `era_transitioned` (same sweep that clears
   other era-local flags, per the classification the Prestige/Checkpoint GDD will own).

3. On era-start, `ChallengeSystem` reads active flags to reconstruct the challenge set for the
   new era (relevant for mid-era save/load).

4. A summary flag records the count and multiplier for quick meta-bonus lookup:

   `HistoryFlagManager.set_flag("challenge_meta_multiplier_" + str(combined_multiplier))`

   This is re-derived from individual challenge flags on restore — the summary flag is a
   convenience cache, not the source of truth.

### 4. Stacking — Multiple Active Challenges

1. If two or more challenges are active simultaneously, their modifiers on the **same axis**
   stack **multiplicatively**:

   Two challenges both applying `0.5×` to `Nagraj vloga` Reach → effective modifier = `0.25×`.

2. Modifiers on **different axes** are independent and apply to their respective reward
   components only.

3. The combined meta-bonus multiplier is also multiplicative:

   `combined_meta_multiplier = product of all active challenges' meta_bonus_multiplier values`

   Example: two challenges each with `meta_bonus_multiplier = 2.0` → combined = `4.0×`.

4. There is no hard cap on the number of simultaneous challenges, but balance.json should
   define `CHALLENGE_MAX_ACTIVE` (default: 3) to limit the selection screen and prevent
   degenerate ultra-hard runs in early Alpha.

### 5. Meta-Bonus Interaction

1. When the player accepts Final Burnout (Choice A), `BurnoutSystem` reads
   `ChallengeSystem.get_combined_meta_multiplier()` and passes it to the meta-bonus grant.
2. The **content** of the meta-bonus (what the multiplier scales) is defined entirely by the
   Prestige/Checkpoint GDD. This spec only defines the multiplier structure.
3. A normal run (zero challenges) has `combined_meta_multiplier = 1.0×` — baseline unchanged.
4. `ChallengeSystem.get_combined_meta_multiplier()` returns 1.0 if no challenge flags are
   active (safe default).

### 6. Persistence

`ChallengeSystem.serialize_state()` / `restore_state()` persists:
- Active challenge IDs for the current era (list of StringName).
- Combined meta-bonus multiplier (float, derived — persisted for quick access).

The active challenge list is also fully reconstructible from HistoryFlagManager flags — the
persisted list is a cache for performance. On restore_state(), `ChallengeSystem` re-reads
flags to verify consistency.

---

## Challenge Catalogue (5 Designed Examples)

Each challenge entry follows the structure:

```
id              — StringName key; also used to derive the HistoryFlag key
name            — Player-visible name (Polish, sardonic influencer register)
flavor          — Satirical description shown on the selection screen
modifier_type   — Which reward axis is affected: reach_multiplier | cringe_multiplier | morale_multiplier
modifier_value  — The ratio multiplier applied (float, > 0, < 1 for harder, > 1 for exotic)
applies_to      — Which action(s) are affected (StringName array, or "all")
meta_bonus_multiplier — How much this challenge scales the era's meta-bonus on accept
```

---

### Challenge 1 — "Influencer bez duszy"

| Field | Value |
|---|---|
| `id` | `"brak_duszy"` |
| Name | Influencer bez duszy |
| Flavor | *"Wiesz że to nie wychodzi dobrze, ale klikasz 'nagraj' i tak. Zasięgi same się zrobią, prawda?"* |
| `modifier_type` | `reach_multiplier` |
| `modifier_value` | `0.3` |
| `applies_to` | `["nagraj_vloga"]` |
| `meta_bonus_multiplier` | `2.0` |

**Design intent:** "Nagraj vloga" — the safe, reliable action — becomes nearly worthless for
active Reach. The player is forced toward "Zrób dramę" or to tolerate slower progression,
leaning on passive Haters income. Satirically: the hollow vlog that exists only to post
something gets exactly the engagement it deserves.

---

### Challenge 2 — "Drama queen bez granic"

| Field | Value |
|---|---|
| `id` | `"drama_bez_granic"` |
| Name | Drama queen bez granic |
| Flavor | *"Zrób dramę, nie żałuj. Twoja publika karmi się bólem — niech karmi się twoim też."* |
| `modifier_type` | `cringe_multiplier` |
| `modifier_value` | `2.0` |
| `applies_to` | `["zrob_drame"]` |
| `meta_bonus_multiplier` | `2.5` |

**Design intent:** "Zrób dramę" now generates Cringe at 2× its declared delta (+20 becomes
effectively +40, clamped to 100 ceiling). The Cringe→Haters→Morale spiral accelerates
dramatically — the action is still rewarding in Reach, but the systemic cost balloons. Pillar 1
holds: the multiplier is visible at era-start, the math is predictable. Satirically: the
influencer who keeps escalating the drama finds the Cringe ceiling arrives faster each time.

**Edge case:** When Cringe is near the ceiling (e.g., C=55), `effective_delta = 40` but
Resource System's clamp ensures `C` never exceeds 100. The modifier amplifies the *declared*
delta before the clamp — it does not override the clamp.

---

### Challenge 3 — "Przeproś, ale nie za bardzo"

| Field | Value |
|---|---|
| `id` | `"przepros_na_niby"` |
| Name | Przeproś, ale nie za bardzo |
| Flavor | *"Publiczny łuk i kilka płaczu-emoji. Morale jak nowe, Cringe... no, prawie."* |
| `modifier_type` | `cringe_multiplier` |
| `modifier_value` | `0.3` |
| `applies_to` | `["przepros_w_internecie"]` |
| `meta_bonus_multiplier` | `1.8` |

**Design intent:** "Przeproś w internecie" normally removes 15 Cringe. Under this challenge,
the declared delta is `-15 × 0.3 = -4.5` (rounded to -5 by ResourceManager). Recovery is
crippled — the player can still apologise but it barely works, trapping them in elevated Cringe
longer and accelerating Haters growth. The Morale bonus from the action is unaffected (modifier
only targets `cringe_multiplier`). Satirically: the apology that addresses nothing changes
nothing.

---

### Challenge 4 — "Bez tłumu nie ma show"

| Field | Value |
|---|---|
| `id` | `"bez_tlumu"` |
| Name | Bez tłumu nie ma show |
| Flavor | *"Hejterzy odeszli. Zostały tylko tysiące pustych kont. Zasięgi wciąż coś znaczą... podobno."* |
| `modifier_type` | `reach_multiplier` |
| `modifier_value` | `0.5` |
| `applies_to` | `"all"` |
| `meta_bonus_multiplier` | `3.0` |

**Design intent:** All three base actions earn 0.5× Reach from active play. Passive Reach from
Haters (Formula D) is **unaffected** — this challenge deliberately shifts the income balance
toward passive sources, forcing the player to lean on the Cringe→Haters→Passive chain.
Strategically, the player may deliberately run high Cringe to maximise Haters and compensate.
Satirically: without an engaged audience, every post into the void earns half of nothing.

**Balance note:** This is the strongest modifier on Reach. At `meta_bonus_multiplier = 3.0` it
is also the single best challenge for meta-bonus hunting. Expect this to be the most popular
pick — that is fine, it is the intended dominant strategy for players prioritising meta
progression.

---

### Challenge 5 — "Wypalony, ale core"

| Field | Value |
|---|---|
| `id` | `"wypalony_ale_core"` |
| Name | Wypalony, ale core |
| Flavor | *"Tworzysz content bez radości od pierwszego dnia ery. Morale startuje niżej. Deal?"* |
| `modifier_type` | `morale_multiplier` |
| `modifier_value` | `0.6` |
| `applies_to` | `["przepros_w_internecie"]` |
| `meta_bonus_multiplier` | `2.0` |

**Design intent:** "Przeproś w internecie" normally grants +5 Morale. Under this challenge,
effective Morale recovery is `+5 × 0.6 = +3` (rounded). The recovery action still works — it
can still pull the player out of low bands — but it is slower. The player must apologyse more
frequently to maintain the same Morale floor. Pair this with "drama_bez_granic" for a combined
multiplier of `4.0×` and a run where recovery is slow while Cringe escalates fast. Satirically:
the creator who long ago stopped finding joy in their work can barely fake the enthusiasm for a
proper apology.

---

## Tuning Knobs

| Knob | Default | Range | Category | Rationale |
|------|---------|-------|----------|-----------|
| `CHALLENGE_MAX_ACTIVE` | 3 | 1–5 | gate | Caps UI complexity and prevents multiplicative stacking from creating nonsense runs in early Alpha |
| `brak_duszy.modifier_value` | 0.3 | 0.1–0.7 | balance | Below 0.1: `Nagraj vloga` becomes so weak it is never worth pressing. Above 0.7: challenge barely felt |
| `drama_bez_granic.modifier_value` | 2.0 | 1.5–4.0 | balance | Below 1.5: negligible extra pressure. Above 4.0: single drama action hits Cringe ceiling immediately, removing strategic choice |
| `przepros_na_niby.modifier_value` | 0.3 | 0.1–0.6 | balance | Below 0.1: apology is functionally zero — DDR-0001 #2 violation floor. 0.6+: challenge barely felt |
| `bez_tlumu.modifier_value` | 0.5 | 0.3–0.7 | balance | Below 0.3: active play useless. Above 0.7: not meaningfully harder than no challenge |
| `wypalony_ale_core.modifier_value` | 0.6 | 0.3–0.8 | balance | Below 0.3: recovery barely works, high risk of death-spiral (forbidden per anti-pillars) |
| `brak_duszy.meta_bonus_multiplier` | 2.0 | 1.5–3.0 | feel/meta | Baseline "single axis, moderate hit" challenge tier |
| `drama_bez_granic.meta_bonus_multiplier` | 2.5 | 2.0–4.0 | feel/meta | Higher than baseline — Cringe spiral is the most dangerous modifier type |
| `przepros_na_niby.meta_bonus_multiplier` | 1.8 | 1.5–2.5 | feel/meta | Slightly softer than challenge 1 — Cringe recovery impairment is less acute than Reach loss |
| `bez_tlumu.meta_bonus_multiplier` | 3.0 | 2.0–4.0 | feel/meta | Highest single-challenge multiplier — "all actions, Reach axis" is the broadest scope |
| `wypalony_ale_core.meta_bonus_multiplier` | 2.0 | 1.5–3.0 | feel/meta | Matches `brak_duszy` tier — single action, one delta axis |
| `CHALLENGE_MODIFIER_FLOOR` | 0.05 | 0.01–0.1 | safety | Hard floor applied at reward resolution — prevents zeroing from misconfigured balance.json |

All numeric values must live in `assets/data/balance.json`, not hardcoded. Challenge catalogue
entries (id, name, flavor, modifier_type, applies_to) should be defined in a separate
`assets/data/challenges.json` file loaded by `ChallengeSystem` at startup.

## Affected Systems

| System | Impact | Action Required |
|--------|--------|-----------------|
| BurnoutSystem | `era_transitioned` signal is the trigger for challenge selection | No structural change — existing signal; `ChallengeSystem` connects to it |
| ActionSystem | Applies challenge modifier as a second multiplicative pass after Morale multiplier (Formula C), at reward resolution time | New: read `ChallengeSystem.get_active_modifiers()` at resolution; multiply into final Reach, Cringe delta, Morale delta as appropriate |
| ResourceFormulas | No change to formula definitions | No action — modifiers applied by ActionSystem before passing deltas to ResourceManager |
| ResourceManager | Receives already-modified deltas from ActionSystem | No change — existing `apply_delta()` API handles this transparently |
| HistoryFlagManager | `set_flag()` called for each active challenge + combined multiplier cache | No structural change — existing API |
| SaveSystem | ChallengeSystem added to serialize/restore cycle | Add at implementation time |
| DecisionCardSystem | No direct impact — card pool weighting reads Cringe (which is affected indirectly via challenge modifiers on Cringe delta), but no new API needed | No action |
| Offline Progress System | Formula D (passive Reach from Haters) is explicitly excluded — offline sim unaffected | No action — confirm exclusion in Offline Progress System GDD |
| Prestige/Checkpoint System | **Consumes** `ChallengeSystem.get_combined_meta_multiplier()` to scale meta-bonus on era accept | Full GDD required (Alpha) — this spec defines the multiplier; Prestige GDD defines the content |
| UI (Challenge Selection Screen) | New screen presented at era-start | New UI story required (Alpha) — layout, challenge cards, confirm flow; cite this spec as the data source |

## Acceptance Criteria

- [ ] After `era_transitioned` fires, Challenge Selection screen is shown before any other era-start logic; player can pick 0–`CHALLENGE_MAX_ACTIVE` challenges or confirm with zero
- [ ] Selecting zero challenges and confirming produces `combined_meta_multiplier = 1.0` and no active modifier flags
- [ ] Each selected challenge writes `"challenge_active_" + challenge_id` as an era-local HistoryFlag
- [ ] On save/load mid-era, `ChallengeSystem.restore_state()` re-reads flags and reconstructs the active challenge set identically
- [ ] At `era_transitioned`, all `"challenge_active_*"` era-local flags are cleared before the new selection screen appears
- [ ] `Nagraj vloga` Reach reward with `brak_duszy` active: base=5, Morale High (Mult=1.0) → `5 × 1.0 × 0.3 = 1.5` → round-half-up → 2 Zasięgi (not 5)
- [ ] `Zrób dramę` Cringe delta with `drama_bez_granic` active: declared=+20 → effective=`20 × 2.0 = 40`, subject to clamp; at C=70 → actual C becomes `min(100, 110) = 100` → delta stored as +30
- [ ] `Przeproś w internecie` Cringe delta with `przepros_na_niby` active: declared=-15 → effective=`-15 × 0.3 = -4.5` → passes -4.5 to ResourceManager (ResourceManager clamps at 0 if needed); Morale delta remains +5 unmodified
- [ ] `bez_tlumu` active: all base actions produce 0.5× Reach; passive Reach income (Formula D tick) is unaffected — same value with or without any challenge active
- [ ] `wypalony_ale_core` active: `Przeproś w internecie` Morale delta = `+5 × 0.6 = 3.0` → round-half-up → +3 Morale; Cringe delta remains -15 unmodified
- [ ] Two challenges with `meta_bonus_multiplier` 2.0 and 2.5 both active → `ChallengeSystem.get_combined_meta_multiplier()` returns 5.0
- [ ] `CHALLENGE_MODIFIER_FLOOR` enforced: if `modifier_value` in balance.json is set to 0.0, effective modifier applied at resolution is `0.05`, not 0.0
- [ ] With `CHALLENGE_MAX_ACTIVE = 3`: attempting to select a 4th challenge on the selection screen is rejected; confirm button is the only way to proceed
- [ ] No challenge modifier affects Formula D (passive Reach) under any active challenge combination

## Systems Index / DDR Reference

**ChallengeSystem** is a sub-component of the Prestige/Checkpoint epic (system #17,
`design/gdd/systems-index.md`, Alpha tier). It is not a standalone tracked system — reference
this spec in the Prestige/Checkpoint GDD's Context section when `/design-system
prestige-checkpoint` runs in Alpha.

**DDR-0001 #2 ruling** (`design/decisions/ddr-0001-post-mvp-mechanics-pillar-rulings.md`):
> "Challenge runs — express challenge modifiers as **ratio multipliers** (e.g. 'Nagraj vloga
> earns 0.2× Reach'), never **zeroing** a core reward — zeroing collapses the
> Cringe→Haters→Morale resource triangle into a single forced path."

All five challenge examples in this spec comply: every `modifier_value` is > 0 and
`CHALLENGE_MODIFIER_FLOOR = 0.05` enforces this as a runtime guarantee.

**No zeroing in any challenge.** Pillar 2 (decisions have memory) is served by flag storage.
Pillar 4 (offline first-class) is served by Formula D exclusion. Anti-pillars (no hard-lock,
no death-spiral) are served by the modifier floor and by the Morale delta modifier being on
recovery, not on drain — the player can always recover Morale even under the hardest challenges,
just more slowly.
