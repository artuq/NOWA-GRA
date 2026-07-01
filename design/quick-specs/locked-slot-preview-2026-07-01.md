# Quick Design Spec: Locked Slot Preview (Visible Content + Unlock Requirement)

**Type**: Addition
**System**: Action Grid / Action Unlocks UI
**GDD Reference**: `design/gdd/action-ui.md`
**Related Spec**: `design/quick-specs/milestone-gated-action-slots-2026-06-30.md`
**Date**: 2026-07-01

---

## Change Summary

Locked action slots 4–6 currently display as blank, featureless locked areas. This
addition replaces that blank state with a **preview card**: a grayed-out, non-interactive
rendering of the future action showing its name, a lock icon, a human-readable unlock
requirement, and a live progress indicator. Tapping a locked slot produces a brief
informational nudge rather than doing nothing.

---

## Motivation

Playtesting and comparable title analysis confirm that blank locked slots are the
primary cause of first-5-minute drop-off. The player has no visible goal after
exhausting the 3 base actions. Melvor Idle, Idle Research, Your Chronicle, and Trimps
all show locked content before it is reachable — this is the single highest-impact
retention fix available at this stage of development.

The milestone-gated action slots spec (2026-06-30) defines *what* is behind each
locked slot and *how* it unlocks. This spec defines *how those locked slots look and
behave* until the unlock condition is met.

---

## Design Delta

### Before

- Locked slots 4–6 render as an empty rectangle with a 🔒 icon (or are visually
  indistinguishable from an unused slot).
- Tapping a locked slot: no response.
- Player has no information about what unlocks or how.

### After

- Locked slots 4–6 render a **preview card** at reduced opacity (40–50% alpha).
- The preview card shows: lock icon overlay, action display name, unlock condition
  string, and a small live progress bar.
- Tapping a locked slot: shows a transient toast/label with the shortfall
  ("Need X more choices" / "Need a specific story moment").
- Once the unlock condition is satisfied the slot transitions to the normal active
  state (existing behavior, unchanged).

---

## New Rules / Values

### 1. Preview Card Visual Layout

Each locked slot renders the following layers, top to bottom:

| Layer | Content | Notes |
|---|---|---|
| Background | Same slot background as active slots | Full opacity — slot is clearly present |
| Content group | Action name label + lock icon | 40–50% alpha on the content group |
| Unlock label | Unlock requirement string (see §2) | 40–50% alpha; smaller font than action name |
| Progress bar | Thin bar below unlock label (see §3) | 40–50% alpha |
| Lock icon overlay | Centered 🔒 or padlock sprite | Full opacity — unmistakably locked |

The content group is grayed out, not hidden. The player can read what the action is
called before they unlock it. This is intentional: the name is the goal, not a secret.

**Mobile readability constraint**: minimum touch target for the slot remains 48×48 dp
(ADR-0007). The slot must not shrink to fit the additional labels — the layout must
accommodate them within the existing slot footprint, using smaller font sizes for
secondary text (unlock label, progress bar) if needed.

### 2. Unlock Requirement String (per slot)

The label must be in **English** (project standard — game-ui-language-english.md).
Wording follows the unlock condition type:

| Slot | Action | Unlock condition | Display string |
|---|---|---|---|
| 4 | Record a Collab | `risky_choices_count >= 3` OR `safe_choices_count >= 3` | `"Make 3 choices"` |
| 5 | Give an Interview | `risky_choices_count >= 6` OR `safe_choices_count >= 6` | `"Make 6 choices"` |
| 6 | Launch a Course | `has_milestone("card.staged_drama.chosen_risky")` OR `has_milestone("card.cancel_threat.apologized")` | `"Reach a story moment"` |

**Rationale for simplified wording:**

- Slots 4 and 5 use either-path choice counts. "Make X choices" is true regardless
  of which path the player takes, avoids exposing the risky/safe dichotomy prematurely,
  and is immediately actionable.
- Slot 6 is milestone-gated on named narrative events. The exact milestone IDs are
  implementation details; "Reach a story moment" preserves mystery and is accurate
  without spoiling which specific card triggers it.

### 3. Progress Indicator

**Slots 4 and 5 (choice-count gated):** Show a filling progress bar.

- Track `max(risky_choices_count, safe_choices_count)` — whichever path the player
  is on, show the more favorable count. This is the correct denominator because the
  OR condition means only the higher count matters.
