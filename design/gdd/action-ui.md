# Action UI

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 1 — Uczciwa matematyka, nieuczciwy świat

## Overview

Action UI to ekran główny gry — implementacja wymagań zadeklarowanych w Action System GDD: 3 zawsze widoczne przyciski akcji (Nagraj vloga / Zrób dramę / Przeproś w internecie), progress bar aktywnej akcji, i layout zarezerwowany na 3 przyszłe akcje odblokowywane przy kamieniach milowych. Ten GDD nie definiuje logiki gry (to robi Action System) — definiuje **jak** ta logika jest prezentowana i jak gracz wchodzi z nią w interakcję: rozmiar przycisków, stan disabled/enabled, etykiety czasu trwania i nagród.

Dla gracza to jest ekran, na którym spędza większość czasu aktywnej sesji — to jest "podłoga", na której stoi cała pętla select-and-wait potwierdzona przez prototypy.

## Player Fantasy

Gracz dotyka ekranu i czuje, że dzieje się coś realnego — duży, responsywny przycisk, czytelny czas trwania, jasna nagroda. To jest fizyczne wrażenie kontroli nad swoim "biznesem contentowym": każde dotknięcie jest decyzją, nie przypadkiem. Layout musi sygnalizować "więcej nadejdzie" (zablokowane sloty na przyszłe akcje), budując ciche oczekiwanie na rozwój, bez ogłaszania tego wprost.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents (game-designer, ux-designer) not consulted — Lean mode. Review manually before production.*

### Core Rules

**Layout (3 zones of the main screen):**

1. **Resource HUD** (top) — displays all 5 resources in real time (Zasięgi, Cringe, Hatersi, Morale, Sponsorzy), per Resource System GDD's UI requirement. The Morale indicator communicates the band (High/Normal/Low/Critical), not just the raw %.
2. **Action Grid** (middle) — 6 slots: 3 unlocked actions (Nagraj vloga / Zrób dramę / Przeproś w internecie) + 3 locked slots (🔒, with unlock threshold), modeled on the "locked action preview" from the v2 prototype, which proved to be a strong motivator on its own.
3. **Running Action Overlay** — while an action is `running`, the active action shows a progress bar labeled with its name and effective remaining time. Live action choices stay available for queueing and disable only when `QUEUE_CAP` is reached.

