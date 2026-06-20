# Offline Report Screen

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 4 — Offline jest pierwszą klasą obywatelską

## Overview

Offline Report Screen to ekran prezentacji wyniku symulacji offline — wyświetla `total_Z_gained`, zmiany w `final_H`/`final_M`, oraz komunikat o `capped` jeśli offline trwało dłużej niż 24h. Ten GDD nie liczy niczego (to robi Offline Progress System) — definiuje, jak ten wynik jest pokazany graczowi i jaki gest go zamyka, przenosząc Offline Progress System ze stanu `presenting` do `idle`.

Dla gracza to pierwszy ekran, który widzi po powrocie do gry — moment "co przegapiłem?", który ma zbudować zaufanie do systemu offline (Pillar 4) i zachętę do regularnych powrotów.

## Player Fantasy

Gracz wraca do gry i pierwsze co widzi to dowód, że jego imperium "żyło" bez niego — duże, satysfakcjonujące liczby, czytelny opis tego co się stało. To jest moment nagrody za samo wrócenie, analogiczny do otwierania powiadomień z social media po przerwie. Gracz aktywnie czyta i zamyka ekran jednym gestem — krótki, satysfakcjonujący rytuał, nie przeszkoda między nim i graniem.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents not consulted — Lean mode. Review manually before production.*

### Core Rules

**Design question resolved:** should this screen appear on *every* return to the game, even if `Δt` was negligible (e.g., a quick app-switch)? Offline Progress System's Edge Case says `Δt=0` yields `total_Z_gained=0` — showing "you gained 0 Zasięgi" every time would be irritating.

