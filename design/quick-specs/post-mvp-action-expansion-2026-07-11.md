# Post-MVP Action Expansion — Backlog Candidates

> **Date**: 2026-07-11
> **Status**: Backlog — NOT scheduled, not designed, no ADR/GDD coverage yet
> **Source**: Gemini-generated concept mockup (12-action grid), user-flagged during Wave 2 icon spec session
> **Decision**: Game is meant to run long like its genre forebears (Melvor Idle, incremental/idle scope) — current 6 actions are MVP scope only. Expanding the action roster is explicitly planned for after MVP ships, not a scope-creep risk right now.

## Why this file exists
A design/economy pass on these is real work (each new action needs reward-formula design, resource-sink/faucet balance, path-tag interaction with the Class Path System, and its own icon) — not something to improvise between Wave 2 icon prompts. This file just parks the candidate list so it isn't lost, with a first-pass fit read per idea. None of this is committed scope.

## Candidate actions (from the mockup, Polish labels as generated — final names TBD, UI is locked English)

| Concept (PL from mockup) | Working EN name | First-pass fit read | Flag |
|---|---|---|---|
| Drop Merchu | Merch Drop | New resource-sink/faucet shape, fits the existing loop | economy-designer should model against Resource System formulas |
| Zrób Giveaway | Run a Giveaway | Plausible Sponsors-faucet with a Cringe-risk trade, consistent with existing action shape (cost/reward/risk triangle) | — |
| Product Placement | Product Placement | Strong direct Sponsors play | **Check for thematic overlap with existing Sponsors-adjacent actions before adding** — don't want two actions doing the same economic job with different flavor text |
| Współpraca ze Streamerem | Streamer Collab | Reads very close to the existing "Record a Collab" action | **Likely duplicate mechanic, different skin — needs differentiation pass or should be folded into Collab as a variant, not a new slot** |
| Zatrudnij Managera | Hire a Manager | Smells like passive/meta-progression (a persistent modifier), not a one-shot action like the other 11 | **Different mechanic class entirely — may not belong in the action grid at all; could be its own system (upgrades/hires layer)** |
| Załóż drugi kanał | Start a Second Channel | Multi-channel implies parallel progression tracks | **This is not a small addition — it's a systemic feature (second progression axis), needs its own ADR + GDD pass, not a slot in the existing grid** |

## Recommended next step (when MVP ships and this is picked up)
1. `game-designer` + `economy-designer` pass on the 4 straightforward candidates (Merch Drop, Giveaway, Product Placement, Streamer Collab) — resolve the Product Placement/Streamer Collab overlap flags first
2. Treat "Hire a Manager" and "Start a Second Channel" as separate system proposals, not action-grid additions — each needs its own scoping conversation before folding in
3. Run `/create-epics` for whatever survives that pass, same pipeline as the original 6 actions
4. New icons follow the same Wave-1/Wave-2 spec + outline+flat-fill style pipeline already locked

## Explicitly out of scope right now
- Any implementation, ADR, or GDD writing for these — this file is a parking lot, not a spec
- Naming — Polish labels are from the AI mockup only, not locked English UI names
