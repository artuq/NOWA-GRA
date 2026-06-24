# Story 002: Resource HUD

> **Epic**: Action UI
> **Status**: Complete
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-24

## Context

**GDD**: `design/gdd/action-ui.md`
**Requirement**: Resource HUD section of the GDD's Core Rules (no dedicated TR-ID yet — registry-completeness gap, see EPIC.md)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007: Action UI scene structure and Autoload binding pattern (primary); ADR-0001 (secondary — direct-call/signal consumption pattern this ADR applies)
**ADR Decision Summary**: `ResourceHud` is one of 3 sibling Control scripts under the root `ActionScreen`. It connects to `ResourceManager.resource_changed` in `_ready()` and updates only the changed resource's label per signal — never polls, never reads all 5 resources every frame.

**Engine**: Godot 4.6.3 | **Risk**: MEDIUM (ADR-0007's self-rated risk — Control/UI domain, post-cutoff rendering specifics unverified for this use case, though this story uses only stable, pre-4.4 Control/Label/signal primitives)
**Engine Notes**: `Button` (not `TouchScreenButton`) is the correct node type for any interactive elements per ADR-0007's engine specialist review — this story has no buttons, but if any are added later, follow that precedent.

**Control Manifest Rules (this layer)**:
- Required: PascalCase class name (`ResourceHud`), snake_case file name (`resource_hud.gd`), scene file PascalCase matching root node
- Forbidden: Calling another zone's script directly (ADR-0007's "no cross-zone coupling" decision) — this zone only ever talks to `ResourceManager`
- Guardrail: No polling — signal-driven updates only

---

## Acceptance Criteria

*From GDD `design/gdd/action-ui.md`, scoped to this story:*

- [ ] Given valid state, when the screen renders, the Resource HUD zone is present (one of the screen's 3 zones)
- [ ] Given the Resource HUD renders, when all 5 resources are provided, all 5 display simultaneously
- [ ] The Morale indicator communicates the band (High/Normal/Low/Critical), not the raw percentage
- [ ] Resource values are formatted via `ActionUIFormatting.format_number()` (Story 001) — e.g. 28,412 displays as "28.4K"

---

## Implementation Notes

*Derived from ADR-0007's Implementation Guidelines:*

Create `res://scenes/action_screen/resource_hud.tscn` (root `Control`, script `resource_hud.gd`, `class_name ResourceHud`) as one of 3 children under the `ActionScreen` root scene. This story creates the `ActionScreen` root scene file itself (`res://scenes/action_screen/action_screen.tscn`) since it's the first zone implemented — Stories 003 and 004 add their zones as siblings under the same root.

In `_ready()`: connect to `ResourceManager.resource_changed(name: StringName, new_value: float, old_value: float)` and update only the Label matching `name`. Read each resource's initial value directly via `ResourceManager.get_resource()` once at `_ready()` to populate the HUD's starting state (the signal only fires on *changes*, not on initial state).

For the Morale band label: derive the band (High ≥70 / Normal 40-69 / Low 15-39 / Critical 0-14) using the same boundary values `ResourceFormulas.action_effectiveness_multiplier()` already encodes (`E_FULL_THRESHOLD`, `E_HIGH_THRESHOLD`, `E_LOW_THRESHOLD` constants) — do not hardcode duplicate boundary numbers in this UI script; reference the existing constants from `ResourceFormulas` directly to avoid drift between the formula's bands and the HUD's displayed band.

**Performance**: signal-driven, O(1) work per `resource_changed` emission (one label update) — no per-frame cost, unlike Story 004's `RunningActionOverlay` which is the only zone using `_process()`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003 (Action Grid): the action buttons themselves, separate sibling zone
- Story 004 (Running Action Overlay): the progress bar overlay, separate sibling zone
- Story 001 (Number Formatting): this story calls `ActionUIFormatting.format_number()`, does not implement it

---

## QA Test Cases

*Test specs reused/adapted from `production/qa/qa-plan-sprint-6-2026-06-24.md`'s Manual QA Checklist (UI story type — manual verification, not automated).*

- **Manual check: Resource HUD displays all 5 resources simultaneously**
  - Setup: run `action_screen.tscn` directly in the Godot editor with `ResourceManager` populated with non-zero test values for all 5 resources
  - Verify: all 5 resource labels show their current value, correctly formatted (e.g. a value of 28,412 shows "28.4K")
  - Pass condition: all 5 visible at once, no missing/overlapping labels

- **Manual check: Morale shows a band label, not raw percentage**
  - Setup: set Morale to 4 test values, one per band (e.g. 90, 50, 25, 5)
  - Verify: the displayed label reads "High"/"Normal"/"Low"/"Critical" respectively, never a raw number like "50%"
  - Pass condition: correct band label at all 4 boundary-representative values, including the inclusive-lower-bound cases (exactly 70, exactly 40, exactly 15)

- **Manual check: HUD updates live on resource change**
  - Setup: with the scene running, call `ResourceManager.apply_delta({&"Reach": 100.0})` from the Godot editor's remote debugger or a temporary test button
  - Verify: only the Reach label updates; the other 4 labels do not flicker/reflow
  - Pass condition: single-label update, no full-HUD redraw

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- `tests/integration/action_ui/resource_hud_interaction_test.gd` — interaction test using GdUnit4's `scene_runner()` (chosen over a manual evidence doc, since this session cannot actually view a rendered scene — see `docs/tech-debt-register.md` 2026-06-24 entry)

**Status**: [x] Created — 4/4 passing

---

## Dependencies

- Depends on: Story 001 (Number Formatting & Progress Bar Math) — must be DONE first, this story calls `ActionUIFormatting.format_number()`
- Unlocks: Story 003 (Action Grid), Story 004 (Running Action Overlay) — both add siblings under this story's `ActionScreen` root scene

---

## Completion Notes
**Completed**: 2026-06-24
**Criteria**: 4/4 passing (none deferred)
**Deviations**: 1 advisory, fully documented in 2 places (this file, `docs/tech-debt-register.md`) — evidence method changed from manual walkthrough doc to automated `scene_runner()` interaction test, now standing approach for all UI stories in this epic
**Test Evidence**: UI — `tests/integration/action_ui/resource_hud_interaction_test.gd`, 6/6 passing (full regression 186/186 passing)
**Code Review**: Complete — `/code-review` APPROVED (engine specialist CLEAN; qa-tester found 1 real gap, fixed — teardown/dangling-connection test; 1 flagged "isolation bug" analyzed and found not real)
