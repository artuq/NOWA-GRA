# ADR-0005: Decision Card Weighting and Cooldown Implementation

## Status
Accepted (2026-06-20, following independent /architecture-review — verdict CONCERNS overall but no conflicts or blockers against this ADR specifically)

## Date
2026-06-19

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core (Scripting / gameplay logic) |
| **Knowledge Risk** | LOW — pure GDScript math and `RandomNumberGenerator`, no engine-specific API risk; nothing in 4.4-4.6 changes this domain |
| **References Consulted** | `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Autoload architecture — `DecisionCardSystem`'s interface), ADR-0004 (Action System — emits `action_completed`, which drives the cooldown countdown) |
| **Enables** | Card UI implementation (cannot build the Card modal scene until `present_next_card()`'s selection behavior is fixed) |
| **Blocks** | Card UI epic |
| **Ordering Note** | None beyond the above |

## Context

### Problem Statement
`decision-card-system.md` specifies a weighted-random card selection (`card_selection_weight` formula, registered in `entities.yaml`) and a 2-completed-action cooldown between card presentations. `onboarding-tutorial.md` additionally requires this system to be suppressible (Phase 1) and have its cooldown forced to 0 (Phase 2→3 transition). This ADR fixes the concrete GDScript implementation of weighting, cooldown countdown, and the suppression/override hooks Onboarding needs.

### Constraints
- Godot 4.6.3, GDScript, no threading
- Must integrate with `ActionSystem.action_completed` (ADR-0004) as the cooldown-decrement trigger
- Must expose a way for `OnboardingGate` to suppress card presentation and force cooldown to 0, without `DecisionCardSystem` needing to know `OnboardingGate` exists by name (per ADR-0001's "ownership-clear reads" pattern — `DecisionCardSystem` calls `OnboardingGate.is_card_suppressed()`, a direct read, not the reverse)

### Requirements
- Selection must use the exact `card_selection_weight` formula from `entities.yaml`: `weight(card) = base_weight + (current_Cringe / 100) × intensity(card)`
- Cooldown counts completed actions, not elapsed time — explicitly NOT a `Timer`
- `present_next_card()` must be a no-op (not an error) when cooldown hasn't elapsed or `DecisionCardSystem` is suppressed

## Decision

Implement cooldown as an integer counter decremented on every `ActionSystem.action_completed` signal, and card selection as a cumulative-weight roll over `CardContentDatabase.get_all_cards()`, filtered to cards not currently on cooldown-from-recent-use (if such a rule exists — confirmed not needed per `decision-card-system.md`, all 12 cards are always eligible).

```gdscript
# DecisionCardSystem (Autoload)
var _actions_until_next_card: int = DECISION_CARD_COOLDOWN  # 2, from entities.yaml
var current_card: Resource = null  # null when no card presented
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    ActionSystem.action_completed.connect(_on_action_completed)
    _rng.randomize()

func set_seed(s: int) -> void:
    # Test hook only — production code never calls this. Allows tests/unit/
    # to pin _rng to a fixed seed, satisfying coding-standards.md's
    # "no random seeds" determinism rule for the weighted-pick statistical test.
    _rng.seed = s

func _on_action_completed(_action_id: StringName, _rewards: Dictionary) -> void:
    if OnboardingGate.is_card_suppressed():
        return  # Phase 1: don't even decrement, per onboarding-tutorial.md's intent
    if _actions_until_next_card > 0:
        _actions_until_next_card -= 1
        return
    present_next_card()

func present_next_card() -> void:
    if current_card != null:
        return  # single-concurrency: a card is already presented
    current_card = _weighted_pick(CardContentDatabase.get_all_cards())
    _actions_until_next_card = DECISION_CARD_COOLDOWN  # reset for next cycle
    card_presented.emit(current_card)

func force_cooldown_zero() -> void:
    # Called by OnboardingGate at the Phase 1->2 transition (architecture.md Decision: ownership-clear write, OnboardingGate owns this call)
    _actions_until_next_card = 0

func _weighted_pick(cards: Array) -> Resource:
    var current_cringe: float = ResourceManager.get_resource(&"Cringe")
    var weights: Array[float] = []
    var total: float = 0.0
    for card in cards:
        var w: float = BASE_WEIGHT + (current_cringe / 100.0) * card.intensity
        weights.append(w)
        total += w
    var roll := _rng.randf() * total
    var cumulative := 0.0
    for i in cards.size():
        cumulative += weights[i]
        if roll <= cumulative:
            return cards[i]
    return cards[-1]  # float-rounding fallback, never reached in practice

