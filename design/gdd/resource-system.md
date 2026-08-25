# Resource System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 1 — Uczciwa matematyka, nieuczciwy świat

## Overview

Resource System to warstwa danych definiująca wszystkie zasoby gry — Zasięgi, Cringe, Hatersi, Morale, Sponsorzy — oraz reguły ich przepływu między systemami (Action System je generuje, Decision Card System je modyfikuje i konsumuje, Offline Progress System je akumuluje w tle, Team/Staff Management zwiększa ich tempo). Dla gracza to bezpośrednio odczuwalny rdzeń satysfakcji: każda liczba na ekranie rośnie w sposób przewidywalny i uczciwy (Pillar 1), a obserwowanie tego wzrostu jest samo w sobie nagrodą — to jest "uczciwa matematyka" w praktyce, widoczna gołym okiem przy każdej akcji.

Bez tego systemu żadna inna mechanika nie ma na czym operować — to jest dosłownie fundament, od którego zaczyna się projektowanie (zgodnie z `systems-index.md`).

## Player Fantasy

Gracz bezpośrednio widzi i rozumie każdy zasób (Zasięgi rosną, Cringe się kumuluje, Hatersi przybywają) — to jest namacalna, czytelna nagroda za każdą akcję, dająca poczucie "budowania czegoś realnego". Pod tą warstwą leży infrastruktura przepływów między systemami, niewidoczna dla gracza, ale to ona gwarantuje, że to poczucie wzrostu jest zawsze uczciwe — żadna liczba nie rośnie ani nie spada bez zrozumiałego powodu (Pillar 1: uczciwa matematyka, nieuczciwy świat). Satyryczny twist: Cringe i Hatersi — zasoby, które brzmią negatywnie — same w sobie też muszą "się opłacać" rosnąć, co zaczyna budować w graczu pierwsze wątpliwości moralne, zanim jeszcze dotrze do kart decyzji.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents (game-designer, systems-designer) not consulted — Lean mode. Review manually before production.*

### Core Rules

**Zasoby (5):**

> **Resolved 2026-06-24 (Sprint 5, 5-1):** the column below shows the code's
> actual `StringName` key (`src/core/resource_manager.gd`) alongside the
> Polish display term used throughout this document's prose. Three of these
> previously drifted — `Zasięgi`/`Hatersi`/`Sponsorzy` were the original
> placeholder names; the locked code keys are `Reach`/`Haters`/`Sponsors`.
> Only this table and `design/registry/entities.yaml` are updated here — the
> narrative prose elsewhere in this document still uses the Polish terms and
> is unaffected (translating it is out of scope for this tech-debt fix).

| Code Key | Zasób (PL) | Rola | Generowany przez | Konsekwencja |
|---|---|---|---|---|
| **Reach** | Zasięgi | Główna waluta progresji, napędza kamienie milowe (potwierdzone w prototypie v2) | Akcje podstawowe, Hatersi (passive), Decision Cards | Brak bezpośredniej kary — to "uczciwa" liczba z Pillar 1 |
| **Cringe** | Cringe | Bufor ryzyka — rośnie z ryzykownych akcji ("Zrób dramę"), opada wolno z bezpiecznych ("Przeproś w internecie") | Akcje, Decision Cards | Napędza tempo przyrostu Hatersów (pośrednio) ORAZ przesuwa pulę kart decyzji w stronę ryzykownych wariantów (Decision Card System) |
| **Haters** | Hatersi | Generator darmowych Zasięgów w tle, ale drenuje Morale | Pośrednio z poziomu Cringe (tempo przyrostu = f(Cringe)) | Każdy Haters drenuje Morale proporcjonalnie do swojej liczby |
| **Morale** | Morale | Modyfikator efektywności wszystkich akcji | Bazowo pełne; regenerowane przez "Przeproś w internecie" | Niskie Morale = mnożnik efektywności akcji < 1.0 (patrz Formuły) |
| **Sponsors** | Sponsorzy | Waluta ekonomii zespołu — pełna mechanika należy do Team/Staff Management (Alpha), tu tylko zdefiniowana jako istniejący zasób | Decision Cards (nagrody sponsorskie), przyszłe Team/Staff Management | Brak konsekwencji w MVP — placeholder na przyszłe sprzężenie |

**Łańcuch konsekwencji (Pillar 1 w praktyce):**

`Akcja ryzykowna → ↑Cringe → ↑tempo przyrostu Hatersów (w tle) → ↑Hatersi → ↓Morale → ↓mnożnik efektywności akcji`

