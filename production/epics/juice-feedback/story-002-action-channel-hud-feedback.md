# Story 002: Action Channel — ResourceHud Count-Up + Flash

> **Epic**: Juice/Feedback System
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Integration
> **Estimate**: M (2–3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-07-06

## Context

**GDD**: `design/gdd/juice-feedback-system.md`
**Requirements**: `TR-juice-002` (Action half), `TR-juice-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011: Juice/Feedback Architecture — Stateless FeedbackMath + Additive UI-Node Effects
**ADR Decision Summary**: ResourceHud gains an additive `ActionSystem.action_completed` subscription driving (a) a number count-up tween and (b) a 150–200ms `self_modulate` flash pulse on the pill chrome. No shake, no audio in this channel — structurally absent. Count-up start value is derived from the payload (`start = end − rewards[r]`), and the existing `resource_changed` snap handler skips resources with a live count-up tween (architecture-review advisory, folded into ADR §2).

**Secondary ADRs**: ADR-0007 (ResourceHud zone ownership), ADR-0004 (`action_completed` carries final post-scaling deltas)

**Engine**: Godot 4.6.3 | **Risk**: LOW
**Engine Notes**: `create_tween()`, `self_modulate` — pre-4.3 stable. **Critical**: flash MUST animate the pill's `self_modulate`, NOT `modulate` — `modulate` cascades to the child value Label and tints the number text, violating the GDD's "number stays legible, chrome-only flash" rule (engine-specialist finding, 2026-07-06).

**Control Manifest Rules (Presentation layer)**:
- Required: UI reads via signals/getters, never mutates game state; additive subscription only
- Forbidden: valence-coded feedback (registry, ADR-0011) — ONE neutral flash color token, identical for gains and losses; no red/green variants anywhere
- Guardrail: one tween handle per effect, kill-before-restart (prevents pile-up at the 4–9s action cadence)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria "Two distinct feedback channels" + ADR-0011 §2:*

- [ ] **GIVEN** an `action_completed` event at any magnitude, **THEN** feedback = count-up (fixed duration, magnitude-independent) + pill flash (150–200ms, one neutral token) + **no shake, no audio** (structurally absent from ResourceHud — no shake/audio code exists in this node)
- [ ] **GIVEN** the count-up, **THEN** the displayed number animates from `end − rewards[r]` to `end` — never snapping to `end` first (the `resource_changed` handler skips its snap for a resource with a live/pending count-up tween)
- [ ] **GIVEN** two events of opposite sign but equal magnitude, **THEN** flash color token, flash duration, and count-up duration are identical (no-valence-coding)
- [ ] **GIVEN** a zero-magnitude event (all deltas 0), **THEN** the flash still plays at the lowest tier — never silently skipped
- [ ] **GIVEN** a second action completes while a count-up is mid-flight, **THEN** the previous tween is killed and the new count-up starts from the currently displayed value — no stacking, no visual jump
- [ ] **GIVEN** the flash pulse, **THEN** it animates the pill's `self_modulate` only — the child value Label's own modulate is untouched (number legibility)

---

## Implementation Notes

*From ADR-0011 §2 (read the ADR's Decision section in full before implementing):*

1. In `resource_hud.gd` `_ready()`: `ActionSystem.action_completed.connect(_on_action_completed)` (additive — do not touch existing `resource_changed` wiring beyond the skip-guard below).
2. `_on_action_completed(action_id, rewards)`: for each rewarded resource, start a count-up tween on the value label from `end − rewards[r]` to `end` (fixed short duration matching the Offline Report count-up pattern) + a `self_modulate` pulse on the pill (150–200ms, `# TODO: art-bible-pending` neutral token).
3. `resource_changed` handler: skip the instant snap for any resource with a live (or same-frame pending) count-up tween — the count-up owns that label until it settles.
4. One stored tween handle per resource; `kill()` before restarting (CardScreen bounce-tween precedent).
5. Magnitude (`FeedbackMath.magnitude(rewards)`) currently affects nothing in this channel except being computed for future content scaling — count-up/flash durations are fixed per GDD rule 2. Do not scale durations by magnitude.

---

## Out of Scope

- Story 001: FeedbackMath itself (dependency)
- Story 003: Card channel (pulse/shake/stinger)
- Any shake or audio in ResourceHud — permanently out of scope for this channel per GDD rule 2, not just this story

---

## QA Test Cases

*Derived from GDD §Acceptance Criteria (qa-lead classification in GDD §H: Logic/Integration, BLOCKING).*

- **AC-1**: action event → count-up + flash, no shake
  - Given: ResourceHud instantiated via scene_runner; `action_completed` emitted with `{&"Reach": 5.0, ...}`
  - When: 1 frame simulated
  - Then: value label has a live tween; pill `self_modulate` ≠ WHITE mid-pulse; node position unchanged (no shake)
  - Edge: after tween durations elapse, label shows exact end value and `self_modulate` returns to identity

- **AC-2**: count-up start derivation
  - Given: Reach displayed at X; `apply_delta` fires `resource_changed` (snap suppressed), then `action_completed` with `{&"Reach": +5}`
  - Then: label animates from X to X+5 — assert intermediate displayed value < end value mid-tween

- **AC-3**: sign-invariance of presentation
  - Given: two events, `{&"Cringe": +20}` and `{&"Cringe": -20}`
  - Then: identical flash token/duration and count-up duration (assert the tween parameters/color constants, not subjective look)

- **AC-4**: zero-magnitude still flashes
  - Given: `action_completed` with all-zero deltas
  - Then: flash tween still created and plays

- **AC-5**: tween pile-up guard
  - Given: two `action_completed` events 1 frame apart
  - Then: exactly one live count-up tween per resource; final label == second event's end value

- **AC-6**: `self_modulate` not `modulate`
  - Given: mid-flash frame
  - Then: pill `self_modulate` altered; pill `modulate` == WHITE; value Label `modulate`/`self_modulate` == WHITE

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/action_ui/resource_hud_feedback_test.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (FeedbackMath) must be DONE
- Unlocks: None (Story 003 is parallel, not dependent)

## Completion Notes
**Completed**: 2026-07-06
**Criteria**: 6/6 passing (automated) + 3 gap-closure tests from code review (multi-resource event, clamped-Cringe true-start, unknown-key guard)
**Deviations**: 2 — (1) count-up start derived from cached resource_changed old_value instead of the ADR's payload arithmetic (payload deltas are pre-clamp; code-review WARNING fixed); (2) Morale is flash-only, no count-up (band label would flicker through thresholds mid-tween — design call from code review INFO).
**Test Evidence**: Integration: tests/integration/action_ui/resource_hud_feedback_test.gd (9 tests PASSED); manual spot-checks recorded in production/qa/evidence/juice-card-feel-evidence.md
**Code Review**: Complete — combined epic review; both WARNINGs fixed and covered by new tests
