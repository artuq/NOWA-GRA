# DDR-0001: Post-MVP Mechanics — Pillar Rulings

> **Design Decision Record** (not a technical ADR — `docs/architecture/` is reserved
> for engine/code decisions). This records binding game-design rulings on proposed
> mechanics, so rejected ideas cannot quietly creep back in during later design work.

## Status

**Accepted — binding** (2026-06-30)

Authority: `creative-director` (final authority on tone/identity/pillar conflicts, per
`.claude/docs/coordination-rules.md`) + `game-designer` (mechanical/systems review).
Both evaluated the 10 ideas independently and converged on the same verdicts.

## Context

Ten post-MVP "polish" mechanics inspired by Trimps / Evolve / Your Chronicle were proposed
to expand the game and increase retention (Vertical Slice / Alpha tiers). They were
evaluated against the 4 Pillars and anti-pillars from `design/gdd/game-concept.md` and the
existing system designs (Resource System formulas A–E, Action System, Decision Card System,
History Flag System).

**The 4 Pillars** (the test every mechanic must pass):
1. **Fair core, unfair world** — core math always predictable/fair; chaos lives in the
   surrounding systems, never the core loop.
2. **Decisions have memory, not points** — choices accumulate as history flags, never a
   moral meter / score.
3. **Satire through mechanics, not lecture** — critique emerges from what the game rewards
   and punishes, never moralizing text.
4. **Offline is a first-class citizen.**

**Load-bearing anti-pillars** (cited repeatedly below):
- **NO permanent failure / hard-lock.** Bad decisions are *deferred* consequences
  (Morale/reputation), and the player can always act their way out — never a state where
  the game plays itself and the player waits.
- **NO explicit moral score/HUD** — no UI element that reads as a good/bad judgment.

## The Rulings

| # | Mechanic | Verdict | Tier |
|---|----------|---------|------|
| 1 | Action queue / auto-repeat | ✅ Approved | Vertical Slice (build now) |
| 2 | Challenge "Era Change" runs | ✅ Approved (ratio multipliers, not zeroing) | Alpha |
| 3 | Milestone-gated action slots | ✅ Approved — **highest priority** | Vertical Slice (build now) |
| 4 | PR Stances | ⚠️ Redesign required (see ruling) | Alpha / Full Vision |
| 5 | Narrative forced prestige ("Final Burnout") | ⭐ Approved — **protect as a pillar, not polish** | Design now, build Alpha |
| 6 | Sponsor network shield | ✅ Approved (must be time-limited) | Vertical Slice |
| 7 | Cancel Storm | ❌ **Rejected as written; reskin approved** | Vertical Slice (reskin only) |
| 8 | Purchasable card trigger | ❌ **Rejected — do not build in any tier** | — |
| 9 | Soft Reach cap ("Algorithm Barrier") | ✅ Approved (active income only) | Alpha |
| 10 | Worker upkeep costs | ⚠️ Redesign required (no hard-floor) | Alpha |

---

## Binding rejections (these must not return without reopening this DDR)

### #8 — Purchasable card trigger — REJECTED, all tiers

Spending Reach to force a specific decision card to appear is a **Pillar 2 + Pillar 3
conflict with no recoverable redesign that preserves the original intent.** The entire
satirical thesis of the card system (`decision-card-system.md` Player Fantasy) is that
*the algorithm reads you* — the player feels steered by their own accumulated history
(Cringe level + pattern). A "buy a specific card" button inverts the satire from "the
system shapes you" into "you command the system" — a vending machine. It also flattens
Pillar 2 (history-driven emergence) into a shop, and trivializes the Cringe-weighted pool
into a dominant-strategy optimization (always summon the highest-value card), collapsing
the Discovery aesthetic.

**The legitimate underlying desire** (player agency over card *pacing*, not being purely
passive between cooldowns) is redirected: let the player spend a *moderate* Reach cost to
*extend the cooldown* — "I want to focus on actions right now, not cards." This preserves
full system control over *which* card appears (agency through behavior, never a bypass
button). Do not build the as-proposed version.

### #7 — Cancel Storm — REJECTED as written; reskin approved

Greying out **all** Action UI buttons at Cringe=100 and forcing one mandatory "Crisis
Management" action with Morale **locked** at 0.5x is a **hard-lock — direct violation of
the "no permanent failure/blocking" anti-pillar.** It also breaks Pillar 1: locking the
Morale multiplier breaks Formula C's contract (Morale is a continuous resource, not a
lockable state). Worst case is a literal death-spiral: Morale 0.5x → lower income → Haters
still growing at max → no exit.

**The line** (both reviewers, independently): a crisis beat is *meaningful* when the player
still chooses how to spend their loop; it is a *punishment loop* when the game plays itself
and the player waits.

**Approved reskin:** at Cringe=100, the Decision Card System *injects* a high-weight
"Crisis Management" card (the pool already steers toward drama at max Cringe, so this is
consonant, not new machinery), with a steep but *optional* trade-off. Standard actions
remain available; the player acts their way out. A deferred Morale penalty is fine; the
lockout is not. (Full-Vision option: temporarily push the Cringe-weighting to its logical
extreme — zero the `base_weight` floor for high-intensity cards during the storm so the
pool is *probabilistically* terrible without locking anything.)

---

## Approved with mandatory redesign

### #4 — PR Stances — only as a costed, history-bearing choice (not a persistent toggle)

