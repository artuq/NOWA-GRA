# Quick Design Spec: Early Sponsor and Polish Humor Showcase

**Type**: Addition
**System**: Decision Card System / Card Content Database
**GDD Reference**: `design/gdd/card-content-database.md`, `design/gdd/onboarding-tutorial.md`
**Date**: 2026-08-13

## Change Summary

The first-session card sequence must demonstrate the game's strongest loops
instead of leaving them to a 26-card random pool. After one ordinary decision,
the game presents a one-time four-card showcase: Feed Sprint, a guaranteed
Sponsor-paying brand deal, Comment Moderation, and a Polish-humor card.

## Motivation

A ten-minute playtest produced neither Sponsors nor the promised Polish humor.
Both are key return-loop and identity signals, so failing to surface them is an
onboarding failure rather than desirable variance.

## New Rules / Values

1. Card one remains an ordinary weighted decision.
2. Cards two through five are guaranteed once per career in this order:
   `feed_sprint_challenge`, `brand_deal_choice`,
   `comment_moderation_challenge`, `polish_export_disaster`.
3. Unseen showcase cards are excluded from random selection until their turn.
4. Showcase completion is persisted. Loading a save never repeats a card that
   was already shown; older saves receive only showcase entries they have not
   seen yet.
5. `brand_deal_choice` is used because both choices grant Sponsors (+3 or +1),
   making Sponsor acquisition guaranteed without removing player choice.
6. Polish cultural copy is localization-only. Mechanics and option ordering
   remain identical in English and Polish.

## Acceptance Criteria

- [ ] A fresh career receives the four showcase cards in the specified order
  after its opening ordinary card.
- [ ] Either choice on the guaranteed brand deal grants at least one Sponsor.
- [ ] Showcase progress survives save/restore and New Game clears it.
- [ ] The Polish humor card has complete English and Polish localization keys.
- [ ] After the showcase, selection returns to the existing weighted pool.
- [ ] No regression in the normal card cooldown or minigame launch flow.

## GDD Update Required?

Yes. The onboarding tutorial and card-content inventory should adopt the
one-time showcase sequence and updated card count during the next documentation
consolidation pass. This quick spec is the implementation source meanwhile.