**Decision:** the screen only appears when `Δt ≥ MIN_REPORT_THRESHOLD_SECONDS` (minimum threshold, 300s/5min — revised up from an initial 60s proposal per `systems-designer` review, which flagged 60s as too short given Action System's 4-9s session rhythm and the risk of anticlimactic "+2 Zasięgi" reports) — shorter gaps return directly to the game without interruption.

**Layout:**
1. Headline: large `total_Z_gained` number (formatted per Action UI's `action_ui_number_format` — same K/M convention, not a new one).
2. Secondary section: Hatersi change (`final_H - H0`) and Morale (`final_M` vs `M0`, with band label).
3. Time description: "You were offline for [X]" (e.g., "6 hours", "23 hours") — a legible unit, not raw seconds.
4. If `capped=true`: an additional message ("Your break was longer than 24h — we only counted the first 24h").
5. One "Continue!" button (or tap anywhere) to dismiss.

**Rules:**
1. The screen appears once, at app start, **after** Offline Progress System's simulation completes (`presenting` state) — only if `Δt ≥ MIN_REPORT_THRESHOLD_SECONDS`.
2. If `Δt < MIN_REPORT_THRESHOLD_SECONDS`, Offline Progress System transitions `presenting→idle` automatically (no player gesture) — this case doesn't need the screen.
3. Dismiss (tap/button) is the only way to close — no auto-dismiss timer (the player must actively confirm, per Offline Progress System's "gated on player action"). Both the "Continue!" button and tapping anywhere on the screen are live simultaneously and trigger the identical dismiss signal — there is no distinction between the two input sources; whichever fires first wins (see Edge Cases for the multi-tap/mixed-input case).

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `hidden` | Screen not visible | → `showing` when Offline Progress System enters `presenting` AND `Δt ≥ MIN_REPORT_THRESHOLD_SECONDS` |
| `showing` | Report visible, awaiting dismiss | → `hidden` on player tap/button |

### Interactions with Other Systems

- **Offline Progress System** (hard, read+write) → reads the simulation result (`total_Z_gained`, `final_H`, `final_M`, `capped`, `Δt`); sends the dismiss signal that transitions that system from `presenting` to `idle`
- **Action UI** (peer, read) → reuses the same number-formatting convention (`action_ui_number_format`), does not define its own

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

This GDD has one genuine display derivation; everything else (`total_Z_gained`, ΔH, ΔM, band, `capped`) is direct pass-through of values already computed by Offline Progress System's `simulate_offline` — documented as Detailed Rules, not new formulas.

**format_duration** is defined as:

`format_duration(Δt) = pick the largest unit U ∈ {hours, minutes} where Δt ≥ U.seconds, round down, render "N unit(s)"`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Elapsed time | Δt | int | [300, 86400] (bounded by `MIN_REPORT_THRESHOLD_SECONDS` and `MAX_OFFLINE_CAP_SECONDS`) | Offline duration in seconds |
| Selected unit | U | enum | {hours, minutes} | No "days" tier needed — `MAX_OFFLINE_CAP_SECONDS` is locked at 86400 (24h), so the display never exceeds "24 hours" |
| Displayed count | N | int | 5–59 (minutes), 1–24 (hours) | Floored count in the chosen unit |

**Output Range:** bounded string, max value "24 hours" (display caps here rather than ever showing "1 day").
**Example:** Δt=85620s (23h47m) → hours=floor(85620/3600)=23 → "23 hours". Δt=300s (5min, the minimum) → minutes=floor(300/60)=5 → "5 minutes".

**Singular/plural rule:** N=1 renders the singular unit label ("1 hour", "1 minute"); N≠1 renders the plural ("23 hours", "5 minutes").

**Single-unit display only — no remainder:** the formula shows exactly one unit, never a remainder (e.g., Δt=3601s renders "1 hour", not "1 hour 0 minutes" or "1 hour 1 second") — this is intentional simplicity, not an oversight.

**Detailed Rules (pass-through, not formulas):**
- `total_Z_gained` displayed using Action UI's `action_ui_number_format` (K/M convention) — not redefined here.
- Hatersi change shown as signed delta: `"+" + (final_H - H0)` rounded to nearest integer.
- Morale shown as its band label (per Resource System's bands), with an indicator if the band changed during the offline period (e.g., "High → Critical").
- `capped` flag, if true, triggers the additional message defined in Core Rules — no computation, just a conditional display branch.

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If `Δt` is below `MIN_REPORT_THRESHOLD_SECONDS`**: the screen never appears — Offline Progress System transitions `presenting→idle` automatically (per Core Rules rule 2), the player returns straight to the game.
- **If `final_H = H0`** (no Hatersi at start, none accrued in the period): the delta displays as "+0" — not hidden, since it's still true information.
- **If the Morale band didn't change** during offline (e.g., stayed "High" the whole time): only one band label is shown, no arrow/change indicator — the change indicator only appears when the band actually shifted.
- **If the player taps repeatedly while the screen is dismissing** (e.g., rapid multi-tap): the first tap initiates the `showing→hidden` transition; subsequent taps during the transition are ignored — no double-dismiss call.
- **If `total_Z_gained = 0` despite exceeding the threshold** (theoretically possible with `H0=0` and a short period just above the threshold): the screen still appears (the threshold gates on `Δt`, not the result) and displays "0" with no special treatment — rare but valid case.

## Dependencies

**Upstream (this system depends on):**
- **Offline Progress System** (hard) — simulation result and `presenting` state.

**Peer:**
- **Action UI** (soft) — reuses its number-formatting convention; not a hard dependency since the convention could be duplicated if needed, but should not diverge.

**Downstream (depends on this system):**
- **Main Navigation/Screen Flow** (hard, Vertical Slice, undesigned) — will integrate this screen into broader app navigation.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `MIN_REPORT_THRESHOLD_SECONDS` | 300 (5 min) | 60–900 | Too low: anticlimactic reports on trivial app-switches. Too high: genuine short breaks never get acknowledged |

**Knob interaction:** none — independent of other GDDs' tuning knobs, though conceptually related to `MAX_OFFLINE_CAP_SECONDS` (Offline Progress System) as the other end of the Δt range this screen handles.

## Visual/Audio Requirements

> *Specialist consulted: `art-director` — category is "UI systems," mandatory for Visual/Audio.*

- **Headline count-up:** `total_Z_gained` animates from 0 up to its final value over a short, fixed duration (independent of magnitude — large and small results feel equally snappy, not proportionally slower). Mirrors the real "FOMO notification" feeling the screen intentionally leans into (Pillar 3: satire through mechanics). Skippable — the dismiss gesture works immediately without waiting for the count-up to resolve.
- **Morale band crash (no valence color-coding):** a band shift (e.g., High→Critical) is communicated through **magnitude of motion/scale**, never color or "danger" iconography — consistent with the established anti-pillar (no explicit moral score). A one-band shift gets a small transition; a multi-band crash gets more pronounced motion (bigger scale, brief impact beat) — but stays within the same neutral palette used for Morale at every band. No separate "bad" color family exists for crashes.
- **Audio:** one short, distinct stinger on screen entry ("report ready" cue, not looping). If count-up is implemented, digit-tier rollovers (crossing into K, then M) get a subtle synced tick. A Morale crash gets a lower, weightier non-melodic thud proportional to crash magnitude — texture-distinct, not pitch-as-warning — never a separate "failure" sound.

📌 **Asset Spec** — once the art bible is approved, run `/asset-spec system:offline-report-screen`.

## UI Requirements

- The screen must block other app interactions for its entire on-screen duration — a full-screen modal, similar to Card UI.
- The "Continue!" button must have a large touch area, per `technical-preferences.md` — zero hover-only.
- The headline count-up animation must run smoothly on target Android devices without stutter (frame budget per `technical-preferences.md`).

> 📌 **UX Flag — Offline Report Screen**: This screen has real UI requirements. In Phase 4, run `/ux-design` for `design/ux/offline-report.md` before writing epics.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Threshold gate:**
- **GIVEN** Δt<300s, **WHEN** Offline Progress System enters `presenting`, **THEN** screen never shows; transitions `presenting→idle` directly, no player gesture.
- **GIVEN** Δt=299s, **THEN** screen does not appear (boundary excluded).
- **GIVEN** Δt=300s exactly, **THEN** screen appears (inclusive boundary, `≥`).
- **GIVEN** Δt≥300s, **WHEN** entering `presenting`, **THEN** → `hidden→showing`.

**format_duration formula:**
- **GIVEN** Δt=300s, **THEN** output="5 minutes".
- **GIVEN** Δt=3599s, **THEN** output="59 minutes".
- **GIVEN** Δt=3600s, **THEN** output="1 hour" (singular).
- **GIVEN** Δt=3601s, **THEN** output="1 hour" (single-unit, no remainder shown).
- **GIVEN** Δt=85620s, **THEN** output="23 hours".
- **GIVEN** Δt=86400s (max cap), **THEN** output="24 hours" (never "1 day").

**Display rules:**
- **GIVEN** total_Z_gained=1,500,000, **WHEN** rendered, **THEN** headline matches Action UI's `action_ui_number_format` output exactly (e.g., "1.5M") — contract, not re-derived here.
- **GIVEN** final_H=394, H0=5, **THEN** Hatersi delta displays "+389".
- **GIVEN** final_H=H0, **THEN** delta displays "+0" (shown, not hidden).
- **GIVEN** Morale band changed during offline (e.g., High→Critical), **THEN** change indicator shown alongside current band.
- **GIVEN** Morale band unchanged, **THEN** only current band label shown, no indicator.
- **GIVEN** capped=true, **THEN** the capped message is displayed in addition to standard fields.
- **GIVEN** capped=false, **THEN** no capped message.

**State transitions:**
- **GIVEN** `showing`, **WHEN** the player taps the dismiss button OR taps anywhere on screen, **THEN** → `hidden`, dismiss signal sent to Offline Progress System (`presenting→idle`) — both input sources trigger the identical signal.
- **GIVEN** `hidden`, **WHEN** no trigger met, **THEN** stays `hidden` indefinitely (no auto-dismiss).

**Defined edge cases:**
- **GIVEN** final_H=H0, **THEN** "+0" shown, never hidden/omitted.
- **GIVEN** Morale band unchanged, **THEN** no change indicator (consistent with display rules above).
- **GIVEN** `showing→hidden` in progress, **WHEN** the player taps multiple times (button, background, or mixed) during the transition, **THEN** only the first tap initiates the transition and fires the dismiss signal exactly once; all subsequent taps during the window are no-ops.
- **GIVEN** total_Z_gained=0 and Δt≥300s, **THEN** screen still appears, displays "0" (or formatted equivalent), no special-case messaging.

**Not testable against this GDD alone:**
- Full integration with Main Navigation/Screen Flow (does this screen block other launch UI, splash screens, etc.) — undesigned, Vertical Slice.
- Exact `action_ui_number_format` output string — owned by Action UI; this GDD can only assert the contract is used, not the literal formatted string.
- Exact Morale band names/thresholds — owned by Resource System; this GDD tests indicator behavior (shown only on change), not label content.

## Open Questions

- **Full integration with Main Navigation/Screen Flow** (does the screen block splash screens, other launch UI) — undesigned. *Owner: Main Navigation/Screen Flow GDD. Target: Vertical Slice.*
- **Exact count-up animation duration** — "short, fixed duration" not specified in ms. *Owner: `/ux-design`. Target: Pre-Production.*
