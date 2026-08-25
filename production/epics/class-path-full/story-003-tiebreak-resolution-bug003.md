# Story 003: Tie-Break Resolution Fix (F5, BUG-003)

> **Epic**: Class Path System (Full)
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: S (1-2h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-13

## Context

**GDD**: `design/gdd/class-path-system.md`
**Requirement**: `TR-cps-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0010 §9 (Tie-Break Resolution)
**ADR Decision Summary**: Shipped `_update_active_path()` uses a strict `>` comparison with no margin check — two paths within `PATH_AFFILIATION_TIE_BREAK_MARGIN` silently resolve to whichever iterates first, instead of GDD F5's "ambiguous" state. Fix: track top-two candidates and compare their gap.

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: None post-cutoff.

**Control Manifest Rules (this layer)**:
- Required: n/a
- Forbidden: n/a
- Guardrail: n/a

---

## Acceptance Criteria

*From GDD `design/gdd/class-path-system.md`, scoped to this story — regression coverage for BUG-003:*

- [ ] GIVEN `pato_streamer` at Tier 2, affiliation `45.0`, and `guru_celebryta` at Tier 2, affiliation `42.0` (diff `3.0 < M(5.0)`), WHEN active path is recomputed, THEN `get_active_path()` returns empty ("ambiguous") — NOT `pato_streamer`. *This is the exact case BUG-003 documents: shipped code's strict `a > best_affil` comparison currently returns `pato_streamer` here.*
- [ ] GIVEN the same two paths but `guru_celebryta = 38.0` (diff `7.0 ≥ M`), THEN `get_active_path()` returns `pato_streamer`
- [ ] GIVEN two paths at Tier 1+ with exactly equal affiliation (diff `= 0.0`), THEN `get_active_path()` returns empty — exact ties always fall into "ambiguous," regardless of `M`
- [ ] GIVEN the system is in an ambiguous state, WHEN `get_active_multiplier(action_id)` is called for either tied path's action, THEN it returns `1.0` for both — guards against a partial fix where `get_active_path()` returns empty but `get_active_multiplier` still reads a stale internal `_active_path`
- [ ] GIVEN three or more paths are simultaneously at Tier 1+, WHEN active path is resolved, THEN only the top two affiliations determine ambiguity — a third, lower-affiliation Tier-1+ path never affects the result
- [ ] GIVEN an ambiguous state resolves because further investment breaks the tie, WHEN the gap crosses the margin threshold, THEN `active_path_changed` fires exactly once with the newly-resolved path_id
- [ ] GIVEN no path has ever reached Tier 1, THEN `get_active_path()` returns empty and `get_active_multiplier(action_id)` returns `1.0` for every action_id
- [ ] GIVEN `pato_streamer` is the resolved active path (Tier 2, no ambiguity) and `ekspert_niszowy` is also at Tier 1 but not tied (diff ≥ M), WHEN `get_active_multiplier` is queried for an `ekspert_niszowy`-tier-bonus action, THEN it returns `1.0` — secondary paths never stack (Core Rule 6)

---

## Implementation Notes

*Derived from ADR-0010 §9:*

```gdscript
func _update_active_path() -> void:
    var best_path: StringName = &""
    var best_affil: float = -1.0
    var second_affil: float = -1.0
    for path_id: StringName in _affiliation:
        if _current_tier.get(path_id, 0) >= 1:
            var a: float = _affiliation[path_id]
            if a > best_affil:
                second_affil = best_affil
                best_affil = a
                best_path = path_id
            elif a > second_affil:
                second_affil = a
    var resolved: StringName = best_path
    if second_affil >= 0.0 and (best_affil - second_affil) < PATH_AFFILIATION_TIE_BREAK_MARGIN:
        resolved = &""  # ambiguous — GDD F5
    if resolved != _active_path:
        _active_path = resolved
        active_path_changed.emit(_active_path)
```

`PATH_AFFILIATION_TIE_BREAK_MARGIN` (5.0 default) stays a GDScript `const`, matching `CARD_AFFILIATION_PER_CHOICE`/`CARD_CONTRIBUTION_MAX`'s placement — not `balance.json`. Also add `get_ambiguous_gap() -> float` (returns `best_affil - second_affil` when ambiguous, `-1.0` otherwise — ADR-0010 Key Interfaces) for Story 005's UI to consume.

**Performance**: no impact — `_update_active_path()` stays O(n paths) (n=4), same call sites (card resolution, `invest()`) as before; tracking a second candidate is one extra float comparison per path, negligible at this scale.

**Behavioural change note**: `active_path_changed("")` can now fire in a case it never did before (any two paths landing within the margin after previously having a resolved winner) — intentional per F5, already covered by GDD UI Requirements' Ambiguous state.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: UI rendering of the "Ambiguous — keep investing to commit" state and the numeric gap display

---

## QA Test Cases

**Logic — automated test specs:**

- **AC-1 (BUG-003 exact repro case, now fixed)**:
  - Given: pato_streamer T2/45.0, guru_celebryta T2/42.0
  - When: `_update_active_path()` runs
  - Then: `get_active_path()` returns `""`
  - Edge cases: diff exactly at margin boundary (`= 5.0`, should resolve — margin is `<`, not `<=`)

- **AC-2 (resolved, gap ≥ margin)**:
  - Given: pato_streamer T2/45.0, guru_celebryta T2/38.0
  - When: recomputed
  - Then: returns `pato_streamer`

- **AC-3 (exact tie)**:
  - Given: two paths at identical affiliation, both Tier 1+
  - When: recomputed
  - Then: returns `""`

- **AC-4 (multiplier consistency during ambiguity)**:
  - Given: ambiguous state
  - When: `get_active_multiplier(action_id)` called for either tied path
  - Then: returns `1.0` for both — no stale `_active_path` leak

- **AC-5 (3+ paths, only top-two matter)**:
  - Given: 3 paths at Tier 1+, third path far below the top two
  - When: recomputed
  - Then: third path's affiliation has zero effect on ambiguity resolution

- **AC-6 (signal fires exactly once on tie-break resolution)**:
  - Given: ambiguous state
  - When: investment breaks the tie past the margin
  - Then: `active_path_changed` fires exactly once with the new path_id

- **AC-7 (baseline unaffiliated)**:
  - Given: no path ever reached Tier 1
  - Then: `get_active_path() == ""`, `get_active_multiplier()` returns 1.0 for any action_id

- **AC-8 (secondary paths never stack)**:
  - Given: pato_streamer active (resolved, no ambiguity), ekspert_niszowy also T1 but not tied
  - When: `get_active_multiplier` queried for an ekspert_niszowy-tier action
  - Then: returns `1.0`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/class-path/class_path_tiebreak_test.gd` — must exist and pass; closes `production/qa/bugs/BUG-003-class-path-no-tiebreak-logic.md`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (not a hard blocker — fix applies regardless of path count — sequencing after 001 lets AC-5's "3+ paths" case use real registered paths instead of a mock)
- Unlocks: Story 005 (UI needs `get_ambiguous_gap()` to exist)

## Completion Notes
**Completed**: 2026-07-13
**Criteria**: 8/8 passing
**Deviations**: ADVISORY — `_ambiguous_gap` reset in `reset_era_state()`, shared `_compute_top_two_tier1plus()` helper. A BLOCKING `restore_state()` gap-recompute bug was found and fixed during code review — not a remaining deviation.
**Test Evidence**: Logic — `tests/unit/class-path/class_path_tiebreak_test.gd` (21 tests, all passing)
**Code Review**: Complete — APPROVED
