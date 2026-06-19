# History Flag System

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 2 — Decyzje mają pamięć, nie punkty

## Overview

History Flag System to warstwa danych zapisująca każdą znaczącą decyzję gracza jako trwałą flagę (boolean lub licznik) w persystentnym rejestrze historii. To nie jest jeden licznik "moralności" — to zbiór dyskretnych faktów ("gracz wybrał kartę X", "gracz odmówił sponsorowi Y trzy razy"), które inne systemy (Decision Card System, Class Path System) odczytują, by warunkowo odblokowywać treść i ścieżki. Dla gracza to bezpośrednio odczuwalna pamięć: świat reaguje na konkretne wybory z przeszłości, nie na abstrakcyjny wynik — to jest Pillar 2 w praktyce ("decyzje mają pamięć, nie punkty").

Bez tego systemu Decision Card System nie ma czego odpytywać przy doborze kart, a Class Path System nie ma podstawy do rozstrzygania ścieżek klas — to drugi fundament po Resource System.

## Player Fantasy

Gracz nigdy nie widzi surowej listy flag jako interfejsu — ale czuje ich efekt bardzo bezpośrednio: karta decyzji, którą widzi za tydzień, wspomina jego wcześniejszy wybór; ścieżka klasy, którą odblokowuje, jest konsekwencją konkretnego wzorca zachowań, nie przypadkiem. To daje poczucie "świat mnie pamięta i traktuje serio moje wybory" — przeciwieństwo płaskiego licznika moralności, który tylko rośnie lub spada bez kontekstu. Satyrycznie: gracz zaczyna rozpoznawać własny wzorzec ("zawsze wybierałem dramę") dokładnie wtedy, gdy gra mu go odbija w treści — to jest mechanika, nie wykład (Pillar 3), zbudowana na fundamencie tego systemu.

> *`creative-director` not consulted — Lean mode. Review manually before production.*

## Detailed Design

> *Specialist agents (game-designer, narrative-director) not consulted — Lean mode. Review manually before production.*

### Core Rules

**Two flag types:**

