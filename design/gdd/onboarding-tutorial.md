# Onboarding/Tutorial

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 1, 2, 3, 4 — pierwsze wrażenie gracza ze wszystkimi czterema pillarami

## Overview

Onboarding/Tutorial to sekwencja wprowadzająca pierwsze sesje gracza — rozkłada w czasie ekspozycję na 3 akcje podstawowe (Action System), pierwszą kartę decyzji (Decision Card System), i pierwszy powrót offline (Offline Progress System), tak by gracz nie był zalany złożonością w pierwszych minutach. Ten GDD nie tworzy nowej logiki gry — definiuje **kolejność i tempo**, w jakim istniejące systemy są odsłaniane.

Dla gracza to pierwsze wrażenie z grą — decyduje, czy zrozumie pętlę select-and-wait (potwierdzoną w prototypach) zanim natrafi na pierwszą kartę decyzji, i czy poczuje, że gra go prowadzi, nie zalewa.

## Player Fantasy

Gracz czuje, że gra "rozumie", że jest nowy — pierwsze minuty są proste i nagradzające, bez presji decyzji moralnych, zanim zdąży zrozumieć podstawową pętlę. Pierwsza karta decyzji pojawia się w momencie, gdy gracz już ma pewność co do akcji — to jest moment "aha, jest tu więcej" bez poczucia zagubienia. To nie jest "tutorial" w sensie wykładu (Pillar 3 obowiązuje też tutaj) — gra uczy przez strukturę doświadczenia, nie przez tekst instrukcji.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents not consulted — Lean mode. Review manually before production.*

### Core Rules

This GDD resolves Action System's Open Question: "the first 3 actions without cards must be designed."

**Sequencing rules:**
1. **Phase 1 — Pure action (variety-gated, not count-gated):** Decision Card System is **suppressed** (does not query the card pool) until the player has completed **at least one of each of the 3 action types** (Nagraj vloga, Zrób dramę, Przeproś w internecie) — not simply "3 actions," since 3 repeats of the same action would never expose the player to the full reward table. Resource System and History Flag System operate normally in the background (writing data), but the player doesn't see cards yet.
2. **Phase 2 — First card (after all 3 types completed):** Once all 3 action types have each completed at least once, Decision Card System's normal cooldown (2 actions) is **reset and forced to 0** — the first card appears immediately after the next completed action (the 4th overall, at minimum), guaranteeing both full reward-table exposure and a predictable "ah, there's more here" moment.
3. **Phase 3 — Normal play:** From this point on, Decision Card System operates fully per its own GDD (2-action cooldown, weighting, etc.) — Onboarding/Tutorial doesn't intervene further.
4. **Resource System and History Flag System are never gated** — they operate from the first action per their own rules; onboarding only controls card *visibility*, not resource logic.
5. The initial 3 unlocked Action Grid slots (per Action UI) are sufficient for the entirety of Phase 1 — the player never needs to wait for further action unlocks to see the first card.

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `phase_pure_action` | Decision Card System suppressed, not all 3 action types tried yet | → `phase_first_card_pending` when all 3 action types have each completed ≥1 time |
| `phase_first_card_pending` | Cooldown forced to 0, awaiting next completed action | → `phase_normal` once the first card appears |
| `phase_normal` | Onboarding complete, Decision Card System fully autonomous | (terminal — no further transitions) |

### Interactions with Other Systems

- **Action System** (hard, read) → reads the "action completed" event to count Phase 1 progress
- **Decision Card System** (hard, write) → suppresses/unsuppresses card pool checking; overrides cooldown to 0 at the Phase 1→2 transition
- **Resource System, History Flag System** (peer, no intervention) → operate normally from the start, independent of onboarding phase

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

This system performs no calculations — pure sequencing/state logic, same shape as History Flag System's Path Resolution Algorithm. The Phase 1→2 transition is a variety-coverage check (all 3 action types completed ≥1 time each, see Tuning Knobs), and Phase 2's cooldown override is a fixed assignment (cooldown = 0), both consumed from Action System and Decision Card System respectively. No formula is owned by this GDD.

**Confirmed (no tutorial-specific reward boost):** rewards during Phase 1 stay exactly as Action System defines them — a boost would break Pillar 1's "what you see is what you get" contract on the player's very first interaction with numbers, and would require new formula/decay logic for a system whose stated purpose is sequencing only, not new mechanics. Generosity, if wanted, comes from Phase 2's forced-cooldown-to-0 pacing, not from altered numbers.

**Timing sanity check:** 3 actions (one of each type) take roughly 12-27s depending on combination (durations 6s/9s/4s from Action System), comfortably within normal mobile-onboarding windows (most successful idle tutorials resolve core-loop comprehension in 10-30s) — confirms the variety-gate approach doesn't make Phase 1 feel too long.

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If the app closes during `phase_pure_action`**: which action types have already been tried must be saved by Save/Persistence System — on return, onboarding resumes from exactly that point, never resets.
- **If the player closes the app right after entering `phase_first_card_pending`**: cooldown=0 must survive save/load — on return, the first card still appears after the next completed action.
- **If the player uninstalls/reinstalls** (no save file): onboarding starts from scratch, consistent with Save/Persistence System's "first session" behavior.
- **If the player is already in `phase_normal` and a developer resets test data**: no special handling — this is a developer/QA scenario, not a design case; a data reset is treated as a first session.
- **If all 3 action types are tried in a non-"natural" order** (e.g., Zrób dramę first, then Przeproś, then Nagraj vloga): no required order — `phase_pure_action` checks only the *set* of tried types, not sequence.

## Dependencies

