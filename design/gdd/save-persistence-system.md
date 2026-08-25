# Save/Persistence System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 4 — Offline jest pierwszą klasą obywatelską

## Overview

Save/Persistence System to warstwa serializacji odpowiedzialna za zapisanie i odtworzenie pełnego stanu gry między sesjami: 5 zasobów z Resource System, milestone flags i pattern counters z History Flag System, oraz stan cooldown/wykluczeń kart z Decision Card System. Zapisuje stan automatycznie po każdym znaczącym zdarzeniu (zakończenie akcji, rozwiązanie karty) i wczytuje go przy starcie aplikacji.

Bez tego systemu Offline Progress System nie ma punktu odniesienia — "ile czasu minęło od ostatniej sesji" wymaga zapisanego timestampu, a "jaki był stan gry" wymaga zapisanej migawki wszystkich zasobów i flag. To jest fundament Pillar 4 ("offline jest pierwszą klasą obywatelską") — bez trwałego zapisu, offline progress jest fikcją.

## Player Fantasy

Gracz nigdy nie myśli o tym systemie — i to jest cel. Jedyny moment, w którym ten system "istnieje" dla gracza, to brak frustracji: gra wraca dokładnie tak, jak ją zostawił, a po powrocie czeka czytelny raport tego, co się wydarzyło offline. To zaufanie ("moje postępy są bezpieczne") jest fundamentem, na którym stoi cała obietnica idle gry — żaden inny system nie działa, jeśli ten zawiedzie.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents (systems-designer, gameplay-programmer) not consulted — Lean mode. Review manually before production.*

### Core Rules

**Save schema (single JSON file):**

```yaml
save_file:
  schema_version: int            # for future migrations
  last_saved_at: timestamp       # needed by Offline Progress System to compute Δt
  resources:                     # snapshot from Resource System
    zasiegi: int
    cringe: int
    hatersi: int
    morale: float
    sponsorzy: int
  history_flags:                 # from History Flag System
    milestones: Dict[string, bool]      # only milestones set to true
    counters: Dict[string, int]         # counter name -> value
  decision_card_state:           # from Decision Card System
    cooldown_actions_remaining: int
    resolved_milestone_cards: List[string]  # card IDs whose milestone is already set
```

