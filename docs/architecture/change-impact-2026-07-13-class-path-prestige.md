# Design Change Impact Report

**Trigger**: `design/gdd/class-path-system.md` and `design/gdd/prestige-checkpoint-system.md` full GDD authoring + independent `/design-review` (2 rounds on the Prestige GDD, 1 round on Class Path).
**Date**: 2026-07-13

## Change Summary

Both GDDs went from quick-spec-only to full 8-section GDDs, with substantive `/design-review` revisions on both (Class Path: MAJOR REVISION resolved; Prestige/Checkpoint: NEEDS REVISION resolved across 2 rounds). See each GDD's own Revision Log / commit history for the full list of design changes. This report covers architecture-level impact only.

## ADRs Referencing the Changed GDDs

Loaded all ADRs in `docs/architecture/`. 3 reference Class Path System: ADR-0003, ADR-0007, ADR-0010. 0 directly reference Prestige/Checkpoint System (new system, no prior ADR existed).

## Impact Analysis

### ADR-0010: Class Path System — Autoload, Signal Contract, and Multiplier Application
**Status**: ✅ Still Valid, with an additive extension applied

Verified against shipped code (`src/core/class_path_system.gd`, `src/core/card_content_database.gd`, `src/core/decision_card_system.gd`) — every decision in ADR-0010 (Autoload registration, `card_resolved` signal, `path_tag` schema field, `get_active_multiplier()` pull model, `restore_state()`) matches what's actually implemented. No contradiction from either GDD revision.

**Gap found while writing Prestige/Checkpoint's F3b** (not a GDD contradiction — a genuinely new requirement): Class Path's Sponsor-tier bonuses (`guru_celebryta`/`biznesmen_contentu` T1) have no resolution hook, since Sponsors are granted at Decision Card resolution, not via `ActionSystem`'s `action_id`-keyed path ADR-0010 §5 already covers.

**Resolution**: Updated in place (user decision — additive extension, same pattern as the ADR's own precedent for `card_resolved`). Added §5a (`get_active_sponsor_multiplier()`, same pull-model shape as §5) and the corresponding Key Interfaces entry.

### ADR-0002: Save File Format and Atomic Write
**Status**: ✅ Still Valid, with an additive extension applied

The atomic-write mechanism (`save_now()`, temp-file-rename swap) is unaffected by either GDD. **Gap found**: Prestige/Checkpoint System's era-transition atomicity contract (found during `/design-review`'s second round — a real race condition) requires the existing card-resolution autosave trigger to be suppressible during the transition window, but no such capability exists.

**Resolution**: Updated in place. Added an "Autosave suppression window" section defining `suppress_autosave()`/`resume_autosave()`, their interaction with the existing debounce timer, and a paired-call contract (no `await` between suppress/resume — mirrors Prestige/Checkpoint's own call-contract lock for `reset_era_state()`).

### False alarm — corrected, not an ADR issue

`class-path-system.md`'s Open Questions (written during its own `/design-review`) flagged a "BLOCKING counter-name collision with History Flag System" — claimed `path_tag` didn't exist and counters were still on a 2-path `risky_choices_count`/`safe_choices_count` scheme. **Verified against shipped code and found incorrect**: `path_tag` already exists on every card, and `class_path_system.gd` already reads the correct `{path_id}_choices_count` 4-path-ready naming. The `risky_choices_count`/`safe_choices_count` scheme does exist, but it's dead code — `HistoryFlagManager.resolve_path_eligibility()` uses it and nothing in production calls that function (grep confirms only its own unit test file references it).

**Real gap, corrected description**: only 6 cards are tagged `pato_streamer` and 2 `guru_celebryta` in `card_content_database.gd` — zero cards exist for `ekspert_niszowy`/`biznesmen_contentu`. This is a content-authoring gap (narrative-director/writer task: tag or write cards for the other two paths), not an architecture or schema blocker. No ADR change needed for this item.

Both GDDs' Open Questions sections corrected to reflect this (2026-07-13 commit).

## Resolution Summary

| Item | Status | Action Taken |
|---|---|---|
| ADR-0010 sponsor-multiplier gap | Needs Review → Resolved | Updated in place, §5a added |
| ADR-0002 autosave suppression gap | Needs Review → Resolved | Updated in place, new section added |
| Counter-naming "collision" | False alarm | Corrected in both GDDs' Open Questions |
| `best_tier_reached`/`eras_spent_as` cross-doc contradiction | Already resolved (prior commit, 2026-07-13) | `class-path-system.md` Dependencies corrected |

**No ADRs marked Superseded.** No new ADRs required — both gaps were legitimately additive extensions to existing Accepted decisions, following the same precedent those ADRs themselves already established for additive signal/API growth.

## Follow-Up

Both GDDs' implementation-blocking prerequisites are now cleared. Remaining non-blocking items (tracked in each GDD's own Open Questions, not architecture-level):
- Card-content coverage for `ekspert_niszowy`/`biznesmen_contentu` (narrative-director)
- Per-path investment economic normalization (economy-designer, before Alpha)
- Joint META_BONUS pacing tuning pass (economy-designer, before Alpha)
- Meta-bonus visibility UI + Wypalenie card interaction pattern (`/ux-design`, blocking for implementation stories per Prestige/Checkpoint's UI Requirements)

Next: `/create-epics` for both systems, then `/create-stories` per epic.
