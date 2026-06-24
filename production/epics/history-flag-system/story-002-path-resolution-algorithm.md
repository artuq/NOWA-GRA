# Story 002: Path Resolution Algorithm

> **Epic**: History Flag System
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: S (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/history-flag-system.md`
**Requirement**: `TR-hist-001`
*(No dedicated sub-ID exists for the Path Resolution Algorithm specifically in `docs/architecture/tr-registry.yaml` — it currently only registers the general "flag log plus pattern counters" requirement. This is a registry hygiene gap, flagged by the QL-STORY-READY gate as non-blocking; recommend registering a dedicated `TR-hist-002` via `/architecture-review` at some point. Requirement text for `TR-hist-001` lives in `tr-registry.yaml` — read fresh at review time.)*

**ADR Governing Implementation**: ADR-0001: Autoload singleton vs. event bus
**ADR Decision Summary**: `resolve_path_eligibility()` is a public method on the `HistoryFlagManager` Autoload — a pure query layer with no side effects. It does not call other Autoloads and is not itself an Autoload; it's a method added to the Story 001 singleton.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: No post-cutoff APIs involved — pure comparison/sort logic over integers and a small static array.

**Control Manifest Rules (Foundation layer)**:
- Required: Implement every Core/Foundation module as a Godot Autoload singleton — source: ADR-0001 (already satisfied by Story 001; this story only adds a method to the existing Autoload)
- Forbidden: Never introduce a central `EventBus` autoload — source: ADR-0001 (not applicable here — no signals involved)

---

## Acceptance Criteria

*From GDD `design/gdd/history-flag-system.md` § Acceptance Criteria, scoped to this story:*

- [ ] GIVEN risky=4, safe=2, WHEN `resolve_path_eligibility()`, THEN returns `null` (zero eligible).
- [ ] GIVEN risky=6, safe=1, WHEN `resolve_path_eligibility()`, THEN returns `"Pato-Streamer Hazardowy"` (one eligible).
- [ ] GIVEN risky=7, safe=5, WHEN `resolve_path_eligibility()`, THEN returns `"Pato-Streamer Hazardowy"` (margin of 2 exactly met, `>=`).
- [ ] GIVEN risky=6, safe=5, WHEN `resolve_path_eligibility()`, THEN returns `null` (margin 1 < 2).
- [ ] GIVEN risky=5, safe=5, WHEN `resolve_path_eligibility()`, THEN returns `null` (exact tie).

---

## Implementation Notes

*Derived from GDD Detailed Design § Core Rules (Path Resolution Algorithm), generalized per the GDD's own `systems-designer` review to scale past the current 2 paths:*

```gdscript
# Added to HistoryFlagManager (Story 001's Autoload)

const _REGISTERED_PATHS: Array[Dictionary] = [
    {"path": "Pato-Streamer Hazardowy", "counter": &"risky_choices_count", "threshold_min": 5},
    {"path": "Guru-Celebryta", "counter": &"safe_choices_count", "threshold_min": 5},
    # future paths (Vertical Slice/Alpha) register here: {path, counter, threshold_min}
]
const _MARGIN: int = 2  # tuning knob — see GDD Tuning Knobs table, safe range 1-4

func resolve_path_eligibility() -> Variant:  # returns String path name or null
    var eligible: Array[Dictionary] = []
    for p in _REGISTERED_PATHS:
        if counter_above_threshold(p["counter"], p["threshold_min"]):
            eligible.append(p)
    if eligible.is_empty():
        return null

    eligible.sort_custom(func(a, b): return get_counter(a["counter"]) > get_counter(b["counter"]))
    var highest: Dictionary = eligible[0]
    if eligible.size() == 1:
        return highest["path"]

    var second: Dictionary = eligible[1]
    if get_counter(highest["counter"]) - get_counter(second["counter"]) >= _MARGIN:
        return highest["path"]
    return null  # tie — ambiguous pattern, not yet resolved
```

- **Read `_MARGIN` and each path's `threshold_min` from named constants (Tuning Knobs), never hardcode `2` or `5` inline in the algorithm body or in tests** — this is an explicit GDD test-suite note (see GDD § Formulas / § Acceptance Criteria closing note) so future tuning changes don't silently invalidate the test suite.
- This is a query layer only — `resolve_path_eligibility()` answers a question, it does not commit a path or mutate any state. Deciding when/how to act on a non-null result belongs to the future Class Path System (Vertical Slice tier, not yet built) — do not add commit/mutation logic here.
- Builds directly on Story 001's `counter_above_threshold()` and `get_counter()` — do not duplicate counter-reading logic.
- `null` is a valid, expected return value for ambiguous/no-eligibility cases — never throw, never guess a path on a tie.

---

## Out of Scope

*Handled by neighbouring stories / future epics — do not implement here:*

- Story 001: the underlying `set_milestone`/`has_milestone`/`increment_counter`/`get_counter`/`counter_above_threshold` primitives — this story only adds the algorithm that reads them.
- Class Path System (future epic, Vertical Slice tier, not yet built): deciding when/how to permanently commit a path based on a non-null `resolve_path_eligibility()` result.
- Registering additional paths beyond the current 2 (`Pato-Streamer Hazardowy`, `Guru-Celebryta`) — the algorithm is written to scale, but adding new path entries is content/design work for a later story, not this one.

---

## QA Test Cases

*Sourced from `production/qa/qa-plan-sprint-3-2026-06-24.md` (Automated Tests Required § 3-1), split to this story's scope.*

- **AC-1**: zero eligible paths
  - Given: `risky_choices_count = 4`, `safe_choices_count = 2`
  - When: `resolve_path_eligibility()`
  - Then: returns `null` (neither counter meets its `threshold_min = 5`)
  - Edge cases: both counters below threshold, not just one

- **AC-2**: exactly one eligible path
  - Given: `risky_choices_count = 6`, `safe_choices_count = 1`
  - When: `resolve_path_eligibility()`
  - Then: returns `"Pato-Streamer Hazardowy"`
  - Edge cases: the single-eligible branch must return immediately without needing the margin comparison

- **AC-3**: two eligible, margin exactly met
  - Given: `risky_choices_count = 7`, `safe_choices_count = 5`
  - When: `resolve_path_eligibility()`
  - Then: returns `"Pato-Streamer Hazardowy"` (diff = 2, margin met via `>=`)
  - Edge cases: this is the inclusive boundary case for the margin check — must use `>=`, not `>`

- **AC-4**: two eligible, margin not met
  - Given: `risky_choices_count = 6`, `safe_choices_count = 5`
  - When: `resolve_path_eligibility()`
  - Then: returns `null` (diff = 1, below margin of 2)
  - Edge cases: one short of the margin boundary — pairs with AC-3 to lock the `>=` semantics precisely

- **AC-5**: exact tie
  - Given: `risky_choices_count = 5`, `safe_choices_count = 5`
  - When: `resolve_path_eligibility()`
  - Then: returns `null` (diff = 0)
  - Edge cases: both paths exactly tied at the threshold — must not arbitrarily pick one

**Implementation guidance for the test file**: read `_MARGIN` and `threshold_min` via the Autoload's exposed constants rather than hardcoding `2`/`5` as literals in assertions, per the GDD's test-suite note (see Implementation Notes above).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/history_flag_system/path_resolution_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (HistoryFlagManager Core — Milestone Flags & Pattern Counters) must be DONE; this story reads counters via Story 001's API.
- Unlocks: Class Path System (future epic, Vertical Slice tier) — calls `resolve_path_eligibility()` to determine path eligibility.