1. **Milestone Flags** (boolean, one-time, immutable once set) — e.g. `card.exposed_friend.chosen`, `card.first_apology.chosen`. Once set to `true`, never reverts to `false` — history is immutable (Pillar 2: decisions cannot be undone).
2. **Pattern Counters** (integer, monotonically increasing, never decremented) — e.g. `risky_choices_count`, `safe_choices_count`, `sponsor_betrayals_count`. Grow on events, never shrink — a record of behavioral pattern over time, not current state (unlike Resource System's continuous resources).

**API (contract for other systems):**
- `set_milestone(name)` — sets a milestone flag to `true`; no-op if already set (idempotent)
- `has_milestone(name) → bool` — read
- `increment_counter(name, amount=1)` — increases a counter; `amount` must be ≥0 (this system never decreases a counter)
- `get_counter(name) → int`
- `counter_above_threshold(name, threshold) → bool` — convenience query for systems gating content/paths by thresholds. **Inclusive boundary**: returns `true` when `get_counter(name) >= threshold` (matches the Path Resolution Algorithm's own `>=` filter below) — despite the name, this is "at or above," not strictly greater-than.

**Path Resolution Algorithm (resolves the bottleneck flagged in `systems-index.md`, generalized per `systems-designer` review to scale past the current 2 paths into Vertical Slice/Alpha's 4+):**

```
function resolve_path_eligibility(counters: Dict[String, int]) -> String?:
    registered_paths = [
        { path: "Pato-Streamer Hazardowy", counter: "risky_choices_count", threshold_min: 5 },
        { path: "Guru-Celebryta", counter: "safe_choices_count", threshold_min: 5 },
        # future paths (Vertical Slice/Alpha) register here: { path, counter, threshold_min }
    ]
    margin = 2  # tuning knob

    eligible = [p for p in registered_paths if counters[p.counter] >= p.threshold_min]
    if eligible.is_empty(): return null

    sorted_by_counter_desc = eligible.sort_by(p => counters[p.counter], descending)
    highest = sorted_by_counter_desc[0]
    if sorted_by_counter_desc.length == 1: return highest.path

    second = sorted_by_counter_desc[1]
    if counters[highest.counter] - counters[second.counter] >= margin:
        return highest.path
    else:
        return null  # tie — no eligibility yet, ambiguous pattern
```

**Worked example:** `risky_choices_count=6, safe_choices_count=1` → only "Pato-Streamer Hazardowy" eligible (≥5 threshold met) → returns it. `risky_choices_count=6, safe_choices_count=5` → both eligible, but margin (6-5=1) < 2 → returns `null` (ambiguous, no path yet).

This is a **query layer** — History Flag System only answers questions about counters/milestones via this algorithm. *Deciding when and how to permanently commit a class path* (e.g., calling this function and acting on a non-null result) belongs to Class Path System, not this GDD. New paths only need to register `{path, counter, threshold_min}` — the algorithm itself never changes.

### States and Transitions

| Flag Type | Initial State | Transitions |
|---|---|---|
| Milestone Flag | `unset` | `unset → set` (one-way, never `set → unset`) |
| Pattern Counter | `0` | `N → N+k` for k≥0 (monotonically increasing, never decreases) |

### Interactions with Other Systems

- **Decision Card System** (downstream, hard) → writes milestone flags when specific cards resolve ("has this card appeared before"); writes pattern counters on every decision (risky/safe); reads both types to weight the card pool
- **Class Path System** (downstream, hard) → reads pattern counters via `counter_above_threshold()` to resolve path eligibility per the table above
- **Resource System** (peer, no direct interaction) → Cringe is a continuous resource in Resource System, NOT a flag; pattern counters record discrete choices (decisions), not resource levels — these two systems are deliberately separated

## Formulas

> *Specialist consulted: `systems-designer` — Section D is HIGH-risk, consulted even in Lean mode.*

This system has no continuous formulas — unlike Resource System (rates, decay curves), History Flag System performs only integer comparisons and boolean lookups. All numeric/logical rules are captured in the **Path Resolution Algorithm** (under Detailed Design → Core Rules) and in **Edge Cases** below. No variable tables or output ranges apply here.

## Edge Cases

> *Specialist consulted: `systems-designer` (combined with Formulas review).*

- **If a counter would overflow**: not reachable in practice — GDScript `int` is 64-bit signed, and even 1 increment/second sustained for 10 years yields ≈3×10^8, orders of magnitude below the 64-bit range. No overflow handling needed; explicitly closed, not deferred.
- **If two or more paths are simultaneously eligible and within the tie-break margin**: `resolve_path_eligibility()` returns `null` (no eligibility) rather than picking arbitrarily — ambiguous patterns resolve to "not yet", never a guessed answer. Class Path System must treat `null` as a valid, expected return value.
- **If a counter or milestone is queried before any write has occurred**: counters default to `0`, milestones default to unset/`false` — no special-case handling needed by callers.
- **If a system attempts to decrement a counter or unset a milestone**: rejected at the API level (`increment_counter` requires `amount >= 0`; no `unset_milestone` API exists at all) — history is structurally immutable, not just immutable by convention.
- **If the same milestone is set twice**: idempotent no-op on the second call — no error, no double-counting, no side effect.

## Dependencies

**Upstream (this system depends on):** None — Foundation layer, same tier as Resource System (per `systems-index.md`).

**Downstream (depends on this system):**
- **Decision Card System** (hard) — writes milestone flags when specific cards resolve; writes pattern counters on every decision; reads both types to weight the card pool.
- **Class Path System** (hard) — calls `resolve_path_eligibility()` to determine path eligibility; owns the decision of when/how to permanently commit a path.

## Tuning Knobs

| Knob | Start | Safe Range | What Breaks Outside It |
|---|---|---|---|
| `margin` (tie-break threshold in Path Resolution Algorithm) | 2 | 1–4 | Too low (0-1): paths resolve too easily, ambiguous patterns get assigned anyway. Too high (5+): players rarely resolve to any path, eligibility feels unreachable |
| `threshold_min` per registered path | 5 (both current paths) | 3–10 | Too low: paths unlock almost immediately, no sense of pattern-building. Too high: paths feel unreachable in a normal session |

**Explicit non-knob (by design):** There is **no decay or time-weighting parameter** for Pattern Counters. Per Pillar 2 ("decisions have memory, not points"), counters are permanent and unweighted — do not add a decay/half-life knob without an explicit pillar exception, as it would functionally recreate the moral-meter pattern this system was designed to avoid.

## Visual/Audio Requirements

None — History Flag System produces no visual or audio content directly. Any signal resulting from flag changes (e.g., a class path becoming eligible) is visualized by upstream consuming systems (Decision Card System, Class Path System), not by this system.

## UI Requirements

None — History Flag System has no screen of its own and is not directly consumed by UI. Exposing data to the player (e.g., "you've unlocked a new path") belongs to Class Path System / Decision Card System UI, not this GDD.

## Acceptance Criteria

> *Specialist consulted: `qa-lead` — Section H is HIGH-risk, consulted even in Lean mode.*

- **GIVEN** milestone `"card.exposed_friend.chosen"` has never been set, **WHEN** `set_milestone(...)` is called, **THEN** `has_milestone(...)` returns `true`.
- **GIVEN** a milestone has never been written, **WHEN** `has_milestone(...)` is called, **THEN** it returns `false` (default unset, no error).
- **GIVEN** a milestone already set to `true`, **WHEN** `set_milestone()` is called again, **THEN** state is unchanged, no error, no side effect (idempotent).
- **GIVEN** counter `"risky_choices_count"` never written (defaults to 0), **WHEN** `increment_counter(..., 1)`, **THEN** `get_counter(...)` returns `1`.
- **GIVEN** counter = 3, **WHEN** `increment_counter(..., 4)`, **THEN** counter = 7.
- **GIVEN** counter = 5, **WHEN** `increment_counter(..., 0)`, **THEN** counter remains 5 (no-op).
- **GIVEN** counter = 5, **WHEN** `increment_counter(..., -1)`, **THEN** the call is rejected, counter remains 5 (`amount >= 0` contract).
- **GIVEN** a counter never written, **WHEN** `get_counter(...)`, **THEN** returns `0`.
- **GIVEN** counter = 5, **WHEN** `counter_above_threshold(..., 5)`, **THEN** returns `true` (inclusive boundary, `>=`).
- **GIVEN** counter = 4, **WHEN** `counter_above_threshold(..., 5)`, **THEN** returns `false`.
- **GIVEN** risky=4, safe=2, **WHEN** `resolve_path_eligibility()`, **THEN** returns `null` (zero eligible).
- **GIVEN** risky=6, safe=1, **WHEN** `resolve_path_eligibility()`, **THEN** returns `"Pato-Streamer Hazardowy"` (one eligible).
- **GIVEN** risky=7, safe=5, **WHEN** `resolve_path_eligibility()`, **THEN** returns `"Pato-Streamer Hazardowy"` (margin of 2 exactly met, `>=`).
- **GIVEN** risky=6, safe=5, **WHEN** `resolve_path_eligibility()`, **THEN** returns `null` (margin 1 < 2).
- **GIVEN** risky=5, safe=5, **WHEN** `resolve_path_eligibility()`, **THEN** returns `null` (exact tie).

**Not automatable as runtime tests (static checks, not GIVEN-WHEN-THEN):**
- No API exists to unset a milestone or decrement a counter — verified by code/API-surface review, not a runtime unit test.
- No overflow handling — unreachable in practice (64-bit int); documented as a design acceptance, omitted from the automated suite to avoid false-confidence no-op tests.

**Test suite note:** margin/threshold-dependent criteria should read values from the Tuning Knobs rather than hardcoding them, so future tuning changes don't silently invalidate the test suite.

## Open Questions

- **Should `margin` and `threshold_min` be per-path configurable, or global?** — currently treated as a global `margin` + per-path `threshold_min`; may need revisiting once Class Path System adds 4+ paths. *Owner: Class Path System GDD. Target: before that GDD is approved.*
- **Is a "preview" mechanism needed for the player** (e.g., UI showing "2 more risky choices to unlock this path")? — a UX decision, not owned by this system. *Owner: Class Path System UI / `/ux-design`. Target: before Vertical Slice.*
