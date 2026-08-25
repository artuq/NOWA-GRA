# Asset Specs — Audio Wave 1 (6 stinger/cue sounds)

> **STATUS: CUT 2026-07-12 (permanent design decision) — HISTORICAL RECORD ONLY, NOT IMPLEMENTED.**
> This game ships with no audio, ever. See `design/gdd/juice-feedback-system.md` Open Questions and
> `design/art/art-bible.md` §8/§9 for the decision and its rationale (Reigns/Melvor Idle precedent, and
> AUDIO-003's repeated pitch-detection failures during production). AUDIO-001/002 were produced and
> FFT-verified before the cut and remain in `assets/audio/sfx/` unused. This file is kept as a record of
> the synthesis approach in case audio is ever reconsidered — do not pick up new work from it without a
> fresh decision reversing the cut.

> **Source**: design/assets/entity-inventory.md (Audio table, #1–6) + design/gdd/juice-feedback-system.md
> (`stinger_params(m)`, `src/ui/feedback_math.gd`) + design/gdd/offline-report-screen.md + design/reference/
> tooling-magictools-review-2026-07-07.md + design/art/art-bible.md §8
> **Art Bible**: design/art/art-bible.md
> **Scope note**: descriptions + synthesis specs only, per skill convention — no generation prompts for audio
> (mirrors entity-inventory's "Next Steps" note). Placeholder wave — ChipTone synthesis, not final foley.

## Shared Technical Block (all 6)

- **Format (LOCKED, art-bible §8)**: Ogg Vorbis, mono, 44.1 kHz, quality q4–5. Target ≈15–30 KB per stinger
  (shorter one-shots may legitimately fall below this floor — noted per-asset where relevant).
- **Synthesis tool (adopted, tooling-review 2026-07-07)**: **ChipTone**, Noise patch type ONLY. No tone/pitch
  oscillator patches, no arpeggio/vibrato, no melodic presets — noise-only construction is structural, not
  stylistic: pitch/harmony are reserved exclusively for valence-coded elements (none exist in this game) and
  must never appear here (GDD, Audio — Decision Card resolution stinger family).
- **Hard rule — no pitch, ever**: no pitch-sweep, no pitch-bend, no resonant filter peaks (resonance reads as
  a tone, not noise) on any of the 6 assets. This is the audio equivalent of the icon set's "no gauges/no
  faces" anti-pillar — magnitude/severity is communicated by **loudness, layer density, and tail length**,
  never by pitch.
- **Multi-layer builds**: ChipTone renders one patch/pass at a time — stingers with more than one described
  layer (mid/high-tier card stingers) are built as separate ChipTone exports per layer, mixed down in
  Audacity. This matches the tooling-review pipeline exactly (see Production Checklist).
- **Export pipeline (tooling-review 2026-07-07, unchanged)**:
  1. ChipTone: Noise patch, low-pass filtered, short envelope, no pitch-sweep/arpeggio → export WAV per layer
  2. Audacity: layer-mix (if >1 layer) → verify/resample 44.1kHz → downmix mono → trim silence → normalize to
     **-1.0 dBTP** (see Loudness Target below) → export Ogg Vorbis q4–5 → confirm file size
  3. Drop into the stinger slot; no engine-side DSP is used to fake layers/tail/saturation — everything is
     baked into the file at export time (see Open Flags — this differs from a literal reading of
     `stinger_params(m)` as a runtime mixer; flagged below)
- **Naming (proposed, confirmed 2026-07-13)**: `[category]_[event]_[variant].ogg` → `assets/audio/sfx/`.
  Mirrors the `assets/ui/icons/icon_[category]_[name].png` precedent (art-bible §8) with a categorized
  subfolder under `assets/audio/` (no such folder exists yet in the repo — this spec is what creates the
  convention; `assets/audio/music/`, `assets/audio/ambience/` are the implied sibling folders for future
  waves, not created now).
- **Source-file discipline**: no `.ase`-equivalent source mirror — ChipTone patch settings are fully
  documented in this spec (patch type, filter, envelope, per-asset below) instead of a saved project file,
  since ChipTone doesn't have a stable project-save format in the same way Aseprite does. If a future
  foley/DAW pass replaces these placeholders, its own source-file convention should be defined at that time.
- **Godot import**: default `AudioStreamOggVorbis` import settings — no NEAREST/lossless-style overrides
  needed (that's an icon-specific texture concern). `loop = off` on all 6 — every asset in this wave is a
  non-looping one-shot per its entity-inventory description.
- **Concurrency**: every asset in this wave is a single-voice one-shot (no round-robin/variant pool — see
  Variation Planning in Mixing & Concurrency Documentation below for why).

---

## AUDIO-001 — Card Stinger, Low Magnitude — `stinger_card_low.ogg`
**Code hook**: `FeedbackMath.stinger_params(m)` tier where `layers == 1` (m < `TIER_MID` = 0.3, the only tier
producing 1 layer). Baked at representative **m ≈ 0.0** — the tier's floor, chosen because it produces an
exact match to both the formula's `STINGER_TAIL_MIN_SEC` (0.08s) and entity-inventory's stated "~80ms."

- **Description**: single dry transient ("tap"), atonal, no tail.
- **ChipTone patch**: Noise (white noise generator). No frequency/pitch parameter used.
- **Envelope**: Attack 0ms (instant) → Sustain ~10ms → Decay ~50–60ms → no release tail. Total ≈80ms.
- **Filter**: Low-pass, cutoff ~2.5–3.5 kHz, **zero resonance** (resonance would introduce a perceptible
  pitch center — forbidden). Cutoff chosen to dampen harsh white-noise hiss into a "paper-flick"/light-tap
  character, consistent with the GDD's foley register note (paper/cardboard/body-hit textures).
- **Saturation**: none — `stinger_params(0.0).saturation = 0.0`.
- **Duration target**: 80ms.
- **File size target**: 12–18 KB (below the general 15–30KB band — expected given the very short duration;
  not a defect).
- **Ready-to-paste (ElevenLabs text-to-SFX)**: "A single dry percussive transient, like a light paper-flick or
  soft tap, atonal, no musical pitch, no melody, no reverb tail, low-pass filtered to remove harsh
  high-frequency hiss, textural noise-based sound effect, not a musical note." **Set duration explicitly via
  the tool's duration/length control (~0.08–0.1s) if one exists — text-embedded durations are not reliably
  honored.** If no duration control exists, trim in Audacity per the Production Checklist (this is a normal
  pipeline step, not a failure).

## AUDIO-002 — Card Stinger, Mid Magnitude — `stinger_card_mid.ogg`
**Code hook**: `FeedbackMath.stinger_params(m)` tier where `layers == 2` (0.3 ≤ m < 0.7). Baked at
representative **m ≈ 0.5** (tier midpoint) → `tail_sec` = 0.49s, `saturation` = 0.5 — both fit cleanly inside
entity-inventory's stated 300–500ms range.

- **Description**: transient + light noise-burst tail.
- **Build**: 2 ChipTone layers, mixed in Audacity:
  - **Layer A (transient)**: identical patch to AUDIO-001 (Noise, 0/10/50ms envelope, ~3kHz low-pass, no
    resonance) — the "hit" component.
  - **Layer B (tail)**: Noise patch, longer envelope (Attack 0ms → Sustain ~60ms → Decay ~380ms, total
    ≈440ms), low-pass cutoff **sweeping from ~3kHz down to ~1kHz** across the decay (a filter-cutoff sweep on
    noise reads as "brightness settling," not a pitch glide — this is a texture move, not a tonal one; no
    resonance at any point in the sweep).
  - Mixdown: Layer A leads at full level; Layer B enters ~5ms later at ~70% level under it, extending the
    tail to ~490ms total.
- **Saturation**: mild soft-clip on the mixed peak, ~0.5 intensity (subtle grit, not audible distortion).
- **Duration target**: ~490ms (top half of the 300–500ms band).
- **File size target**: 24–28 KB.
- **Ready-to-paste (ElevenLabs text-to-SFX)**: "A dry percussive tap immediately followed by a short
  noise-burst tail that fades in brightness as it decays, atonal, no musical pitch, no melody, textural
  broadband noise, subtle grit/saturation, not a musical note." Set duration ~0.5s via the tool's duration
  control if available; otherwise trim/mix in Audacity per the checklist.

## AUDIO-003 — Card Stinger, High Magnitude — `stinger_card_high.ogg`
**Code hook**: `FeedbackMath.stinger_params(m)` tier where `layers == 3` (m ≥ 0.7). Baked at representative
**m ≈ 0.85** (tier midpoint) → `tail_sec` = 0.777s, `saturation` = 0.85 — both fit inside entity-inventory's
stated 600–900ms range.

- **Description**: transient + sub-thump + full noise-tail, stacked.
- **Build**: 3 ChipTone layers, mixed in Audacity:
  - **Layer A (transient)**: same as AUDIO-001/002's Layer A — the leading "hit."
  - **Layer B (sub-thump)**: Noise patch, **heavy low-pass cutoff ~100–150 Hz**, zero resonance, envelope
    Attack 0ms → Decay ~150ms. Heavily-filtered noise at this cutoff reads as a low, weighty thump without
    a discernible pitch center — this stays inside the adopted "noise-only" method (a literal sine-wave
    sub-boom was deliberately rejected here specifically because a clean sine is a pitched, tone-generator
    element; filtered noise achieves the same felt weight while remaining structurally non-tonal).
  - **Layer C (full noise-tail)**: broadband Noise patch, longest element, low-pass cutoff sweeping
    ~4 kHz → 600 Hz across ~780ms, sets the overall tail length.
  - Mixdown: A leads, B enters ~5ms later (adds low-end weight under the transient), C underlies both at
    a lower level and carries the tail out to ~780ms total.
- **Saturation**: pronounced soft-clip on the mixed peak, ~0.85 intensity — "reads as physical force, not
  emotional tone" (GDD wording) — audible but not harsh/crunchy distortion.
- **Duration target**: ~780ms (mid-band of 600–900ms).
- **File size target**: 28–30 KB (upper edge of the general budget — if the mixdown exceeds 30KB, trim
  Layer C's tail silence before the export step, not the perceptual length).
- **Ready-to-paste (ElevenLabs text-to-SFX)**: "A dry percussive hit combined with a low weighty sub-thump and
  a longer broadband noise tail that darkens over time, atonal, no musical pitch, no melody, physically
  forceful but not emotional or dramatic, noticeable saturation/grit, textural sound effect, not a musical
  note." Set duration ~0.78s via the tool's duration control if available; otherwise trim/mix in Audacity per
  the checklist.

## AUDIO-004 — Offline Report Entry Stinger — `offline_report_entry.ogg`
**Code hook**: Offline Report Screen `hidden → showing` transition (per GDD States and Transitions table) —
fires once, the moment the screen becomes visible (only reachable when `Δt ≥ MIN_REPORT_THRESHOLD_SECONDS`,
so this never fires on trivial app-switches). **No existing code stub** — unlike the card stinger's
`_stinger_player` in `card_screen.gd`, the Offline Report Screen has no audio wiring yet; this is new
engineering scope (see Open Flags).

- **Description**: short, distinct "report ready" cue, non-looping.
- **ChipTone patch**: Noise, low-pass filtered. Deliberately built with a **different envelope shape** than
  any card stinger so it doesn't read as part of the same event family, while staying inside the same
  texture-only vocabulary (no pitch difference used to distinguish it — shape/timbre only).
- **Envelope**: inverted-shape "swell then drop" — Attack ~40–60ms (soft fade-in) → Decay ~150–200ms (quick
  drop). This slow-attack/fast-decay shape reads as "arriving/opening" purely through dynamics, distinct
  from the card stingers' instant-attack "hit" shape.
- **Filter**: Low-pass, static cutoff ~2–2.5 kHz (slightly darker/duller than the card stingers — an
  "administrative dashboard" texture rather than an "impact" texture), zero resonance.
- **Saturation**: none — this is a notification, not an impact; keep it clean.
- **Duration target**: 250ms.
- **File size target**: 15–18 KB.
- **Ready-to-paste (ElevenLabs text-to-SFX)**: "A soft fade-in swell of muted noise followed by a quick drop,
  like a notification arriving, atonal, no musical pitch, no melody, dull administrative texture, not an
  impact sound, clean with no distortion, textural sound effect, not a musical note." Set duration ~0.25s via
  the tool's duration control if available; otherwise trim in Audacity per the checklist.

## AUDIO-005 — Offline Report Digit-Tier Tick — `offline_report_tick.ogg`
**Status**: optional per GDD ("if implemented" — count-up digit-tier rollover is not confirmed as built).
**Code hook**: Offline Report Screen headline count-up, on K/M digit-tier rollover (GDD Visual/Audio
Requirements). **Not tied to `FeedbackMath`** — no magnitude scaling. The **same file** is reused for both a
K rollover and an M rollover; a louder/brighter tick on the M crossing would imply "bigger milestone = more
triumphant," which is a valence leak this spec deliberately avoids.

- **Description**: subtle synced tick, atonal.
- **ChipTone patch**: Noise, very short, no resonance. Cutoff sits higher than the other 5 assets
  (~4–5 kHz) specifically to read as a crisp "tick" rather than a "thud" — distinguishing role from timbre
  brightness, not pitch.
- **Envelope**: Attack 0ms → Decay ~15–20ms → no tail.
- **Saturation**: none.
- **Duration target**: 30ms.
- **File size target**: 6–10 KB — intentionally under the general 15–30KB band given the extremely short
  duration; not a defect, don't pad it to hit the floor.
- **Ready-to-paste (ElevenLabs text-to-SFX)**: "An extremely short crisp tick of high-frequency noise, atonal,
  no musical pitch, no melody, brief click texture, not a musical note." Set duration ~0.03s via the tool's
  duration control if available — this one is very likely to need heavy trimming in Audacity regardless, since
  most generators have a practical minimum output length well above 30ms.
- **Concurrency note**: if the count-up animation is fast enough to cross K and M within the same ~40ms
  window, two tick instances could overlap. Given the 30ms duration this is a minor risk (short natural
  decay, unlikely to read as a buzz) — flagged for a quick listen once implemented rather than pre-solved
  here with a cooldown/voice-limit rule that may not be needed.

## AUDIO-006 — Offline Report Morale Crash Thud — `offline_report_morale_crash.ogg`
**Code hook**: Offline Report Screen display logic, Morale band-changed branch (GDD Detailed Rules: "Morale
shown as its band label... with an indicator if the band changed"). Plays whenever the band changed during
the offline period. **Severity handling (approved 2026-07-13)**: a single baked file, with **runtime
`volume_db` scaling only** distinguishing a one-band shift from a multi-band crash — no pitch change, no
duration change, no second asset. This matches entity-inventory's single-line listing (#6) and the GDD's own
qualitative (not numeric) severity description.

- **Description**: low, weightier non-melodic thud — texture-distinct from a "failure" cue, not pitch-coded.
- **ChipTone patch**: Noise, heavy low-pass — same family/vocabulary as AUDIO-003's sub-thump layer (for
  cross-event sonic consistency), but built and exported as its own standalone single-layer asset since this
  is a different screen/moment, not a reuse of the card-stinger file.
- **Filter**: Low-pass cutoff ~100–180 Hz, zero resonance (avoid any ringing that would read as a pitch).
- **Envelope**: Attack 0ms → Punch/Decay ~150–250ms → no long tail — a thud is a single compact event, unlike
  the card stingers' noise-tails.
- **Saturation**: moderate soft-clip baked in — reads as "weightier impact," per GDD wording.
- **Duration target**: 220ms.
- **File size target**: 15–20 KB.
- **Runtime severity mapping (proposed default, pending audio-director/systems-designer confirmation — no
  numeric formula exists in offline-report-screen.md to derive this from)**:
  - One-band shift: `volume_db ≈ -6.0`
  - Multi-band crash: `volume_db = 0.0` (full baked level)
  - This is the same "loudness = magnitude, never pitch" principle already used for the card stinger family,
    applied here in the absence of a real formula.
- **Ready-to-paste (ElevenLabs text-to-SFX)**: "A low weighty thud of heavily filtered low-frequency noise,
  atonal, no musical pitch, no discernible note, physically heavy impact texture, not an emotional or dramatic
  cue, moderate saturation/grit, textural sound effect, not a musical note." Set duration ~0.22s via the
  tool's duration control if available; otherwise trim in Audacity per the checklist.

---

## Mixing & Concurrency Documentation

**Bus assignment (proposed — no audio bus infrastructure exists yet)**: `project.godot` currently defines
only the default `Master` bus. This spec recommends a single `SFX` bus for all 6 assets (routed to `Master`,
no ducking/sidechain needed at this scope — there is no music/ambience bus yet to duck against). This is a
**recommendation for engineering**, not a change made by this spec — bus creation is outside sound-designer
scope (middleware/config change).

**Relative levels**: card stingers scale loudness with `saturation`/tier as already baked (low quietest, high
loudest — see Loudness Target below for the exact ratio). The two Offline Report one-shots (entry stinger,
Morale crash) are independent screens from the Card stingers and never play concurrently with them (Card UI
and Offline Report Screen are mutually exclusive full-screen modals per their own state machines) — no
cross-fade/masking risk between those families in practice.

**Frequency masking**: AUDIO-003 (card high) and AUDIO-006 (Morale crash) share the same low-frequency
sub-thump register (~100–180Hz low-pass noise). Since the two screens can't be visible simultaneously, this
is a non-issue for this wave — noted here only so a future ambience/music layer knows this low-end pocket is
already "claimed" by these two SFX.

**Concurrency/voice limits**:
- Card stingers: single-voice, one `AudioStreamPlayer` (`_stinger_player` in `card_screen.gd`) — Card UI's
  existing single-card-at-a-time rule means only one card stinger can ever be pending at once. No
  voice-limit/cooldown logic needed.
- Offline Report entry stinger: fires exactly once per screen `showing` (matches the screen's own
  hidden→showing→hidden state machine — can't retrigger without a full dismiss/re-show cycle).
- Offline Report tick: see AUDIO-005's concurrency note above (minor, unsolved-by-design overlap risk at very
  fast count-up speeds).
- Morale crash thud: fires at most once per report (one band-changed check per screen show).

**Variation planning**: no round-robin/pitch-randomization variants are planned for any of the 6 assets.
Two reasons: (1) pitch randomization is structurally forbidden by the no-valence-coding rule — pointless to
ask "how much random pitch" when the answer is zero; (2) repetition-fatigue risk is low at this scope —
Action System events (the frequent 4–9s cycle) carry **no stinger at all** per the GDD (only count-up + label
flash), so stingers only fire on Decision Card resolutions and Offline Report entries, both rare events (12
cards total in Card Content Database, one Offline Report per return-to-game). A single static file per slot
is sufficient; revisit only if a future foley pass finds fatigue in playtesting.

---

## Loudness / Normalization Target (proposed — DRAFT, flagged for audio-director sign-off)

The tooling review (2026-07-07) flagged that no LUFS/normalization target exists anywhere in the juice GDD or
art bible. Proposal:

- **True-peak ceiling: -1.0 dBTP** on every exported file — applied at the Audacity "normalize" step already
  in the adopted pipeline (headroom against clipping/inter-sample peaks on web/mobile output; no change to
  the existing pipeline steps, just a concrete number for the step that already exists).
- **Momentary loudness reference (400ms window): ≈ -18 LUFS** for the loudest asset in the set (AUDIO-003,
  card-high). Integrated LUFS is not proposed as the primary metric — it's not a stable measurement for
  sub-second one-shots (needs sustained duration to gate correctly); momentary/short-term LUFS is more
  appropriate for this material.
- **Relative tier ratio**: card-low sits ≈6dB quieter than card-high (mid ≈3dB below high) — loudness itself
  becomes part of the "how much happened" signal, consistent with the GDD's magnitude-only rule (never a
  valence signal, since both a "win" and a "loss" of equal magnitude get the identical loudness).
- **Status**: this is a first-draft technical threshold proposed by sound-designer, matching the treatment of
  other open technical thresholds this session (draft → flagged for confirmation, not silently locked).

---

## Open Flags / Known Gaps

1. **3 discrete files represent a continuous formula** — `stinger_params(m)`'s `tail_sec`/`saturation` are
   continuous across [0,1] but only 3 fixed files exist. Banding at tier boundaries (e.g., m=0.29 and m=0.05
   sound identical) is an accepted placeholder limitation, not an oversight — matches the tooling review's
   own framing of ChipTone as placeholder-only.
2. **No tier-selection logic exists in code yet** — `card_screen.gd`'s `_play_stinger()` only supports a
   single `_stinger_player.stream`; there is no logic mapping `stinger_params(m).layers` to
   low/mid/high file selection. Needs a follow-up engineering story (godot-gdscript-specialist) before these
   3 assets can actually play differentiated in-game.
3. **Offline Report Screen has zero existing audio wiring** — unlike Card UI's stubbed `_stinger_player`,
   there is no `AudioStreamPlayer`, no null-stream guard, nothing in the Offline Report Screen code for any
   of AUDIO-004/005/006. This is new engineering scope, not a drop-in.
4. **Morale crash "magnitude" has no formula** — offline-report-screen.md only describes severity
   qualitatively (one-band vs multi-band). The `-6dB`/`0dB` volume_db mapping above is a sound-designer
   placeholder default, not derived from a locked systems-design formula.
5. **LUFS/true-peak target is a first-time proposal** — pending audio-director confirmation before being
   treated as a locked technical standard (same status as the Ogg Vorbis q4–5 spec was before art-bible §8
   locked it).
6. **No audio bus infrastructure exists in `project.godot`** — the `SFX` bus recommendation above is
   unimplemented; routing/mixing config changes are out of sound-designer scope.
7. **`assets/audio/sfx/` does not exist yet** — this spec establishes the convention; the folder is created
   when the first asset is actually produced (per the Production Checklist below), not by this spec itself.

---

## Production checklist (per stinger)

1. Build patch(es) in ChipTone per the spec above (Noise-only, correct filter/envelope/layer count)
2. Export WAV per layer → Audacity: layer-mix if >1 layer, resample 44.1kHz, downmix mono, trim silence,
   normalize to -1.0 dBTP, export **Ogg Vorbis q4–5**
3. Confirm file size against the per-asset target; confirm duration against the per-asset target
4. Export → `assets/audio/sfx/[filename].ogg` (creates the folder on first asset)
5. Flag AUDIO-004/005/006 and the tier-selection logic for AUDIO-001/002/003 as engineering follow-up
   stories before wiring into `card_screen.gd` / Offline Report Screen scenes (see Open Flags #2–3)
6. A/B validation per GDD's stated method: audition a "big win" mock event and a "big disaster" mock event
   at matching magnitude for AUDIO-001/002/003 — must be indistinguishable in emotional read
