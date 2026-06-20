# Offline Progress System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 4 — Offline jest pierwszą klasą obywatelską

## Overview

Offline Progress System symuluje upływ czasu między sesjami: przy starcie aplikacji oblicza `Δt` od `last_saved_at` (Save/Persistence System) do teraz, dzieli ten okres na kroki, i krokowo re-ewaluuje pasywny dochód Zasięgów z Hatersów (Resource System Formula D), tempo przyrostu Hatersów (Formula A) i drenaż Morale (Formula B) — bo wszystkie trzy zmieniają się wzajemnie w czasie i nie można ich policzyć jednym uproszczonym wzorem na cały okres. Po zakończeniu symulacji prezentuje graczowi czytelny raport ("co się wydarzyło, gdy nie grałeś").

Dla gracza to jeden z najważniejszych emocjonalnych momentów gry — pierwsze, co widzi po powrocie. To właśnie ten system naprawia główną wadę Beggar's Life (brak satysfakcjonującej progresji offline) i realizuje Pillar 4 w praktyce: offline nie jest dodatkiem, jest pierwszą klasą obywatelską.

## Player Fantasy

Gracz wraca do gry i widzi, że coś się działo bez niego — Zasięgi wzrosły, Hatersi przybyli, Morale spadło — i to jest namacalny dowód, że jego imperium "żyje" nawet gdy telefon jest w kieszeni. Symulacja sama jest niewidoczna (gracz nie widzi kroków, formuł, re-ewaluacji), ale raport, który z niej wynika, jest czytany bezpośrednio i z uwagą — to jest moment "co przegapiłem?", analogiczny do sprawdzania powiadomień z social media po przerwie. Satyrycznie: to dokładnie ten mechanizm FOMO, który napędza realną kompulsywną konsumpcję treści — gra pozwala go poczuć bez kosztu.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents not consulted in Core Rules — Lean mode (section is not D/H); Formulas will receive specialist review.*

### Core Rules

Key simplification: **Cringe does not change offline** (no actions/cards fire without the player) — so Hatersi's growth rate (Formula A) is *constant* throughout the offline period (Cringe as a fixed input). But Morale and `Mult(M)` **do change** as Hatersi accumulates, so the passive-income multiplier (Formula D) must be re-evaluated stepwise — per the Open Question left by Resource System.

