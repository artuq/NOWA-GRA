# Action System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 1 — Uczciwa matematyka, nieuczciwy świat

## Overview

Action System to rdzeń mechaniczny gry — implementuje pętlę **select-and-wait** (wybór akcji → trwa w czasie → nagroda po zakończeniu), potwierdzoną przez dwa prototypy (CONFIRMED w obu). Gracz wybiera jedną z 3 akcji podstawowych (Nagraj vloga / Zrób dramę / Przeproś w internecie), każda z innym czasem trwania i inną kombinacją nagród/kosztów w Zasięgach, Cringe i Morale. To jest dosłownie Pillar 1 w praktyce: każda akcja ma przewidywalny, niezmienny rezultat — gracz zawsze wie, co dostanie, zanim kliknie.

Dla gracza to jest najbardziej bezpośrednio odczuwalny system w grze — to jest to, co robi przez większość czasu aktywnej sesji. Bez tego systemu gra nie ma żadnej aktywnej rozgrywki — Resource System dostarcza zasoby, ale to Action System jest jedynym sposobem, by gracz świadomie nimi zarządzał.

> *No ADR exists yet to cite (`docs/architecture/` doesn't exist) — add a reference once the relevant ADR (e.g., "Action timer architecture") is written during `/create-architecture`.*

## Player Fantasy

Gracz czuje kontrolę i przewidywalność — wybiera akcję wiedząc dokładnie, co dostanie, i patrzy jak progress bar się wypełnia. To jest satysfakcja optymalizatora (jak Melvor Idle), nie hazardzisty: żadnych niespodzianek w samej akcji. Pod tą warstwą leży infrastruktura timerów i reward tables, niewidoczna dla gracza, ale to ona gwarantuje, że "uczciwa matematyka" (Pillar 1) jest rzeczywiście uczciwa — gracz może zaufać liczbom, bo wie, że nic w tym systemie nie jest losowe. Satyrycznie: to jest dokładnie ten sam mechanizm, który w realnym życiu sprawia, że influencerzy traktują content jak fabrykę — przewidywalny input, przewidywalny output, bez przestrzeni na refleksję moralną (to nadchodzi z Decision Card System, nie tutaj).

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents (game-designer, systems-designer) not consulted — Lean mode. Review manually before production.*

### Core Rules

**3 base actions (per prototype and `game-concept.md`):**

| Action | Type | Duration | Role |
|---|---|---|---|
| Nagraj vloga | neutral/baseline | 6s | Safe, basic filler |
| Zrób dramę | risky | 9s | High reward, high Cringe |
| Przeproś w internecie | safe | 4s | Low reward, reduces Cringe, regenerates Morale |

**Rules:**
1. Only **one action at a time** may be `running` (confirmed by both prototypes, required by Resource System's Edge Case).
2. Every action has a **static, predefined** reward table (Zasięgi/Cringe/Morale) — no randomness inside the action itself (Pillar 1).
3. On completion, the final Zasięgi reward is scaled by the **Morale multiplier** from Resource System (Formula C: 1.0x/0.9x/0.75x/0.5x) — the action declares a *base* reward; Resource System applies the modifier.
4. `Zrób dramę` (risky) pays **1.6x** the Zasięgi of `Przeproś w internecie` (safe) — mid-range of the 1.4x-1.8x ratio locked in the registry.
5. Each action's Cringe delta must fall within the registered range of -15 to +20 (Resource System's `cringe_delta_ceiling`/`cringe_delta_floor`).

**Reward table:**

| Action | Duration | Zasięgi (base) | Cringe Δ | Morale Δ | Zasięgi/s |
|---|---|---|---|---|---|
| Nagraj vloga | 6s | +5 | +2 | 0 | 0.83 |
| Zrób dramę | 9s | +10 | +20 (ceiling) | -3 | 1.11 |
| Przeproś w internecie | 4s | +6 | -15 (floor) | +5 | 1.50 |
| Record a Collab (slot 4) * | 12s | +16 | +8 | -2 | 1.33 |
| Give an Interview (slot 5) * | 15s | +24 | +4 | +3 | 1.60 |
| Launch a Course (slot 6) * | 20s | +40 | +18 | -5 | 2.00 |

\* **Milestone/counter-gated unlocks (slots 4-6).** These 3 actions occupy the 3 reserved locked Action Grid slots and become available only through the player's decision history — the *unlock conditions* are owned by `design/quick-specs/milestone-gated-action-slots-2026-06-30.md` (per DDR-0001 #3), not this reward table. They pay a higher Zasięgi/s than the base 3, appropriate for gated progression content; each is self-balanced by a Cringe cost feeding the Cringe→Haters→Morale chain (slot 6's +18 is the apex-grift cost). No Sponsors delta — that faucet stays tied to sponsor/brand cards. The Collab→Interview→Course arc is the archetypal influencer monetization escalation ending in the "sell a course" grift (Pillar 3: critique through what the game rewards).