**Upstream (this system depends on):**
- **Action System** (hard) — reads "action completed" events and action type to track Phase 1 progress.
- **Decision Card System** (hard) — suppresses/unsuppresses card pool checks; overrides cooldown.

**Peer (no intervention):**
- **Resource System, History Flag System** — operate normally from the start, unaffected by onboarding phase.

**Downstream:** None — this system is terminal in the dependency graph (per `systems-index.md`).

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| Required action types before first card | All 3 (Nagraj vloga, Zrób dramę, Przeproś) | 1–3 | Fewer than 3: player may never see the full reward table before facing their first moral choice. Keeping at 3 is the safe default — not really a "tune down" knob, more a documented design lock |
| Cooldown override value at Phase 1→2 | 0 | 0 only | Any nonzero value reintroduces unpredictability into the "first card" moment, defeating the purpose of forcing it |

**Knob interaction:** none — independent of other GDDs' tuning knobs, though the timing sanity check in Formulas assumes Action System's current durations (6s/9s/4s); revisit if those change significantly.

## Visual/Audio Requirements

None — pure sequencing logic, no presentation of its own. Visuals/audio for actions and cards during onboarding are owned by Action UI and Card UI, used unmodified.

## UI Requirements

None — this system has no screen and is never directly surfaced to the player; it only controls when Decision Card System's existing UI becomes active.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**State transition phase_pure_action → phase_first_card_pending:**
- **GIVEN** a fresh session, 0 types completed, **WHEN** 1 action completes (any type), **THEN** stays `phase_pure_action`, no card pool check invoked.
- **GIVEN** 2 distinct types completed, **WHEN** the 3rd action is a repeat of an already-completed type, **THEN** stays `phase_pure_action` (variety not satisfied — count alone doesn't transition).
- **GIVEN** 2 distinct types completed, **WHEN** the previously-untried 3rd type completes, **THEN** → `phase_first_card_pending` immediately.

**Variety-gate (set membership, not count, not order):**
- **GIVEN** `phase_pure_action`, **WHEN** the 3 types complete in non-"natural" order, **THEN** transition fires after the 3rd distinct type regardless of order.
- **GIVEN** `phase_pure_action`, **WHEN** the same type completes 5 times in a row, **THEN** stays `phase_pure_action` (count irrelevant, only distinct-type coverage matters).

**phase_first_card_pending → phase_normal:**
- **GIVEN** `phase_first_card_pending` (cooldown=0), **WHEN** the next action completes, **THEN** a card is presented immediately after, and → `phase_normal`.
- **GIVEN** `phase_normal`, **WHEN** any subsequent action completes, **THEN** Decision Card System's normal cooldown/weighting applies, no onboarding intervention.

**Resources/History Flags never gated:**
- **GIVEN** `phase_pure_action` (cards suppressed), **WHEN** any action completes, **THEN** Resource System and History Flag System update exactly as in `phase_normal`, no suppression/modification.

**Rewards unmodified:**
- **GIVEN** the same action/inputs, **WHEN** executed once in `phase_pure_action` and once in `phase_normal`, **THEN** reward output is identical per Action System's table (no boost in any phase).

**Defined edge cases:**
- **GIVEN** 1 of 3 types completed, **WHEN** the app force-closes and relaunches, **THEN** state is `phase_pure_action` with that type marked, others still pending (read from Save/Persistence, not reset).
- **GIVEN** just entered `phase_first_card_pending`, **WHEN** the app closes before the next action and relaunches, **THEN** still `phase_first_card_pending`, cooldown=0 preserved, first card appears after the next completed action.
- **GIVEN** no save file exists (fresh install/reinstall), **WHEN** the app launches, **THEN** initializes `phase_pure_action`, 0 of 3 types — identical to true first-session behavior.
- **GIVEN** `phase_normal` and a developer/QA reset clears data, **WHEN** the app relaunches, **THEN** initializes `phase_pure_action`, 0 of 3 — identical to a fresh install, no special "returning player" case.
- **GIVEN** the 3 types complete in any of the 6 possible permutations, **WHEN** tested across all permutations, **THEN** the transition fires at the same point (after the 3rd distinct type) in every case.

**Story type classification:** Logic story (pure state-machine sequencing, no formulas) — requires a BLOCKING automated unit test in `tests/unit/onboarding/` covering the state-transition and variety-gate criteria (mockable via simulated "action completed" events, no real Action System integration needed). The Resources/History-Flags and rewards-unmodified criteria are Integration-test candidates (also BLOCKING per this project's Logic/Integration gate).

**Not testable against this GDD alone:**
- "Immediately after that action resolves" (card presentation timing) — UI/animation timing is owned by Action UI/Card UI, not this GDD.
- Exact flags written by History Flag System per action — owned by that GDD; this GDD only asserts flags aren't gated, not their content.
- Multi-session/multi-device save sync — out of scope, not addressed by any current GDD.
- Concurrent/near-simultaneous action completion tie-breaking — Action System doesn't currently support concurrent actions (single-concurrency rule), so not applicable, but flagged if that changes.
- The actual developer/QA reset trigger mechanism (debug menu, config flag, save deletion) — undefined, likely belongs to a future tools/debug GDD.

## Open Questions

- **Is a visual/text "hint" needed during Phase 1**, or does relying purely on experience structure (no text) suffice? — Pillar 3 suggests minimalism, but this needs playtest validation. *Owner: `/playtest-report` at Vertical Slice.*
- **Developer/QA data-reset mechanism** (debug menu, config flag, save deletion) — undefined, likely belongs to a future tools/debug GDD. *Owner: future tools GDD. Target: Production.*
- **Multi-session/multi-device save sync** — out of scope, not addressed by any current GDD. *Owner: revise Save/Persistence System if cloud save enters scope. Target: TBD.*
