# Concept Prototype Report: select-and-wait-loop

> **Date**: 2026-06-19
> **Prototype Path**: HTML
> **Concept File**: design/gdd/game-concept.md

---

## Hypothesis

If the player chooses an action (Nagraj vloga / Zrób dramę / Przeproś w internecie) from a list and it runs over time without further tapping, they will feel the loop is satisfying — evidenced by the player naturally choosing the next action within 3 cycles, without prompting.

---

## Riskiest Assumption Tested

That the absence of active tapping would make the loop feel "dead" or passive on a small mobile screen. This did not hold — the player engaged naturally with the progress bar and reward feedback without needing tap-driven input.

---

## Approach

Built a single self-contained `prototype.html` with 3 hardcoded actions, each with a different duration and resource reward, a progress bar, and a completion flash message. No cards, no offline progress, no save, no audio.

**Path chosen:** HTML
**Reason for path:** Idle/incremental genre — turn/time-based logic, no input-timing sensitivity to validate, fastest to build and test.

**Shortcuts taken (intentional):**
- Hardcoded 3 actions with fixed durations/rewards
- No persistence — resets on page reload
- No audio/vibration (acknowledged as untestable in browser anyway)
- Single visual flash for completion feedback, no particle effects

---

## Result

Tester confirmed the core loop worked: the progress bar "ładnie się ładował" (loaded nicely) and completing it gave a clear sense of having earned points. The action outcomes were "jasno opisane" (clearly described) — no confusion about what each action gives. The main gap was **content volume** ("trochę mało tych akcji" — too few actions) and a missing **hook**: the tester explicitly wanted "fajerwerki" (fireworks/celebratory feedback) at milestone point counts, not just the per-cycle flash message.

---

## Metrics

| Metric | Value |
|--------|-------|
| Path used | HTML |
| Iterations to playable | 1 (no engine iteration loop needed) |
| Prototype duration | <1 hour |
| Playtesters | 1 internal |
| Feel assessment | Progress bar fill + completion flash read clearly as "I did something"; no input lag complaints; loop felt understandable on first try |
| Hypothesis verdict | CONFIRMED |

---

## Recommendation: PIVOT

The core hypothesis (select-and-wait without tapping can feel satisfying) is CONFIRMED — the player understood and engaged with the loop without prompting. However, the tester's verdict was PIVOT, not PROCEED: with only 3 actions and flat per-cycle feedback, the loop has no built-in retention hook. The fix is additive, not structural — more actions and milestone-based celebratory feedback — so this is a scope refinement of the same mechanic, not a rejection of it.

---

## If Pivoting

The select-and-wait mechanic itself works and should be preserved exactly as built (action list → progress bar → completion flash). What's missing is breadth (more actions) and a long-term hook (escalating feedback tied to milestones, not just per-action flashes) — this maps directly onto Pillar 1 ("uczciwa matematyka, nieuczciwy świat") and the retention-hook gap noted in the original Core Loop design (game-concept.md): "Curiosity" and "Mastery" hooks need a visible milestone system, not just resource counters ticking up.

**Pivot direction:** Add more actions (likely tied to early game progression / unlocks) and a milestone celebration system (visual "fajerwerki" at resource thresholds or cycle counts) layered on top of the same select-and-wait core.
**What to keep:** The select-and-wait core loop exactly as prototyped — action list, progress bar, completion flash. Tester had zero confusion and zero negative feedback on the core mechanic itself.
**Next step:** `/prototype select-and-wait-loop-v2` (revised hypothesis: milestone celebration + expanded action roster increases perceived engagement without adding tapping)

---

## Lessons Learned

- **What assumptions were broken by actually building this?** None on the core mechanic — the select-and-wait assumption held exactly as designed. The assumption that broke was implicit: that 3 actions + flat feedback would be "enough" to judge engagement. It wasn't enough to judge retention, only initial comprehension.
- **What surprised us that didn't show up in the brainstorm?** The tester's request for "fajerwerki" wasn't part of the original Core Loop design discussion in `/brainstorm` — milestone-based celebratory feedback wasn't called out as a discrete needed system in `systems-index.md` either. The current Juice/Feedback System entry is scoped to per-action completion only; this signal suggests it needs a milestone-tier variant.
- **What would we test differently next time?** Test with more than 1 playtester, and specifically probe for "did you want to keep playing" rather than relying on the tester volunteering it — the PIVOT signal here came from a side comment, not a directly asked retention question.

---

> *Prototype code location: `prototypes/select-and-wait-loop-concept/`*
> *This code is throwaway. Never refactor into production.*
