# Vision: "The Algorithm" — Attention Economy as the Antagonist-Engine

> **Status**: VISION / north-star — NOT scoped, NOT a committed system, NOT in systems-index yet (deliberate). Needs a creative-director pass + roadmap placement before any of it becomes a designed system.
> **Date**: 2026-07-28
> **Author**: user (vision) + agent (capture, tensions, sequencing)
> **Trigger**: live playtest (Sprint 12, 12-3) exposed the "no goal / why come back" gap. This is the user's answer at the highest level: don't bolt a retention system onto the game — make the attention economy itself the antagonist and the engine.

---

## The core insight

We're making a game about the attention economy. So the strongest hook isn't a retention system *beside* the game — it's turning the attention economy **into a character and a mechanic**. Every creator's antagonist — **the Algorithm** — becomes the game's engine: a living, capricious god (a great eye / logo that watches, comments, decides your fate). Everything below is one of its organs.

**Why it's on-concept, not a bolt-on**: game-concept.md:31 already names it — "system (Algorytm, sponsorzy, hejterzy) kształtuje kim się stałem" ("the system — Algorithm, sponsors, haters — shapes who I became"). The Algorithm was always a named force in the fiction. This vision just gives it a body and makes it the retention layer. The player stops returning "for the numbers" and returns to check **what mood the god is in, finish the drama, catch the trend** — a relationship, not a grind.

---

## The six organs

1. **Viral roll (variable-ratio).** Every content action has ~1-2% chance to EXPLODE: "47× reach", a jackpot-scale moment. Slot-machine psychology — the brain hooks on anticipation, not reward; every tap becomes a lottery ticket. A **hidden pity timer** (guaranteed viral within max N actions) ensures a dry streak never kills the fun. Turns "clicking in an idle" into "one more spin."

2. **Algorithm's moods (appointment mechanic).** Each real-world day, a rolled mood: "Today the Algorithm feeds DRAMA (+100% for pato)." A daily reason to return that isn't a login-calendar — it's **diegetic**, because that's how real platforms work. Interlocks with the tier fix: moods make "off your path" days interesting (bank? switch strategy?), and a higher-tier biznesmen could get partial mood-immunity — "sponsored content always promotes itself." Mechanic + satire + class identity in one.

3. **Trends (FOMO waves).** Periodically a trend arrives with a countdown: "Plank challenge — expires in 3h 12min." Join → multiplier + a unique headline for the collection. Miss → gone forever (but another's coming, so it's a pinch of scarcity, not a punishment). Natural **push-notification** material that reads like a platform notification, not spam.

4. **Return feed (open loop / Zeigarnik).** Instead of "you earned X offline" — you return to a scrollable fake notification feed: comments, a little drama, and ONE waiting decision card with a timer: "Someone called you out. Reply expires in 4h." **Iron rule: a session never ends with all loops closed** — there's always a visible counter (mood change in 3h, a trend, a card). The player's brain keeps a tab open on the game. Pure Zeigarnik effect.

5. **Cringe Hall of Fame (collection).** Every viral generates a collectible fake-headline / thumbnail. Collection is long-term retention, and screenshots of absurd headlines are **free marketing** — players post them themselves. Unifies with the T5 signature cards into one collection system.

6. **The game KNOWS what it's doing (the spine — see below).** The Algorithm occasionally breaks the fourth wall ("you came back. I knew you would."). And since Wypalenie is already our prestige — leaving is progress — push it: a "Digital Detox" achievement for 48h of absence, rewarded with full Morale. A game that uses addictive mechanisms AND openly mocks them is the press/reviewer/player story. Nobody else in the store has it. That's the "break the system": **a retention system that is satire of retention systems.**

---

## The ethical spine — load-bearing, not a cherry

