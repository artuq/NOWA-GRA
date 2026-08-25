# Art Bible — King of Cringe (Król Cringe'u)

> **Status**: **COMPLETE** — all 9 sections approved 2026-07-07 (user + art-director drafts + ux-designer review [2 corrections adopted] + technical-artist constraints). AD-ART-BIBLE gate: skipped — Lean mode.
> **Supersedes**: `design/art/art-bible-stub.md` (2026-06-20/25) — the stub's locked decisions
> (dark-mode Gamified Analytics, palette tokens, pill/card vocabulary) are carried forward
> here verbatim as the foundation; the stub remains as decision history.
> **Anchor**: *"Deadpan analytics dashboard for a clout economy"* — flat, observational,
> satirical; a metrics readout, never a moral judgment.
> **Platforms**: Android touch + Web/HTML5 portals (9:16 portrait everywhere; ≤10 MB initial download budget)

---

## Section 1: Visual Identity Statement

**Visual rule**: Every screen must read as if the player is auditing someone else's metrics dashboard — flat, precise, and emotionally neutral, even when the numbers describe something absurd or damning. The dashboard never editorializes; the content does.

**Supporting principles**:

1. **Precision without judgment** (Pillar 3 — Satire through mechanics, not lecture). The interface renders every number and icon at dashboard-grade neutrality; it never adopts a "good/bad" visual register (glow for success, red for failure). *Design test: when a UI element could be styled as a moral signal, render it as a metric instead.*
2. **Legibility is the fairness** (Pillar 1 — Fair math, unfair world). The one place the UI must never be ambiguous, hidden, or theatrical is the numbers themselves — chaos lives in the systems around the player, never in whether they can read their own state. *Design test: when in doubt between a decorative flourish and numeric clarity, choose clarity.*
3. **One dashboard, always** (Pillar 4 — Offline is a first-class citizen). Active play and the offline report use the identical card/pill/dashboard vocabulary — no separate "away" or "sleep" skin. *Design test: when designing any offline/summary screen, reuse the live-session shape and color system rather than inventing a distinct look.*

---

## Section 2: Mood & Atmosphere

| State | Primary Emotion | Surface Character (dark palette) | Adjectives | Energy | Concrete Element |
|---|---|---|---|---|---|
| **Action screen** | Calm competence / anticipation | Baseline: bg `#15151A`, surfaces `#2B2B36` at rest, low internal contrast, no accent warmth | steady, procedural, quiet, unhurried | Low–medium | Progress bar fill on a neutral track (never a resource hue) ticking at constant rate |
| **Card modal** | Weight / hesitation — deliberately NOT good/bad | Card surface lifts in contrast against a further-dimmed scrim behind it; same neutral gray family, contrast shift only, no hue shift | hushed, spotlighted, deliberate, still | Medium (everything else pauses) | Full-screen dim scrim isolating the card — darkens, never tints, so neither option reads as the "safe" one |
| **Resolution payoff beat** | Release / consequence landing | Brief `self_modulate` brightness pulse using the neutral `color_activity` token, fast decay | snap, immediate, deadpan, brief | High, short spike | Count-up numeral synced to a single neutral flash on the affected pill(s) |
| **Offline report** | Curiosity / audit-review ("checking last night's shift") | Same dark base, presented as a distinct ledger stack (card separation, not color change) | retrospective, orderly, matter-of-fact, ambiguous-pride | Low, contemplative | One hero readout (largest single delta) above itemized rows — same shape language as live screens |
| **Era transition / burnout** (future) | Rupture without punishment | Full-screen brightness/contrast shift through the neutral `color_activity` family, then resolves to fresh baseline | hollow, momentous, deadpan-epilogue | High transient → reset | *Open — placeholder: full-bleed neutral wipe (no hue), pending Prestige/Checkpoint system design* |

