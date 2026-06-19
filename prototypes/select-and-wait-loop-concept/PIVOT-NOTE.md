# Pivot Note: select-and-wait-loop → select-and-wait-loop-v2

> **Date**: 2026-06-19
> **Original hypothesis**: If the player chooses an action and it runs over time without tapping, they will feel the loop is satisfying — evidenced by naturally choosing the next action within 3 cycles.
> **Verdict on original**: CONFIRMED (mechanic works) but PIVOT overall (not enough on its own to retain)

---

## What to keep

- The select-and-wait core mechanic exactly as built: action list → progress bar fill → completion flash. Zero confusion, zero negative feedback on the mechanic itself.
- The clear per-action description of cost/reward ("jasno opisane co daje dana akcja i jaki jest rezultat") — keep this legibility in v2.

## What to change

- **More actions.** Only 3 felt thin — expand the action roster (could tie early unlocks to this, consistent with Class Path System / progression).
- **Add a hook.** Tester explicitly wants "fajerwerki" — celebratory feedback at milestone thresholds (resource counts, cycle counts), not just the flat per-cycle flash. This is a new tier of feedback above the existing Juice/Feedback System scope (which only covers per-action completion in `systems-index.md`).

## Revised hypothesis for v2

If the player has access to 6+ actions and receives escalating celebratory feedback at milestone thresholds (not just per-cycle), they will perceive the loop as having a retention hook — evidenced by the player describing a specific desire to "keep playing" or "see what's next" when asked directly, not just confirming the mechanic is comprehensible.

## Next step

`/prototype select-and-wait-loop-v2` — build on the same HTML base, add 3+ more actions and a milestone celebration system, then re-run the debrief with a direct retention question ("did you want to keep playing?") instead of relying on volunteered feedback.