**Organ #6 is not a garnish. It is the structural element that makes the whole thing defensible.** The hard truth: **satire does not disable the mechanism.** A variable-ratio schedule with a hidden pity timer conditions behavior identically whether the game winks or not. The only thing separating "satire of dark patterns" from "dark patterns with a wink" is whether the game **genuinely rewards leaving.**

Therefore the non-negotiable design constraint: the self-awareness (#6) and the Digital-Detox reward must be **central and real**, or we don't build the hooks at all. If we ship the five hooks and skimp on #6, we've built Zynga with an ironic caption. This is a *decision*, not flavour — and it should be the first thing the creative-director pass confirms.

---

## Tensions to resolve before building (honest)

1. **Scope — this is a new PILLAR, not a feature.** Six organs, each of which reworks or duplicates an existing system. Alpha/Beta+ scope, north-star. Context: we are mid-Sprint-12 (a *close-out* sprint) with a **FAILED** Production→Polish gate, hollow tiers, no New Game button, placeholder T5 cards. This vision is ~10× the size of what we currently can't finish. It must be sequenced, not spontaneously built.

2. **Pillar 1 clash — real.** Viral-roll (variable-ratio, hidden pity) vs. the core "honest math" where the player always reads their own state. Reconciled *only* by the concept's own line: "chaos i hazard żyją TYLKO w systemach wokół gracza, nie w rdzeniu" — the tap and the counters stay honest and legible; the Algorithm is the chaos *around* them. Must be deliberate, not accidental. The core readout must never lie; the unpredictability lives in the Algorithm's behavior, not in whether the player can read their resources.

3. **Art-bible collision (compounding).** Jackpot spectacle / "screen explodes" / ceremony vs. the locked deadpan-dashboard direction (§1 "precision without judgment", no celebration), the no-highlight icon style (locked 2026-07-11), the MANDATORY reduce-motion (§7), and the permanent no-audio decision (a jackpot with no sound sting). This is the same pivot flagged for the tier-ceremony ideas, now larger. Needs art-director + creative-director — it's a genuine art-direction change, not a fold-in.

4. **Reworks systems already shipped/designed (not purely additive):**
   - **Return feed (#4) replaces the shipped Offline Report Screen** (ADR-0009). A redesign of a done system.
   - **Moods (#2) overlap Challenge Era modifiers** — both are day/era modifiers. Do not build two parallel modifier engines; moods are probably the *evolution* of challenges.
   - **Detox/Wypalenie (#6) overlaps the existing Burnout/Prestige** — here it's aligned, good.
   - **Hall of Fame (#5) subsumes the T5 signature cards** into one collection system.

5. **Platform.** Push notifications are Android-only — Web/CrazyGames (iframe) can't do them, and portals have their own rules. Any organ that leans on push (#3 trends, #4 return feed) needs a non-push fallback for web.

---

## How it interlocks with the near-term tier fix

Good news: the vision and the immediate playtest fix are *compatible*, not competing. The tier-bonus fill (see `class-path-tier-bonus-table-draft.md`) proceeds underneath as near-term work; the Algorithm makes tiers *richer* later (moods × class identity, e.g. biznesmen mood-immunity). Sequence: fix legibility → fill tiers (near-term, unblocks the playtest complaint) → THEN the Algorithm as the north-star pillar that reframes the whole meta-loop.

---

## Next step

1. **Creative-director pass** — confirm the ethical spine (#6 central), reconcile Pillar 1 (chaos-in-systems-not-core), and rule on the art-direction pivot (deadpan → juicy). This is the gate: if the spine isn't committed, the hooks don't get built.
2. **Roadmap placement** — north star, post-Alpha. Not Sprint 12, not while the Production→Polish gate is failing on basics.
3. Only after 1+2: decompose into actual systems (`/map-systems` additions, GDDs), respecting the "reworks not adds" reality (Offline Report → Return Feed, Challenges → Moods).

This doc preserves the vision at full fidelity so it isn't lost — and records the tensions so future-us doesn't build it blind.