Równolegle: `↑Cringe → przesunięcie puli kart decyzji w stronę ryzykownych wariantów` (Decision Card System).

Rdzeń (nagrody z akcji) jest zawsze przewidywalny i niezmienny — to "nieuczciwy świat" (Hatersi, Morale, dobór kart) reaguje na decyzje gracza, nigdy odwrotnie.

### States and Transitions

**Morale Bands:**

| Stan Morale | Zakres | Mnożnik efektywności akcji |
|---|---|---|
| Wysokie | 70–100% | 1.0x |
| Normalne | 40–69% | 0.9x |
| Niskie | 15–39% | 0.75x |
| Krytyczne | 0–14% | 0.5x |

### Interactions with Other Systems

- **Action System** → pisze bezpośrednio do Zasięgi/Cringe/Morale po zakończeniu cyklu (wartości z reward table akcji)
- **Decision Card System** → czyta poziom Cringe do wagowania puli kart; pisze do flag historii; może modyfikować zasoby jako koszt/nagroda decyzji
- **Offline Progress System** → czyta liczbę i tempo Hatersów do symulacji passive Zasięgi/drenaż Morale w czasie offline
- **Team/Staff Management** *(Alpha, forward reference)* → czyta/pisze Sponsorzy; modyfikuje globalne mnożniki tempa generowania zasobów

## Formulas

> *Specialists consulted: `systems-designer` (formula proposals), `economy-designer` (ratio/curve validation) — Section D is HIGH-risk, consulted even in Lean mode.*

**A. Hatersi Passive Growth Rate (function of Cringe)**

`H_rate(C) = H_base + (C / 100)^H_exp × H_max_add`

ΔHatersi per tick: `ΔH = H_rate(C) × Δt / 60`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cringe | C | float | 0–100 | Current Cringe at tick start |
| Base rate | H_base | float (tuning) | 0.0–0.05 | Min Hatersi/min even at C=0 |
| Escalation exponent | H_exp | float (tuning) | 2.0 | Steepness — gentle early, steep late (Pillar 1) |
| Max additional rate | H_max_add | float (tuning) | 0.5–2.0 | Extra Hatersi/min at C=100 |
| Elapsed time | Δt | float (s) | ≥0 | Supports offline deltas |

**Output Range:** [H_base, H_base + H_max_add] Hatersi/min, never zero but capped.
**Example:** H_base=0.02, H_exp=2.0, H_max_add=1.0 → C=10: 0.03/min; C=50: 0.27/min; C=100: 1.02/min.

---

**B. Morale Drain Rate (function of Hatersi count, with buffer zone)**

`M_drain(N) = M_drain_per_hater × max(0, N - N_buffer)^M_drain_exp`

ΔMorale per tick: `ΔM = -M_drain(N) × Δt / 60` (floored at -M_current)

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Hatersi count | N | int | 0–∞ | Current Hatersi |
| Buffer threshold | N_buffer | int (tuning) | 3 | First N Hatersi drain nothing — protects new players (Pillar 1) |
| Drain per hater | M_drain_per_hater | float (tuning) | 0.05–0.3 | Base %/min beyond buffer |
| Escalation exponent | M_drain_exp | float (tuning) | 1.3 | Mild escalation past buffer |
| Elapsed time | Δt | float (s) | ≥0 | — |

