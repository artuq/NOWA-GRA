# Juice/Feedback System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-20
> **Implements Pillar**: Pillar 3 — Satyra przez mechanikę, nie wykład

## Overview

Juice/Feedback System to warstwa odpowiedzi na zdarzenia z Action System i Decision Card System, w dwóch częściach: (1) **sensoryczny juice** — krótkie efekty wizualne/audio (count-up, flash, screen-shake skalowany magnitudą) i (2) **resolution payoff** — krótka, napisana reakcja tekstowa po rozwiązaniu karty, potwierdzająca konsekwencję wyboru (styl Reigns: "coś się wydarzyło", nie tylko "liczby się zmieniły"). To rozróżnienie wynika z analizy referencyjnych gier: Melvor Idle/Idle Research hookują przez number-go-up + odhaczanie kamieni milowych (sensoryczne), Reigns/Beggar's Life hookują przez narracyjny punchline po decyzji — oba mechanizmy są tu w zakresie.

Ten GDD nie wymyśla nowej logiki gry ani nowej treści narracyjnej — definiuje **mapowanie zdarzeń na efekty i strukturę payoff-tekstu** (kiedy się pojawia, jak długo, jaki ma format), nie sam tekst (to konsumuje istniejące pole `text`/`resolution_reaction` Card Content Database lub wymaga jego rozszerzenia — flagowane w Dependencies). Intensywność obu kanałów skaluje się z magnitudą wyniku, nigdy z walencją moralną (kontynuacja anti-pillara z Action UI/Card UI/Offline Report Screen).

Bezpośrednia motywacja: pierwszy vertical slice (PIVOT, 2026-06-20) potwierdził działającą mechanikę, ale zerowy hook — "klikałem byle klikać". Ten system istnieje, by to naprawić, łącząc sensoryczny feedback z narracyjnym payoff.

## Player Fantasy

Gracz czuje **wielkość tego, co się właśnie wydarzyło** — niezależnie od tego, czy to dobrze czy źle dla niego wypadło. To jest sedno Pillar 2 (decyzje są pamięcią, nie punktami) zamienione w fizyczne odczucie: decyzja, która zdetonowała wielki kontrakt sponsorski, ląduje z **dokładnie tą samą intensywnością** (ten sam shake, ta sama rodzina stingerów) co decyzja, która wywołała viralowy sukces — gracz reaguje "łaa" zanim mózg przypisze ocenę "dobre/złe". Tekst-payoff po rozwiązaniu karty czyta się jak płaski, obserwacyjny raport z wnętrza logiki algorytmu — nigdy moralizujący, czasem absurdalny w swojej beznamiętności (gallows humor Reigns, nie sitcomowy laugh track). To jest moment, w którym anti-pillar (intensywność = magnituda, nie walencja) przestaje być regułą UI, a staje się odczuciem.

> *Player Fantasy shaped by `creative-director` — Option 2 "Consequences Have Weight" selected.*

## Detailed Design

> *Specialists not consulted — Lean mode (Core Rules is not D/H).*

### Core Rules

**Sensory juice — shared magnitude scale:**
1. Every event (`action_completed`, `card_resolved`) carries a magnitude `0.0-1.0`, computed from the size of resource deltas relative to their known ranges (formula in Section D).
2. **Action System** (frequent, 4-9s cycle): subtler channel — number count-up in the HUD (short, fixed duration regardless of magnitude, matching the existing Offline Report Screen pattern), light flash on the resource label, no screen-shake (too frequent, would fatigue).
3. **Decision Card System** (rare, weighty): stronger channel — screen-shake/scale-pulse scaled by magnitude, audio stinger from a texture family (not pitch — magnitude means "how much," not "good/bad"), **plus resolution payoff** (rule 5).
4. No channel ever encodes valence (good/bad) — only magnitude. The same effect set for a huge win and a huge disaster.