(Zasięgi ratio 10/6 = 1.67x for the base risky/safe pair, within the locked 1.4-1.8x registry range; the 1.4-1.8x rule binds risky/safe *pairs*, not the gated escalation actions above. Duration was tuned — per `systems-designer` review — to 9s rather than the original 12s: at 12s, drama's Zasięgi/s tied exactly with the neutral baseline (0.83/s), making the risky action strictly dominated for a player optimizing Zasięgi/time, with all downside and no upside. At 9s, drama clears the baseline (1.11 > 0.83/s) while Przeproś remains the fastest per-second — correct, since its premium is conditional on actually needing Cringe/Morale relief, not a flat advantage.)

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `idle` | No active action, player choosing | → `running` when an action is chosen |
| `running` | Action is in progress, progress bar fills | → `resolved` when `duration` elapses |
| `resolved` | Reward applied to Resource System | → `idle` immediately (ready for next choice) |

### Interactions with Other Systems

- **Resource System** (hard, write+read) → on `resolved`, Action System writes base Zasięgi/Cringe/Morale deltas; reads the current Morale multiplier (Formula C) to scale the final Zasięgi reward
- **Offline Progress System** (downstream, undesigned) → must simulate actions across offline time; this GDD defines the reward table that system will query

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

**final_zasiegi_reward** is defined as:

`final_zasiegi_reward = base_zasiegi × Mult(M)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base Zasięgi | base_zasiegi | int | {5, 10, 6} | Static per-action reward from the lookup table |
| Morale multiplier | Mult(M) | float | {0.50, 0.75, 0.90, 1.00} | Resource System's Formula C, read at resolution time |

**Output Range:** bounded below by 0.5× base (Critical Morale band), effectively a 4-value discrete output per action — no continuous curve.
**Example:** Zrób dramę resolves at Normal Morale (M=55%) → 10 × 0.90 = 9.0 → round-half-up → 9 Zasięgi.

This is the only formula this system owns — Cringe/Morale deltas are flat static lookups with no math (the clamp/composition logic for Cringe already belongs to Resource System's `cringe_delta_from_actions` formula, not here).

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If the player tries to choose an action while `running`**: the action is added to the queue (not started immediately). Queue cap is `QUEUE_CAP` (default 10); when the queue is full, action buttons are disabled with a "Queue full" tooltip. See quick-spec `design/quick-specs/action-queue-auto-repeat-2026-06-30.md` for full queue rules.
- **If the queue is suspended** (Decision Card visible OR Morale ≤ Critical): the current action runs to completion, but the next queued action does not auto-start until the suspend condition clears.
- **If the game is closed mid-`running`**: on return, Offline Progress System must resolve whether the action "completed" during offline time (closed duration ≥ remaining action time) — this is a dependency, not resolved here; flagged as an Open Question for Offline Progress System.
- **If Morale is 0% (Critical) at resolution**: `Mult(M) = 0.50` applies normally — no special penalty beyond what Resource System's Formula C already defines.
- **If Cringe is already at 100 when `Zrób dramę` resolves**: Resource System's `cringe_delta_from_actions` formula naturally clamps the gain (soft brake) — Action System does nothing extra, it just passes the declared delta (+20) to Resource System.
- **If the player immediately re-selects the same action after `resolved`**: allowed — no cooldown between actions beyond the natural duration of the next action.

## Dependencies

**Upstream (this system depends on):** Resource System (hard) — writes reward deltas, reads Morale multiplier.

**Downstream (depends on this system):**
- **Action UI** (hard) — displays the running action's progress bar and disables choice during `running`.
- **Onboarding/Tutorial** (hard) — sequences the first plays of these 3 actions before Decision Card System is introduced.
- **Juice/Feedback System** (hard, Vertical Slice) — provides completion-beat feedback (audio/VFX) when an action resolves.
- **Offline Progress System** (hard, undesigned) — must simulate this reward table across offline time deltas.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| Action durations | 6s / 9s / 4s | 3s–20s | Too short: feels like tapping again (defeats select-and-wait). Too long: kills session pacing |
| Per-action Zasięgi (base) | 5 / 10 / 6 | tied to risky:safe ratio (1.4-1.8x) | Changing one value without checking Zasięgi/s against the others can recreate the dominated-action bug found in this GDD's review |
| Per-action Cringe Δ | +2 / +20 / -15 | within Resource System's -15 to +20 range | Exceeding the registered ceiling/floor breaks the locked Resource System contract |
| Per-action Morale Δ | 0 / -3 / +5 | -10 to +10 | Too high: a single action can jump a full Morale band, undermining gradual escalation (Pillar 1) |
| `QUEUE_CAP` | 10 | 5–20 | Too low: frustrating for offline play (Pillar 4). Too high: trivialises resource management |

**Knob interaction:** changing any action's duration or base Zasięgi requires recomputing all 3 actions' Zasięgi/s — this GDD's own review found that a naive duration change (12s for drama) created a dominated strategy. Always check per-second rates together, not in isolation.

## Visual/Audio Requirements

> Not mandatory (category "Gameplay" isn't on the required-Visual/Audio list), but needed — flagged by Acceptance Criteria gaps.

- Progress bar filling over the action's duration — confirmed by both prototypes as legible and satisfying without tapping.
- "Soczystość" (effect/sound/short vibration) concentrated on the **`resolved` moment**, not on action start or mid-progress — per `game-concept.md`'s original design ("juice at cycle completion, not on every tap").
- Distinct visual signals per action (progress bar color/icon) — the player must distinguish which action is active at a glance.
- No sound/effect implying good/bad for `Zrób dramę` vs `Przeproś` — same anti-pillar constraint as Card Content Database (no moral color-coding).

📌 **Asset Spec** — once the art bible is approved, run `/asset-spec system:action-system`.

## UI Requirements

- 3 action buttons, always visible on the main screen (per prototype) — large touch areas (standard `Button` node, not `TouchScreenButton` — per ADR-0007), zero hover-only.
- During `running`: all 3 buttons disabled (not just visually muted — see Acceptance Criteria), visible progress bar labeled with the active action.
- Layout must reserve room for 3 future actions (unlocked at milestones, Vertical Slice) without a screen redesign.

> 📌 **UX Flag — Action System**: In Phase 4 (Pre-Production), run `/ux-design` for the main screen (actions + progress bar). UI stories should cite `design/ux/main-screen.md`, not this GDD.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**State transitions:**
- **GIVEN** `idle`, **WHEN** the player selects `Nagraj vloga`, **THEN** state → `running`, progress tracks toward 6s.
- **GIVEN** `running`, **WHEN** elapsed time reaches the action's `duration` (6s/9s/4s), **THEN** state → `resolved`, reward deltas written to Resource System.
- **GIVEN** `resolved`, **WHEN** the reward write completes, **THEN** state → `idle` immediately, no player-visible delay.
- **GIVEN** `idle` with no action ever selected, **WHEN** rendered, **THEN** no progress bar shown, all 3 choices enabled.

**Queue rules (replaces single-concurrency reject):**
- **GIVEN** an action is `running`, **WHEN** the player selects any action, **THEN** it is added to the queue; the running action continues unaffected.
- **GIVEN** queue length = `QUEUE_CAP`, **WHEN** the player selects any action, **THEN** rejected (queue full); UI shows "Queue full" tooltip.
- **GIVEN** `resolved` → `idle` transition, **WHEN** queue is non-empty AND not suspended, **THEN** `queue.pop_front()` starts immediately → `running`.
- **GIVEN** `resolved` → `idle`, **WHEN** queue is empty, **THEN** state stays `idle`; no auto-start.
- **GIVEN** an action just returned to `idle` with empty queue, **WHEN** the player immediately selects the same action again, **THEN** accepted with no cooldown.

**Queue suspend rules:**
- **GIVEN** a Decision Card is presented, **WHEN** queue is non-empty, **THEN** queue is suspended (frozen); current action finishes, next does not auto-start until card is dismissed.
- **GIVEN** Morale ≤ Critical, **WHEN** `resolved` → `idle`, **THEN** queue is suspended; does not auto-start. Resumes when Morale exits Critical.
- **GIVEN** queue is suspended, **WHEN** suspend condition clears, **THEN** auto-start resumes from the front of the queue on the next `resolved` → `idle` transition.

**Reward formula at each Morale band:**
- **GIVEN** High Morale (Mult=1.00), **WHEN** `Zrób dramę` (base=10) resolves, **THEN** final = 10.
- **GIVEN** Normal Morale (Mult=0.90), **WHEN** `Zrób dramę` resolves, **THEN** final = 9 (10×0.9=9.0, round-half-up).
- **GIVEN** Low Morale (Mult=0.75), **WHEN** `Nagraj vloga` (base=5) resolves, **THEN** final = 4 (5×0.75=3.75, round-half-up).
- **GIVEN** Critical Morale (Mult=0.50), **WHEN** `Przeproś w internecie` (base=6) resolves, **THEN** final = 3, no additional penalty beyond the 0.5x multiplier.
- **GIVEN** any resolution, **WHEN** the Morale multiplier is read, **THEN** it is exactly one of {0.50, 0.75, 0.90, 1.00} — never interpolated.

**Cringe/Morale deltas (flat lookups):**
- **GIVEN** `Nagraj vloga` resolves, **THEN** Cringe +2, Morale +0, regardless of Morale band.
- **GIVEN** `Zrób dramę` resolves, **THEN** Cringe +20 (subject to Resource System's clamp), Morale -3.
- **GIVEN** `Przeproś w internecie` resolves, **THEN** Cringe -15 (subject to clamp), Morale +5.

**Defined edge cases:**
- **GIVEN** `running`, **WHEN** the player taps any other action, **THEN** added to queue (not rejected); no partial reward applied to the running action.
- **GIVEN** Critical Morale at resolution, **THEN** Mult=0.50 applies, no separate "Critical penalty" stacks on top.
- **GIVEN** Cringe=100, **WHEN** `Zrób dramę` (ΔCringe=+20) resolves, **THEN** Action System passes +20 unmodified; resulting Cringe is governed solely by Resource System's clamp (`clamp(120,0,100)-100=0` — derived from Formula E, not separately re-tested here).

**Not testable against this GDD alone:**
- App-close mid-`running` — deferred to Offline Progress System, which doesn't exist yet. **BLOCKED pending that GDD.**
- Full UI disablement styling (beyond interaction-level rejection) — this GDD's UI Requirements section must be written first. **PARTIAL pending UI Requirements.**
- Resolution-beat visual/audio feedback — owned by Juice/Feedback System (undesigned) and this GDD's own Visual/Audio section. **BLOCKED pending both.**
- Rounding rule ("round-half-up") is used in examples but not declared as a named, owned rule anywhere — flag as a **documentation gap** to confirm with engineering before treating these AC as locked regression tests.

## Open Questions

- **Quests/challenges for the player** — not yet planned in `systems-index.md`; consider in a future `/map-systems` pass if MVP + subsequent tiers still feel thin. *Owner: future `/map-systems` pass. Target: after `/vertical-slice`.*
- **App-close mid-`running`** — requires Offline Progress System to be designed. *Owner: Offline Progress System GDD. Target: next in design order.*
- **Rounding rule provenance** — "round-half-up" used in examples but never formally declared as a named, owned rule. *Owner: confirm with engineering before `/create-architecture`.*
- **Milestone thresholds (25/75/150) need re-validation** — tuned against a different baseline (3-8/cycle) than this GDD's final table (5/10/6). *Owner: future Milestone/Progression aspect of Class Path System. Target: before locking thresholds in the registry.*