**Output Range:** 0 at N≤N_buffer; unbounded growth beyond, self-limiting via Critical-band multiplier feedback.
**Example:** M_drain_per_hater=0.15, N_buffer=3: N=2 → 0%/min (free); N=10 → 0.15×7^1.3≈1.88%/min; N=25 → 0.15×22^1.3≈8.34%/min. (Corrected 2026-06-23 — original worked examples here had an arithmetic error, caught during Story 003's implementation; the formula and constants were always correct, only this prose example was wrong.)

**Sponsor Shield override (DDR-0001 #6):** While the Sponsor Shield is active, the effective N_buffer passed to this formula is `M_BUFFER + SHIELD_BUFFER_BONUS` (= 8, default) rather than `M_BUFFER` (= 3). This is a temporary override — when the shield expires, N_buffer reverts to M_BUFFER. Implementation: `morale_drain_rate(N, effective_buffer)` accepts an optional second parameter; callers that need the shield effect pass `ResourceManager.get_shield_effective_buffer()`.

---

**C. Action Effectiveness Multiplier (Morale band lookup)**

```
Mult(M) = 1.00  if 70 ≤ M ≤ 100
        = 0.90  if 40 ≤ M < 70
        = 0.75  if 15 ≤ M < 40
        = 0.50  if  0 ≤ M < 15
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Morale | M | float | 0–100 | At point of reward calculation |

**Output Range:** {0.50, 0.75, 0.90, 1.00} — discrete bands, no interpolation (legible math, Pillar 1).
**Example:** Base reward 25 Zasięgi, M=35% (Low) → 25×0.75=18.75 → round-half-up → 19 Zasięgi.
**Edge case:** Boundaries (70/40/15) are inclusive-lower (M=40 is Normal, not Low).

---

**D. Passive Zasięgi Income from Hatersi**

`Z_passive(N, Δt) = N × Z_per_hater × Mult(M) × (Δt / 60)`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Hatersi count | N | float | 0–∞ | — |
| Income per hater | Z_per_hater | float (tuning) | 0.1–0.5 | Zasięgi/min per Hater |
| Morale multiplier | Mult(M) | float | {0.5,0.75,0.9,1.0} | From Formula C |
| Elapsed time | Δt | float (s) | ≥0 | Active or offline |

**Output Range:** ≥0, unbounded upward (intended long-term growth engine).
**Example:** Z_per_hater=0.2, N=10, M=80%→Mult=1.0, Δt=600s → 10×0.2×1.0×10 = 20 Zasięgi/10min.

**Resolved cadence (2026-08-05):** both active and offline play execute one
shared H→M→Mult→Reach transition. Active play uses complete 1-second logical
steps only while `ActionScreen` exists; offline play retains 60-second steps and
the 24-hour cap. State remains float in both paths; only Formula B's existing
`int(H)` conversion is intentional.

---

**E. Cringe Delta from Actions**

`ΔCringe = clamp(C + Cringe_delta_action, 0, 100) - C`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Cringe before | C | float | 0–100 | — |
| Per-action delta | Cringe_delta_action | float (per-action constant) | -15 to +20 | Defined per action in Action System's reward table |

**Output Range:** Clamped to [0,100]; near the ceiling, marginal Cringe gain naturally shrinks (soft brake against risky-action stacking, no explicit punishment rule needed).
**Example:** "Zrób dramę" (+15): C=40→55. "Przeproś w internecie" (-10): C=55→45. Near ceiling: C=95, +20 action → actual +5 only.

> **Cross-reference note for Action System GDD:** economy-designer recommends risky actions pay 1.4x–1.8x the Zasięgi of safe actions (immediate fair payout per Pillar 1), with the *real* cost deferred through this Cringe→Hatersi→Morale chain. This ratio belongs in the Action System's reward table, not here — flagging it now so it isn't lost.

---

**Sponsorzy Acquisition and Consumption (DDR-0001 #6)**

Flat 1–3 Sponsorzy per qualifying Decision Card, not scaled to card tier or Zasięgi reward.

**Consumption — Sponsor Shield (first sink, quick-spec `sponsor-network-shield-2026-06-30.md`):**
The player may spend SHIELD_COST Sponsors (default: 5) to activate the Sponsor Shield for SHIELD_DURATION seconds (default: 300 s). While the shield is active, Formula B uses an elevated N_buffer (`M_BUFFER + SHIELD_BUFFER_BONUS = 8`), reducing Morale drain from Hatersi. Activating while already active adds SHIELD_DURATION to the remaining timer (additive stacking). Shield state persists across sessions.

**Future sink:** Full Sponsors economy (spending on Team/Staff) is deferred to Team/Staff Management GDD (Alpha tier).

## Edge Cases

> *`systems-designer` not consulted — Lean mode (section is not D/H). Review manually before production.*

- **If Morale = 0 and Hatersi keep draining**: drain still computed, but ΔMorale is floored at -M_current (Morale never goes negative); effectiveness multiplier stays at 0.5x (Critical band) — does not go lower.
- **If Cringe = 0 and the player performs a safe action ("Przeproś")**: `ΔCringe = clamp(0 + (-10), 0, 100) - 0 = 0` — no effect, Cringe cannot go negative; the action still grants its Zasięgi/Morale reward independently.
- **If two actions would complete "simultaneously"**: not reachable in MVP — only one action can be `running` at a time (single-slot, confirmed by both prototypes). Flagged as an assumption the Action System GDD must preserve.
- **If Hatersi = 0**: Formula D gives Z_passive = 0 (no passive income), Formula B gives drain = 0 — this is the game's fully "fair" starting state.
- **If Cringe stays at 100 for an extended period**: Hatersi grow at the maximum rate (`H_base + H_max_add`) indefinitely until the player lowers Cringe — this is the intended pressure peak, not a bug. No hard cap on Hatersi count; self-regulated via the Morale/Critical-band feedback loop, not an artificial ceiling.
- **Degenerate strategy check — can the player farm Cringe to zero and never take risk?** Yes, and this is a legal "clean path" strategy, deliberately not punished at the Resource System level — Decision Card System and Class Path System decide whether that path has its own narrative trade-offs (e.g., fewer high-value dramatic cards). Flagged as a downstream dependency, not resolved here.

## Dependencies

**Upstream (this system depends on):** None — Resource System is Foundation layer, the first system designed (per `systems-index.md`).

**Downstream (depends on this system):**
- **Action System** (hard) — writes Zasięgi/Cringe/Morale deltas via each action's reward table; reads Morale band multiplier (Formula C) to scale rewards.
- **Decision Card System** (hard) — reads Cringe to weight the card pool; writes resource deltas as card costs/rewards; reads/writes Sponsorzy.
- **Offline Progress System** (hard) — reads Hatersi count, Morale, and Formulas A/B/D to simulate passive accumulation across arbitrary time deltas; must implement the stepped-evaluation approach flagged in Formula D's Open Question.
- **Team/Staff Management** (soft, forward reference) — will read/write Sponsorzy and may introduce new multipliers on Formulas A/B/D once designed (Alpha tier); Resource System's interfaces must remain stable enough to accept this later without breaking changes.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `H_base` | 0.02 | 0.0–0.05 | Too high: Hatersi grow even at Cringe=0, breaks "fair core" |
| `H_exp` | 2.0 | 1.5–2.5 | Too low (≤1): linear escalation, early game too harsh. Too high (>3): late game too forgiving |
| `H_max_add` | 1.0 | 0.5–2.0 | Too high: Hatersi explode at max Cringe, Morale unsustainable |
| `N_buffer` | 3 | 2–5 | Too high: Hatersi become practically harmless, Morale never drains |
| SHIELD_COST | 5 Sponsors | 3–10 | Too low: shield trivially maintained, Sponsors pile up; too high: shield rarely used |
| SHIELD_DURATION | 300 s | 60–900 | Too long: effectively permanent (DDR-0001 forbidden); too short: not worth buying |
| SHIELD_BUFFER_BONUS | +5 | +2 to +7 | Too high (e.g. +8 with N_buffer=3 → effective 11): dominant strategy per DDR-0001; +7 ceiling safe |
| `M_drain_per_hater` | 0.15 | 0.05–0.3 | Too high: death-spiral Morale even at low Hatersi counts |
| `M_drain_exp` | 1.3 | 1.1–1.6 | Too high: drain explodes, Critical band reached within minutes |
| `Z_per_hater` | 0.2 | 0.1–0.5 | Too high: passive income overtakes active (violates economy-designer's MVP rule that active must dominate) |
| Cringe delta ceiling/floor | +20 / -15 | — | Asymmetry is intentional — don't change without reconsidering Cringe "cleanup" pacing |
| Sponsorzy per card | 1–3 | 1–5 | Placeholder — revisit once Team/Staff Management GDD defines sinks |

**Knob interactions:** `H_exp` and `M_drain_exp` together define the total pace of the Cringe→Hatersi→Morale spiral — changing one without the other can accidentally compress or stretch the entire difficulty curve (flagged by systems-designer as requiring a joint pass across both curves before final tuning).

## Visual/Audio Requirements

Resource System itself produces no visual/audio content directly — that belongs to the layers that wrap it (Action UI, Card UI, Offline Report Screen). However, this system defines *events* those layers must be able to visualize:
- A Morale band change (High→Normal→Low→Critical) should have a clear visual signal (e.g., Morale bar color change) — emitted by this system, consumed by UI.
- Cringe crossing a threshold that affects the future card pool (Decision Card System) should be subtly signaled (e.g., icon/hue shift), never via an explanatory pop-up — per Pillar 3.
- No dedicated sounds owned by this system — audio belongs to the Juice/Feedback System (per `systems-index.md`).

## UI Requirements

Resource System is pure infrastructure — it has no screen of its own. Requirements for the UI layers that consume it:
- HUD must display all 5 resources in real time (Zasięgi, Cringe, Hatersi, Morale, Sponsorzy), consistent with the v1/v2 prototypes.
- The Morale indicator must clearly communicate the current band (High/Normal/Low/Critical), not just the raw % — the player needs to know "what state am I in," not just "what number is this."
- The Cringe indicator should eventually (once Decision Card System exists) signal that it affects the card pool — at this GDD's level, it's sufficient that the value is visible and live-updating.
- Sponsor Shield must remain visible beside the Resource HUD: exact 5-Sponsor
  cost, inactive 3-to-8 Haters buffer explanation, active countdown, additive
  five-minute extension, and an explicit shortfall while disabled.
- Ambient one-second changes update displayed values but do not trigger the
  action/card pop, count-up, or flash feedback channels.

> 📌 **UX Flag — Resource System**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` for the HUD screen before writing epics. Stories referencing UI should cite `design/ux/hud.md`, not this GDD directly.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

- **GIVEN** an action in progress with defined Zasięgi/Cringe/Morale deltas, **WHEN** the action completes, **THEN** all three values update by exactly their defined deltas, with no partial write before completion.
- **GIVEN** Cringe=10 vs Cringe=80 in two identical states, **WHEN** 10 minutes elapse, **THEN** the Cringe=80 state produces Hatersi growth per `H_rate(80)=0.02+0.64×1.0=0.66/min` (≈6.6 over 10 min), vs Cringe=10's `H_rate(10)=0.03/min` (≈0.3 over 10 min) — strictly greater growth at higher Cringe.
- **GIVEN** Hatersi=10, **WHEN** 1 minute of drain elapses, **THEN** Morale decreases by `0.15×(10-3)^1.3≈1.88%` (Formula B, buffer of 3 subtracted before escalation). (Corrected 2026-06-23 — see Formula B's worked example note.)
- **GIVEN** Morale=35% (Low band, 15-39%), **WHEN** the player completes an action with a 25 Zasięgi base reward, **THEN** effective reward = 25×0.75=18.75 → round-half-up → 19 Zasięgi.
- **GIVEN** Hatersi=10, Morale=80% (Mult=1.0), **WHEN** 10 minutes elapse with no player action, **THEN** Zasięgi increases by exactly `10×0.2×1.0×10=20` (Formula D).
- **GIVEN** Cringe=95, **WHEN** an action with nominal ΔCringe=+20 completes, **THEN** actual increase = `clamp(115,0,100)-95=5`, not 20 (natural clamp behavior, not a separate curve).
- **GIVEN** a Decision Card flagged "qualifying" for Sponsorzy, **WHEN** the player resolves it, **THEN** Sponsorzy increases by a random integer in [1,3] and may subsequently be spent on Sponsor Shield, Staff, or eligible path investment.
- **GIVEN** Morale=0 and a drain tick is due, **WHEN** drain is computed, **THEN** Morale remains at 0 (never negative), and the effectiveness multiplier used is exactly 0.5x.
- **GIVEN** Cringe=0, **WHEN** the player completes a safe action (ΔCringe≤0), **THEN** Cringe remains at 0 — no negative value is ever stored.
- **GIVEN** an action is currently "running", **WHEN** the player selects another available action, **THEN** it is appended to the bounded FIFO queue; only the active action's deltas resolve at a time.
- **GIVEN** Hatersi=0, **WHEN** any duration elapses with no player action, **THEN** passive Zasięgi = 0 and Morale drain = 0 for the entire duration.
- **GIVEN** Cringe held at 100 for 50+ minutes, **WHEN** Hatersi growth is evaluated each minute, **THEN** the rate stays at `H_base+H_max_add=1.02/min` with no hard cap on Hatersi count.
- **GIVEN** the player takes only Cringe-reducing actions continuously, **WHEN** this pattern is sustained across a session, **THEN** no penalty, soft-lock, or forced escalation is triggered at this system's level as a consequence.

## Open Questions

- ~~**"Qualifying card" definition for Sponsorzy rewards** — owned by Decision Card System; resolve when that GDD is authored.~~ **RESOLVED** in `design/gdd/card-content-database.md`: only `sponsor_offer_shady` and `brand_deal_choice` qualify (cards whose premise is a sponsor/brand/monetization offer).
- ~~**Continuous delta-time vs. discrete ticks**~~ — **RESOLVED 2026-08-05**:
  shared transition, 1-second active cadence, 60-second offline cadence.
- **Should the "clean path" (Cringe=0 forever) carry any systemic trade-off?** — Deferred to Decision Card / Class Path System. *Owner: Decision Card System / Class Path System. Target: before those GDDs are approved.*