**Rules:**
1. Saving is **autosave** — triggered after every significant event: action completion (Action System `resolved`) and card resolution (Decision Card System `resolving`→`cooldown`). No manual "Save" button for the player (consistent with "the player never thinks about this system").
2. Saving is a **full snapshot**, not a differential patch — simpler and less error-prone at this game's small data scale (5 resources + a handful of flags/counters).
3. Loading happens **once, at app start** — if no file exists (first session), all systems initialize to defaults (Zasięgi=0, Cringe=0, etc. — per Resource System's Edge Cases "fully fair starting state").
4. `last_saved_at` is stored as a Unix timestamp (seconds) — consumed directly by Offline Progress System to compute `Δt`.
5. **Mobile lifecycle flush**: if a debounced save is pending (timer running, not yet fired) when the OS signals the app is going to background/being suspended, the save fires immediately, bypassing the remaining debounce window — never lose progress to a backgrounding event, which is routine on mobile (app switching, incoming calls, lock screen).
6. **Maximum dirty age (2026-08-05):** the first unsaved mutation starts a
   separate 10-second one-shot deadline. Further mutations restart only the
   two-second trailing debounce. Whichever schedule saves first cancels both,
   so continuous one-second live-resource ticks cannot starve persistence or
   cause a duplicate write.

### States and Transitions

| State | Description | Transition |
|---|---|---|
| `uninitialized` | App just started, file not loaded | → `loading` immediately |
| `loading` | Reading the file (or initializing defaults if none exists) | → `ready` on completion |
| `ready` | Game state available, all systems populated | → `saving` after a significant event |
| `saving` | Writing the snapshot to file | → `ready` immediately after write |

### Interactions with Other Systems

- **Resource System** (hard, read on save, write on load) → reads the 5 resource values to save; overwrites them with loaded values on load
- **History Flag System** (hard, read on save, write on load) → reads milestones/counters; restores them on load
- **Decision Card System** (hard, read on save, write on load) → reads cooldown and excluded cards; restores state on load
- **Offline Progress System** (downstream, undesigned) → reads `last_saved_at` at startup to compute `Δt` from last save to now

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

No formulas required. This system has no probability, curve, or balance math — its complexity lives in save schema, state transitions, and write timing policy (see Detailed Design and Tuning Knobs). Its numeric timing parameters are `save_debounce_interval_sec` and `max_dirty_age_sec`.

## Edge Cases

> *Specialist not consulted — Lean mode (section is not D/H).*

- **If two save-triggering events (action + card) fall within the debounce window (2s)**: saves are coalesced into one, trailing-edge — the latest state is always written, never lost, simply not written twice.
- **If the save file doesn't exist** (first session): all systems initialize to defaults — not an error, the expected starting state.
- **If the save file is corrupted/unparseable as JSON**: treated as "file doesn't exist" — initialize to defaults, the player loses progress, but the game doesn't crash. *(Flagged as an acceptable risk for MVP — full recovery/backup is out of scope.)*
- **If the app is closed mid-`saving`**: risk of a partial/corrupted file. Mitigation: write to a temp file, then atomically rename to the target file — a partial write never overwrites the previous, complete file.
- **If `schema_version` in the file differs from what the current game version expects**: for MVP — no migration logic; treated as "file doesn't exist" (reset). Schema migration is a future Open Question (Alpha+, once the schema actually changes).
- **If the app is backgrounded/suspended by the OS while a debounced save is pending**: the save fires immediately (mobile lifecycle flush, see Core Rules rule 5) — never relies on the debounce timer completing naturally during a backgrounding event.

## Dependencies

**Upstream (this system depends on):** None — Foundation layer (per `systems-index.md`).

**Peer (reads on save, writes on load):**
- **Resource System** (hard) — 5 resource values.
- **History Flag System** (hard) — milestone flags, pattern counters.
- **Decision Card System** (hard) — cooldown state, resolved-milestone card list.

**Downstream (depends on this system):**
- **Offline Progress System** (hard, undesigned) — reads `last_saved_at` to compute `Δt` at startup.
- **Prestige/Checkpoint System** (hard, Alpha, undesigned) — will need its own state included in the save schema once designed.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `save_debounce_interval_sec` | 2 | 1–5 | Too low: defeats the purpose of coalescing near-simultaneous triggers. Too high: reintroduces real data-loss risk if the app is killed mid-session, conflicting with the Player Fantasy goal ("my progress is safe") |
| `max_dirty_age_sec` | 10 | 5–30 | Too low: excessive full-snapshot writes during continuous play. Too high: larger progress-loss window when one-second ambient changes never let the trailing edge settle. |
| `schema_version` | 1 | — | Not a tunable in the traditional sense — increment only when the save schema changes; never decrement |

**Knob interaction:** none — this system's two knobs are independent of each other and of other GDDs' tuning knobs.

## Visual/Audio Requirements

None — pure infrastructure, produces no visual/audio content. Not a required category for Visual/Audio.

## UI Requirements

None — this system has no screen and is never directly surfaced to the player (per Player Fantasy: "the player never thinks about this system").

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

**State transitions:**
- **GIVEN** app launching, no save file exists, **WHEN** initialization completes, **THEN** `uninitialized → loading → ready`, all peer systems report defaults.
- **GIVEN** a valid, schema-matching save file exists, **WHEN** the app starts and loads it, **THEN** `uninitialized → loading → ready`, each peer system's state matches the file.
- **GIVEN** `ready`, **WHEN** an action completes or a card resolves and the debounce window elapses, **THEN** `ready → saving → ready`, no other save can trigger while `saving`.
- **GIVEN** load has already happened once this session, **WHEN** any subsequent save-triggering event occurs, **THEN** the system never re-enters `loading` — only `ready ↔ saving` for the rest of the session.

**Debounce/coalescing mechanism:**
- **GIVEN** `ready` and idle, **WHEN** one trigger fires and nothing else for 2s, **THEN** exactly one save is written.
- **GIVEN** a trigger has fired and the 2s timer is running, **WHEN** a second trigger fires at 1.0s into the window, **THEN** only one save is written, 2s after the *second* (latest) trigger.
- **GIVEN** multiple triggers within one debounce window leave peer systems in different states, **WHEN** the trailing-edge save executes, **THEN** the written file reflects the state at the *last* trigger, not an earlier one.
- **GIVEN** the debounce timer is at 1.9s, **WHEN** a new trigger fires at that moment, **THEN** the timer resets to 0, save fires 2 full seconds after this newest event.
- **GIVEN** `ready` with no triggers, **WHEN** any amount of time passes, **THEN** no write occurs, state remains `ready`.
- **GIVEN** mutations continue at least once per second, **WHEN** the trailing
  debounce keeps restarting, **THEN** exactly one save fires no later than 10
  seconds after the first dirty event and cancels the pending trailing write.

**Save/load round-trip correctness:**
- **GIVEN** a specific resource snapshot, **WHEN** saved then reloaded after restart, **THEN** values match exactly.
- **GIVEN** specific milestone flags/counters, **WHEN** saved then reloaded, **THEN** they match exactly.
- **GIVEN** specific cooldown state, **WHEN** saved then reloaded, **THEN** it matches exactly.
- **GIVEN** a specific `resolved_milestone_cards` list, **WHEN** saved then reloaded, **THEN** same members, no duplication, no loss.
- **GIVEN** a save already exists, **WHEN** a second save is triggered after further changes, **THEN** the new file is a complete, independent snapshot — loading it never references the prior file.
- **GIVEN** any save write, **WHEN** the file is inspected, **THEN** it contains a correct `schema_version` and a `last_saved_at` matching that write's time.

**Defined edge cases:**
- **GIVEN** no save file exists, **WHEN** the app starts, **THEN** defaults initialize, `ready` reached, no error surfaced.
- **GIVEN** a corrupted/unparseable save file, **WHEN** load is attempted, **THEN** falls back to defaults, `ready` reached, no crash/error shown.
- **GIVEN** a save write in progress (`saving`, temp-file step), **WHEN** the app is killed before atomic rename, **THEN** the previously complete save loads intact on next launch — no partial data.
- **GIVEN** a save write completes its rename step, **WHEN** inspected, **THEN** the file reflects the full new snapshot, no remnant of the previous save.
- **GIVEN** a `schema_version` mismatch in an otherwise valid file, **WHEN** load is attempted, **THEN** discarded, defaults initialize, `ready` reached, no partial migration attempted.
- **GIVEN** a completed save operation, **WHEN** the app restarts, **THEN** only the final renamed file is read — any stray temp file from an interrupted prior operation is never loaded.
- **GIVEN** either save Timer is pending, **WHEN** the OS signals backgrounding/suspension, **THEN** the save fires immediately and cancels both schedules.

**Not testable against this GDD alone:**
- Offline progress reconciliation (what happens between `last_saved_at` and next load) — depends on undesigned Offline Progress System.
- Prestige/Checkpoint reset behavior on the save schema — depends on undesigned Prestige/Checkpoint System.
- Schema migration logic — explicitly out of scope for MVP; AC for the mismatch case (treat-as-missing) is a placeholder, will need superseding once migration is designed.
- Concurrent/multi-instance write protection (e.g., split-screen tablets) — no locking/ownership rule defined yet.
- Storage-full write failure — distinct from "missing file"/"corrupted file," not yet designed.

## Open Questions

- **Multiple publishing platforms** (TikTok/YouTube/Twitter-style separate content channels) — not planned in `systems-index.md`; could become a new card type or a separate channel-selection system. *Owner: future `/map-systems` pass / `/brainstorm`. Target: after `/vertical-slice`.*
- **Fan events / meet-and-greets** — similarly not planned; could become a new card type or a standalone event system. *Owner: future `/map-systems` pass. Target: after `/vertical-slice`.*
- **Concurrent/multi-instance write protection** (e.g., split-screen tablets) — no locking/ownership rule defined. *Owner: revise this GDD or `/architecture-decision`. Target: before `/create-architecture`.*
- **Storage-full write failure** — distinct from "missing file"/"corrupted file," not yet designed. *Owner: revise this GDD. Target: before Production.*
- **Schema migration logic** — explicitly out of scope for MVP; the `schema_version` mismatch AC (treat as missing file) is a placeholder to be superseded. *Owner: revisit at Alpha, once the schema actually changes.*