func resolve_choice(option: StringName) -> void:
    var resolved_card := current_card
    current_card = null
    ResourceManager.apply_delta(resolved_card.get_effects(option))
    HistoryFlagManager.record_choice(resolved_card.id, option)
    card_resolved.emit(resolved_card.id, option)
```

### Architecture Diagram
```
ActionSystem.action_completed -> DecisionCardSystem._on_action_completed()
    -> OnboardingGate.is_card_suppressed()?  [ownership-clear read, no signal needed]
        yes -> no-op
        no  -> decrement cooldown counter, or present_next_card() if counter == 0

OnboardingGate (at Phase1->2 transition) -> DecisionCardSystem.force_cooldown_zero()  [direct call, ownership-clear]
```

### Key Interfaces
New methods beyond ADR-0001's baseline: `force_cooldown_zero()` (called by `OnboardingGate` only), `_weighted_pick()` (private, implementation detail). `present_next_card()` and `resolve_choice()` match ADR-0001's signatures unchanged.

## Alternatives Considered

### Alternative A: Cooldown as a `Timer` (time-based)
- **Description**: Use a `Timer` node, cooldown expires after N seconds instead of N actions.
- **Pros**: Reuses the same `Timer` pattern as ADR-0004.
- **Cons**: Directly contradicts `decision-card-system.md`'s explicit "2 completed actions" cooldown definition — actions take 4-9s each, so a time-based cooldown would produce inconsistent card frequency depending on which actions the player chooses, which the GDD's design intent doesn't call for.
- **Rejection Reason**: Wrong unit — the GDD specifies action-count cooldown, not time cooldown. Using a Timer would require translating "2 actions" into an estimated time window, introducing inaccuracy for no benefit.

### Alternative B: Integer counter decremented on `action_completed` — CHOSEN
Described above. Directly matches the GDD's stated cooldown unit (completed actions, not time).

## Consequences

### Positive
- Cooldown behavior matches `decision-card-system.md` exactly — no unit-translation risk
- `force_cooldown_zero()` gives `OnboardingGate` a single, explicit, ownership-clear call — no signal indirection needed for a one-time Phase transition event

### Negative
- None significant

### Risks
- **Risk**: `_weighted_pick()`'s cumulative-weight roll has a float-rounding edge case where the loop could theoretically fall through without selecting a card (extremely rare, sum of floating-point weights not exactly matching `total`).
  - **Mitigation**: `return cards[-1]` fallback at the end of the function guarantees a card is always returned — never a `null` return from `_weighted_pick()`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| decision-card-system.md | `card_selection_weight` formula, cooldown=2 completed actions | `_weighted_pick()` implements the registered formula exactly; `_actions_until_next_card` counts actions, not time |
| onboarding-tutorial.md | Decision Card System suppressed in Phase 1 | `_on_action_completed()` checks `OnboardingGate.is_card_suppressed()` before any cooldown logic runs |
| onboarding-tutorial.md | Cooldown forced to 0 at Phase 1→2 transition | `force_cooldown_zero()`, called by `OnboardingGate` |
| card-ui.md | Single-concurrency (only one card presented at a time) | `present_next_card()`'s `if current_card != null: return` guard |

## Performance Implications
- **CPU**: Negligible — weighted pick is O(12) (card count), runs at most once per 2 actions
- **Memory**: Negligible
- **Load Time**: None
- **Network**: N/A

## Migration Plan
N/A — first implementation.

## Validation Criteria
- Complete 2 actions with no suppression: confirm a card is presented immediately after the 2nd
- Complete actions while `OnboardingGate.is_card_suppressed()` returns true: confirm cooldown never decrements and no card appears
- Call `force_cooldown_zero()`, then complete 1 action: confirm a card presents immediately (not requiring 2 more actions)
- Using `set_seed()` to pin a fixed seed (per coding-standards.md's determinism rule), at `current_Cringe = 100`, run `_weighted_pick()` 1000 times: confirm higher-intensity cards appear proportionally more often than at `current_Cringe = 0` — deterministic and reproducible given the fixed seed

## Related Decisions
- ADR-0001 (Autoload singleton architecture) — defines the interface this ADR implements
- ADR-0004 (Action System) — `action_completed` signal drives this ADR's cooldown countdown
- `design/gdd/onboarding-tutorial.md` — source of the suppression/force-cooldown-zero requirements
