# Reference-Games Progression Analysis — Why the pierwowzory Retain, and Where King of Cringe Breaks

> **Status**: Reference / design input (not a GDD — no 8-section contract)
> **Date**: 2026-07-28
> **Author**: user + agents
> **Trigger**: live playtest (Sprint 12, story 12-3). Player reached "Content Mogul T5" and asked "what benefits do I get — I don't see the goal." Investigation found the Class Path tier ladder is mechanically hollow above T2 and entirely empty for biznesmen_contentu — see the "Where we break it" section.
> **Purpose**: capture what actually makes our reference games retain players, so the tier-bonus fill and meta-loop telegraphing work is grounded in proven patterns, not invented from scratch. This is the design input for a later `/design-system retrofit design/gdd/class-path-system.md` (tier bonuses) + a Prestige telegraphing pass.

---

## The reference set

Per `design/gdd/game-concept.md` (Comparable Titles + the user's own played-games list): **Melvor Idle, Beggar's Life, Idle Research: Endless Tycoon** for progression, **Reigns** for the decision-card layer. All four were run through the project's own playtest-question audit (game-concept.md §Reference Games) — only Reigns got PROCEED; the other three got PIVOT (mechanically/thematically divergent) but each contributes one transferable element. This doc is about the *progression* element each contributes, which the earlier audit under-weighted.

---

## What actually makes each retain (web-verified + design framing)

### Melvor Idle — interlocking systems + no wasted level
- **Mastery** (verified, [wiki](https://wiki.melvoridle.com/w/Mastery)): every individual item/action has its own Mastery Level 1-99, each level granting a bonus; doing the action also fills a shared **Mastery Pool** that grants global checkpoint bonuses at **10% / 25% / 50% / 95%** filled. Two stacked progression layers, both always-rewarding.
- **Web of dependencies** (design framing): Woodcutting → logs → Firemaking / Fletching → bows → Ranged → loot → gear upgrades. No action is a dead end; every action is an investment in another system. Planning the optimal path becomes "a game within the game."
- **Transferable principle**: **every progression step gives a concrete, visible reward, and steps interlock** so nothing feels wasted.

### Beggar's Life — escalation + curiosity, on a branching class tree
- **Multi-tiered classes** (verified, [Steam](https://store.steampowered.com/app/3772140/Beggars_Life/)): you don't pick a class up front — you unlock and grow through them; classes are "multi-tiered and grow in scope"; paths branch (Church → Alms Collector → Acolyte → Priest, OR pivot to Sewers → Rat Warden / Pickpocket); **some paths close off others**. This is the direct model for our Class Path.
- **Absurd escalation** (design framing): coins → cities → countries → planets → alien "part-time workers." Humor/absurd masks repetition — the player climbs to see "what dumber, bigger thing unlocks next," not just to see a bigger number. Pure curiosity engine.
- **Transferable principle**: **each tier should reveal something visibly bigger/absurder**, so climbing is driven by curiosity, and the branching itself is a meaningful (partly exclusive) choice.

### Idle Research: Endless Tycoon — nested prestige
- **Nested reset loops** (verified, [Google Play](https://play.google.com/store/apps/details?id=com.CryptoGrounds.IdleResearch) + design framing): instead of one hard whole-game reset, separate prestige trees per subsystem (energy production, lab, crafting mastery). Prestige resets selected progress and grants permanent bonuses.
- **Micro-decisions**: "reset now for a small bonus, or wait and unlock a new multiplier?" — constant low-stakes optimization keeps the player deciding.
- **Transferable principle**: **the meta-reset is a dangled, telegraphed choice with a clear permanent payoff**, not a surprise wall.

### Reigns — each death is progress
- **Binary balance, hidden magnitude** (design framing): 4 gauges; a swipe shows *which* factions a choice hits but not *how much*; any gauge hitting 0 or 100 kills you. Constant juggling forces deliberately "bad" choices to stay alive.
- **Roguelite framing**: each death unlocks new cards → **death is progress, not punishment**.
- **Transferable principle**: **the run-ending event must read as progress** (you banked something permanent), not as a loss.

---

## Where King of Cringe currently breaks each

| Reference principle | Our state (code-verified) |
|---|---|
| Melvor: no wasted level | `class_path_system.gd:93-122` `_MULTIPLIER_TABLE` — **tiers 3-5 are `{}` (nothing) for ALL four paths; biznesmen_contentu is `{}` at EVERY tier.** Reaching Content Mogul T5 gives a 1.0× action multiplier — identical to T0. Only pato T1/T2 (drama +30%/+60%), guru T1/T2 (interview +20%/+40%), ekspert T2 (vlog +20%) do anything at all. |
| Melvor: interlocking systems | Tier bonuses are (where they exist) flat single-action Reach multipliers. No tier unlocks a new loop or makes one action feed another system. The designed biznesmen bonuses (Sponsor income, cooldown, Morale cost) have **no gameplay hook implemented** — documented in the GDD, wired to nothing (`class_path_system.gd:90-92` comment). |
| Beggar's Life: escalation/curiosity | The satirical tier names (Trash Streamer → … → Content Mogul, T1→T5) are *perfect* escalation bait — but mechanically empty above T2, so the curiosity ("what does T5 unlock?") is answered with "nothing." The branching IS partly exclusive (single active path, tie-break margin) — that part matches. |
| Idle Research / Reigns: telegraphed, progress-framed reset | Burnout → META_BONUS (e.g. biznesmen → permanent Sponsor floor) IS our "death = progress" / nested-prestige analog — but it is **never telegraphed before it happens**. The player doesn't know eras accumulate, doesn't know accepting burnout banks a permanent bonus, and hits the Wypalenie card as a surprise. Challenge Selection shows the grant *after* commit; nothing dangles it *before*. (Already flagged: game-concept.md:166 "no defined real stake of losing/ending an era"; class-path-system.md Open Questions "era reset never telegraphed".) |

---

## Fix direction (proven-pattern-mapped, for the later design session)

**1. No hollow tiers — differentiated, not flat (Melvor mastery-checkpoint model).** Each tier unlocks a *different kind* of thing, escalating:
- T1 / T2: action multiplier (keep the existing ones).
- T3: **interlocking bonus** — the path's signature action starts feeding a second resource (e.g. pato's drama also yields Sponsors; biznesmen's Reach actions also build Morale-immunity). Turns a dead-end action into a cross-system investment (Melvor's web).
- T4: **power spike** — cut a base-action duration or a cost (the prestige treatise's "skrócenie czasu akcji z 1s na 0.5s"). Felt immediately, not a hidden %.
- T5: **signature payoff** — the biggest, most absurd, path-defining effect + the (currently placeholder) signature card. This is the Beggar's Life "what does the top of the ladder unlock?" answer.

**2. biznesmen_contentu specifically** — wire its three designed-but-unhooked bonuses: Sponsor income multiplier (interlocks with the sponsor economy — and would also help the *separate* guru dead-Sponsors-faucet problem, see BUG/economy findings), action-cooldown reduction (power spike), Morale-cost immunity (lets the "content is a product, viewers are a market" archetype spam without Morale death — thematically on-nose).

**3. Telegraph the meta-loop (Reigns "death=progress" + Idle Research dangle).** Before burnout fires, surface: "Accept Wypalenie → bank +X% permanent [bonus] forever." Make the era-end a *goal the player climbs toward*, not a surprise punishment. Pairs with the already-logged "era reset never telegraphed" Open Question and the Pillar-1 legibility bug (ClassPathPanel shows "Tier N active" with no numbers).

**4. Legibility underpins all of it (Pillar 1).** None of the above helps if the numbers aren't shown. Every tier bonus must render as a concrete value in the ClassPathPanel (the "Tier N bonus in effect" → actual numbers fix, class-path-system.md Open Questions).

---

## What this does NOT recommend (scope guardrails)

- **Not** a literal Melvor skill tree / mastery-per-item grind — our Class Path *is* the tree (Beggar's Life model); the fix is filling it, not replacing it.
- **Not** Melvor's UI density — game-concept.md:167 already flags that as a touch-mobile blocker; keep the 4-path panel, don't add tabs.
- **Not** removing the pato anti-burnout interaction or guru dead-invest here — those are separate economy findings (tracked in the playtest report / class-path Open Questions); this doc is about the tier *ladder* being hollow, which is upstream of both.

---

## Sources

- [Melvor Idle — Mastery (wiki)](https://wiki.melvoridle.com/w/Mastery)
- [Beggar's Life (Steam)](https://store.steampowered.com/app/3772140/Beggars_Life/) and [devlog: Church path](https://pidroh.itch.io/beggars-life-grand-theft/devlog/1358882/version-031-focus-of-the-church)
- [Idle Research: Endless Tycoon (Google Play)](https://play.google.com/store/apps/details?id=com.CryptoGrounds.IdleResearch)
- Project's own reference audit: `design/gdd/game-concept.md` §Reference Games
- Code: `src/core/class_path_system.gd` (`_MULTIPLIER_TABLE`, lines 93-122)
