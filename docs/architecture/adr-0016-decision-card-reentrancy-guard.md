# ADR-0016: DecisionCardSystem — `inject_priority_card()` Internal Reentrancy Guard

## Status
Proposed

## Date
2026-07-22

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.3 |
| **Domain** | Core |
| **Knowledge Risk** | LOW |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/architecture/adr-0012-prestige-checkpoint-system-autoload-orchestration.md` (original `inject_priority_card()` contract), `docs/architecture/adr-0013-burnout-challenge-system-trigger-and-selection.md` (first caller's external guard) |
| **Post-Cutoff APIs Used** | None — plain GDScript enum comparison, no engine API involved |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0012 (Accepted — defines `inject_priority_card()`'s original contract, which this ADR narrows, not replaces), ADR-0013 (Accepted — `BurnoutSystem._try_inject_burnout_card()`'s existing external `state == COOLDOWN` check, which becomes redundant-but-harmless after this fix) |
| **Enables** | Any future forced-card caller (the function is explicitly general-purpose per its own doc comment) can call `inject_priority_card()` safely without independently replicating `BurnoutSystem`'s external guard |
| **Blocks** | Nothing new — `MainNavCoordinator`'s (ADR-0014) Core Rule 5a coordinator-side no-op remains valid defense-in-depth regardless of this fix landing |
| **Ordering Note** | None — this is an isolated one-function change to already-shipped, already-tested code |

## Context

### Problem Statement

`DecisionCardSystem.inject_priority_card()` (`decision_card_system.gd`) only checks its own `_priority_card_pending` flag before presenting a forced card — it never checks `state`. Today this is harmless: `BurnoutSystem._try_inject_burnout_card()` (the only current caller) externally guards on `DecisionCardSystem.state == DecisionCardSystem.State.COOLDOWN` immediately before calling, with no `await` between the check and the call, so no reachable path exists in shipped code to trigger a double-emission of `card_presented`. But `inject_priority_card()`'s own doc comment states it is general-purpose ("any future forced-card mechanic can call this too") — a future caller that omits `BurnoutSystem`'s external check would get a real double-`card_presented` emission if called while a normal card is already `PRESENTING`/`RESOLVING`. This was found and documented as a real (not hypothetical) bug during Main Navigation/Screen Flow's `/design-review` (verified against shipped code, not assumed) — `MainNavCoordinator`'s planned Core Rule 5a no-op is defense-in-depth on the *symptom*, not a fix at the source.

### Constraints

- Must not change `inject_priority_card()`'s existing public signature (`(card_id: StringName) -> bool`) — callers already handle the `bool` return.
- Must not weaken the existing `_priority_card_pending` check — both guards are needed (a `COOLDOWN`-state check alone would not catch a second priority-card injection attempt while the first priority card is still pending in `PRESENTING`/`RESOLVING`, since state during a priority-card presentation is also `PRESENTING`, not a distinct value).
- Must not touch `burnout_system.gd`'s existing external check — it is already shipped, already tested (Story 002), and becomes harmless redundant defense-in-depth after this fix, not dead code to remove.

### Requirements

- `inject_priority_card()` must return `false` (no-op, matching its existing "no queueing" contract) whenever `state != State.COOLDOWN`, in addition to its existing `_priority_card_pending` check.
- The existing unit test coverage for `inject_priority_card()`'s two current no-op paths (already-pending, unknown `card_id`) must gain a third case: called while `state == PRESENTING`.

## Decision

Add a `state == State.COOLDOWN` check to `inject_priority_card()`, evaluated alongside the existing `_priority_card_pending` check, both as early-return guards before any state mutation.

### Architecture Diagram

```
inject_priority_card(card_id: StringName) -> bool
  if _priority_card_pending: return false          # existing guard, unchanged
  if state != State.COOLDOWN: return false          # NEW — this ADR
  var card := CardContentDatabase.get_card(card_id)
  if card.is_empty(): push_error(...); return false # existing guard, unchanged
  _priority_card_pending = true
  present_next_card([card])
  return true
```

### Key Interfaces

```gdscript
# DecisionCardSystem (Autoload) — inject_priority_card(), guard added
func inject_priority_card(card_id: StringName) -> bool:
    if _priority_card_pending:
        return false
    if state != State.COOLDOWN:
        return false   # NEW — self-contained guard, no longer relies solely on caller discipline
    var card: Dictionary = CardContentDatabase.get_card(card_id)
    if card.is_empty():
        push_error("inject_priority_card(%s): unknown card_id, no-op" % card_id)
        return false
    _priority_card_pending = true
    var pool: Array[Dictionary] = [card]
    present_next_card(pool)
    return true
