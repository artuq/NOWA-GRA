# Quick Design Spec: Milestone-Gated Action Slots

**Type**: Addition
**System**: Action UI + Action System (consumes History Flag System)
**GDD Reference**: `design/gdd/action-ui.md`, `design/gdd/action-system.md`
**Decision Reference**: `design/decisions/ddr-0001-post-mvp-mechanics-pillar-rulings.md` (#3 — STRONG FIT, highest priority)
**Date**: 2026-06-30

## Change Summary

The 3 empty "locked" slots in the Action Grid stop being decoration — they unlock via the
player's **decision history** (`has_milestone()` / `counter_above_threshold()`), not a flat
Reach threshold. Introduces 3 new actions (Collab / Interview / Course) unlocked by past card
choices.

## Motivation

This is the strongest expression of Pillar 2 ("decisions have memory") in the progression
layer, and it fills the explicitly-flagged gap in the Action UI GDD ("`unlock_threshold`
(Reach) — no source of truth exists yet"). It gives 3 organic session goals (meso-loop,
5-15 min) before the Prestige system exists. Both `game-designer` and `creative-director`
ranked it the highest-priority, build-now idea (DDR-0001).

## Design Delta

The Action UI GDD currently says (`design/gdd/action-ui.md`, Formulas → Flagged gap):

> The 3 locked action slots need an `unlock_threshold` (Zasięgi) to display — but no current
> GDD defines which actions exist beyond the initial 3 or their thresholds (only the
> now-superseded v2 prototype has placeholder numbers). This GDD does **not** invent those
> values.

This spec replaces that with: each of the 3 slots unlocks via a **decision-history condition**,
satisfying the DDR-0001 constraint — each slot is unlockable via EITHER a risky-path OR a
safe-path condition, so the deliberately-un-punished "clean path" player
(`resource-system.md` Edge Cases) is never locked out of action-economy growth.

## New Rules / Values

**3 new actions** (appended to `ACTION_DURATIONS` / `ACTION_REWARDS` / `ACTION_DISPLAY_NAMES`
in `src/core/action_system.gd`, following the existing typed-const pattern):

| Slot | action_id | Display name (EN) | Duration | Reach | Cringe | Morale | Reach/s |
|---|---|---|---|---|---|---|---|
| 4 | `nagraj_kolaba` | Record a Collab | 12s | +16 | +8 | -2 | 1.33 |
| 5 | `udziel_wywiadu` | Give an Interview | 15s | +24 | +4 | +3 | 1.60 |
| 6 | `wydaj_kurs` | Launch a Course | 20s | +40 | +18 | -5 | 2.00 |

- All deltas are within Resource System ranges (per-action Cringe -15..+20, Morale ±10).
- **No Sponsors delta** — the Sponsors faucet stays tied to sponsor/brand cards (+ the planned
  network shield, DDR-0001 #6), not to actions.
- Reward is scaled by the Morale multiplier (Resource System Formula C) at resolution, exactly
  like the 3 base actions.
- These pay a higher Reach/s than the base 3 (0.83/1.11/1.5) — appropriate for gated
  progression content; self-balancing because each carries a Cringe cost that feeds the
  Cringe→Haters→Morale chain (slot 6's +18 Cringe is the apex-grift cost).
- **Satirical framing** (Pillar 3): the unlock arc — Collab → Interview → Course — is the
  archetypal influencer monetization escalation, ending in the "sell a course" grift apex
  (highest Reach, highest Cringe). Critique through what the game rewards, no text.

**Unlock conditions (either-path OR — DDR-0001 constraint):**

| Slot | Unlocks when | Mechanism |
|---|---|---|
| 4 (Collab) | `risky_choices_count >= 3` **OR** `safe_choices_count >= 3` | `counter_above_threshold()` — path-agnostic, low threshold, first to open |
| 5 (Interview) | `risky_choices_count >= 6` **OR** `safe_choices_count >= 6` | `counter_above_threshold()` — escalating |
| 6 (Course) | `has_milestone("card.staged_drama.chosen_risky")` **OR** `has_milestone("card.cancel_threat.apologized")` | named moral moments — one risky milestone OR one safe milestone (strongest Pillar 2 flavor; uses the 2 existing milestones, one per path) |

**Unlock evaluation timing**: re-evaluate at session start (`action_grid._ready()`) AND on each
return to `idle` (after an action completes — the only moment, besides card resolution, when the
gating state can change). A slot appears at most one action after its condition becomes true.
Once unlocked, permanent (milestones/counters never decrease).

**Onboarding interaction**: no conflict — OnboardingGate gates *card visibility*, not actions;
counters/milestones only grow once cards appear (phase_normal), so no slot can unlock during
Phase 1 (the 3 base actions remain sufficient for the variety gate, per `onboarding-tutorial.md`
rule 5).

## Affected Systems

| System | Impact | Action Required |
|---|---|---|
| Action System | +3 actions in the reward table | update GDD `action-system.md` + code `action_system.gd` |
| Action UI (action_grid) | static `UNLOCKED_ACTION_IDS` → dynamic unlock evaluation via `HistoryFlagManager` | update GDD `action-ui.md` (close the flagged gap) + code `action_grid.gd` |
| History Flag System | read-only (`has_milestone`, `counter_above_threshold`) | **no change** |
| Card Content Database | uses existing milestones | **no change** |
| Save/Persistence | unlock state derives from already-persisted counters/milestones | **no change** |

## Acceptance Criteria

- [ ] Fresh game (0 decisions): slots 4/5/6 are locked (🔒); only the 3 base actions are playable.
- [ ] `risky_choices_count` reaches 3 (pure risky path, safe=0) → slot 4 unlocks. AND
      `safe_choices_count` reaches 3 (pure safe path, risky=0) → slot 4 also unlocks (either-path).
- [ ] Slot 5 unlocks at `risky_choices_count >= 6` OR `safe_choices_count >= 6`, not before.
- [ ] Slot 6 unlocks via `has_milestone("card.staged_drama.chosen_risky")` alone OR via
      `has_milestone("card.cancel_threat.apologized")` alone.
- [ ] An unlocked slot fires its action with the table's deltas; Reach is Morale-multiplier-scaled
      (Formula C) exactly like the base actions.
- [ ] Unlock state survives save/load (it derives from persisted counters/milestones).
- [ ] A slot unlocked mid-session appears at most one completed action after its condition is met.
- [ ] **No regression**: the 3 base actions, single-concurrency, and all existing Action UI /
      Action Grid interaction tests stay green.

## GDD Update Required?

**Yes — two files** (each requires separate approval before editing):

- `design/gdd/action-system.md` — Reward table: append the 3 actions (Collab/Interview/Course)
  with their deltas, and a note that slots 4-6 are milestone/counter-gated (unlock owned by this
  spec, not the reward table).
- `design/gdd/action-ui.md` — Replace the Formulas "Flagged gap" (the `unlock_threshold` Reach
  placeholder with no source of truth) with the milestone/counter gating rule from this spec, and
  mark Open Question #1 (`unlock_threshold` values) as RESOLVED by this quick spec.

## Pipeline Note

This spec bypasses `/design-review` by design (small, well-scoped Addition on existing systems,
no new cross-system contracts). Next: `/story-readiness` then `/dev-story`, referencing this spec
in the story's GDD Reference field.