Each state is distinct through **contrast and scale changes on the same neutral palette**, never through hue — this keeps the card modal's moral weight legible without color-coding valence (registry forbidden pattern, ADR-0011).

---

## Section 3: Shape Language

**Radius tiers** (formalizing the stub's 16–20px range): Containers (screens/cards) = **20px**. Interactive buttons = **16px**. Resource pills = **full stadium/capsule** (radius = height/2) — pills get maximal roundness to read structurally as "identity chips," distinct from the rectangular-rounded buttons that are "targets to press."

**Icon grid — DECISION: 32×32 native** (approved 2026-07-07). The 16×16 assets upscale chunky and can't carry enough silhouette detail to disambiguate 6 actions + 5 resources + future variants. 32×32 native, exported **un-antialiased** (pixel-art read preserved — chunkiness comes from no anti-aliasing, not from an undersized grid), gives silhouette headroom at both mobile touch scale and web/desktop. Cost negligible against the 10 MB budget.

**Hero vs. supporting shapes**: Action screen — action buttons are hero (largest targets, icon-first); the resource pill row is supporting (smaller, top-anchored, glanceable). Card modal — the card is the sole hero shape; everything else recedes via the dim scrim. Offline report — the top-line summary numeral is hero; itemized rows are supporting list shapes.

**Avatar/persona area** (Expression aesthetic, MDA — cosmetic only, per Anti-Pillar 2: never affects numbers): a **circular avatar chip**, anchored consistently (top corner) across screens. The circle is deliberately the one shape in the vocabulary not shared with pills or buttons — its silhouette alone signals "this is you," not a stat. Full spec deferred to Vertical Slice-tier system design.

---

## Section 4: Color System

**Semantic roles** (identity, not valence — carried from the stub, roles formalized):

| Token | Hex | Identity Meaning |
|---|---|---|
| `color_reach` | `#4A8A91` | Audience-size metric |
| `color_cringe` | `#9A6B92` | Absurdity-accumulation metric |
| `color_haters` | `#6F62A8` | Antagonist-pressure metric |
| `color_morale` | `#A88F5C` | Team-wellbeing metric |
| `color_sponsors` | `#5C8F68` | External-capital metric |

**Neutral activity flash token** (`color_activity` = `#E8E6F0` as a *character* reference): the flash stays a `self_modulate` multiplier tuned to this token's near-white, low-saturation, cool cast — the actual multiplier value is an engineering task (a literal hex-derived multiplier overshoots against `#2B2B36` surfaces since self_modulate is multiplicative). Keep close to the playtested ~1.3–1.4× range; hand to technical-artist for the final number. *Not a paint swatch — a flag.*

**Pillarbox/web background**: formalized as `bg_pillarbox_radial` (center `#1A1A24` → edge `#0D0D14`), slightly darker than the in-game `#15151A` — frames the canvas without a new hue, reads as "dashboard in a dim room," crops cleanly for portal thumbnails. (Already shipped in the web shell CSS, 2026-07-06.)

**Colorblind safety**: `color_reach` (teal) ↔ `color_sponsors` (sage) — moderate protanopia/deuteranopia confusion risk; `color_haters` (violet) ↔ `color_cringe` (mauve) — adjacent purples at similar lightness, moderate risk; `color_morale` (tan) — low risk. **Structural backup**: every resource is a locked icon+color pill (never bare color) — icon silhouette is the accessibility backstop, which makes the Sprint 11 icon semantic-map work an accessibility fix, not just legibility. **Acceptance criterion for the new icon set: pills must remain distinguishable in a grayscale render.**

**Text hierarchy grays**: Primary `#FFFFFF`. Secondary `#B8B6C0` — captions, durations, report rows. Tertiary/disabled `#6E6C78` — locked-slot labels (formalizes the gray already used ad hoc since Story 005).

---

## Section 5: Character Design Direction

There are no characters in the traditional sense — the dashboard IS the world. Two elements carry "character" weight:

**Avatar/persona chip**: 32×32 native grid, circular silhouette, un-antialiased. Expression: **single deadpan baseline face** — no reactive/emotional variants at MVP (a smiling/distressed avatar would be a valence signal, breaking "precision without judgment"). Reactive expression is a Vertical Slice+ cosmetic question, not an art-identity one.

**Cosmetic layering rule**: CAN change — accessory/hat, frame border color, background chip fill. CANNOT change — the face/expression itself, and anything sized or shaped to imply a stat (Anti-Pillar 2: cosmetics never carry numeric meaning).

**Cards — text-only (DECISION, 2026-07-07).** The card-category icon is the modal's sole visual anchor. Rationale: (1) budget — illustrating 40+ cards at Full Vision blows past sensible spend inside the 10 MB ceiling; (2) identity — a drawn face reacting to card content reintroduces the moral-signal problem Section 1 forbids. Reigns uses portraits because its fantasy IS a face judging you — ours is the opposite (a dashboard that never judges).

---

## Section 6: Environment Design Language

"Environment" = screen backgrounds, pillarbox, and dashboard chrome — there is no world geometry.

**Texture philosophy**: flat fills everywhere, zero surface noise/grain on cards and buttons (grain reads as "material," undermining the flat dashboard register). The one shipped exception: `bg_pillarbox_radial`'s soft luminance-only gradient — that's the ceiling for texture, not a precedent.

**Density rule**: near-zero decoration. Every rendered element must be load-bearing (a stat, a control, a status). No idle set-dressing, no ambient clutter — the art-side enforcement of Pillar 1 and the Melvor density warning (Section 9).

**Empire growth across eras**: told through **palette-token intensity and layout density shifts**, not new scenery — pill saturation nudging up, more pill rows as systems unlock, the era-transition wipe resetting to a fresh baseline. Escalation stays legible as data; satirical "set dressing" lives in card copy (Pillar 3).

---

## Section 7: UI/HUD Visual Direction

**Icon style spec (32×32 native, REVISED 2026-07-11, highlight dropped same day)**: bold dark outline + flat fill, pixel-art register — **supersedes the earlier no-outline rule**. User-confirmed reference set (thick-outline retro game-icon style) read more distinctive and legible at chip scale than the flat no-outline pass; the original "outline reads as line-art app icon" risk did not materialize. **No white highlight/sheen** — tested, but a glossy highlight patch reads as toy/candy-bright and conflicts with the Section 1 anchor ("deadpan... never adopts a good/bad visual register") and the Section 9 Balatro caution (avoid saturated candy-bright joy palette). 2-tone budget per icon: 1 dark outline (near-black/deep shade of the icon's hue family), 1 base fill — transparent ground stays outside the count. Zero gradients, zero anti-aliasing — outline edges stay pixel-hard, not soft AA. 1–2 interior cutouts still allowed where the concept needs one (e.g. padlock shackle gap).

**Semantic map** (one concept per icon — the systematic fix for "icons don't match their actions", 2026-07-06):

| Icon | Concept |
|---|---|
| Record a Vlog | webcam circle with a solid red rec-dot |
| Make Drama | megaphone with a jagged crack through the bell |
| Apologize Online | two hands pressed together, praying/pleading gesture (REVISED 2026-07-11, was hand+note) |
| Record a Collab | handshake — two hands clasped together (REVISED 2026-07-11, was two overlapping webcam circles) |
| Give an Interview | hand gripping a microphone with cable (REVISED 2026-07-11, was bare mic with waveform notch) |
| Launch a Course | browser window with an open book overlapping its corner (REVISED 2026-07-11, was stacked books+play; flagged as highest-complexity icon in the set — recheck at chip scale) |
| Reach | hub-and-spoke network glyph — person-in-circle with 6 radiating satellite nodes (REVISED 2026-07-11, was eye+signal-arc) |
| Cringe | cracked speech-bubble shard |
| Haters | speech bubble with censored profanity symbols (REVISED 2026-07-11, was clenched fist) — pairs with Cringe as a communication-metric icon family |
| Morale | single static flame (REVISED 2026-07-11, was battery) — one size/color only, never a scale or intensity variant (would re-introduce the banned "shows a level" pattern) |
| Sponsors | handshake with a dollar-coin above it (REVISED 2026-07-11, was chevrons — gen'd as an unreadable star/pinwheel). Accepted risk: shares a base silhouette with Record a Collab (also a handshake), differentiated by coin accent + color family only |
| Card-category | stacked-card corner-fold glyph |
| Locked | padlock, closed shackle only (no keyhole — 1 cutout rule) |
| Settings | single gear, 6 teeth max |
| Avatar placeholder | the bare circle chip itself — its silhouette IS the signifier |

**Typography (DECISION, 2026-07-07)**: a characterful **display face for titles/headline numerals only** — geometric/grotesque, flat-deadpan; explicitly NOT a meme/comic-hand face (humor-through-typeface is the lecture-adjacent shortcut Pillar 3 forbids). OpenSans stays for all body/caption text (sizes locked and readability-confirmed 2026-07-06). Face selection happens in `/asset-spec`.

**UX corrections (adopted 2026-07-07, ux-designer review)**:
- **Pill rest-contrast exemption**: information-bearing pills are EXEMPT from the Action screen's low-contrast-at-rest rule — pill icon+label must hold a glanceable minimum contrast against `#2B2B36`/`#15151A` at rest (the `color_activity` flash covers change-states; this governs resting legibility).
- **Touch-target minimum**: one hit-area spec for all platforms — interactive elements keep a touch-safe minimum hit rect (per technical-preferences' large-touch-area rule) INDEPENDENT of visual size; a pill-styled element that accepts taps (e.g., locked slots' tap-to-toast) is a button behaviorally and sizes its hit area accordingly. Web desktop never shrinks hit rects below the touch minimum.

**Reduce-motion (MANDATE, 2026-07-07 — supersedes the juice GDD's "defer to Polish")**: shake amplitude respects a reduce-motion flag (gates to near-zero); scale-pulse, flash, and stinger are unaffected (they already carry the no-valence guarantee). Implementation: a small story (data-driven multiplier in FeedbackMath's shake functions + a settings toggle).

**UI animation feel**: the juice system's neutral magnitude-scaled effects are already correct. Art adds: **icons carry zero built-in motion** (no idle bob, no hover wiggle) — icons are static art; all motion is the juice system's job. This keeps the set portable and "deadpan" literal at the asset level.

---

## Section 8: Asset Standards

**Format**: PNG, RGBA, 32×32 canvas, transparent background.

**Naming (LOCKED — renames have real cost, see import constraints)**: `assets/ui/icons/icon_[category]_[name].png`; categories: `action`, `resource`, `card`, `system` (locked, settings, avatar).

**Export rules**: no anti-aliasing, no baked drop shadows/outlines beyond the icon's own silhouette, pixel-perfect edges on the 32×32 grid.

**Godot import constraints (technical-artist, 2026-07-07)**:
- **Filter**: every icon-bearing `TextureRect`/`Sprite2D` sets `texture_filter = 1` (NEAREST) explicitly **at the node** (project default is Linear; do not change the project default — it would silently affect all other UI textures). Runtime-created nodes too (action_grid badge precedent).
- **Mipmaps**: off (2D screen-space UI never distance-scales).
- **Compression**: `compress/mode=0` (Lossless) on both mobile and web — VRAM block compression visibly degrades 1px pixel-art edges, and at 32×32 the savings are meaningless.
- **`.import` files**: always committed together with their source PNG. Renaming/moving a source changes its `res://` path + UID and breaks scene references — the naming convention above is locked for this reason.
- **No atlas**: 20–30 individual small PNGs are nowhere near the ≤100 draw-call budget under Godot's 2D batcher. Revisit only if a future profiling pass shows draw-call pressure.

**Audio — CUT (2026-07-12, permanent design decision)**: this game ships with no sound effects or music,
ever. Precedent: Reigns (Day-1 comparable title, `game-concept.md`) — "no audio cues are necessary to play
the game well"; Melvor Idle ships near-silent by design. This project cuts audio entirely rather than making
it optional. The format standard that lived here (Ogg Vorbis, mono, 44.1 kHz, q4–5, ~15–30 KB/stinger) is
preserved in `design/assets/specs/audio-wave-1-assets.md` as a historical record — 2 of 6 assets were produced
and verified before the cut. Not implemented, no `assets/audio/` folder is wired into any scene.

**Source-file discipline**: `.ase` sources live in `assets/_source/icons/`, mirroring `ui/icons/` 1:1 — exports only ever land in `assets/ui/icons/`, never the reverse.

**Nano Banana prompt block (REVISED 2026-07-11, highlight dropped same day — verbatim in every generation prompt, consistency depends on this never drifting)**:

Two family variants — pick by icon category (Section 7 style spec: outline + flat fill, NO highlight):

> **Actions** (neutral/control icons): *"A 2D video game UI icon of a [SUBJECT], low-resolution 32×32 pixel art style, retro 8-bit game asset. Monochromatic pale lavender-blue color palette with thick dark indigo bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games."*

> **Resources** (metric icons): *"A 2D video game UI icon of a [SUBJECT], low-resolution 32×32 pixel art style, retro 8-bit game asset. Vibrant [HUE NAME derived from Section 4 token] color palette with thick dark [deep shade of same hue] bold outlines. Flat solid color fill, no shading, no highlights, no gloss. Isolated on a solid flat magenta (#FF00FF) background, minimalist design, highly readable for mobile games."*

Generation background stays **magenta (#FF00FF)**, not white — keys out cleanly in the Aseprite cleanup pass (Section 8 production checklist) and never appears elsewhere in the palette; never shipped magenta.

---

## Section 9: Reference Direction

| Reference | Take | Avoid |
|---|---|---|
> **Provenance (corrected 2026-07-12)**: this table must trace back to `design/gdd/game-concept.md`'s Day-1
> (2026-06-19) "Comparable Titles" list — Beggar's Life, Melvor Idle, Idle Research: Endless Tycoon — plus
> Reigns (cited separately in the same doc for the card-decision mechanic). **Balatro** and **YouTube Studio /
> TikTok Analytics** were added unilaterally during the 2026-07-07 `/art-bible` session without going through
> `AskUserQuestion` approval like the rest of that session's decisions did — user did not plan or approve
> either and removed both 2026-07-12. Lesson: reference-direction entries are a real design decision, not a
> drafting-judgment-call — they need the same Question→Options→Decision→Approval loop as everything else.

| Reference | Take | Avoid |
|---|---|---|
| **Reigns** | Card-as-sole-hero staging — full-viewport card, everything else dimmed/paused during a decision | Its expressive character portraits with emotional facial read — a valence signal we've ruled out (Section 5) |
| **Melvor Idle** | Nothing visually — cited as the density warning | Its tabbed, panel-heavy UI; confirms our 3-action sparse screen is the right contrast, not a compromise |
| **Beggar's Life** | The *feeling* of watching things degrade — conveyed through our numbers/palette shifts, never scenery | Its overloaded, exhausting UI and illustrated scene art — directly the failure mode Section 6 is designed against |
| **Idle Research: Endless Tycoon** | The idle/active hybrid depth — passive number-watching AND active resource-allocation choices, matching this project's own Core Fantasy ("optimizer satisfaction" + weighty decisions, `game-concept.md`) | Its sheer system breadth (18 research items, 70 skills, 12 potions, 62 accelerators simultaneously) — same density warning as Melvor; we stay sparse by design, not by budget constraint |
