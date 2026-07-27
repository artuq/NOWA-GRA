# Class Path Tier-Bonus Table — Draft (fills the hollow ladder)

> **Status**: DRAFT design input for a later `/design-system retrofit design/gdd/class-path-system.md`. Values are provisional — need an economy-designer balance pass. NOT locked, NOT in code yet.
> **Date**: 2026-07-28
> **Author**: user + agent
> **Trigger**: playtest 12-3 — "Content Mogul T5 gives nothing." Root cause: `class_path_system.gd` `_MULTIPLIER_TABLE` has `{}` at tiers 3-5 for all paths and every tier for biznesmen. See `progression-mechanics-analysis-2026-07.md` for the why and the proven-pattern mapping.

---

## Implementation order (decided)

**4 → 1+2 → 3**, per the user's call:
1. **Legibility FIRST** (was doc-point 4) — even the existing pato/guru T1-T2 bonuses are invisible in ClassPathPanel today. Fixing "bonus in code → number on panel" first validates the pipeline (so every new bonus below renders immediately) and tells us whether legibility alone softens part of the complaint. Cheapest, fastest.
2. **Fill the tiers + biznesmen** (doc-points 1+2, together — biznesmen is just filling its column in the same table).
3. **Telegraph the meta-loop** (doc-point 3) last.

---

## The table

Effect-type tags:
- `[mult]` = action-keyed Reach multiplier — fits the existing `_MULTIPLIER_TABLE` directly.
- `[hook]` = needs NEW code (a new consumer/modifier) — cannot be expressed as an action-keyed Reach multiplier.

| | T1 | T2 | T3 — interlock | T4 — power spike | T5 — signature |
|---|---|---|---|---|---|
| **pato_streamer** (Trash Streamer) | Drama Reach ×1.3 `[mult]` ✓shipped | Drama Reach ×1.6 `[mult]` ✓shipped | Drama also +3 Sponsors / completion `[hook]` | Drama duration 9s→6s `[hook]` | All actions Reach ×2, Cringe gain ×1.5 (bait burns hot) `[hook]` + signature card |
| **guru_celebryta** (Guru Celeb) | Interview Reach ×1.2 `[mult]` ✓shipped | Interview Reach ×1.4 `[mult]` ✓shipped | Interview also +2 Sponsors / completion `[hook]` *(also eases guru's dead-Sponsors-faucet problem)* | Interview duration 15s→10s `[hook]` | Sponsor income ×2 (the "999 zł course" empire) `[hook]` + signature card |
| **ekspert_niszowy** (Niche Expert) | Morale drain −20% `[hook]` *(T1 is `{}` today)* | Vlog Reach ×1.2 `[mult]` ✓shipped | Vlog also +5 Morale / completion (making content you love restores you) `[hook]` | Vlog duration 6s→4s `[hook]` | Haters growth ×0.5 + Morale floor 40 (cult immune to hate) `[hook]` + signature card |
| **biznesmen_contentu** (Content Mogul) | Collab Reach ×1.2 `[mult]` *(all `{}` today)* | Collab Reach ×1.4 `[mult]` | Sponsor income ×1.5 `[hook]` | All action cooldowns −25% `[hook]` | Full Morale-cost immunity — actions cost 0 Morale (content without emotional cost) `[hook]` + signature card |

### Design decisions baked in
- **Differentiated tiers, not flat +X%** (Melvor mastery-checkpoint model): T1/T2 multiplier → T3 interlock → T4 power spike → T5 signature. Each tier a *different kind* of thing, escalating.
- **biznesmen resolved to remove the double-dip** (user's call): T3 = Sponsor multiplier (clean interlock, side-benefit on any Sponsor need), T4 = cooldown, T5 = full Morale immunity as the signature. Morale-immunity lives ONLY at T5 — it is NOT also a T3 interlock.
- Every path gets ≥1 T3 interlock feeding a second resource (Melvor's web-of-dependencies as a design goal).

---

## Scope realities (important — this is not a table edit)

- **Only 10 of 20 cells are `[mult]`** (fit the existing table). The other 10 — all T3/T4/T5 plus ekspert T1 — are **new gameplay hooks**: action-yields-a-second-resource, action duration/cooldown modifiers, income multipliers, a Morale-cost-immunity flag. That's ~10 new mechanics wired into ActionSystem/ResourceManager, not a data edit.
- **All values are provisional** — economy-designer balance pass required before lock (interacts with the pato anti-burnout and guru dead-invest economy findings, and with the session-pacing estimate).
- **T5 flavor is a separate creative-first pass** (user's call): design the four T5 effects as jokes/fantasies first ("what's the most absurd thing Content Mogul could get?"), then balance the numbers — reverse order yields four correct-but-boring multipliers. The mechanical effects above are the skeleton; the names/cards/teasers are the writer + creative-director pass.

---

## Juice / ceremony layer — SEPARATED, pending an art-direction decision

The user proposed a rich game-feel layer on top (delta-counters, per-path tier-promotion ceremonies, visible interlock "pipes", escalating backgrounds, holo signature cards, a burnout spectacle). Three of those — **delta-counter (before→after), Android haptics, next-tier teaser** — are art-bible-compatible and cheap; they can go in with the tier fill.

The rest (full-screen ceremonies, holo-foil, escalating penthouse/neon backdrops, "spectacle", any audio sting) **collides with locked decisions** — deadpan-dashboard (§1), no-highlight icon style, MANDATORY reduce-motion (§7), permanent no-audio. That is a genuine art-direction pivot (cold dashboard → juicy ceremony), bigger than the tier table, and needs art-director + creative-director sign-off. It is NOT folded into this table. See also `the-algorithm-vision.md`, where the same pivot recurs at larger scale.

---

## Next step

After the legibility fix lands: `/design-system retrofit design/gdd/class-path-system.md` to formalize this table into the GDD's Tier Bonuses section, spawning economy-designer (balance) + writer/creative-director (T5 flavor). Then wire the 10 `[hook]` cells in code as their own stories.
