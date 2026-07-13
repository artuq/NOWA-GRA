# BUG-003: ClassPathSystem has no tie-break logic — active path resolved by silent dictionary iteration order

**Severity**: S3 — Minor (incorrect-but-plausible behavior, no crash/data loss) | **Status**: FIXED 2026-07-13 (`production/epics/class-path-full/story-003-tiebreak-resolution-bug003.md`, ADR-0010 §9) | **Found**: 2026-07-12 (during Class Path System GDD authoring, `systems-designer` formula review) | **Existed since**: Sprint 8 (ClassPathSystem MVP implementation)

## Repro (current behavior)
1. Two paths both reach Tier 1+ with equal or near-equal affiliation (achievable via card contributions alone in the 2-path MVP)
2. `_update_active_path()` in `src/core/class_path_system.gd` uses a strict `a > best_affil` comparison with no margin/ambiguous-state handling
3. **Actual**: on an exact or near tie, the first path encountered in dictionary iteration order silently wins active-path status and its multiplier applies — no "Ambiguous — keep investing to commit" UI state is ever triggered, contradicting the now-formalized spec.

## Root cause
`class_path_system.gd`'s MVP implementation predates the formalized tie-break rule (Formula F5, `design/gdd/class-path-system.md`). No `PATH_AFFILIATION_TIE_BREAK_MARGIN` constant or ambiguous-state branch exists in the shipped code.

## Fix (done, 2026-07-13)
`_update_active_path()` now computes the top-2 affiliations among Tier-1+ paths via a shared `_compute_top_two_tier1plus()` helper, compares their gap against `PATH_AFFILIATION_TIE_BREAK_MARGIN` (5.0), and resolves to `&""` (ambiguous) when the gap is under the margin. New `get_ambiguous_gap()` query added for the future UI consumer. 21 regression tests in `tests/unit/class-path/class_path_tiebreak_test.gd`, including the exact repro case from this bug report. UI "Ambiguous" state (Class Path Panel) is Story 005 in the same epic, not yet implemented.

## Prevention
Flag for the Vertical Slice Class Path story that implements the full 4-path + tie-break logic (per `class-path-system.md`'s Alpha vs MVP scope split) — this is expected scope for that story, not a regression to chase down separately.