- Display as `current / required` in text alongside the bar: e.g., `"2 / 3 choices"`.
- Bar fills left-to-right; color matches the slot's locked/muted palette (no bright
  colors — this is a secondary UI element).

**Slot 6 (milestone-gated):** No numeric progress bar — milestones are binary
(either you have the story moment or you don't). Replace the bar with a static label:
`"Play story cards to unlock"`. This is honest and does not give a false sense of
measurable progress toward a binary gate.

### 4. Tap Behavior (Locked State)

Tapping a locked slot must never be a dead interaction. Show a transient informational
message (toast / floating label) that auto-dismisses after ~2 seconds:

| Slot | Message (when tapped while locked) |
|---|---|
| 4 | `"Make [N] more choices to unlock"` (N = `3 - max(risky, safe)`) |
| 5 | `"Make [N] more choices to unlock"` (N = `6 - max(risky, safe)`) |
| 6 | `"Unlock by reaching a key story moment"` |

The tap message is supplementary — the progress bar already communicates this for
slots 4/5. For slot 6 it is the primary feedback since there is no bar.

The toast appears within the slot bounds or directly above it — do not obscure other
slots. It must not block the player from tapping the base action slots.

### 5. Unlock Transition

When an unlock condition becomes true (evaluated on `action_grid._ready()` and after
each action returns to `idle`, per the milestone-gated spec):

- Remove the lock overlay and the unlock-requirement label.
- Animate the preview card from locked appearance (40–50% alpha) to full opacity.
- A brief visual signal (e.g., a short flash or a scale-in pulse on the slot) is
  **recommended** — marks the moment without being disruptive. Exact implementation
  left to the UI programmer.

This transition must not interrupt an in-progress action on another slot.

### 6. Data Source

The preview card reads from the same data that the active slot already uses:

- **Action display name**: `ACTION_DISPLAY_NAMES[action_id]` in `action_system.gd`
- **Unlock condition + progress**: `action_unlocks.gd` (already tracks
  `risky_choices_count`, `safe_choices_count`, and milestone presence)
- No new data structures required.

---

## Affected Systems

| System | Impact | Action Required |
|---|---|---|
| `src/ui/action_grid.gd` | Locked slot rendering changes from blank to preview card | Implementation — add locked-state layout; tap handler |
| `src/ui/action_unlocks.gd` | Expose progress values (choice counts, milestone flags) to the grid | Minor extension — current/required values for the progress bar |
| `src/core/action_system.gd` | Read-only (action display names already available) | No change |
| `src/core/resource_manager.gd` | Not used directly — unlock conditions use history flags, not Reach | No change |
| `design/gdd/action-ui.md` | Document locked-slot visual spec | GDD update (see below) |

---

## Acceptance Criteria

- [ ] Fresh game: slots 4–6 are visibly present but locked. Each shows the action name,
      a lock icon overlay, the unlock requirement string, and (for slots 4/5) a progress
      bar at 0 / required.
- [ ] Slot 4 progress bar shows `max(risky, safe) / 3` and updates live after each card
      choice. It reaches full and the slot unlocks when the condition is met.
- [ ] Slot 5 progress bar shows `max(risky, safe) / 6` independently of slot 4's bar.
- [ ] Slot 6 shows `"Play story cards to unlock"` with no numeric bar.
- [ ] Tapping a locked slot produces the correct informational toast (correct N for slots
      4/5; narrative message for slot 6). Toast auto-dismisses; does not block other slots.
- [ ] When an unlock condition is satisfied, the affected slot transitions to active state
      with a visible (non-jarring) animation. The lock overlay and unlock label disappear.
- [ ] The 3 base action slots (1–3) are visually and functionally unchanged.
- [ ] All existing Action Grid and Action Unlocks tests remain green (no regression).
- [ ] Locked slot minimum touch target is ≥ 48×48 dp on the reference Android device.
- [ ] Text in all locked-slot UI elements is English.

---

## GDD Update Required?

**Yes — one file:**

- `design/gdd/action-ui.md` — Add a "Locked Slot Appearance" subsection under the
  Action Grid section, documenting the preview card layout, unlock label strings, progress
  bar logic (choice-count vs. milestone-gated), and tap behavior. Cross-reference this
  quick spec and the milestone-gated spec (2026-06-30).

Requires separate approval before editing.

---

## Pipeline Note

This spec is a pure UI Addition. It introduces no new cross-system contracts and no new
data structures. Implementation goes directly to a story referencing this spec.
Next: `/story-readiness` check, then `/dev-story`.