**Resolution payoff:**
5. After `resolve_choice()`, instead of immediately closing the card modal, the card's text is **replaced** by a short reaction text (`resolution_reaction` — a field consumed from Card Content Database, see Dependencies) for a duration proportional to text length (1.5-2.5s, formula in Section D), after which the modal closes as before (Card UI's existing `resolving` state).
6. Resolution payoff is this system's only textual element — this GDD defines **when/how long** it appears, not the content itself (content is a narrative-director/writer task when extending Card Content Database).

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `idle` | No active effect | → `pulsing` when `action_completed` or `card_resolved` emits |
| `pulsing` | Sensory effect in progress (count-up/shake/stinger) | → `idle` once the effect completes (duration depends on channel) |
| `payoff_showing` | (Decision Card only) reaction text replaces card text | → `idle`, signals Card UI to proceed to closing the modal |

### Interactions with Other Systems

- **Action System** (peer, read) → listens to `action_completed`, reads rewards to compute magnitude
- **Decision Card System** (peer, read+signal) → listens to `card_resolved`, reads card_id/option to compute magnitude and fetch `resolution_reaction`; sends a "payoff complete" signal to Card UI so it proceeds to closing the modal
- **Card Content Database** (hard, read, requires schema extension — see Dependencies) → reads `resolution_reaction` per card/option

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

**Feedback magnitude** is defined as:

`magnitude(deltas) = clamp(max over r in deltas of (contribution(r)), 0.0, 1.0)`

where `contribution(r)` is linear-ratio for registry-bounded resources and log-compressed for unbounded ones:
- Bounded (Cringe, Morale): `contribution(r) = |delta_r| / norm_ref(r)`
- Unbounded (Zasięgi, Sponsorzy, Hatersi): `contribution(r) = log(1 + |delta_r|) / log(1 + Z_norm_ref)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Resource deltas | deltas | Dictionary[String, float] | — | Resource name → signed delta applied this event |
| Resource key | r | String | {Cringe, Morale, Zasięgi, Sponsorzy, Hatersi} | Resource being evaluated |
| Normalization reference | norm_ref(r) | float | resource-specific | The delta size counted as "maxed out" (1.0) for that resource |
| Zasięgi normalization | Z_norm_ref | float (tuning) | 40 | Reference delta for log normalization — chosen so the largest known base reward (10, Drama) feels strong but leaves headroom |
| Per-resource contribution | contribution(r) | float | [0.0, 1.0] | Normalized magnitude per resource |
| Output | magnitude | float | [0.0, 1.0] | Final feedback intensity driving shake/pulse/audio scale |

Per-resource `norm_ref`: **Cringe** = 35 (max of action ceiling 20 and card ceiling 35); **Morale** = 30 (gap between adjacent bands, e.g. 70→40, so a full band-jump = 1.0); **Zasięgi/Sponsorzy/Hatersi** use the log formula above with `Z_norm_ref = 40`.

**Output Range:** [0.0, 1.0], hard-clamped.
**Example:** Drama action resolves with `{Cringe: +20, Morale: -3, Zasięgi: +10}` → Cringe contribution = 20/35 = 0.571; Morale = 3/30 = 0.100; Zasięgi = log(11)/log(41) = 0.646 → `magnitude = max(0.571, 0.100, 0.646) = 0.646`.

**Rationale:** linear ratio for registry-bounded resources matches the locked bands exactly; log compression only for the unbounded Zasięgi/Sponsorzy case avoids fabricating a ceiling while still preventing runaway shake intensity from a freak large value.

---

**Payoff text duration** is defined as:

`payoff_duration(text_length) = clamp(D_min + (text_length / L_ref) × (D_max - D_min), D_min, D_max)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Text length | text_length | int | [0, ~120] chars | Character count of the resolution-payoff string |
| Duration floor | D_min | float (locked) | 1.5 | Minimum display duration, seconds |
| Duration ceiling | D_max | float (locked) | 2.5 | Maximum display duration, seconds |
| Length reference | L_ref | int (tuning) | 60 | Character count at which duration reaches D_max — approx. one short Polish sentence |
| Output | payoff_duration | float | [1.5, 2.5] | Seconds the payoff text remains on screen |

**Output Range:** [1.5, 2.5] seconds, hard-clamped — handles empty strings (floor) and unexpectedly long localization strings (ceiling) without breaking pacing.
**Example:** "+20 Zasięgów!" (13 chars) → 1.5 + (13/60)×1.0 = 1.717s. "Stracił 15 Cringe, ale zdobyłeś sponsora!" (42 chars) → 1.5 + (42/60)×1.0 = 2.2s.