**Unlocked action button anatomy:**
```
[Action name]
[Duration]s — [Zasięgi]Z, [Cringe]C, [Morale]M
```
e.g., "Zrób dramę / 9s — +10Z, +20C, -3M" (values pulled from registry's `action_zasiegi_base`/`action_cringe_delta`/`action_morale_delta`, never redefined here).

**Rules:**
1. All 6 slots are always visible — the layout never reflows when a new action unlocks; a slot simply switches from 🔒 to active.
2. Tapping an unlocked button while `idle` starts it; tapping one while `running` adds it to Action System's queue. At `QUEUE_CAP`, live action buttons disable with the `Queue full` explanation. Tapping a locked preview never starts or queues an action and instead shows its unlock requirement.
3. The progress bar updates smoothly (every frame, not every second) for a legible sense of progress, consistent with what the prototypes confirmed.

### States and Transitions

| UI State | Description | Transition |
|---|---|---|
| `idle_display` | All unlocked buttons active, no progress bar | → `running_display` when Action System enters `running` |
| `running_display` | Progress bar visible and updating; live action buttons enqueue until `QUEUE_CAP` | → `idle_display` when Action System reaches `resolved`→`idle` with no queued successor |

### Interactions with Other Systems

- **Action System** (hard, read+write) → reads state, effective active duration, progress, queue state, and action data to display; sends the player's choice as start-or-enqueue input
- **Resource System** (hard, read) → reads the 5 resource values in real time for the Resource HUD
- **Juice/Feedback System** (downstream, undesigned, Vertical Slice) → will own resolution-beat effects, not this GDD

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

This GDD introduces no original game-design math — it's presentation logic. Two display derivations are documented below (not full formulas, since they derive from state owned by other systems), plus a real gap flagged rather than invented.

**Progress bar fill (display derivation):**
`fill_ratio = clamp(elapsed_time / duration, 0, 1)`
Owned by Action System's state (`elapsed_time`, `duration`); this GDD only renders it. If `duration = 0` (should not occur per Action System), clamp prevents divide-by-zero by treating it as `fill_ratio = 1`.

**Large-number formatting (display rule, e.g., for Offline Progress System's ~28,000 Zasięgi gains):**

| Range | Format | Example |
|---|---|---|
| < 1,000 | Plain integer | `847` |
| 1,000–999,999 | `X.XK` (1 decimal) | `28,412 → "28.4K"` |
| ≥ 1,000,000 | `X.XM` (1 decimal) | `1,250,000 → "1.3M"` |

Rounding: **CORRECTED 2026-06-24** (Action UI Story 001) — this section originally said "round-half-up," but that rule contradicts this GDD's own `999,999 → "999.9K"` example (round-half-up would give "1000.0K") and its own hard-boundary rule above ("no transition zone"). The two could not both be satisfied by one rounding rule, since the Acceptance Criteria's `1,250,000 → "1.3M"` example assumed rounding while the `999,999 → "999.9K"` example assumed truncation. Resolved (user decision): **truncate**, never round, at the displayed decimal. This satisfies the 999.9K example and the hard-boundary rule exactly; the Acceptance Criteria's `1,250,000 → "1.3M"` example is the error — real measured behavior is `"1.2M"`, locked by `tests/unit/action_ui/action_ui_formatting_test.gd`. The "consistent with Resource System/Action System" rounding-convention claim no longer applies to this specific formatting rule (it still applies to other rounding in this GDD, e.g. reward calculations — this correction is scoped to large-number K/M display only).

**Locked slot unlocking (RESOLVED 2026-06-30):** The 3 locked action slots unlock via the player's **decision history** (`HistoryFlagManager.has_milestone()` / `counter_above_threshold()`), NOT a flat Zasięgi threshold — see `design/quick-specs/milestone-gated-action-slots-2026-06-30.md` (per DDR-0001 #3). Each slot is unlockable via **either a risky-path or a safe-path condition**, so the deliberately-un-punished clean-path player is never locked out (Resource System Edge Cases). The 3 gated actions (Record a Collab / Give an Interview / Launch a Course) and their reward deltas live in Action System's reward table; the unlock conditions live in the quick spec. *(Superseded the earlier "no source of truth for unlock_threshold" gap — this UI reads the gating result, never invents threshold values.)*

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If a locked slot's `unlock_threshold` is `null`/undefined** (per the flagged gap): the slot shows a generic locked state (🔒, no number) — the UI never guesses a value.
- **If a number sits at a formatting boundary** (e.g., 999,999 vs 1,000,000): `999,999 → "999.9K"`, `1,000,000 → "1.0M"` — the boundary is hard at 1,000,000, no transition zone.
- **If an action name is too long for the button** (future actions may have longer names): text truncates with an ellipsis (`...`) rather than breaking the layout — a requirement for future slots, not just the current 3.
- **If the Resource HUD would display a negative value** (shouldn't occur — Resource System clamps Cringe/Morale to 0, but Zasięgi/Sponsorzy have no floor per other GDDs' Open Questions): the UI displays whatever value it receives as-is — clamping is not this presentation layer's responsibility.
- **If the progress bar renders on the very first frame after an action starts** (`elapsed_time=0`): `fill_ratio=0`, bar starts empty, no flicker.

## Dependencies

**Upstream (this system depends on):**
- **Action System** (hard) — state machine, action data, choice input.
- **Resource System** (hard) — 5 resource values for the HUD.
- **Action System or a future Milestone/Unlock System** (hard, gap) — must define which actions exist beyond the initial 3 and their `unlock_threshold` values in Zasięgi. Not currently owned by any GDD; this UI reads the value once it exists, never invents it.

**Downstream (depends on this system):**
- **Main Navigation/Screen Flow** (hard, Vertical Slice, undesigned) — will integrate this screen into the broader app navigation.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| Number formatting K/M breakpoints | 1,000 / 1,000,000 | — (standard, don't change without strong reason) | Inconsistent breakpoints across screens would read as a bug, not a feature |
| Action name truncation length | implementation-defined (per button width) | — | Too short: names become unreadable abbreviations. Too long: layout breaks on smaller screens |

**Knob interaction:** none — independent of other GDDs' tuning knobs.

## Visual/Audio Requirements

> *Specialist consulted: `art-director` — category is "UI systems," mandatory for Visual/Audio.*

- **Resource HUD:** each of the 5 resources has its own identifying hue, independent of whether the resource is thematically "good" or "bad" (Cringe/Hatersi are not coded red/warning) — color aids recognition, not judgment, per Pillar 1 and the anti-pillar (no explicit moral score). Morale displays its band (label/band color), not just the raw %.
- **Action Grid:** each action has an icon + thematic color for quick recognition (e.g., a camera icon for "Nagraj vloga") — the icon is the primary carrier of meaning, color supports it. Locked slots are visually muted (lower contrast/saturation) relative to unlocked ones, but never hidden.
- **Running Action Overlay:** completion "soczystość" scales proportionally with the action's duration — a longer/bigger action (e.g., "Zrób dramę," 9s) gives a visually larger completion effect than a short one (e.g., "Przeproś," 4s), but never encodes good/bad (valence) — intensity, not moral judgment. The progress bar itself has a neutral, uniform style regardless of which action is active.

📌 **Asset Spec** — once the art bible is approved, run `/asset-spec system:action-ui`.

## UI Requirements

- All action buttons must use large touch areas (standard `Button` node, not `TouchScreenButton` — per ADR-0007), per `technical-preferences.md` — zero hover-only interactions.
- Layout must be responsive across Android screen sizes (no hardcoded pixel positions for the 6 Action Grid slots).
- The Resource HUD must be legible without scrolling — all 5 resources visible simultaneously on the main screen.

> 📌 **UX Flag — Action UI**: This screen has real UI requirements. In Phase 4, run `/ux-design` for `design/ux/main-screen.md` before writing epics — already flagged in Action System's GDD; this entry confirms it.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**3-zone layout:**
- **GIVEN** valid state, **WHEN** the screen renders, **THEN** exactly 3 zones present: Resource HUD, Action Grid, Running Action Overlay (conditional).
- **GIVEN** the Resource HUD renders, **WHEN** all 5 resources provided, **THEN** all 5 display simultaneously, Morale shows a band label, not raw %.
- **GIVEN** the Action Grid renders, **WHEN** the screen loads, **THEN** exactly 6 slots: 3 unlocked + 3 locked.
- **GIVEN** a slot unlocks (milestone reached), **WHEN** the grid re-renders, **THEN** no slot is added/removed/repositioned — same slot switches 🔒→active in place.

**Button enable/disable:**
- **GIVEN** `idle`, **WHEN** rendered, **THEN** all 3 unlocked buttons enabled.
- **GIVEN** `idle`, **WHEN** tapping an unlocked button, **THEN** choice sent to Action System.
- **GIVEN** a slot is locked, **WHEN** tapped, **THEN** no action starts and its unlock requirement is shown.
- **GIVEN** `running` and queue length < `QUEUE_CAP`, **WHEN** rendered, **THEN** every live action button remains enabled.
- **GIVEN** `running` and queue length < `QUEUE_CAP`, **WHEN** tapping a live action, **THEN** it is appended without interrupting the active action.
- **GIVEN** queue length = `QUEUE_CAP`, **WHEN** rendered, **THEN** live action buttons are disabled with `Queue full`; locked preview slots remain tappable.
- **GIVEN** the queue is cleared below cap, **THEN** live action buttons re-enable immediately.
- **GIVEN** ActionGrid is recreated while a queue already exists, **WHEN** its first frame renders, **THEN** the queue strip, Clear control, and cap state are reconstructed from the current ordered snapshot.

**Progress bar fill:**
- **GIVEN** elapsed_time=0, duration=D>0, **WHEN** first frame renders, **THEN** fill_ratio=0, no flicker.
- **GIVEN** 0<elapsed_time<duration, **WHEN** rendered, **THEN** fill_ratio=clamp(E/D,0,1).
- **GIVEN** elapsed_time≥duration, **WHEN** rendered, **THEN** fill_ratio=1 (clamped).
- **GIVEN** running, **WHEN** successive frames render, **THEN** the bar updates every frame, not throttled.
- **GIVEN** the overlay is visible, **WHEN** rendered, **THEN** action name and remaining time based on the effective duration captured at start both show alongside the bar.

**Number formatting (boundaries):**
- **GIVEN** 847, **WHEN** formatted, **THEN** `"847"`.
- **GIVEN** 999, **WHEN** formatted, **THEN** `"999"`.
- **GIVEN** 1,000, **WHEN** formatted, **THEN** `"1.0K"` (inclusive lower bound).
- **GIVEN** 28,412, **WHEN** formatted, **THEN** `"28.4K"`.
- **GIVEN** 999,999, **WHEN** formatted, **THEN** `"999.9K"`.
- **GIVEN** 1,000,000, **WHEN** formatted, **THEN** `"1.0M"` (hard boundary).
- **GIVEN** 1,250,000, **WHEN** formatted, **THEN** `"1.2M"` (**CORRECTED 2026-06-24** — was stated as "1.3M", which assumed rounding; see the Large-number formatting section above for why truncation is the resolved rule).

**Defined edge cases:**
- **GIVEN** a locked slot's `unlock_threshold` is null, **WHEN** rendered, **THEN** generic 🔒 state, no number.
- **GIVEN** an action name exceeds button width, **WHEN** rendered, **THEN** truncated with ellipsis, button dimensions unchanged.
- **GIVEN** a negative Zasięgi/Sponsorzy value, **WHEN** rendered, **THEN** displayed as-is, no UI-layer clamping.

**Not testable against this GDD alone:**
- Actual `unlock_threshold` values for locked slots — no source of truth exists yet (blocked on Action System / future Milestone-Unlock System).
- Main Navigation/Screen Flow integration (screen entry/exit, transitions) — undesigned, Vertical Slice.
- Precise truncation length — marked "implementation-defined" in Tuning Knobs, no concrete value to test against yet.
- Juice/Feedback System resolution effects — undesigned downstream system.
- `duration=0` — Action System's own invariant says this "should not occur"; testing it would require violating that contract, not asserting this GDD's behavior.

## Open Questions

- ~~**`unlock_threshold` values and future actions behind locked slots**~~ — **RESOLVED 2026-06-30** by `design/quick-specs/milestone-gated-action-slots-2026-06-30.md`: slots unlock via decision-history milestones/counters (either risky or safe path), not a Zasięgi threshold; the 3 gated actions are defined in Action System's reward table.
- **Precise action-name truncation length** — marked "implementation-defined," no concrete value. *Owner: `/ux-design` for main-screen.md. Target: Pre-Production.*
