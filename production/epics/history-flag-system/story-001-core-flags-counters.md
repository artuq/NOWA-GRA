# Story 001: HistoryFlagManager Core — Milestone Flags & Pattern Counters

> **Epic**: History Flag System
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/history-flag-system.md`
**Requirement**: `TR-hist-001`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001: Autoload singleton vs. event bus
**ADR Decision Summary**: `HistoryFlagManager` is implemented as a Godot Autoload singleton (Foundation-layer module). Other modules call its API directly (no central event bus). Canonical boot order places `HistoryFlagManager` immediately after `ResourceManager` and before `CardContentDatabase`/`SaveSystem`/`ActionSystem`.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs involved — pure GDScript dictionaries/integers, no engine-version-sensitive behavior.

**Control Manifest Rules (Foundation layer)**:
- Required: Implement every Core/Foundation module as a Godot Autoload singleton — source: ADR-0001
- Required: Register Autoloads in the exact canonical order: `ResourceManager`, `HistoryFlagManager`, `CardContentDatabase`, `SaveSystem`, `ActionSystem`, `OfflineProgressSystem`, `OnboardingGate`, `DecisionCardSystem` — source: ADR-0001
- Forbidden: Never introduce a central `EventBus` autoload — source: ADR-0001

**Implementation note — current boot order is out of sequence**: `project.godot` currently registers `ResourceManager` then `ActionSystem` only. This story must insert `HistoryFlagManager` **between** them (i.e., the new order becomes `ResourceManager`, `HistoryFlagManager`, `ActionSystem`), matching the canonical position even though `CardContentDatabase`/`SaveSystem` don't exist yet — do not append `HistoryFlagManager` after `ActionSystem`.

---

## Acceptance Criteria

*From GDD `design/gdd/history-flag-system.md` § Acceptance Criteria, scoped to this story:*

- [ ] GIVEN milestone `"card.exposed_friend.chosen"` has never been set, WHEN `set_milestone(...)` is called, THEN `has_milestone(...)` returns `true`.
- [ ] GIVEN a milestone has never been written, WHEN `has_milestone(...)` is called, THEN it returns `false` (default unset, no error).
- [ ] GIVEN a milestone already set to `true`, WHEN `set_milestone()` is called again, THEN state is unchanged, no error, no side effect (idempotent).
- [ ] GIVEN counter `"risky_choices_count"` never written (defaults to 0), WHEN `increment_counter(..., 1)`, THEN `get_counter(...)` returns `1`.
- [ ] GIVEN counter = 3, WHEN `increment_counter(..., 4)`, THEN counter = 7.
- [ ] GIVEN counter = 5, WHEN `increment_counter(..., 0)`, THEN counter remains 5 (no-op).
- [ ] GIVEN counter = 5, WHEN `increment_counter(..., -1)`, THEN the call is rejected, counter remains 5 (`amount >= 0` contract).
- [ ] GIVEN a counter never written, WHEN `get_counter(...)`, THEN returns `0`.
- [ ] GIVEN counter = 5, WHEN `counter_above_threshold(..., 5)`, THEN returns `true` (inclusive boundary, `>=`).
- [ ] GIVEN counter = 4, WHEN `counter_above_threshold(..., 5)`, THEN returns `false`.

---

## Implementation Notes

*Derived from ADR-0001 Implementation Guidelines + GDD Detailed Design § Core Rules:*

Implement the `HistoryFlagManager` Autoload with two internal stores and a public API:

```gdscript
extends Node

var _milestones: Dictionary[StringName, bool] = {}
var _counters: Dictionary[StringName, int] = {}

func set_milestone(name: StringName) -> void:
    _milestones[name] = true  # idempotent: setting true on true is a no-op in effect

func has_milestone(name: StringName) -> bool:
    return _milestones.get(name, false)

func increment_counter(name: StringName, amount: int = 1) -> void:
    if amount < 0:
        return  # rejected at the API level — counters never decrease
    _counters[name] = _counters.get(name, 0) + amount

func get_counter(name: StringName) -> int:
    return _counters.get(name, 0)

func counter_above_threshold(name: StringName, threshold: int) -> bool:
    return get_counter(name) >= threshold  # inclusive boundary, despite the name