**Rationale:** linear scaling between locked bounds gives longer localized strings more read-time without violating the fixed display-window pattern already established for count-up animations elsewhere in the project.

## Edge Cases

> *Specialist not consulted — Lean mode.*

- **If `magnitude=0` (delta near zero)**: the sensory effect still plays (lowest tier — minimal flash, no shake/audio), never skipped — the player always gets confirmation "something happened," even if minimal.
- **If a `card_resolved` event has an empty/missing `resolution_reaction` field** (card doesn't have payoff text written yet): the `payoff_showing` state is skipped, modal closes as it did before this GDD existed — doesn't block play while Card Content Database is being extended.
- **If two events (`action_completed` and `card_resolved`) overlap in time**: impossible per the existing single-concurrency rules of both source systems (Action System, Decision Card System) — no handling needed here.
- **If magnitude would exceed 1.0 before clamping** (theoretically, a very large Zasięgi delta): the Section D formula already handles this (hard clamp) — no additional logic.
- **If the app is backgrounded mid-effect** (interruption): the effect simply doesn't finish visually, but internal state (`idle`/`pulsing`) resets to `idle` on resume — no persisted state to restore (this system has no `restore_state()`, nothing persists).

## Dependencies

**Upstream (this system depends on):**
- **Action System** (peer, read) — `action_completed` signal, reward data for magnitude calculation.
- **Decision Card System** (peer, read) — `card_resolved` signal, card/option data for magnitude calculation.
- **Card Content Database** (hard, requires schema extension) — needs a new `resolution_reaction` field per card per option (currently doesn't exist — all 12 cards need this field added before resolution payoff can show real content; until then, Edge Cases' empty-field fallback applies).

**Peer:**
- **Card UI** (hard, write) — receives the "payoff complete" signal to proceed with closing the modal; Card UI's existing `resolving` state absorbs this addition without a new state of its own.

**Downstream (depends on this system):** None yet.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `Z_norm_ref` (Zasięgi log normalization) | 40 | 20-80 | Too low: small rewards already feel maxed-out, no headroom for big sponsor cards. Too high: even Drama's reward feels weak |
| `L_ref` (payoff text length reference) | 60 chars | 40-100 | Too low: long localized strings get cut off feeling rushed. Too high: short reactions linger too long, slowing pacing |
| `norm_ref(Cringe)` | 35 | 20-50 | Should track Card Content Database's `card_cringe_delta_band` ceiling (currently 35) — keep in sync if that range changes |
| `norm_ref(Morale)` | 30 | 20-40 | Should track Resource System's band gaps (currently 30, e.g. 70→40) — keep in sync if bands change |

**Knob interaction:** `norm_ref(Cringe)` and `norm_ref(Morale)` are derived from other GDDs' already-locked values, not independently tunable — changing Resource System's bands or Card Content Database's delta ceiling requires updating these knobs to match, not the reverse.

## Visual/Audio Requirements

> *Specialists consulted: `art-director` and `audio-director` — category is "Visual effects/Audio systems," mandatory for Visual/Audio. No art bible exists yet — values below use placeholder/data-driven tokens, flagged `// TODO: art-bible-pending` in implementation.*

**Visual — resource-label flash (Action System, subtle channel):**
- Single flash pulse on the label background/glow, fixed duration (~150-200ms) regardless of magnitude — only the count-up number content changes with magnitude, not the flash duration.
- One neutral "activity" color token only, identical for every event regardless of whether the resource went up or down — no valence-paired colors (no red/green hue swap).
- Flash is a brightness/opacity pulse on existing label chrome, not a color change of the number text itself, so the number stays legible regardless of value direction.

**Visual — screen-shake/scale-pulse (Decision Card System, magnitude-scaled channel):**
- Single effect family across the full magnitude range — only amplitude/duration scale, never effect type or color.
- Low magnitude (~0.0-0.3): small scale-pulse only (card scales to ~102-105% and settles), no camera shake.
- Mid magnitude (~0.3-0.7): scale-pulse + light shake (small amplitude, short duration, e.g. 2-4px, ≤150ms).
- High magnitude (~0.7-1.0): larger scale-pulse (up to ~110-115%) + stronger shake, capped to avoid motion-sickness/readability loss.
- Same curve/easing applies whether the card resolved as a triumph or disaster — intensity is the only variable.
- A reduce-motion consideration should be evaluated now, even before the art bible, given Pillar accessibility intent.

**Audio — Decision Card resolution stinger family:**
- Palette: percussive-impact + noise-texture, **atonal** — no melodic or harmonic content. Pitch and major/minor harmony are reserved exclusively for valence-coded elements elsewhere (none currently exist) and must never appear in this family.
- Magnitude (0.0-1.0) drives three stacked parameters (never substituted, so ends differ in weight/duration, never in "color"):
  - **Layer density**: low magnitude = one dry transient ("tap"); high magnitude = transient + sub-thump + noise-burst tail stacked.
  - **Decay/tail length**: ~80ms dry at magnitude 0, scaling to ~600-900ms textured noise tail at magnitude 1 (filtered-noise decay, not pitch-bend).
  - **Transient saturation**: subtle soft-clip/distortion proportional to magnitude — reads as physical force, not emotional tone.
- Source material: broadband filtered noise, foley-style impacts (paper/cardboard/body-hit textures fit the satirical "office cringe" register), sub-bass thump for weight — all non-pitched or pitch-ambiguous.
- Explicitly avoid: bright filter-sweeps or pitch-rise on high magnitude (common "win" cue), downward pitch-bend or dissonant clusters on high magnitude (common "loss" cue) — both are valence leaks.
- Validation method for `sound-designer`: audition a "big win" mock event and a "big disaster" mock event at matching magnitude — they must be indistinguishable in emotional read.

📌 **Asset Spec** — once the art bible is approved, run `/asset-spec system:juice-feedback-system`.

## UI Requirements

- No screen of its own — this system only adds effects on top of Action UI's Resource HUD and Card UI's modal.
- Resolution payoff text must reuse Card UI's existing text label component and styling (font, size, wrap behavior) — not a new label type, to avoid visual inconsistency between the card's question text and its payoff text.
- Screen-shake must never move UI elements outside their touch-target bounds (per `technical-preferences.md`'s large-touch-area requirement) — shake is a visual offset only, not a layout reflow.

> 📌 **UX Flag — Juice/Feedback System**: This system modifies existing UI Requirements (Action UI, Card UI) but has no screen of its own. In Phase 4, update `design/ux/main-screen.md` and `design/ux/decision-card.md` (once authored) to include this system's effects, rather than creating a new UX spec file.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**Magnitude formula (boundary values):**
- **GIVEN** a linear-ratio resource event (Cringe/Morale), **WHEN** magnitude is computed, **THEN** output is clamped to [0,1] inclusive — see Formulas section for exact numeric pairs.
- **GIVEN** a log-compressed resource event (Zasięgi/Sponsorzy/Hatersi) with a delta large enough to exceed 1.0 pre-clamp, **THEN** final magnitude is hard-clamped to 1.0.
- **GIVEN** an event with deltas across multiple resources simultaneously, **WHEN** magnitude is computed, **THEN** the event's magnitude equals the **maximum** of per-resource contributions, never a sum or average.
- **GIVEN** an event where all deltas are zero (magnitude=0), **WHEN** it fires, **THEN** the lowest-tier effect still plays (see Edge Cases).

**Two distinct feedback channels:**
- **GIVEN** an Action System event at any magnitude, **THEN** feedback = count-up (fixed duration) + label flash (150-200ms, one neutral token) + **no shake**.
- **GIVEN** a Decision Card event with magnitude in [0, 0.3), **THEN** only scale-pulse, no shake.
- **GIVEN** magnitude in [0.3, 0.7), **THEN** scale-pulse + light shake, both present.
- **GIVEN** magnitude in [0.7, 1.0], **THEN** bigger pulse + stronger shake, capped at the high-tier ceiling.
- **GIVEN** a Card event at any magnitude, **THEN** the stinger is atonal; density/tail/saturation scale with magnitude; pitch/harmony never change.
- **GIVEN** an Action event and a Card event of equal magnitude, **THEN** their effect sets are mutually exclusive — Action never shakes/pulses/stings, Card never count-ups.

**No-valence-coding rule (highest priority — most explicit test):**
- **GIVEN** two Card events, one winning-outcome and one losing-outcome, with the **same computed magnitude**, **WHEN** feedback plays, **THEN** scale-pulse size, shake intensity, stinger density/tail/saturation, and flash color token are frame-for-frame identical — a tester observing only the feedback (text obscured) cannot tell win from loss.
- **GIVEN** the label flash token across events of differing valence but matching magnitude, **THEN** exactly one color token is used — no second "negative"/"positive" variant exists anywhere.
- **GIVEN** the stinger for a win-flavored vs. loss-flavored Card event of equal magnitude, **THEN** pitch/harmony are identical; only magnitude-driven density/tail/saturation may differ, identically in both cases.

**Resolution payoff timing formula:**
- **GIVEN** `resolution_reaction` length=0, **THEN** duration = 1.5s (floor).
- **GIVEN** length=60 chars, **THEN** duration = 2.5s (ceiling, exact per formula).
- **GIVEN** length=30 chars, **THEN** duration = 2.0s (midpoint).
- **GIVEN** length>60 chars (e.g. 200), **THEN** duration clamps at 2.5s, never exceeding.
- **GIVEN** payoff duration elapses, **THEN** the card closes automatically, no input required.

**Defined edge cases:**
- **GIVEN** magnitude=0 exactly, **THEN** the lowest-tier effect for that channel still plays in full — never silently skipped.
- **GIVEN** a Card event missing `resolution_reaction` entirely, **THEN** `payoff_showing` is skipped entirely, card closes via its normal path, no error/crash/stuck state.
- **GIVEN** any combination of deltas including extreme values, **THEN** magnitude is mathematically guaranteed ≤1.0 (requires a code-level fuzz test, not manual QA alone — see Story Type below).
- **GIVEN** any effect mid-playback when the app is backgrounded and resumed, **THEN** the system is in `idle` on resume — no effect resumes/replays/partially completes, no persisted state.

**Story Type Classification (test evidence gating):**
- Magnitude formula, payoff timing formula: **Logic** — automated unit test in `tests/unit/feedback/`, BLOCKING (pure functions, deterministic, no RNG).
- Action vs. Card channel behavior: **Logic/Integration** — automated, BLOCKING.
- **No-valence-coding rule: Logic, BLOCKING** — this is a pure data/config comparison (same magnitude → same output), not subjective feel; should be a dedicated automated test (`tests/unit/feedback/feedback_no_valence_coding_test.gd`), not left to manual spot-checks, given its stated importance as the GDD's central guarantee.
- Magnitude hard-clamp: **Logic**, needs a fuzz/boundary-sweep unit test.
- App-backgrounded edge case: **Integration** — needs an app-lifecycle test or documented manual playtest (true OS-level backgrounding may require device testing).

**Not testable against this GDD alone:**
- Exact subjective "feel" of shake/pulse magnitudes at each tier — Visual/Feel evidence (screenshot/video + lead sign-off), not automatable.
- Audio stinger's actual emotional-read indistinguishability (AC's A/B audition method) — requires human listening test, not unit-testable.

## Open Questions

- **`resolution_reaction` content for all 12 cards** — Card Content Database needs this field added and written (narrative-director/writer task). Until then, Edge Cases' empty-field fallback applies. *Owner: revise Card Content Database. Target: before next `/vertical-slice` re-run.*
- **Reduce-motion toggle** — flagged by `art-director` as worth considering now, before the art bible exists, given the screen-shake channel. Not yet a committed accessibility tier item (see `design/accessibility-requirements.md`'s "Basic" tier, which currently defers full reduced-motion). *Owner: revise `design/accessibility-requirements.md` if this becomes a confirmed need. Target: Polish, or sooner if a playtester flags motion sensitivity.*
- **Exact shake amplitude/duration values per tier** — art-director gave ranges (e.g., "2-4px, ≤150ms" for mid-tier) but final values await the art bible. *Owner: `/asset-spec` once art bible exists. Target: before Production implementation.*
- **No art bible exists yet** — recurring project-level open risk (2nd consecutive gate-check CONCERNS). This GDD's Visual/Audio section works around it with placeholder/data-driven tokens, consistent with the established pattern.
