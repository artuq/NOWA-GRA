# Sprint 11 Prep — Art Bible + First Asset Wave

**Prepared**: 2026-07-06 (end of Sprint 10 day 1 — 6/7 done, only perf pass pending)
**Goal shape**: turn the art-bible stub into the full art bible, then produce the first wave of real assets through the user's pipeline (**Nano Banana generation → Aseprite cleanup/rescale**).

---

## 1. Where we stand (inventory, 2026-07-06)

**Already locked (art-bible-stub, 2026-06-20/25 — do NOT relitigate in the session):**
- Tone: "deadpan analytics dashboard for a clout economy" — metrics readout, never moral judgment
- Aesthetic: **Gamified Analytics, dark mode** (`#15151A` bg, `#2B2B36` surfaces, `#FFFFFF` text) — light mode tried and reverted 2026-06-25
- Rounded card surfaces (~16-20px radius), resource pills icon+color, icon-first action buttons
- Palette tokens: hue-distinct per resource, **NOT valence-coded** (aligns with the juice no-valence rule — now also a registry forbidden pattern, ADR-0011)

**Assets that exist**: 12 icons, all **16×16 pixel-art PNG** (3 action + 5 resource + avatar, card-category, locked, settings) + OpenSans-Regular + MinimalUI4 theme.

**Known problems (user + session findings):**
- Icons don't match their actions well (user, 2026-07-06) — e.g. current mappings feel arbitrary
- 16×16 upscaled onto large buttons reads chunky (visible in web screenshots)
- 3 gated actions (Collab / Interview / Course) REUSE base action icons — need their own
- Font: sizes now fixed (readability confirmed), but the FACE itself is an open art-bible question (typography section)
- Audio: zero assets — stinger structure ships silent (FeedbackMath params ready, layer slots waiting)

## 2. Art bible session agenda (user + art-director, ~1h)

Pre-decided → confirm only: tone, dark palette, pill/card language, no-valence rule.
**Genuinely open decisions:**
1. **Icon grid & style spec**: stay 16×16 (chunky-retro as a feature?) vs 32×32 (crisper at button size)? Outline? Palette constraint per icon?
2. **Icon→action semantic map**: one icon concept per action/resource, written down (fixes "icons don't match" systematically, not ad hoc) — incl. the 3 gated actions and card categories
3. **Typography**: keep OpenSans (readable, confirmed) vs a characterful display font for titles only? (body stays readable)
4. **Audio identity**: stinger palette is already specced in juice GDD (atonal, foley/noise, no pitch coding) — confirm + define the broader audio direction (music? ambient? or silence-first?)
5. **Marketing surface**: thumbnail + hover-video style (portal CTR driver — Poki reference doc) — what single image says "King of Cringe"?
6. **Reduce-motion stance** (carried GDD open question — shake retune raised its relevance)

## 3. First asset wave (candidate scope, priority order)

| # | Asset batch | Count | Unblocks |
|---|---|---|---|
| 1 | Action icons redone to the semantic map (6: vlog, drama, apology, collab, interview, course) | 6 | user's top complaint |
| 2 | Resource icons refresh to same spec (5) | 5 | pill consistency |
| 3 | Card category icon(s) — modal header currently generic | 1-4 | card UI polish (tech-debt item) |
| 4 | Flash color token + pillarbox background art | 2 | replaces `# TODO: art-bible-pending` in code + web shell gradient |
| 5 | Stinger family (transient / sub-thump / noise-tail × magnitude tiers) | ~3-6 files | juice audio goes live (structure ready) |
| 6 | Thumbnail + hover-video capture plan | — | portal launch prep (Release) |

Pipeline per asset: `/asset-spec` prompt sheet → Nano Banana gen → Aseprite cleanup/rescale → drop into `assets/` (layout swap-ready by design).

## 4. Proposed Sprint 11 skeleton (finalize via /sprint-plan after Sprint 10 closes)

- **MH 11-1**: `/art-bible` session (user + art-director) — full doc from stub (0.5d)
- **MH 11-2**: `/asset-spec` — per-asset specs + generation prompts for waves 1-4 (0.5d)
- **MH 11-3**: Asset production wave 1-2 (user in Aseprite/Nano Banana) + integration (1d, user-paced)
- **SH 11-4**: Stinger audio wave (sound sourcing/gen + integration into the ready slots) (0.5d)
- **NTH 11-5**: Card category icons + pillarbox art (0.5d)
- Carry-in: 10-3 perf pass if the device session hasn't happened by then

## 5. Open follow-ups riding along
- Colleague's tunnel test results → spike doc addendum (incl. first-card hook first impression!)
- Formal perf pass (10-3) before Production → Polish gate
- Reduce-motion decision (agenda #6)