**Simulation algorithm (1-minute steps, per Resource System's recommendation):**

```
function simulate_offline(Δt_seconds, Cringe_fixed, H0, M0):
    remaining = min(Δt_seconds, MAX_OFFLINE_CAP_SECONDS)
    H = H0; M = M0; Z_gained = 0
    H_rate = H_base + (Cringe_fixed/100)^H_exp × H_max_add   # constant, Cringe doesn't change offline
    while remaining > 0:
        dt = min(60, remaining)
        H += H_rate × (dt/60)
        M_drain = M_drain_per_hater × max(0, H - N_buffer)^M_drain_exp
        M = max(0, M - M_drain × (dt/60))
        Mult = band(M)   # Resource System Formula C
        Z_gained += H × Z_per_hater × Mult × (dt/60)
        remaining -= dt
    return { final_H: H, final_M: M, total_Z_gained: Z_gained, capped: Δt_seconds > MAX_OFFLINE_CAP_SECONDS }
```

**Rules:**
1. The simulation runs **once, at app start**, after Save/Persistence System loads state.
2. `Δt` is **capped** at `MAX_OFFLINE_CAP_SECONDS = 86400` (24 hours) — encourages daily returns, bounds the computation, avoids absurd numbers after long real-world gaps.
3. Only **passive** sources (Hatersi → Zasięgi) accrue offline — active actions (Action System) and cards (Decision Card System) **never** fire automatically offline.
4. Cringe remains unchanged for the entire offline period (no actions = no source of Cringe change).
5. The simulation result is applied to Resource System **once, after completion** (not stepped in real time) — the player sees the already-updated final state.
6. **Within-step ordering is fixed**: each step updates `H` first, then computes `M_drain`/`M` from the *new* `H`, then computes `Mult(M)` from the *new* `M`, then accumulates `Z_step` using the *post-update* `H` and `M` — exactly the order shown in the pseudocode above. This is not ambiguous: H and M are always updated before being read for that same step's Z contribution.
7. **Malformed `last_saved_at`** is handled upstream: Save/Persistence System treats any unparseable save data (including a malformed timestamp) as "file doesn't exist" and falls back to defaults — so this system never receives a malformed timestamp; it either gets a valid one or doesn't run at all (per Edge Cases).

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `idle` | No simulation running, normal active play | → `computing` at app start |
| `computing` | Running the stepped simulation | → `presenting` once complete |
| `presenting` | Offline report ready, awaiting player acknowledgment | → `idle` only when the player dismisses the Offline Report Screen (gated on player action, not automatic) |

### Interactions with Other Systems

- **Save/Persistence System** (hard, read) → reads `last_saved_at` to compute `Δt`; reads `resources`/`history_flags` for `H0`/`M0`/`Cringe_fixed` initial values
- **Resource System** (hard, read+write) → reads Formulas A/B/C/D and their tuning knobs (`H_base`, `H_exp`, `H_max_add`, `M_drain_per_hater`, `N_buffer`, `M_drain_exp`, `Z_per_hater`); writes the final `H`, `M`, and accumulated `Z_gained` once simulation completes
- **Offline Report Screen** (downstream, undesigned) → reads the simulation result (`total_Z_gained`, `capped` flag, elapsed Δt) to display the report

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

**simulate_offline** is defined as:

`{final_H, final_M, total_Z_gained} = simulate_offline(Δt_seconds, Cringe_fixed, H0, M0)` (see pseudocode in Core Rules)

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Elapsed time | Δt_seconds | int | ≥0 | Time since `last_saved_at`, capped at 86400 (24h) |
| Fixed Cringe | Cringe_fixed | int | 0–100 | Cringe value at last save — constant for the whole simulation |
| Initial Hatersi | H0 | float | ≥0 | Hatersi count at last save |
| Initial Morale | M0 | float | 0–100 | Morale % at last save |
| Final Hatersi | final_H | float | ≥H0, unbounded upward | Hatersi after simulation |
| Final Morale | final_M | float | 0–100 | Morale after simulation (commonly 0 — see worked example) |
| Total Zasięgi gained | total_Z_gained | float | ≥0 | Accumulated passive income across the simulation |

**Step size:** 1-minute fixed steps (not coarser, not adaptive) — confirmed by `systems-designer`: computationally trivial (1440 iterations max, microseconds-to-low-ms in GDScript, no background thread needed) and guarantees offline math can never silently diverge from live-play formulas (Pillar 4).

**Worked example:** Cringe=50 (fixed), H0=5, M0=80%, Δt=24h (capped) → `H_rate = 0.02 + (0.5)^2.0×1.0 = 0.27/min` (constant) → **final_H ≈ 394**, **final_M ≈ 0%**, **total_Z_gained ≈ 28,000–29,000 Zasięgi**.

**Confirmed behavior (intentional, not a bug):** Morale crashes through all bands within ~70-90 minutes of offline time for any player with moderate-to-high Cringe, then sits at Critical (0.5x) for ~21-22 of the 24 hours. This is accepted as a deliberate satirical/FOMO hook ("your empire burned out while you weren't looking") consistent with the game's social-media-burnout theme — not corrected via new Resource System constants, per design decision. See Edge Cases and Open Questions.

## Edge Cases

> *Specialist consulted: `systems-designer` (carried over from Formulas review).*

- **If `Δt = 0`** (player returns immediately, e.g., app-switching): simulation runs 0 steps, `final_H = H0`, `final_M = M0`, `total_Z_gained = 0` — no effect, no special case.
- **If `Δt > MAX_OFFLINE_CAP_SECONDS`**: simulation only computes the first 24h, `capped = true` in the result — Offline Report Screen should communicate this (e.g., "Your 3 days offline counted as 24h").
- **If `H0 = 0`** (fresh game start, zero Hatersi): `Z_gained` accrues from zero per the formula — Hatersi grow at `H_rate`, but `Z_per_hater × H` starts at 0, so the first minutes yield negligible income. Correct, not a bug.
- **If Morale hits 0% before the simulation ends** (confirmed as typical behavior): the remainder of the simulation computes at `Mult=0.5x` until the end — accepted as a deliberate satirical hook (see Formulas).
- **If the player closes and reopens the app repeatedly in quick succession** (e.g., several times within a minute): each launch computes `Δt` from the last save — since Save/Persistence System saves after a 2s debounce, rapid restarts compute very small `Δt` values, effectively no accumulation (consistent with the `Δt=0` case above).
- **If this is the first session ever (no `last_saved_at` exists)**: Save/Persistence System initializes defaults — Offline Progress System **does not run at all** (no time reference point); the main screen's starting state shows no offline report.

## Dependencies

**Upstream (this system depends on):**
- **Save/Persistence System** (hard) — `last_saved_at`, initial resource/history-flag values.
- **Resource System** (hard) — Formulas A/B/C/D and their tuning knobs; writes the simulation result back.

**Downstream (depends on this system):**
- **Offline Report Screen** (hard, undesigned) — reads the simulation result to display the report.
- **Prestige/Checkpoint System** (hard, Alpha, undesigned) — may interact with offline accumulation once designed.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `MAX_OFFLINE_CAP_SECONDS` | 86400 (24h) | 43200–259200 (12h–72h) | Too low: punishes players who miss a day, feels stingy. Too high: weakens the daily-return hook, risks absurd numbers after long gaps |
| `OFFLINE_STEP_SECONDS` | 60 | 60 only (do not change without re-profiling) | Coarser steps lose accuracy on Morale-band transitions; finer steps add cost with no accuracy benefit per `systems-designer`'s analysis |

**Knob interaction:** `MAX_OFFLINE_CAP_SECONDS` is independent of Resource System's knobs, but changing Resource System's `H_base`/`H_exp`/`H_max_add`/`M_drain_per_hater` will change how quickly Morale crashes within this GDD's simulation — revisit the worked example in Formulas if those upstream knobs change.

## Visual/Audio Requirements

None — pure simulation logic, produces no visual/audio content directly. Presentation belongs to Offline Report Screen (downstream, undesigned).

## UI Requirements

None — this system has no screen of its own. Exposing the result to the player belongs to Offline Report Screen, not this GDD.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**State transitions:**
- **GIVEN** valid `last_saved_at` exists, **WHEN** the app launches, **THEN** `idle → computing`.
- **GIVEN** `computing`, **WHEN** `simulate_offline` finishes, **THEN** → `presenting`.
- **GIVEN** `presenting`, **WHEN** the player dismisses the Offline Report Screen, **THEN** → `idle` (gated on player action, not automatic).
- **GIVEN** `computing` or `presenting`, **WHEN** a second app-start event fires before the cycle completes, **THEN** `simulate_offline` is not invoked a second time concurrently (no re-entrant simulation).

**Cringe constancy:**
- **GIVEN** `simulate_offline` called with `Cringe_fixed=50`, **WHEN** any step executes, **THEN** the Cringe value used in every step's `H_rate` equals 50, unchanged from first to last step.

**Stepped evolution — Hatersi:**
- **GIVEN** Cringe=50, H0=5, M0=80%, Δt=24h, **WHEN** simulation completes, **THEN** `H_rate≈0.27/min` constant, `final_H≈394` (±2%).
- **GIVEN** any step, **WHEN** `H` updates, **THEN** `H_new = H_old + H_rate×(dt/60)`, dt=60 for interior steps.
- **GIVEN** H0=0, **WHEN** simulation runs, **THEN** H still increases per the same formula; early Z gains are nonzero but small relative to a higher-H0 run.

**Stepped evolution — Morale:**
- **GIVEN** a step where H≤N_buffer, **WHEN** M_drain computed, **THEN** M_drain=0.
- **GIVEN** a step where H>N_buffer, **WHEN** M_drain computed, **THEN** `M_drain = M_drain_per_hater×(H-N_buffer)^M_drain_exp`, M floored at 0.
- **GIVEN** the worked example, **WHEN** simulation completes, **THEN** `final_M≈0%` (±1pp).
- **GIVEN** M reaches 0 before the final step, **WHEN** subsequent steps execute, **THEN** `Mult(M)=0.5x` for those steps — not flagged as a bug (intentional, per Formulas).

**Stepped evolution — Zasięgi:**
- **GIVEN** any step, **WHEN** `Z_gained` accumulates, **THEN** `Z_step = H×Z_per_hater×Mult(M)×(dt/60)` using the *post-update* H and M for that step (fixed ordering, see Core Rules rule 6).
- **GIVEN** the worked example, **WHEN** simulation completes, **THEN** `total_Z_gained` falls within 28,000–29,000.
- **GIVEN** Δt=0, **WHEN** invoked, **THEN** `total_Z_gained=0`, `final_H=H0`, `final_M=M0`.

**Cap behavior:**
- **GIVEN** Δt=200,000s (>86400 cap), **WHEN** simulation runs, **THEN** only the first 1440 steps execute, `capped=true`.
- **GIVEN** Δt=86400s exactly, **WHEN** simulation runs, **THEN** all 1440 steps execute, `capped=false` (boundary inclusive).
- **GIVEN** Δt=86401s, **WHEN** simulation runs, **THEN** exactly 1440 steps execute (trailing 1s discarded, not rounded into a 1441st step), `capped=true`.

**Defined edge cases:**
- **GIVEN** Δt=0, **WHEN** invoked, **THEN** `idle→computing→presenting→idle` with zero gain, no error.
- **GIVEN** Δt>86400, **WHEN** simulation completes, **THEN** the result equals a standalone run with Δt=86400 exactly (deterministic, reproducible).
- **GIVEN** H0=0, **WHEN** simulation completes, **THEN** no division-by-zero/NaN/negative values; all outputs ≥0.
- **GIVEN** M0=0% at start, **WHEN** simulation runs, **THEN** `Mult(M)=0.5x` from step 1 onward.
- **GIVEN** two saves within the 2s debounce window, **WHEN** the next app start reads `last_saved_at`, **THEN** Δt reflects only the time since the actually-persisted (debounced) save — negligible Z/H/M change.
- **GIVEN** no `last_saved_at` exists (first session), **WHEN** the app launches, **THEN** `simulate_offline` is never invoked, state stays `idle`, no report shown.
- **GIVEN** a malformed/corrupted save (including a bad timestamp), **WHEN** the app launches, **THEN** Save/Persistence System already treats this as "file doesn't exist" (per that GDD) — this system never receives a malformed timestamp; it either gets a valid one or doesn't run.

**Not testable against this GDD alone:**
- Offline Report Screen presentation (formatting, "you were away for X" copy, capped-flag messaging) — undesigned, owned by a future GDD.
- Resource System's exact Morale band thresholds — owned by that GDD; these AC assume that spec is stable, re-validate if it changes.

## Open Questions

- **Does the offline Morale spiral need playtest validation before Vertical Slice?** — accepted as an intentional hook, but this is a design assumption, not yet validated by play. *Owner: `/playtest-report` at Vertical Slice.*
- **Re-entrancy guard for rapid repeated app launches** — flagged by qa-lead, no explicit lock rule defined. *Owner: revise this GDD or `/architecture-decision`. Target: before `/create-architecture`.*
- **Is 24h the right `MAX_OFFLINE_CAP_SECONDS`?** — chosen as the recommended default, not yet validated with real player data. *Owner: `/playtest-report`, revisit after initial testing. Target: before Production.*
