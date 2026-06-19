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

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
