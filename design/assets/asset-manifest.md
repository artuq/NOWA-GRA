# Asset Manifest

> Last updated: 2026-07-12

## Progress Summary

| Total | Needed | In Progress | Done | Approved | Cut |
|-------|--------|-------------|------|----------|-----|
| 21 | 0 | 0 | 15 | 2 | 4 |

## Assets by Context

### Icons: Wave 1 (actions + resources)
All 11 generated, cleaned up, wired into `assets/ui/icons/`, reimported, and confirmed live in the web build on real device/browser (2026-07-11) — dark background, readable at chip scale, outline+flat-fill style holds up.

| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-001 | Record a Vlog | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-002 | Make Drama | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-003 | Apologize Online | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-004 | Record a Collab | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-005 | Give an Interview | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-006 | Launch a Course | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-007 | Reach | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-008 | Cringe | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-009 | Haters | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-010 | Morale | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |
| ASSET-011 | Sponsors | UI/Icon | Done | design/assets/specs/icons-wave-1-assets.md |

### Icons: Wave 2 (system/card, 32×32 redo)
Generated, cleaned up, reimported, 402/402 tests green (2026-07-11). Card-category and Locked confirmed live (card modal, locked-badge). Settings and Avatar are asset-ready but have no consuming scene yet — `SettingsScreen` and an avatar-chip node don't exist in `src/`/`scenes/` yet, that's separate UI-construction work, not an art gap.

| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| ASSET-012 | Card-category | UI/Icon | Done — confirmed live in card modal | design/assets/specs/icons-wave-2-assets.md |
| ASSET-013 | Locked | UI/Icon | Done — confirmed live in locked-badge | design/assets/specs/icons-wave-2-assets.md |
| ASSET-014 | Settings | UI/Icon | Approved — asset ready, no Settings screen to host it yet | design/assets/specs/icons-wave-2-assets.md |
| ASSET-015 | Avatar placeholder | UI/Icon | Approved — asset ready, no avatar-chip node to host it yet | design/assets/specs/icons-wave-2-assets.md |

### Audio: Wave 1 (6 stingers/cues) — CUT 2026-07-12 (permanent)
**Audio is out of this game entirely — not deferred, a locked design pillar** (precedent: Reigns' "no audio
cues necessary," Melvor Idle's near-silence — both Day-1 comparable titles, see `game-concept.md` and
art-bible.md §9). Decision made after AUDIO-003 repeatedly failed the no-pitch requirement (AI-gen kept
producing a ~45Hz tonal sub-bass instead of filtered noise) and research confirmed 2 of this project's own
4 reference games barely use audio anyway. AUDIO-001/002 were already produced and FFT-verified (no pitch
detected, correct format) before the cut — kept in `assets/audio/sfx/` as unused historical files, not wired
into any scene. `stinger_params()`/`_play_stinger()`/`_stinger_player` in `feedback_math.gd`/`card_screen.gd`
are now dead code pending a cleanup story.

| Asset ID | Name | Category | Status | Spec File |
|----------|------|----------|--------|-----------|
| AUDIO-001 | Card stinger — low magnitude | SFX | Cut — produced+verified, unused | design/assets/specs/audio-wave-1-assets.md |
| AUDIO-002 | Card stinger — mid magnitude | SFX | Cut — produced+verified, unused | design/assets/specs/audio-wave-1-assets.md |
| AUDIO-003 | Card stinger — high magnitude | SFX | Cut — abandoned mid-production (pitch violation) | design/assets/specs/audio-wave-1-assets.md |
| AUDIO-004 | Offline report — entry stinger | SFX | Cut — never started | design/assets/specs/audio-wave-1-assets.md |
| AUDIO-005 | Offline report — digit-tier tick | SFX | Cut — never started | design/assets/specs/audio-wave-1-assets.md |
| AUDIO-006 | Offline report — Morale crash thud | SFX | Cut — never started | design/assets/specs/audio-wave-1-assets.md |

## Queued (not yet specced)
- VFX: card edge vignette (shader, technical-artist spec)
