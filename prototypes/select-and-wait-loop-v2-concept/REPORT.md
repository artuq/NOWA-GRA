# Concept Prototype Report: select-and-wait-loop-v2

> **Date**: 2026-06-19
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player has access to 6+ actions and receives escalating celebratory feedback at milestone thresholds (functional unlock + visual celebration), they will perceive the loop as having a retention hook — evidenced by the player describing a specific desire to "keep playing" or "see what's next" when asked directly.

This is the revised hypothesis from `select-and-wait-loop-concept/PIVOT-NOTE.md`.

---

## Riskiest Assumption Tested

That milestone unlocks (functional + celebratory) would meaningfully change the player's desire to continue, not just be a cosmetic flourish on top of the same core loop. This held — the player reported actively wanting to reach the next milestone ("chciałem szybko zdobyć ostatni poziom!").

---

## Approach

Extended the v1 HTML prototype: 3 starting actions + 3 actions gated behind milestone thresholds (25/75/150 Zasięgi), each unlock showing a locked preview card, a full-screen celebratory popup with confetti, and a pulsing highlight on the newly unlocked action button.

**Path chosen:** HTML
**Reason for path:** Same as v1 — idle/incremental, no input-timing sensitivity, fast iteration on the same base.

**Shortcuts taken (intentional):**
- Hardcoded 3 milestone thresholds and their unlocks
- Cringe resource tracked and displayed but has no defined effect — deliberately left undefined per v1 prototype scope, but this surfaced as a real gap (see Result)
- No persistence, no audio, no save

---

## Result

The milestone-unlock mechanic strongly confirmed the hypothesis: the player explicitly wanted to reach the next milestone ("chciałem szybko zdobyć ostatni poziom!") and called out the confetti/celebration as a highlight ("fajne były fajerwerki"). This is a much stronger engagement signal than v1, where feedback was purely about comprehension, not desire to continue.

The recurring friction point from v1 — pacing — was again mentioned but explicitly acknowledged by the player as expected/acceptable at the prototype stage, not a real concern.

A new, more important gap surfaced: the player reached 85 Zasięgi / 22 Cringe and could not tell what Cringe *does* — it accumulates with no visible effect, positive or negative. This isn't a v2-specific bug; it's a gap inherited from the concept design itself (Cringe is meant to interact with Morale/Reputation per `game-concept.md` Pillar 2, but that interaction was never modeled in either prototype).

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | 1 |
| Prototype duration | <1.5 hours |
| Playtesters | 1 internal |
| Feel assessment | Milestone popup + confetti read as a clear, motivating "win" moment; player self-reported wanting to rush toward the next one |
| Hypothesis verdict | CONFIRMED |

---

## Recommendation: PROCEED

Both the core select-and-wait mechanic (v1) and the milestone-unlock retention hook (v2) are now validated with a real desire-to-continue signal, not just comprehension. The remaining open issue — Cringe having no visible consequence — is a content/systems-design gap, not a prototype-mechanic failure, and should be carried directly into the Resource System and History Flag System GDDs rather than triggering another prototype cycle.

---

## If Proceeding

- **Core tuning values discovered:** Milestone thresholds at roughly 3x, 9x, 18x the base action's per-cycle reward (25/75/150 against a 3-8 Zasięgi/cycle baseline) produced a noticeable "almost there" pull without feeling unreachable in a short session — worth using as a starting ratio in the Resource System GDD's tuning knobs.
- **Assumptions confirmed:** Select-and-wait without tapping is engaging (v1). Functional + celebratory milestone unlocks create a genuine "keep playing" pull (v2).
- **Assumptions disproved:** None — both prototype hypotheses held.
- **Emergent mechanics worth formalizing:** The "locked action preview" card (visible but greyed out, showing its unlock threshold) was not originally planned but proved to be a strong motivator on its own — it should be considered as a formal UI pattern in the Action UI and Class Path System GDDs, not just a prototype shortcut.
- **New gap surfaced (not resolved by this prototype):** Cringe accumulates with no visible player-facing consequence. When `/design-system Resource System` and `/design-system History Flag System` are authored, the Cringe → Morale/Reputation interaction (implied by Pillar 2 and Pillar 3 in `game-concept.md`) must be made concrete and visible, not left as an abstract number. This is now the single most important open question carried forward.

**Next steps:**
1. `/design-review design/gdd/game-concept.md`
2. `/gate-check`
3. Resume `/design-system Resource System` (first in `systems-index.md` design order) — explicitly resolve the Cringe consequence gap here
4. Continue MVP GDDs per the systems-index.md design order, using the milestone-threshold ratios above as starting tuning knobs

---

## Lessons Learned

- **What assumptions were broken by actually building this?** None on the mechanics tested — both held. What broke was an assumption that wasn't even explicit: that leaving Cringe's effect undefined in the prototype wouldn't matter for a mechanics-only test. It did — it was the single biggest piece of feedback in this round.
- **What surprised us that didn't show up in the brainstorm?** The "locked action preview" (greyed-out card with its unlock threshold visible) wasn't planned as a feature — it emerged from wanting to show *what's coming* — and it turned out to be a meaningful motivator on its own, separate from the milestone popup itself.
- **What would we test differently next time?** When a resource's purpose is intentionally left undefined for prototype scope reasons, flag it to the tester explicitly before they play, OR accept that its absence will surface as feedback — both are fine, but the lesson is to expect it rather than be surprised by it.

---

> *Prototype code location: `prototypes/select-and-wait-loop-v2-concept/`*
> *This code is throwaway. Never refactor into production.*