A persistent top-of-screen "Family Friendly / Edgy" toggle is rejected: it competes with
Cringe as the satirical risk-axis (Pillar 3 redundancy), and a persistent toggle labeled
with moral valence *is* a soft moral meter — letting the player *declare* their morality
cleanly instead of *living* it through accumulated card history (Pillar 2: memory, not
points — a toggle is a point). It also muddies Pillar 1 (a global multiplier the player must
remember to check before reading a reward).

**Required form:** express it inside the Decision Card System as a recurring "Content
Calendar" card (a *choice with a cooldown and history*, applying the multiplier as a card
effect), OR a short-lived costed tactical lever with a cooldown. **It must never be a free
persistent posture, and must never touch the card-weighting pool** — that axis belongs to
Cringe alone.

### #10 — Worker upkeep costs — no hard-floor, offline-capped

The economic-pressure intent is sound, but "income < upkeep → Morale hits 0%" is a
death-spiral / hard-lock (same anti-pillar as #7), and offline upkeep could turn the Pillar 4
offline report from a reward into a punishment reveal.

**Required form:** underwater = staff drop to *reduced capacity* (e.g. 50% passive income),
never zero, and the player climbs out by acting (lower Cringe to raise income, or
dismiss staff via a real UI action — not a punishment). Offline upkeep is *capped at a
proportion of the offline income it earned* — staff can never cost more than they made you
while you were away. Also: introduce only one new Reach sink at a time (Resource System
currently has zero) — sequence after #6 and #9, with isolated playtesting.

---

## Clean approvals (build per tier)

- **#1 Action queue** — wraps the existing Action System state machine, zero new systems.
  Cap the queue (10–20, tuning knob) and/or auto-pause when Morale enters Critical, and
  auto-pause when a Decision Card is presented (so queueing never lets the player ignore
  the moral-decision tension). Serves Pillar 4.
- **#2 Challenge runs** — express challenge modifiers as **ratio multipliers** (e.g.
  "Nagraj vloga earns 0.2× Reach"), never **zeroing** a core reward — zeroing collapses the
  Cringe→Haters→Morale resource triangle into a single forced path.
- **#3 Milestone-gated action slots** — `has_milestone()` already exists and is tested; the
  3 locked slots already exist in the Action UI spec. **Design constraint:** each slot must
  be unlockable via *either* a risky-path *or* a safe-path milestone, so the "clean path"
  player (deliberately un-punished per `resource-system.md`) is never locked out of action-
  economy growth. The strongest Pillar 2 expression in the list.
- **#5 Narrative forced prestige ("Final Burnout")** — **the strongest identity-advancer:
  it doesn't just avoid breaking the satire, it delivers it** (build empire → inevitable
  burnout → era reset = structural critique, Pillar 3). It also answers the concept's own
  open question (a "real stake" without permadeath, `game-concept.md` Open Questions). Must
  be a *narrative checkpoint / era-transition, never a game-over*; the card needs genuine
  binary stakes (accept burnout & reset with a meta-bonus, OR defer once at a large Morale
  cost) so it stays "a decision with memory," not something done *to* the player without
  consent. Design it *now* so the Prestige/Checkpoint System (Alpha) is built around it,
  not retrofitted.
- **#6 Sponsor network shield** — closes the Sponsors no-sink/no-faucet tech-debt. **Must be
  time-limited** (renewed per content cycle), never permanent: a permanent N_buffer 3→10
  makes Formula B return 0 drain until 10 Haters, i.e. the first ~10 Haters (≈2.0 Reach/min
  passive) come *free of Morale cost* — a dominant strategy that trivializes the whole
  Cringe chain.
- **#9 Soft Reach cap** — apply **only to active action income**, never to passive Haters
  income (Formula D). Capping passive income inverts the Cringe-chain's risk/reward (the
  player took the Haters risk; the reward must not be throttled). Only meaningful once
  Prestige exists (Alpha).

## Build order (both reviewers agree)

1. **#3 Milestone-gated slots** — zero new systems, highest Pillar 2 impact, build first.
2. **#1 Action queue** — zero new systems, critical for Pillar 4.
3. **#6 Sponsor shield (simplified, time-limited)** — first real Sponsors sink, no Team/Staff dependency.
4. **#5 Final Burnout** — design now, build in Alpha alongside Prestige/Checkpoint.
5. **#9 Soft cap**, then **#2 Challenge runs** — Alpha, after Prestige exists.
6. **#4 Stances (redesigned)**, **#10 Upkeep (redesigned)** — Alpha / Full Vision, lowest priority.
7. **Do not build:** #8 (any tier), #7 as written (reskin only).

## Consequences

- Future feature/design work (especially the Prestige/Checkpoint and Team/Staff GDDs) must
  honor these rulings. Reopening #7-as-lockout or #8 requires explicitly superseding this
  DDR with a recorded counter-decision and a creative-director sign-off — not a silent
  reintroduction.
- The redesign conditions on #4, #6, #9, #10 are *requirements*, not suggestions: shipping
  the as-proposed versions would re-introduce the pillar/death-spiral problems documented
  above.
- #5 is elevated from "polish idea" to a protected identity feature — the Prestige/Checkpoint
  System should be designed around it.

## Related

- `design/gdd/game-concept.md` — the 4 Pillars and anti-pillars (source of authority)
- `design/gdd/resource-system.md` — Formulas A–E, the Cringe→Haters→Morale chain, N_buffer
- `design/gdd/decision-card-system.md` — Cringe-weighted pool, cooldown
- `design/gdd/history-flag-system.md` — `has_milestone()`, pattern counters
- `docs/tech-debt-register.md` — Sponsors placeholder (addressed by #6)
