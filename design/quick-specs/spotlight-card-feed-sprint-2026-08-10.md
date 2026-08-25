# Quick Design Spec: Skill Challenge Card — Feed Sprint

**Type**: Addition
**System**: Decision Card System / Card UI / Card Content Database
**GDD References**: `design/gdd/decision-card-system.md`, `design/gdd/card-ui.md`
**Date**: 2026-08-10

## Change Summary

A separate `Skill Challenge` card category offers an optional 24-second Feed
Sprint. These cards contain no moral/path decision: Play starts the challenge
and its score determines the reward amount; Skip exits without cost or reward.

## Motivation

The card loop is the game's highest-attention moment but currently contains only
narrative choices. A clearly separate skill-card category varies pacing without
contaminating moral decisions with dexterity or making execution skill mandatory
for Class Path and story progression.

## Design Delta

Current cards resolve one of two authored consequences. A
`card_category = "skill_challenge"` card still has two explicit options, but
`Play` enters a temporary Spotlight phase and resolves a validated score reward;
`Skip` resolves normally with zero deltas. DecisionCardSystem remains the only
reward authority.

## New Rules / Values

1. The prototype adds one neutral `feed_sprint_challenge` card. Until its
   persisted intro flag is set, it is guaranteed as the second card unless
   selected naturally as the first, forming a lightweight controls tutorial.
   This also upgrades older saves once; after the first appearance, selection
   returns to the normal weighted pool. Existing moral,
   path, Burnout, and signature cards never launch mini-games.
2. Feed Sprint contains 16 deterministic 1.5-second events across three equal,
   full-height lanes. The interface names all lanes, highlights the player's
   current lane, and identifies the active target as a Trend to catch or Strike
   to avoid. Left/Right controls work by touch and keyboard.
3. `score = collected_trends / total_trends`, clamped to `[0,1]`.
4. Completing pays `reward = round(R_min + (R_max-R_min) * score^k)`.
   Prototype: `R_min=30 Reach`, `R_max=220 Reach`, `k=1.5`. Skip gives zero.
5. Interruption completes with the score earned so far and never traps the card.
   Skill cards write no risky/safe/path counters or milestones.
6. No reward is applied until Spotlight finishes. Duplicate finish/skip resolves
   exactly once.
7. The reaction beat states the exact payout. Skip states that no penalty was
   applied.
8. Reduce Motion replaces vertical travel with a static lane event and countdown;
   scoring, timing, labels, and controls remain identical.
9. The library also includes `comment_moderation_challenge`: ten timed
   KEEP/DELETE classifications covering fans, useful feedback, hate, spam, and
   scams. Every session shuffles the balanced 5/5 set and rejects strict
   alternation or simple one-action blocks. Accuracy maps to 25..190 Reach with
   exponent 1.35.
10. Each undiscovered Skill Challenge receives its own one-shot showcase with
    one ordinary card between showcases. Seen challenge IDs persist, including
    migration from the original Feed-Sprint-only boolean flag.

## Tuning Data

Timing, lanes, events, moderation ordering policy, reward resource,
minimum/maximum payout, and curve exponent live in
`assets/data/spotlight_minigames.json`.

## Affected Systems

| System | Impact | Action Required |
|---|---|---|
| Card Content Database | Adds skill category and challenge metadata | Add `feed_sprint_challenge`; existing cards unchanged |
| Decision Card System | Defers Play and validates score reward | Optional score input; default cards unchanged |
| Card UI | Adds `SPOTLIGHT` state and Feed Sprint | Preserve modal blocking/reaction beat |
| Action System | Suspended until final resolution | No API change |
| Settings System | Supplies Reduce Motion | Read only |

## Acceptance Criteria

- [ ] Every existing card resolves byte-for-byte as before.
- [ ] Skill-card Play enters Feed Sprint before reward mutation; Skip gives zero.
- [ ] Score 0 completion grants exactly 30 Reach; score 1 grants 220 Reach.
- [ ] Intermediate scores follow the exponent curve.
- [ ] Non-finite/out-of-range scores cannot inflate rewards.
- [ ] Skill cards change no counters, milestones, path affiliation, or Cringe.
- [ ] Duplicate completion/skip cannot resolve twice.
- [ ] Touch, keyboard, interruption, and Reduce Motion remain completable.
- [ ] Prototype fits 720x1280 with minimum 44x44 controls.
- [ ] Existing Decision Card and Card UI regression suites pass.

## GDD Update Required?

Yes. After feel validation, fold the skill-card category, Spotlight state, and
schema into Decision Card System, Card UI, and Card Content Database GDDs. This
quick spec is the implementation authority for the single-card prototype.
