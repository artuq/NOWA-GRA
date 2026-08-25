# Tooling Review — fucking-magictools awesome-list (2026-07-07)

**Source**: https://github.com/Correia-jpv/fucking-magictools
**Reviewers**: Fable (repo scan) + audio-director (SFX deep-dive vs stinger spec)

## Verdicts

| Tool | Category | Verdict for King of Cringe |
|---|---|---|
| **ChipTone** | SFX generator | **ADOPT for stinger placeholders** — best fit (2023 rewrite, multi-layer tone+noise stacking = our GDD "layer density" model). NOISE-ONLY patches, heavy low-pass, short envelopes, NO presets (melodic by construction = no-pitch rule violation). Placeholder-only: synthesis can't do the GDD's foley register (paper/cardboard/body-hit) — final pass = sound-designer with real foley |
| jfxr | SFX generator | Fallback for ChipTone (browser, same class) |
| Bfxr | SFX generator | Skip — oldest, presets skew tonal/arpeggiated |
| Squoosh | Image compression | Use at Release — thumbnail/store asset weight for portals |
| LibreSprite / PiskelApp | Pixel art | Backup only — user has Aseprite |
| Littera | Bitmap fonts | Skip — typography decision needs TTF display face (Google Fonts at /asset-spec) |
| Rosebud / Unity AI tools | AI asset gen | Skip — not Godot; Nano Banana pipeline stays |

## Stinger placeholder pipeline (ChipTone → spec)

1. ChipTone: Noise patch type only, low-pass filtered, short envelope, no pitch-sweep/arpeggio
2. Export WAV → Audacity: verify/resample 44.1kHz, downmix mono, trim silence, normalize, export **Ogg Vorbis q4-5**, confirm 15-30KB
3. Drop into stinger slots (structure ships ready — null-stream guard, `stinger_params(m)` drives layers/tail/saturation)

## Open gap flagged (audio-director)

**No LUFS/normalization target defined** in juice GDD or art bible audio standards — add when sound-designer does the final foley pass.

## Bottom line

1 strong adoption (ChipTone = all 6 placeholder stingers, unblocks audible juice THIS sprint-tier), 1 minor (Squoosh at Release), rest duplicates existing pipeline.
