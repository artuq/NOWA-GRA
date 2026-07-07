# Visual Entity & Screen Inventory — King of Cringe

> Generated: 2026-07-07
> Sources: `design/art/art-bible.md`, `design/gdd/action-ui.md`, `design/gdd/card-ui.md`,
> `design/gdd/offline-report-screen.md`, `design/gdd/juice-feedback-system.md`,
> `design/gdd/card-content-database.md`, `production/sprints/sprint-11-prep.md`

## Entities (Icons — 32×32, per art bible §7 semantic map)

| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| 1 | Record a Vlog (action icon) | Icon | Webcam circle, solid red rec-dot | art-bible §7 | Needed |
| 2 | Make Drama (action icon) | Icon | Megaphone, jagged crack through the bell | art-bible §7 | Needed |
| 3 | Apologize Online (action icon) | Icon | Hand holding a folded note/scroll | art-bible §7 | Needed |
| 4 | Record a Collab (action icon) | Icon | Two overlapping webcam circles | art-bible §7 | Needed |
| 5 | Give an Interview (action icon) | Icon | Microphone with small waveform notch | art-bible §7 | Needed |
| 6 | Launch a Course (action icon) | Icon | Stacked rectangles (book) + play-triangle badge | art-bible §7 | Needed |
| 7 | Reach (resource icon) | Icon | Eye inside a signal-bars arc | art-bible §7 | Needed |
| 8 | Cringe (resource icon) | Icon | Cracked speech-bubble shard | art-bible §7 | Needed |
| 9 | Haters (resource icon) | Icon | Clenched fist silhouette (angle implies thumb-down) | art-bible §7 | Needed |
| 10 | Morale (resource icon) | Icon | Battery glyph, no numeric fill | art-bible §7 | Needed |
| 11 | Sponsors (resource icon) | Icon | Handshake reduced to two overlapping chevrons | art-bible §7 | Needed |
| 12 | Card-category icon | Icon | Stacked-card corner-fold glyph (modal header anchor — card-ui.md, card-content-database.md) | art-bible §7 | Needed |
| 13 | Locked (system icon) | Icon | Padlock, closed shackle only, 1 cutout | art-bible §7 | Have (16×16 placeholder — needs 32×32 redo) |
| 14 | Settings (system icon) | Icon | Single gear, 6 teeth max | art-bible §7 | Have (16×16 placeholder — needs 32×32 redo) |
| 15 | Avatar placeholder | Icon | Bare circle chip, no glyph — silhouette IS the signifier | art-bible §5/§7 | Have (16×16 placeholder — needs 32×32 redo) |

*Note: items 13-15 exist at 16×16 and are functional placeholders; redo at 32×32 per the locked grid decision, same semantic concept.*

## UI Screens

| # | Screen Name | Description | Source | Status |
|---|-------------|-------------|--------|--------|
| 1 | Action Screen | Main loop screen: resource HUD + 6-slot action grid + running action overlay | action-ui.md | Implemented (code/scene done; visual polish pending real icons) |
| 2 | Card Modal | Full-screen swipe-to-decide card, text-only per art bible §5 | card-ui.md | Implemented |
| 3 | Offline Report Screen | Full-screen modal on return; headline count-up + itemized deltas | offline-report-screen.md | Implemented |
| 4 | Class Path HUD Indicator | Small badge, top bar, path+tier label | (class-path-system quick-spec) | Implemented |

*All 4 screens are functionally built in `src/ui/` + `scenes/` — this inventory tracks their VISUAL asset needs (icons, backgrounds, VFX polish), not construction.*

## HUD Elements

| # | Element | Description | Source | Status |
|---|---------|-------------|--------|--------|
| 1 | Resource pill background/chrome | Stadium-shaped pill per art bible §3; needs `self_modulate` flash color finalized | art-bible §4 | Needs tech pass (color_activity multiplier — flagged as engineering task, not art) |
| 2 | Locked-slot padlock badge | TextureRect inline with title (Sprint 10 fix) — currently reuses icon_locked.png at 16×16 | src/ui/action_grid.gd | Needs 32×32 asset (same as Entity #13) |
| 3 | Progress bar (action completion) | Neutral track color, uniform style regardless of action — no asset needed, theme-driven | action-ui.md | No asset needed (StyleBox, not image) |
| 4 | Card edge vignette | Soft neutral-tint glow tracking drag direction by position, not hue | card-ui.md | Needed (VFX/shader, not a static icon — candidate for technical-artist spec, not Nano Banana) |
| 5 | Web pillarbox background | `bg_pillarbox_radial` gradient — already shipped as CSS, formalize as in-game asset if native (non-web) builds want the same treatment | art-bible §4 (shipped 2026-07-06) | Done (web); N/A for native builds unless requested |

## Audio

| # | Name | Type | Description | Source | Status |
|---|------|------|-------------|--------|--------|
| 1 | Card stinger — low magnitude | SFX | Single dry transient ("tap"), ~80ms, atonal | juice-feedback-system.md | Needed |
| 2 | Card stinger — mid magnitude | SFX | Transient + light noise-burst tail, ~300-500ms | juice-feedback-system.md | Needed |
| 3 | Card stinger — high magnitude | SFX | Transient + sub-thump + full noise-tail, ~600-900ms | juice-feedback-system.md | Needed |
| 4 | Offline report — entry stinger | SFX | Short, distinct "report ready" cue, non-looping | offline-report-screen.md | Needed |
| 5 | Offline report — digit-tier tick | SFX | Subtle synced tick on K/M rollover during count-up | offline-report-screen.md | Needed (optional per GDD — "if implemented") |
| 6 | Offline report — Morale crash thud | SFX | Low, weightier non-melodic thud, proportional to crash magnitude, texture-distinct not pitch-as-warning | offline-report-screen.md | Needed |

---

## Next Steps

- Run `/asset-spec system:juice-feedback-system` (or icons directly) to spec the 11 NEW icons (#1-12 minus #12 shared) — top priority, user's stated pain point
- Run `/asset-spec` again for the 3 redo icons (#13-15) once wave 1 is approved
- Audio (6 items) specs are DESCRIPTIONS only (per skill convention — no generation prompts for audio); can be specced alongside icons or separately
- Card edge vignette (HUD #4) is a shader/VFX spec, not a static icon — flag for technical-artist when specced
