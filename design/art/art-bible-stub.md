# Art Bible Stub — King of Cringe

> **Status**: Stub — minimal unblock for the Pre-Production → Production gate
> (Art Director's escalation, 2026-06-20, due 2026-06-27). Full art bible
> (all 9 sections) remains an open commitment for Production; this stub is
> not a substitute for it.

**Tone descriptor**: Deadpan analytics dashboard for a clout economy — flat,
observational, satirical; reads like a metrics readout, never a moral judgment.

**Revised 2026-06-25 (Art Director review)**: the first implementation (dark,
flat, bordered, text-only — the MinimalUI4 generic theme) read as a debug
console, not a satire of social-media glitz. Locked direction going forward:

- **"Gamified Analytics" aesthetic** — think YouTube Studio / TikTok Analytics,
  not a spreadsheet (explicitly the failure mode we're avoiding from
  Beggar's Life, per the GDD's own stated critique of that game's overloaded UI).
- **Dark mode** (**reversed 2026-06-25, second playtest round**): the light-mode
  attempt above was implemented, but the project has no custom viewport
  background configured — white cards rendered floating on Godot's default
  near-black clear color, producing exactly the harsh, broken-looking contrast
  this direction was meant to avoid. Reverted to dark surfaces (`#15151A` app
  background, `#2B2B36` card/button surfaces, `#FFFFFF` text) — this also
  re-aligns with the `color_*` palette tokens below, which were already
  calibrated against a dark background (see that section's own revision note).
  "Gamified Analytics" tone is unchanged — dark mode is a legitimate variant of
  that aesthetic (most real analytics dashboards ship a dark theme), not a
  reversion to the earlier "debug console" failure mode, since surfaces stay
  rounded/card-like and icon-first, just on a dark base instead of light.
- **Rounded, card-like surfaces** — `corner_radius` ~16-20px on buttons and
  resource pills, never sharp rectangles.
- **Resources as icon+color "pills"**, not bare colored text — each resource
  gets a rounded pill with an icon and its `color_*` token as an accent (fill
  or icon tint), not just a colored text label.
- **Icon-first action buttons** — the action's icon is the primary meaning-
  carrier; name/duration/reward text is a secondary caption beneath it, not
  the main content.
- **Icons are real pixel-art assets (Aseprite), not yet produced** — emoji are
  used as temporary placeholders only (🎥 vlog, 🔥 drama, 🙏 apology, 👁️ Reach,
  😬 Cringe, 😡 Haters, 💚 Morale, 💰 Sponsors) until real sprites exist; swap
  placeholders for real art without redesigning the layout around them.
- **Light "juice"**: resource value changes get a brief scale-punch (~1.0→1.3→1.0,
  ~200ms) on the pill, not just an instant text swap — a small, locally-scoped
  piece of the eventual `Juice/Feedback System` (Vertical Slice tier), not a
  substitute for it.

## Palette Tokens

Data-driven, hue-distinct identity only — **NOT valence-coded**. Hues chosen
for maximum mutual separation across the color wheel for fast touch-glance
recognition. The `color_activity` token (desaturated near-white) is the only
color used for magnitude-based feedback (flashes, popups) — intensity there
reads via scale/opacity, never hue, per the locked no-valence-coding anti-pillar.

| Token | Hex | Resource |
|---|---|---|
| `color_reach` | `#4A8A91` | Reach (muted teal) |
| `color_cringe` | `#9A6B92` | Cringe (muted mauve) |
| `color_haters` | `#6F62A8` | Haters (muted violet) |
| `color_morale` | `#A88F5C` | Morale (muted tan) |
| `color_sponsors` | `#5C8F68` | Sponsors (muted sage) |
| `color_activity` | `#E8E6F0` | Neutral flash/popup (magnitude-only feedback) |

**Revised 2026-06-25** (playtest finding): the original tokens (brighter cyan-teal
`#2BB3C0`, magenta `#C44FB0`, violet `#7A5BE0`, amber `#E0A63A`, green `#3FA85A`)
were hue-distinct as designed, but high saturation + brightness made several of
them read as valence-coded in practice despite the stated "NOT valence-coded"
intent — Cringe's magenta was perceived as warning-red/pink, and Morale's amber
glowed as alarm-red against the dark UI background. **Saturation and brightness
are the actual drivers of "alarm" perception, not hue alone** — this revision
keeps the same 5 hue families (preserves mutual separation for fast touch-glance
recognition) but desaturates and darkens all 5 uniformly, removing the
warning-color reading without losing identity-distinctness.

Note: `color_sponsors` uses green purely as a distinct identity hue, not as a
"good" indicator — consistent with the project's locked rule that no color
anywhere encodes valence. Reconsider further if playtesting still surfaces an
unintended "good money" reading even at this desaturated value.

## Typeface Pairing

- **Display/headings**: Archivo (or any grotesque with heavy weights) — blocky, dashboard-like.
- **Body/numerals**: Inter — neutral, tabular figures for clean count-up readouts.
- **Current (2026-06-25, Art Director call)**: the project ships **VT323**
  (SIL OFL 1.1, `assets/ui/fonts/`) as the global UI font, imported with
  antialiasing OFF + subpixel positioning OFF for crisp pixel-perfect glyphs
  that match the pixel-art icons. The earlier smooth Open-Sans placeholder
  clashed hard with the pixel-art icons ("cheap 2005 Flash game" look) — a
  pixel font was the missing piece that visually unifies the whole screen.
  Archivo/Inter remain the aspirational pairing for a future polish pass if a
  non-pixel direction is ever revisited, but VT323 is the locked interim choice
  and reads well for the retro-analytics-dashboard tone.

## Next Steps

This stub satisfies the Production-gate unblock condition only. The full art
bible (visual identity foundation, asset standards, UI/UX visual direction,
production pipeline — all 9 sections) is still owed before the next phase gate.
Run `/art-bible` when ready to expand this into the full document.