```

- Milestone Flags are boolean, one-time, immutable once set (`unset → set`, never reverts) — Pillar 2: decisions cannot be undone.
- Pattern Counters are integer, monotonically increasing, never decremented — a record of behavioral pattern over time, distinct from Resource System's continuous resources.
- No `unset_milestone()` API exists at all, by design — do not add one even as a private/internal helper. This is verified by API-surface review, not a runtime test (see GDD's "Not automatable" note).
- `increment_counter`'s `amount >= 0` contract is the only validation this module performs — there is no decrement path, structurally, not just by convention.
- Counter overflow is explicitly out of scope (GDScript `int` is 64-bit signed; not reachable in practice) — do not add overflow-guard code, this is a closed, not deferred, decision per the GDD.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: the Path Resolution Algorithm (`resolve_path_eligibility()`) — this story only provides the counter/milestone primitives it will read.
- Decision Card System (separate epic): writing milestone flags/counters when cards resolve — this story only implements the API those future writes will call.
- Save/Persistence System (separate epic): `restore_state(data)` for `HistoryFlagManager` — out of scope here; this story's state is in-memory only for now.

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-24.md` (Automated Tests Required § 3-1), split to this story's scope.*

- **AC-1**: `set_milestone()` on an unset milestone
  - Given: milestone `"card.exposed_friend.chosen"` never set
  - When: `set_milestone("card.exposed_friend.chosen")`
  - Then: `has_milestone("card.exposed_friend.chosen")` returns `true`
  - Edge cases: milestone name never seen before (no pre-existing key in the dictionary)

- **AC-2**: `has_milestone()` default
  - Given: a milestone never written
  - When: `has_milestone(...)`
  - Then: returns `false`, no error
  - Edge cases: querying immediately after Autoload `_ready()`, before any write

- **AC-3**: `set_milestone()` idempotency
  - Given: a milestone already `true`
  - When: `set_milestone()` called again
  - Then: state unchanged, no error, no side effect
  - Edge cases: call it 2+ times in a row, confirm no toggling or error on the 3rd+ call

- **AC-4**: `increment_counter()` from default
  - Given: counter `"risky_choices_count"` never written (defaults to 0)
  - When: `increment_counter(..., 1)`
  - Then: `get_counter(...)` returns `1`
  - Edge cases: counter name never seen before

- **AC-5**: `increment_counter()` accumulation
  - Given: counter = 3
  - When: `increment_counter(..., 4)`
  - Then: counter = 7
  - Edge cases: multiple sequential increments compound correctly

- **AC-6**: `increment_counter()` zero amount
  - Given: counter = 5
  - When: `increment_counter(..., 0)`
  - Then: counter remains 5 (no-op)
  - Edge cases: confirm no error and no spurious write

- **AC-7**: `increment_counter()` negative amount rejected
  - Given: counter = 5
  - When: `increment_counter(..., -1)`
  - Then: call rejected, counter remains 5
  - Edge cases: confirm the `amount >= 0` contract — this is the one validation this module performs

- **AC-8**: `get_counter()` default
  - Given: a counter never written
  - When: `get_counter(...)`
  - Then: returns `0`
  - Edge cases: querying immediately after Autoload `_ready()`

- **AC-9**: `counter_above_threshold()` inclusive boundary, true case
  - Given: counter = 5
  - When: `counter_above_threshold(..., 5)`
  - Then: returns `true` (inclusive `>=`, despite the method name)
  - Edge cases: exact equality is the boundary being tested, not an approximation

- **AC-10**: `counter_above_threshold()` inclusive boundary, false case
  - Given: counter = 4
  - When: `counter_above_threshold(..., 5)`
  - Then: returns `false`
  - Edge cases: one below threshold is the boundary being tested

**Not automatable as runtime tests** (per GDD, verify via code/API-surface review instead — e.g., `grep -n "unset_milestone\|decrement" src/core/history_flag_manager.gd` returns nothing):
- No API exists to unset a milestone or decrement a counter.
- Counter overflow handling — unreachable in practice (64-bit int); explicitly closed by GDD design, not deferred. Do not write a no-op overflow test.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/history_flag_system/history_flag_manager_core_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (Foundation layer, same tier as Resource System — no story prerequisites)
- Unlocks: Story 002 (Path Resolution Algorithm reads the counters this story provides)

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 10/10 passing (none deferred)
**Deviations**: None
**Test Evidence**: Logic — `tests/unit/history_flag_system/history_flag_manager_core_test.gd`, 10/10 passing (full regression 84/84 passing)
**Code Review**: Complete — `/code-review` APPROVED; LP-CODE-REVIEW gate APPROVE; QL-TEST-COVERAGE gate ADEQUATE