# Guarantee (revised): false is now returned for every reachable case where injecting would
# double-present a card, regardless of whether the caller independently checked state first.
```

## Alternatives Considered

### Alternative 1: Remove `BurnoutSystem`'s external check, rely solely on the new internal guard
- **Description**: Since `inject_priority_card()` now defends itself, delete the now-redundant `if DecisionCardSystem.state != DecisionCardSystem.State.COOLDOWN: return` in `_try_inject_burnout_card()`.
- **Pros**: Slightly less code.
- **Cons**: `burnout_system.gd`'s existing check also serves a second purpose this ADR doesn't touch — it prevents resetting `_cringe_sustained_seconds` on a failed-due-to-mid-cycle attempt (per its own doc comment: "the trigger condition stays latched, never silently lost"). Removing it would require re-deriving that latch behavior from `inject_priority_card()`'s `false` return instead, an unrelated behavior change to already-shipped, already-tested code, for no correctness benefit.
- **Rejection Reason**: Touches working, tested code for a behavior this ADR doesn't need to change; the redundancy is harmless, not costly.

### Alternative 2: Leave the guard as caller-enforced convention, document it more clearly instead
- **Description**: Add a stronger doc-comment warning instead of a runtime guard.
- **Pros**: Zero code change.
- **Cons**: Doc comments are not enforced — this is exactly the class of bug `/design-review` already found once from an undocumented-enough contract. A future caller (human or agent) can miss a comment; a runtime guard cannot be missed.
- **Rejection Reason**: Matches the project's own precedent for rejecting assert-only guards — `inject_priority_card()`'s existing doc comment explicitly states real runtime guards are required here, "not just an `assert()`," for the identical reason (asserts/comments are insufficient, this must be a real safety rail).

## Consequences

### Positive
- `inject_priority_card()` becomes safe to call from any future forced-card mechanic without requiring every caller to independently replicate `BurnoutSystem`'s external guard.
- Closes the one remaining real (not hypothetical) bug flagged during Main Navigation's `/design-review`, at its actual source rather than only via the coordinator's symptomatic no-op.

### Negative
- None.

### Risks
- None beyond standard regression risk for a one-function, two-line change — mitigated by the required new unit test case (called while `PRESENTING`).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| decision-card-system.md | `inject_priority_card()`'s "no queueing" contract — a second forced-card attempt while one is already active must no-op, not double-present | Internal `state == COOLDOWN` guard now covers this for every caller, not only `BurnoutSystem` |
| main-navigation-screen-flow.md | Open Question — "Naprawa u źródła podwójnego `card_presented` w `DecisionCardSystem`" | This ADR is that source-level fix; `MainNavCoordinator`'s Core Rule 5a no-op remains as independent defense-in-depth, unchanged |

## Performance Implications
- **CPU**: Negligible — one additional enum comparison per call, already an infrequent (forced-card-only) code path.
- **Memory**: None.
- **Load Time**: None.
- **Network**: N/A.

## Migration Plan

1. Add the `state == State.COOLDOWN` guard to `inject_priority_card()` in `decision_card_system.gd`.
2. Add one new unit test case: `inject_priority_card()` called while `state == PRESENTING` (or `RESOLVING`) returns `false` and does not mutate `_priority_card_pending` or emit `card_presented`.
3. No changes to `burnout_system.gd`, `prestige_system.gd`, `challenge_system.gd`, or the Main Navigation GDD/ADR-0014 — this is an isolated fix.

## Validation Criteria

New unit test (`tests/unit/decision_card/...`) asserting the three no-op paths (`_priority_card_pending` already true, unknown `card_id`, `state != COOLDOWN`) all return `false` without mutating `_priority_card_pending` or emitting `card_presented`; existing tests for the success path and the two pre-existing no-op paths must continue passing unchanged.

## Related Decisions
- ADR-0012 (original `inject_priority_card()` contract)
- ADR-0013 (`BurnoutSystem`'s external guard, now redundant-but-harmless)
- ADR-0014 (Main Navigation Coordinator — Core Rule 5a no-op, independent defense-in-depth)
- `design/gdd/main-navigation-screen-flow.md` (Open Question this ADR resolves)
