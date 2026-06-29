# Story 001: OnboardingGate State Machine

> **Epic**: Onboarding/Tutorial
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M (2-3h)
> **Manifest Version**: 2026-06-20
> **Last Updated**: 2026-06-29

## Context

**GDD**: `design/gdd/onboarding-tutorial.md`
**Requirement**: `TR-onb-001` — Decision Card suppression (Phase 1) and force-cooldown-zero (Phase 1→2) — this story implements the state machine itself, in isolation from real `ActionSystem`/`DecisionCardSystem` signal wiring (Story 002)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0001 (primary — Autoload pattern, multi-subscriber signal fan-out); ADR-0005 (secondary — the `is_card_suppressed()`/`force_cooldown_zero()` contract this state machine drives)
**ADR Decision Summary**: `OnboardingGate` is a new Autoload, pure logic, no signals or UI of its own (per the GDD's own Visual/Audio and UI Requirements sections: "None"). It tracks 3 phases and the set of distinct action types completed, per `architecture.md`'s documented module entry.

**Engine**: Godot 4.6.3 | **Risk**: LOW — pure GDScript state machine, no engine-specific API
**Engine Notes**: None — no post-cutoff APIs.

**Control Manifest Rules (this layer — Core)**:
- Required: PascalCase `class_name` not strictly needed for an Autoload (no other code instantiates it directly), but follow the existing Autoload doc-comment convention (see `decision_card_system.gd`'s header style); static typing throughout
- Forbidden: this story must NOT connect to the real `ActionSystem.action_completed` signal or call into the real `DecisionCardSystem` — that wiring is Story 002's scope. This story's `on_action_completed(action_id)` method is called directly by tests with synthetic IDs.
- Guardrail: O(1) per action-completed call (a set-membership check + enum compare) — negligible

---

## Acceptance Criteria

*From GDD `design/gdd/onboarding-tutorial.md`'s States and Transitions + Acceptance Criteria sections, scoped to this story (the state machine logic; Story 002 wires it to real signals):*

**State transition `phase_pure_action` → `phase_first_card_pending`:**
- [ ] Fresh state, 0 types completed, 1 action completes (any type) → stays `phase_pure_action`
- [ ] 2 distinct types completed, 3rd action is a repeat of an already-completed type → stays `phase_pure_action` (variety not satisfied — count alone doesn't transition)
- [ ] 2 distinct types completed, the previously-untried 3rd type completes → transitions to `phase_first_card_pending` immediately

**Variety-gate (set membership, not count, not order):**
- [ ] The 3 types complete in non-"natural" order → transition fires after the 3rd distinct type regardless of order
- [ ] The same type completes 5 times in a row → stays `phase_pure_action` (count irrelevant, only distinct-type coverage matters)
- [ ] All 6 possible permutations of the 3 types tested → transition fires at the same point (after the 3rd distinct type) in every permutation

**`phase_first_card_pending` → `phase_normal`:**
- [ ] In `phase_first_card_pending`, the next action completes → transitions to `phase_normal`
- [ ] In `phase_normal`, any subsequent action completes → state stays `phase_normal` (terminal, no further transitions)

**Suppression query:**
- [ ] `is_card_suppressed()` returns `true` only in `phase_pure_action`; `false` in `phase_first_card_pending` and `phase_normal`

---

## Implementation Notes

*Derived from ADR-0001's Autoload pattern + ADR-0005's contract + architecture.md's module entry:*

Create `res://src/core/onboarding_gate.gd`, registered as an Autoload (registration itself is Story 002's scope, since it must sit at the correct position in `project.godot` relative to `ActionSystem`/`DecisionCardSystem` — this story can be written and unit-tested as a plain script first).

```gdscript
extends Node

enum Phase { PURE_ACTION, FIRST_CARD_PENDING, NORMAL }

var phase: Phase = Phase.PURE_ACTION
var _completed_types: Dictionary = {}  # set semantics: StringName -> true

const REQUIRED_TYPES: Array[StringName] = [&"nagraj_vloga", &"zrob_drame", &"przeprosiny"]

## Called once per completed action (Story 002 wires this to the real
## ActionSystem.action_completed signal; this story's tests call it directly).
func on_action_completed(action_id: StringName) -> void:
    match phase:
        Phase.PURE_ACTION:
            _completed_types[action_id] = true
            if _completed_types.size() >= REQUIRED_TYPES.size():
                phase = Phase.FIRST_CARD_PENDING
        Phase.FIRST_CARD_PENDING:
            phase = Phase.NORMAL
        Phase.NORMAL:
            pass  # terminal, no further transitions

func is_card_suppressed() -> bool:
    return phase == Phase.PURE_ACTION
```

Confirm the exact 3 action-type `StringName` IDs against `ActionSystem.ACTION_DURATIONS`/`UNLOCKED_ACTION_IDS` (the GDD names them "Nagraj vloga, Zrób dramę, Przeproś w internecie" — Polish-slug internal IDs per the established convention, English-UI display names only) before hardcoding — do not invent new IDs.

`_completed_types` uses Dictionary-as-set (the established project idiom — see `HistoryFlagManager._milestones`), keyed by the action's `StringName` ID; `.size() >= REQUIRED_TYPES.size()` is the variety-gate check (set membership, never a count of total actions).

Note: at the moment the Phase 1→2 transition fires, Story 002's `force_cooldown_zero()` call into `DecisionCardSystem` must happen — but that's an `OnboardingGate`-owns-the-call decision per ADR-0005 ("called by `OnboardingGate` at the Phase 1→2 transition"). This story's `on_action_completed` can include a `# TODO Story 002: force_cooldown_zero() here` marker, or Story 002 can add the call directly at this exact transition point — confirm with Story 002's implementer which approach, but the transition LOGIC (phase flips) belongs here, fully testable without `DecisionCardSystem` existing at all.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002 (Live Wiring): subscribing to the real `ActionSystem.action_completed` signal, calling `DecisionCardSystem.force_cooldown_zero()`, the suppression check inside `DecisionCardSystem._on_action_completed()`, Autoload registration in `project.godot`
- Story 003 (Persistence): `restore_state()`/`serialize_state()`, save/load edge cases, `BootController` wiring

---

## QA Test Cases

*Automated unit-test specs, derived directly from the GDD's exact ACs. Mockable per the GDD's own classification note — no real ActionSystem/DecisionCardSystem needed.*

- **AC: phase_pure_action → phase_first_card_pending (variety, not count)**
  - Given: a fresh `OnboardingGate` instance
  - When: `on_action_completed()` called with various sequences of the 3 type IDs
  - Then: phase transitions exactly when all 3 distinct types have each been seen ≥1 time, never on count alone
  - Edge cases: a repeat of an already-seen type does not count toward the gate; all 6 permutations transition at the same logical point (after the 3rd distinct type)

- **AC: phase_first_card_pending → phase_normal**
  - Given: `OnboardingGate` in `phase_first_card_pending`
  - When: `on_action_completed()` is called once more (any type)
  - Then: phase becomes `phase_normal`; further calls leave it unchanged (terminal)

- **AC: is_card_suppressed()**
  - Given: each phase value
  - When: `is_card_suppressed()` is called
  - Then: `true` only for `phase_pure_action`

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/onboarding/onboarding_gate_state_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (Live Wiring) — connects this state machine to real signals; Story 003 (Persistence) — saves/restores `phase` and `_completed_types`
