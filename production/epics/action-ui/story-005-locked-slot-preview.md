# Story 005: Locked Slot Preview

> **Epic**: Action UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-01
> **Completed**: 2026-07-01

## Context

**GDD**: `design/gdd/action-ui.md`
**Quick Spec**: `design/quick-specs/locked-slot-preview-2026-07-01.md`
**Requirement**: Locked slots 4–6 must show visible content and unlock requirements (no dedicated TR-ID — same registry gap as other Action UI stories; reference quick-spec directly)

**ADR Governing Implementation**: ADR-0007 (primary); ADR-0001 (secondary)
**ADR Decision Summary**: ActionGrid is the correct owner of locked-slot rendering. No new cross-zone coupling. No `_process()` in ActionGrid zone — progress bar values read once at `_ready()` and on `action_completed` signal (same existing update hook). Tap handler on locked slot uses a transient label/toast within the slot bounds.

**Engine**: Godot 4.6.3 | **Risk**: LOW (no post-cutoff APIs — standard Button, Label, ProgressBar nodes)

---

## Acceptance Criteria

- [ ] Fresh game: slots 4–6 are visibly present and show a grayed preview (40–50% alpha content group) with the action name, a lock icon overlay, and an unlock requirement string
- [ ] Slot 4 shows `"Make 3 choices"` with a progress bar displaying `max(risky_choices_count, safe_choices_count) / 3`; bar updates after each card resolution
- [ ] Slot 5 shows `"Make 6 choices"` with a progress bar displaying `max(risky_choices_count, safe_choices_count) / 6`; bar updates after each card resolution
- [ ] Slot 6 shows `"Reach a story moment"` with no numeric progress bar (binary gate)
- [ ] Tapping slot 4 while locked shows a toast: `"Make [N] more choices to unlock"` (correct N = `3 - max(risky, safe)`), auto-dismisses ~2s
- [ ] Tapping slot 5 while locked shows a toast: `"Make [N] more choices to unlock"` (correct N = `6 - max(risky, safe)`), auto-dismisses ~2s
- [ ] Tapping slot 6 while locked shows a toast: `"Unlock by reaching a key story moment"`, auto-dismisses ~2s
- [ ] When an unlock condition is satisfied, the slot transitions to active state with a visible animation (lock overlay + unlock label removed, content fades to full opacity)
- [ ] The 3 base action slots (1–3) are visually and functionally unchanged — no regression
- [ ] All text in locked-slot UI is English
- [ ] Locked slot touch target remains ≥ 48×48 dp (ADR-0007 requirement)

## Implementation Notes

*From quick-spec `locked-slot-preview-2026-07-01.md` and ADR-0007:*

**`src/ui/action_grid.gd`** — primary change file:
- Add a locked-slot rendering state: content group at 40–50% modulate alpha, lock icon overlay at full alpha
- Connect tap handler on locked slots (currently `disabled = true` — switch to enabled but handle in `_pressed()` with a locked-branch that shows toast instead of calling `ActionSystem`)
- On `action_completed` signal (already connected): re-query `action_unlocks.gd` for progress values and update progress bars

**`src/ui/action_unlocks.gd`** — minor extension:
- Expose `get_choice_progress(slot_index) -> Dictionary` returning `{current: int, required: int}` for slots 4/5
- Expose `is_milestone_gated(slot_index) -> bool` for slot 6

**No new Autoloads, no new scenes.** The toast can be a transient `Label` instantiated inside the slot's Control bounds and freed after 2s via a `get_tree().create_timer(2.0).timeout` connection.

**ADR-0007 constraint**: No `_process()`. Progress bar updates happen only on `action_completed` and at `_ready()` — not per-frame polling.

## Out of Scope

- Animated unlock celebration (beyond a simple fade-in — defer to Juice/Feedback System)
- Class Path affiliation bars (separate system, separate story)
- Any changes to the 3 base action slots

## QA Test Cases

**AC-1 — Fresh game locked slot appearance:**
- Given: fresh game state (0 risky/safe choices, no story milestones)
- When: main screen renders
- Then: slots 4/5/6 show action names at ~50% alpha, lock icon, unlock string; slots 1/2/3 unchanged

**AC-2 — Progress bar updates:**
- Given: slot 4 locked, risky_choices_count=1, safe_choices_count=2
- When: action_grid renders after a card resolution
- Then: slot 4 bar shows 2/3 (max of 1,2 = 2)

**AC-3 — Tap toast slot 4:**
- Given: slot 4 locked, max(risky,safe) = 1
- When: player taps slot 4
- Then: toast reads "Make 2 more choices to unlock"; disappears after ~2s; no action started

**AC-4 — Tap toast slot 6:**
- Given: slot 6 locked
- When: player taps slot 6
- Then: toast reads "Unlock by reaching a key story moment"; base slots unaffected

**AC-5 — Unlock transition:**
- Given: slot 4 locked, max(risky,safe) = 2
- When: card resolves pushing max to 3
- Then: slot 4 animates to active (lock removed, content fades to full opacity); slot is now tappable

**AC-6 — No regression:**
- Given: all 3 base slots active
- When: any action completes
- Then: base slot behavior identical to pre-story (re-enabled, no visual change)

## Test Evidence

**Story Type**: UI
**Required evidence**: Manual walkthrough OR interaction test in `production/qa/evidence/story-005-locked-slot-preview-evidence.md`
**Status**: [ ] Not yet created

## Dependencies

- Depends on: Story 003 (Action Grid — Complete), milestone-gated action slots (DDR-0001 #3 — Complete)
- Unlocks: nothing blocked by this story

## Completion Notes
**Completed**: 2026-07-01
**Criteria**: 4/11 auto-verified from code; 7/11 deferred to manual playtest (require game launch)
**Deviations**:
- ADVISORY: ADR-0007 originally specified `disabled=true` for locked slots; Story 005 changes to `disabled=false` + locked tap handler. Safety guarantee identical (no `start_action()` call). Logged to tech-debt-register.md.
- ADVISORY: Toast implemented as `PRESET_FULL_RECT` Label child of Button (not CanvasLayer overlay). Functional for 2s ephemeral use; upgrade path to Juice/Feedback System. Logged to tech-debt-register.md.
**Test Evidence**: ADVISORY — manual walkthrough doc required at `production/qa/evidence/story-005-locked-slot-preview-evidence.md` before sprint QA sign-off
**Code Review**: Complete (2026-07-01) — 2 fixes applied inline (as VBoxContainer cast; PRESET_FULL_RECT toast anchor)
